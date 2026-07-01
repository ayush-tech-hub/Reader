import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../platform/native_channels.dart';

const _channel = MethodChannel(NativeChannels.speech);

/// A mic-icon button that triggers Android speech recognition and calls
/// [onResult] with the transcribed text (null if cancelled or unavailable).
class VoiceSearchButton extends StatefulWidget {
  const VoiceSearchButton({
    super.key,
    required this.onResult,
    this.prompt = 'Speak your search…',
    this.tooltip = 'Search by voice',
  });

  final ValueChanged<String?> onResult;
  final String prompt;
  final String tooltip;

  @override
  State<VoiceSearchButton> createState() => _VoiceSearchButtonState();
}

class _VoiceSearchButtonState extends State<VoiceSearchButton> {
  bool _listening = false;

  Future<void> _listen() async {
    if (_listening) return;
    setState(() => _listening = true);
    try {
      final result = await _channel.invokeMethod<String>(
        'listen',
        {'prompt': widget.prompt},
      );
      widget.onResult(result);
    } on PlatformException {
      widget.onResult(null);
    } finally {
      if (mounted) setState(() => _listening = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return IconButton(
      tooltip: widget.tooltip,
      icon: _listening
          ? const _PulsingMic()
          : const Icon(Icons.mic_none),
      onPressed: _listening ? null : _listen,
    );
  }
}

class _PulsingMic extends StatefulWidget {
  const _PulsingMic();

  @override
  State<_PulsingMic> createState() => _PulsingMicState();
}

class _PulsingMicState extends State<_PulsingMic>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 700),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _ctrl,
      builder: (_, __) => Icon(
        Icons.mic,
        color: Color.lerp(
          Theme.of(context).colorScheme.primary,
          Theme.of(context).colorScheme.error,
          _ctrl.value,
        ),
      ),
    );
  }
}
