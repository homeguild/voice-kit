import 'package:flutter/material.dart';

/// Voice transcript display showing real-time transcription.
///
/// Features:
/// - Interim results (grey, italic) — real-time feedback
/// - Final results (dark) — confirmed transcription
/// - Auto-scroll as text appears
/// - Optional clear button
class VoiceTranscriptDisplay extends StatefulWidget {
  final String? interimTranscript;
  final String? finalTranscript;
  final VoidCallback? onClear;
  final double maxHeight;
  final bool showClearButton;

  const VoiceTranscriptDisplay({
    Key? key,
    this.interimTranscript,
    this.finalTranscript,
    this.onClear,
    this.maxHeight = 120,
    this.showClearButton = true,
  }) : super(key: key);

  @override
  State<VoiceTranscriptDisplay> createState() =>
      _VoiceTranscriptDisplayState();
}

class _VoiceTranscriptDisplayState extends State<VoiceTranscriptDisplay> {
  final ScrollController _scrollController = ScrollController();

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  @override
  void didUpdateWidget(VoiceTranscriptDisplay oldWidget) {
    super.didUpdateWidget(oldWidget);

    if (widget.interimTranscript != oldWidget.interimTranscript ||
        widget.finalTranscript != oldWidget.finalTranscript) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (_scrollController.hasClients) {
          _scrollController.animateTo(
            _scrollController.position.maxScrollExtent,
            duration: const Duration(milliseconds: 200),
            curve: Curves.easeOut,
          );
        }
      });
    }
  }

  bool get _hasContent =>
      (widget.finalTranscript?.isNotEmpty ?? false) ||
      (widget.interimTranscript?.isNotEmpty ?? false);

  @override
  Widget build(BuildContext context) {
    if (!_hasContent) return const SizedBox.shrink();

    return Container(
      constraints: BoxConstraints(maxHeight: widget.maxHeight),
      decoration: BoxDecoration(
        color: Colors.grey[50],
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey[300]!, width: 1),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: Colors.grey[100],
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(12),
                topRight: Radius.circular(12),
              ),
            ),
            child: Row(
              children: [
                Icon(Icons.transcribe, size: 16, color: Colors.grey[600]),
                const SizedBox(width: 8),
                Text(
                  'Transcript',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: Colors.grey[700],
                  ),
                ),
                const Spacer(),
                if (widget.showClearButton && widget.onClear != null)
                  InkWell(
                    onTap: widget.onClear,
                    borderRadius: BorderRadius.circular(4),
                    child: Padding(
                      padding: const EdgeInsets.all(4),
                      child: Icon(Icons.close, size: 16, color: Colors.grey[600]),
                    ),
                  ),
              ],
            ),
          ),

          // Transcript content
          Flexible(
            child: SingleChildScrollView(
              controller: _scrollController,
              padding: const EdgeInsets.all(12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (widget.finalTranscript != null &&
                      widget.finalTranscript!.isNotEmpty)
                    Text(
                      widget.finalTranscript!,
                      style: const TextStyle(
                        fontSize: 15,
                        color: Colors.black87,
                        height: 1.4,
                      ),
                    ),
                  if (widget.interimTranscript != null &&
                      widget.interimTranscript!.isNotEmpty) ...[
                    if (widget.finalTranscript != null &&
                        widget.finalTranscript!.isNotEmpty)
                      const SizedBox(height: 4),
                    Text(
                      widget.interimTranscript!,
                      style: TextStyle(
                        fontSize: 15,
                        color: Colors.grey[600],
                        fontStyle: FontStyle.italic,
                        height: 1.4,
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Compact transcript for inline use.
class VoiceTranscriptDisplayCompact extends StatelessWidget {
  final String transcript;
  final bool isFinal;

  const VoiceTranscriptDisplayCompact({
    Key? key,
    required this.transcript,
    this.isFinal = false,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    if (transcript.isEmpty) return const SizedBox.shrink();

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: isFinal ? Colors.blue[50] : Colors.grey[100],
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        children: [
          Icon(
            isFinal ? Icons.check_circle : Icons.mic,
            size: 16,
            color: isFinal ? Colors.blue[700] : Colors.grey[600],
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              transcript,
              style: TextStyle(
                fontSize: 14,
                color: isFinal ? Colors.blue[900] : Colors.grey[700],
                fontStyle: isFinal ? FontStyle.normal : FontStyle.italic,
              ),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }
}

/// Bubble-style transcript for chat-like UI.
class VoiceTranscriptBubble extends StatelessWidget {
  final String transcript;
  final bool isFinal;
  final bool isUser;

  const VoiceTranscriptBubble({
    Key? key,
    required this.transcript,
    this.isFinal = false,
    this.isUser = true,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    if (transcript.isEmpty) return const SizedBox.shrink();

    final bubbleColor = isUser
        ? (isFinal ? Colors.blue[600] : Colors.blue[300])
        : Colors.grey[300];
    final textColor = isUser ? Colors.white : Colors.black87;

    return Align(
      alignment: isUser ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: 4),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        constraints: BoxConstraints(
          maxWidth: MediaQuery.of(context).size.width * 0.75,
        ),
        decoration: BoxDecoration(
          color: bubbleColor,
          borderRadius: BorderRadius.circular(18),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (!isFinal) ...[
              SizedBox(
                width: 12,
                height: 12,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  valueColor: AlwaysStoppedAnimation<Color>(textColor),
                ),
              ),
              const SizedBox(width: 8),
            ],
            Flexible(
              child: Text(
                transcript,
                style: TextStyle(
                  fontSize: 15,
                  color: textColor,
                  fontStyle: isFinal ? FontStyle.normal : FontStyle.italic,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
