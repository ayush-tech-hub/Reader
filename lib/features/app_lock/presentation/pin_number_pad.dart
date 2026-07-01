import 'package:flutter/material.dart';

/// Numeric keypad used by the app-lock and PIN-setup screens.
class PinNumberPad extends StatelessWidget {
  const PinNumberPad({
    super.key,
    required this.onDigit,
    required this.onBackspace,
  });

  final ValueChanged<String> onDigit;
  final VoidCallback onBackspace;

  @override
  Widget build(BuildContext context) {
    const rows = [
      ['1', '2', '3'],
      ['4', '5', '6'],
      ['7', '8', '9'],
    ];

    return Column(
      children: [
        for (final row in rows)
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children:
                row.map((d) => _PadButton(label: d, onTap: onDigit)).toList(),
          ),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const SizedBox(width: 88),
            _PadButton(label: '0', onTap: onDigit),
            SizedBox(
              width: 88,
              height: 72,
              child: IconButton(
                icon: const Icon(Icons.backspace_outlined),
                onPressed: onBackspace,
              ),
            ),
          ],
        ),
      ],
    );
  }
}

class _PadButton extends StatelessWidget {
  const _PadButton({required this.label, required this.onTap});
  final String label;
  final ValueChanged<String> onTap;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 88,
      height: 72,
      child: TextButton(
        style: TextButton.styleFrom(
          textStyle: const TextStyle(fontSize: 24, fontWeight: FontWeight.w400),
          shape: const CircleBorder(),
        ),
        onPressed: () => onTap(label),
        child: Text(label),
      ),
    );
  }
}
