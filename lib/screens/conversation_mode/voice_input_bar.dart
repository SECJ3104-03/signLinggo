import 'package:flutter/material.dart';

class VoiceInputBar extends StatelessWidget {
  final Future<void> Function(String content, String type, String previewText) onSend;

  const VoiceInputBar({super.key, required this.onSend});

  void _handleSend() {
    // In a real app, this would trigger a voice recording and upload
    // For now, it sends the placeholder text.
    onSend('[Voice]', 'voice', 'Sent a voice message');
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      color: Colors.white,
      child: GestureDetector(
        onTap: _handleSend,
        child: Container(
          width: double.infinity,
          height: 56,
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              colors: [Color(0xFFAC46FF), Color(0xFFE50076)],
            ),
            borderRadius: BorderRadius.circular(16),
          ),
          child: const Icon(Icons.mic, color: Colors.white, size: 28),
        ),
      ),
    );
  }
}