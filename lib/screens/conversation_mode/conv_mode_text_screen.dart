import 'package:flutter/material.dart';

class ConversationModeTextScreen extends StatefulWidget {
  const ConversationModeTextScreen({super.key});

  @override
  State<ConversationModeTextScreen> createState() => _ConversationModeTextScreenState();
}

class _ConversationModeTextScreenState extends State<ConversationModeTextScreen> {
  final TextEditingController _controller = TextEditingController();
  final List<Map<String, dynamic>> _messages = [];
  String _mode = "Text";

  void _sendMessage() {
    if (_controller.text.trim().isEmpty) return;
    setState(() {
      _messages.add({
        'text': _controller.text.trim(),
        'isUser': true,
        'time': TimeOfDay.now().format(context),
      });
      _controller.clear();

      // Simulate reply
      Future.delayed(const Duration(milliseconds: 500), () {
        setState(() {
          _messages.add({
            'text': _mode == "Text"
                ? "Got it! ($_mode mode)"
                : _mode == "Sign"
                    ? "🤟 (Sign mode response)"
                    : "🎤 (Voice mode response)",
            'isUser': false,
            'time': TimeOfDay.now().format(context),
          });
        });
      });
    });
  }

  Widget _buildMessageBubble(Map<String, dynamic> message) {
    bool isUser = message['isUser'];
    return Align(
      alignment: isUser ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: 6, horizontal: 12),
        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
        decoration: BoxDecoration(
          color: isUser
              ? const Color(0xFF155DFC)
              : const Color(0xFFF3F4F6),
          borderRadius: BorderRadius.circular(14),
        ),
        child: Column(
          crossAxisAlignment:
              isUser ? CrossAxisAlignment.end : CrossAxisAlignment.start,
          children: [
            Text(
              message['text'],
              style: TextStyle(
                color: isUser ? Colors.white : Colors.black,
                fontSize: 16,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              message['time'],
              style: const TextStyle(
                color: Colors.grey,
                fontSize: 12,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildModeSelector() {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 16),
      color: const Color(0xFFEFF6FF),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: ['Text', 'Sign', 'Voice'].map((mode) {
          bool isSelected = _mode == mode;
          return GestureDetector(
            onTap: () {
              setState(() => _mode = mode);
            },
            child: Container(
              padding:
                  const EdgeInsets.symmetric(vertical: 8, horizontal: 24),
              decoration: BoxDecoration(
                color: isSelected ? const Color(0xFFEBEBEB) : Colors.white,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(
                  color: isSelected ? Colors.purple : Colors.transparent,
                  width: 1,
                ),
              ),
              child: Text(
                mode,
                style: TextStyle(
                  fontSize: 14,
                  color: Colors.black87,
                  fontWeight:
                      isSelected ? FontWeight.bold : FontWeight.normal,
                ),
              ),
            ),
          );
        }).toList(),
      ),
    );
  }

  Widget _buildInputBar() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border(
          top: BorderSide(color: Colors.grey.shade300),
        ),
      ),
      child: Row(
        children: [
          Expanded(
            child: TextField(
              controller: _controller,
              decoration: InputDecoration(
                hintText: "Type a message...",
                contentPadding: const EdgeInsets.symmetric(
                    horizontal: 16, vertical: 10),
                filled: true,
                fillColor: const Color(0xFFF9FAFB),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(16),
                  borderSide:
                      const BorderSide(color: Color(0xFFE5E7EB), width: 1.2),
                ),
              ),
            ),
          ),
          const SizedBox(width: 10),
          GestureDetector(
            onTap: _sendMessage,
            child: Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [Color(0xFFAC46FF), Color(0xFFE50076)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(16),
                boxShadow: const [
                  BoxShadow(
                    color: Color(0x19000000),
                    blurRadius: 6,
                    offset: Offset(0, 4),
                  ),
                ],
              ),
              child: const Icon(Icons.send, color: Colors.white),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 1,
        title: Row(
          children: [
            const CircleAvatar(
              backgroundColor: Color(0xFF980FFA),
              child: Text("JD", style: TextStyle(color: Colors.black)),
            ),
            const SizedBox(width: 12),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: const [
                Text("John Doe",
                    style: TextStyle(color: Colors.black, fontSize: 18)),
                Text("Online",
                    style: TextStyle(color: Colors.grey, fontSize: 14)),
              ],
            ),
          ],
        ),
      ),
      body: Column(
        children: [
          _buildModeSelector(),
          Expanded(
            child: ListView.builder(
              reverse: true,
              itemCount: _messages.length,
              itemBuilder: (context, index) {
                final reversedIndex = _messages.length - 1 - index;
                return _buildMessageBubble(_messages[reversedIndex]);
              },
            ),
          ),
          _buildInputBar(),
        ],
      ),
    );
  }
}