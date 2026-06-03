import 'package:flutter/material.dart';
import '../src/models/voice_conversation_state.dart';

/// Voice status indicator showing current conversation state.
///
/// Displays a color-coded badge with icon, status text, and optional
/// animated wave indicators.
class VoiceStatusIndicator extends StatelessWidget {
  final VoiceConversationState state;
  final String? customMessage;

  const VoiceStatusIndicator({
    Key? key,
    required this.state,
    this.customMessage,
  }) : super(key: key);

  Color _getBackgroundColor() {
    switch (state) {
      case VoiceConversationState.idle:
        return Colors.grey[300]!;
      case VoiceConversationState.listening:
        return Colors.red[100]!;
      case VoiceConversationState.processing:
        return Colors.orange[100]!;
      case VoiceConversationState.speaking:
        return Colors.green[100]!;
    }
  }

  Color _getTextColor() {
    switch (state) {
      case VoiceConversationState.idle:
        return Colors.grey[700]!;
      case VoiceConversationState.listening:
        return Colors.red[900]!;
      case VoiceConversationState.processing:
        return Colors.orange[900]!;
      case VoiceConversationState.speaking:
        return Colors.green[900]!;
    }
  }

  IconData _getIcon() {
    switch (state) {
      case VoiceConversationState.idle:
        return Icons.mic_none;
      case VoiceConversationState.listening:
        return Icons.mic;
      case VoiceConversationState.processing:
        return Icons.pending;
      case VoiceConversationState.speaking:
        return Icons.volume_up;
    }
  }

  String _getStatusText() {
    if (customMessage != null) return customMessage!;

    switch (state) {
      case VoiceConversationState.idle:
        return 'Tap to speak';
      case VoiceConversationState.listening:
        return 'Listening...';
      case VoiceConversationState.processing:
        return 'Processing...';
      case VoiceConversationState.speaking:
        return 'Speaking...';
    }
  }

  @override
  Widget build(BuildContext context) {
    final bgColor = _getBackgroundColor();
    final textColor = _getTextColor();

    return AnimatedContainer(
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeInOut,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(_getIcon(), color: textColor, size: 20),
          const SizedBox(width: 8),
          Text(
            _getStatusText(),
            style: TextStyle(
              color: textColor,
              fontWeight: FontWeight.w600,
              fontSize: 14,
            ),
          ),
          if (state == VoiceConversationState.processing) ...[
            const SizedBox(width: 12),
            SizedBox(
              width: 16,
              height: 16,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                valueColor: AlwaysStoppedAnimation<Color>(textColor),
              ),
            ),
          ],
          if (state == VoiceConversationState.listening)
            Padding(
              padding: const EdgeInsets.only(left: 12),
              child: _WaveIndicator(color: textColor, barCount: 3),
            ),
          if (state == VoiceConversationState.speaking)
            Padding(
              padding: const EdgeInsets.only(left: 12),
              child: _WaveIndicator(
                color: textColor,
                barCount: 4,
                duration: const Duration(milliseconds: 800),
                reverse: true,
              ),
            ),
        ],
      ),
    );
  }
}

/// Full-width banner version for prominent display.
class VoiceStatusBanner extends StatelessWidget {
  final VoiceConversationState state;
  final String? customMessage;
  final VoidCallback? onDismiss;

  const VoiceStatusBanner({
    Key? key,
    required this.state,
    this.customMessage,
    this.onDismiss,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      child: Row(
        children: [
          Expanded(
            child: VoiceStatusIndicator(
              state: state,
              customMessage: customMessage,
            ),
          ),
          if (onDismiss != null)
            IconButton(
              icon: Icon(Icons.close, size: 20, color: Colors.grey[700]),
              onPressed: onDismiss,
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints(),
            ),
        ],
      ),
    );
  }
}

/// Animated wave indicator used for listening/speaking states.
class _WaveIndicator extends StatefulWidget {
  final Color color;
  final int barCount;
  final Duration duration;
  final bool reverse;

  const _WaveIndicator({
    required this.color,
    this.barCount = 3,
    this.duration = const Duration(milliseconds: 1200),
    this.reverse = false,
  });

  @override
  State<_WaveIndicator> createState() => _WaveIndicatorState();
}

class _WaveIndicatorState extends State<_WaveIndicator>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(vsync: this, duration: widget.duration)
      ..repeat(reverse: widget.reverse);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        return Row(
          mainAxisSize: MainAxisSize.min,
          children: List.generate(widget.barCount, (index) {
            final delay = index * 0.15;
            final value = (_controller.value - delay).abs();
            final height = 4.0 + (value * 8);

            return Container(
              width: widget.barCount == 4 ? 2.5 : 3,
              height: height.clamp(4.0, widget.barCount == 4 ? 14.0 : 12.0),
              margin: const EdgeInsets.symmetric(horizontal: 1),
              decoration: BoxDecoration(
                color: widget.color,
                borderRadius: BorderRadius.circular(2),
              ),
            );
          }),
        );
      },
    );
  }
}
