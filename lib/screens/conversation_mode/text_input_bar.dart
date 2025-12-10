import 'package:flutter/material.dart';

class TextInputBar extends StatefulWidget {
  final Future<void> Function(String content, String type, String previewText) onSend;

  const TextInputBar({super.key, required this.onSend});

  @override
  State<TextInputBar> createState() => _TextInputBarState();
}

class _TextInputBarState extends State<TextInputBar> {
  final TextEditingController _textController = TextEditingController();

  void _handleSend() {
    final text = _textController.text.trim();
    if (text.isEmpty) return;
    
    widget.onSend(text, 'text', text); 
    _textController.clear();
  }

  @override
  void dispose() {
    _textController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 20),
      color: Colors.white,
      child: Row(
        children: [
          Expanded(
            child: TextField(
              controller: _textController,
              decoration: InputDecoration(
                hintText: "Type a message...",
                filled: true,
                fillColor: const Color(0xFFF9FAFB),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(20),
                  borderSide: const BorderSide(color: Color(0xFFE5E7EB), width: 1.2),
                ),
              ),
              onSubmitted: (_) => _handleSend(),
            ),
          ),
          const SizedBox(width: 16),
          GestureDetector(
            onTap: _handleSend,
            child: Container(
              width: 56,
              height: 56,
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [Color(0xFFAC46FF), Color(0xFFE50076)],
                ),
                borderRadius: BorderRadius.circular(16),
              ),
              child: const Icon(Icons.send, color: Colors.white, size: 28),
            ),
          ),
        ],
      ),
    );
  }
}