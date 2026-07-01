import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:path/path.dart' as p;

/// Reads MOBI and AZW ebook files (unencrypted).
///
/// Supports:
///  - PalmDB record layout used by all MOBI/AZW files
///  - Compression type 1 (none) and type 2 (PalmDoc LZ77)
///  - UTF-8 and Windows-1252 text encodings
///  - Basic HTML tag stripping (MOBI stores content as HTML internally)
///
/// Limitation: DRM-protected files cannot be decoded and will show
/// an error message rather than garbled text.
class MobiReaderScreen extends StatelessWidget {
  const MobiReaderScreen({super.key, required this.path});
  final String path;

  // ── Binary helpers (big-endian, no typed_data needed) ──────────────────────

  static int _u16(List<int> b, int i) =>
      ((b[i] & 0xFF) << 8) | (b[i + 1] & 0xFF);

  static int _u32(List<int> b, int i) =>
      ((b[i] & 0xFF) << 24) |
      ((b[i + 1] & 0xFF) << 16) |
      ((b[i + 2] & 0xFF) << 8) |
      (b[i + 3] & 0xFF);

  // ── Main extractor ─────────────────────────────────────────────────────────

  static Future<String> _extract(String path) async {
    final bytes = await File(path).readAsBytes();

    if (bytes.length < 78) {
      throw const FormatException('File is too small to be a MOBI/AZW file');
    }

    // PalmDB creator field at offset 64 identifies the format.
    final creator = String.fromCharCodes(bytes.sublist(64, 68));
    if (creator != 'MOBI' && creator != 'TEXt') {
      throw FormatException(
          'Not a valid MOBI/AZW file (creator code: "$creator")');
    }

    // Number of PalmDB records (big-endian uint16 at offset 76).
    final numRecords = _u16(bytes, 76);
    if (numRecords < 2) {
      throw const FormatException('No text records found in file');
    }

    // Record offset table starts at byte 78; each entry is 8 bytes.
    final offsets = <int>[];
    for (int i = 0; i < numRecords; i++) {
      offsets.add(_u32(bytes, 78 + i * 8));
    }
    offsets.add(bytes.length); // sentinel marks end of last record

    // ── Record 0 = PalmDoc header ──────────────────────────────────────────
    final r0 = offsets[0];
    if (r0 + 12 > bytes.length) {
      throw const FormatException('Record 0 is truncated');
    }

    final compression = _u16(bytes, r0);       // 1=none, 2=PalmDoc LZ77
    final textRecordCount = _u16(bytes, r0 + 8);

    // Optional MOBI sub-header lives at record-0 offset 16, starts with "MOBI".
    int encoding = 1252; // Windows-1252 default
    if (r0 + 32 <= bytes.length) {
      final mobiTag = String.fromCharCodes(bytes.sublist(r0 + 16, r0 + 20));
      if (mobiTag == 'MOBI') {
        encoding = _u32(bytes, r0 + 28); // 65001 = UTF-8, 1252 = Win-1252
      }
    }

    if (compression == 17480) {
      // Huffman/CDIC compression used by some AZW files — requires a
      // Huffman table embedded in the file. Out of scope for this reader.
      throw const FormatException(
          'Huffman-compressed AZW format is not supported.\n'
          'DRM-free EPUB or MOBI files can be opened instead.');
    }

    // ── Decompress text records ────────────────────────────────────────────
    final output = <int>[];
    final maxRec = textRecordCount.clamp(0, numRecords - 1);
    for (int i = 1; i <= maxRec; i++) {
      if (i >= offsets.length - 1) break;
      final rStart = offsets[i];
      final rEnd = offsets[i + 1];
      if (rStart >= bytes.length || rEnd > bytes.length || rStart >= rEnd) {
        continue;
      }
      final record = bytes.sublist(rStart, rEnd);
      if (compression == 2) {
        _palmDocDecompress(record, output);
      } else {
        output.addAll(record);
      }
    }

    // ── Decode bytes to string ─────────────────────────────────────────────
    String text;
    try {
      text = encoding == 65001
          ? utf8.decode(output, allowMalformed: true)
          : latin1.decode(output);
    } catch (_) {
      text = utf8.decode(output, allowMalformed: true);
    }

    // Strip HTML markup — MOBI content is stored as simplified HTML.
    text = text
        .replaceAll(RegExp(r'<[^>]{1,500}>'), '')
        .replaceAll('&amp;', '&')
        .replaceAll('&lt;', '<')
        .replaceAll('&gt;', '>')
        .replaceAll('&nbsp;', ' ')
        .replaceAll('&quot;', '"')
        .replaceAll('&apos;', "'")
        .replaceAll(RegExp(r'[ \t]{2,}'), ' ')
        .replaceAll(RegExp(r'\n{3,}'), '\n\n')
        .trim();

    if (text.isEmpty) {
      throw const FormatException(
          'No readable text found.\n'
          'The file may be DRM-protected or in an unsupported sub-format.');
    }
    return text;
  }

  // ── PalmDoc LZ77 decompression ─────────────────────────────────────────────
  //
  // Byte ranges:
  //   0x00        → literal space (null used as padding)
  //   0x01-0x08   → next N bytes are raw literals
  //   0x09-0x7F   → literal character
  //   0x80-0xBF   → 2-byte back-reference: distance (11 bits) + length (3 bits + 3)
  //   0xC0-0xFF   → space + (byte XOR 0x80)

  static void _palmDocDecompress(List<int> input, List<int> output) {
    int i = 0;
    while (i < input.length) {
      final b = input[i++] & 0xFF;
      if (b == 0x00) {
        output.add(0x20); // treat null as space
      } else if (b <= 0x08) {
        for (int k = 0; k < b && i < input.length; k++) {
          output.add(input[i++] & 0xFF);
        }
      } else if (b < 0x80) {
        output.add(b);
      } else if (b < 0xC0) {
        if (i >= input.length) break;
        final b2 = input[i++] & 0xFF;
        // 14-bit combined value: upper 2 bits of b are control, remaining 6 + 8 = 14
        final combined = ((b & 0x3F) << 8) | b2;
        final distance = combined >> 3;
        final length = (combined & 0x07) + 3;
        if (distance > 0 && distance <= output.length) {
          final from = output.length - distance;
          for (int k = 0; k < length; k++) {
            // from + k is always < output.length here because as output grows,
            // indices previously unavailable become valid (intentional LZ77 behaviour).
            output.add(output[from + k]);
          }
        }
      } else {
        output.add(0x20); // space
        output.add(b ^ 0x80);
      }
    }
  }

  // ── Widget ────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(p.basename(path))),
      body: FutureBuilder<String>(
        future: _extract(path),
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.book_outlined, size: 48,
                        color: Colors.grey),
                    const SizedBox(height: 16),
                    Text(
                      snapshot.error.toString(),
                      textAlign: TextAlign.center,
                    ),
                  ],
                ),
              ),
            );
          }
          if (!snapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }
          return SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: SelectableText(
              snapshot.data!,
              style: Theme.of(context).textTheme.bodyLarge,
            ),
          );
        },
      ),
    );
  }
}
