import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../src/models/voice_conversation_state.dart';

/// Voice input button with push-to-talk interaction.
///
/// Visual states:
/// - Idle (grey): Ready to listen
/// - Listening (red): Recording speech with pulse animation
/// - Processing (orange): Backend is processing
/// - Speaking (green): TTS is playing
class VoiceInputButton extends StatefulWidget {
  final VoiceConversationState state;
  final VoidCallback onStart;
  final VoidCallback onStop;
  final VoidCallback? onCancel;
  final double size;
  final double audioLevel; // 0.0 to 1.0

  const VoiceInputButton({
    Key? key,
    required this.state,
    required this.onStart,
    required this.onStop,
    this.onCancel,
    this.size = 72.0,
    this.audioLevel = 0.0,
  }) : super(key: key);

  @override
  State<VoiceInputButton> createState() => _VoiceInputButtonState();
}

class _VoiceInputButtonState extends State<VoiceInputButton>
    with SingleTickerProviderStateMixin {
  late AnimationController _pulseController;
  late Animation<double> _pulseAnimation;

  @override
  void initState() {
    super.initState();

    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1000),
    )..repeat(reverse: true);

    _pulseAnimation = Tween<double>(begin: 1.0, end: 1.2).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _pulseController.dispose();
    super.dispose();
  }

  @override
  void didUpdateWidget(VoiceInputButton oldWidget) {
    super.didUpdateWidget(oldWidget);

    if (widget.state == VoiceConversationState.listening) {
      if (!_pulseController.isAnimating) {
        _pulseController.repeat(reverse: true);
      }
    } else {
      if (_pulseController.isAnimating) {
        _pulseController.stop();
        _pulseController.value = 0;
      }
    }
  }

  Color _getStateColor() {
    switch (widget.state) {
      case VoiceConversationState.idle:
        return Colors.grey[400]!;
      case VoiceConversationState.listening:
        return Colors.red[400]!;
      case VoiceConversationState.processing:
        return Colors.orange[400]!;
      case VoiceConversationState.speaking:
        return Colors.green[400]!;
    }
  }

  IconData _getStateIcon() {
    switch (widget.state) {
      case VoiceConversationState.idle:
      case VoiceConversationState.listening:
        return Icons.mic;
      case VoiceConversationState.processing:
        return Icons.hourglass_empty;
      case VoiceConversationState.speaking:
        return Icons.volume_up;
    }
  }

  void _handleTap() {
    HapticFeedback.mediumImpact();

    switch (widget.state) {
      case VoiceConversationState.idle:
        widget.onStart();
      case VoiceConversationState.listening:
        widget.onStop();
      case VoiceConversationState.processing:
        break;
      case VoiceConversationState.speaking:
        widget.onCancel?.call();
    }
  }

  @override
  Widget build(BuildContext context) {
    final color = _getStateColor();
    final icon = _getStateIcon();
    final isListening = widget.state == VoiceConversationState.listening;

    return GestureDetector(
      onTap: _handleTap,
      child: AnimatedBuilder(
        animation: _pulseAnimation,
        builder: (context, child) {
          final scale = isListening ? _pulseAnimation.value : 1.0;

          return Container(
            width: widget.size,
            height: widget.size,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(
                  color: color.withValues(alpha: 0.3),
                  blurRadius: 8,
                  spreadRadius: isListening ? 4 : 2,
                ),
              ],
            ),
            child: Transform.scale(
              scale: scale,
              child: Stack(
                alignment: Alignment.center,
                children: [
                  Container(
                    width: widget.size,
                    height: widget.size,
                    decoration: BoxDecoration(
                      color: color,
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      icon,
                      color: Colors.white,
                      size: widget.size * 0.5,
                    ),
                  ),
                  if (isListening && widget.audioLevel > 0)
                    Container(
                      width: widget.size + (widget.audioLevel * 20),
                      height: widget.size + (widget.audioLevel * 20),
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: color.withValues(alpha: 0.5),
                          width: 2,
                        ),
                      ),
                    ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}

/// Compact voice button for headers/toolbars.
class VoiceInputButtonCompact extends StatelessWidget {
  final VoiceConversationState state;
  final VoidCallback onPressed;

  const VoiceInputButtonCompact({
    Key? key,
    required this.state,
    required this.onPressed,
  }) : super(key: key);

  Color _getStateColor() {
    switch (state) {
      case VoiceConversationState.idle:
        return Colors.grey;
      case VoiceConversationState.listening:
        return Colors.red;
      case VoiceConversationState.processing:
        return Colors.orange;
      case VoiceConversationState.speaking:
        return Colors.green;
    }
  }

  IconData _getStateIcon() {
    switch (state) {
      case VoiceConversationState.idle:
      case VoiceConversationState.listening:
        return Icons.mic;
      case VoiceConversationState.processing:
        return Icons.hourglass_empty;
      case VoiceConversationState.speaking:
        return Icons.volume_up;
    }
  }

  @override
  Widget build(BuildContext context) {
    return IconButton(
      icon: Icon(
        _getStateIcon(),
        color: _getStateColor(),
      ),
      onPressed: () {
        HapticFeedback.lightImpact();
        onPressed();
      },
      tooltip: 'Voice input',
    );
  }
}
