import 'package:flutter/material.dart';

class ConversationModeSignScreen extends StatefulWidget {
  const ConversationModeSignScreen({super.key});

  @override
  State<ConversationModeSignScreen> createState() =>
      _ConversationModeSignScreenState();
}

class _ConversationModeSignScreenState
    extends State<ConversationModeSignScreen> {
  final List<Map<String, dynamic>> _messages = [];
  bool _isCameraOn = false;

  void _toggleCamera() {
    setState(() {
      _isCameraOn = !_isCameraOn;
    });
  }

  void _simulateReply() {
    setState(() {
      _messages.add({
        'text': '🤟 Recognized sign: “Hello”',
        'isUser': false,
        'time': TimeOfDay.now().format(context),
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
          color: isUser ? const Color(0xFF155DFC) : const Color(0xFFF3F4F6),
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
              style: const TextStyle(color: Colors.grey, fontSize: 12),
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
          bool isSelected = mode == 'Sign';
          return Container(
            padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 24),
            decoration: BoxDecoration(
              color: isSelected ? const Color(0xFFEBEBEB) : Colors.white,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(
                color: isSelected ? Colors.purple : Colors.transparent,
              ),
            ),
            child: Text(
              mode,
              style: TextStyle(
                fontSize: 14,
                fontWeight:
                    isSelected ? FontWeight.bold : FontWeight.normal,
              ),
            ),
          );
        }).toList(),
      ),
    );
  }

  Widget _buildCameraPreview() {
    return GestureDetector(
      onTap: _toggleCamera,
      child: Container(
        margin: const EdgeInsets.all(16),
        height: 200,
        decoration: BoxDecoration(
          color: Colors.black12,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: Colors.grey.shade400),
        ),
        child: Center(
          child: _isCameraOn
              ? const Text(
                  '📸 Camera On (Simulated)',
                  style: TextStyle(color: Colors.green, fontSize: 16),
                )
              : const Text(
                  'Tap to activate camera for sign recognition',
                  style: TextStyle(color: Colors.black54, fontSize: 16),
                  textAlign: TextAlign.center,
                ),
        ),
      ),
    );
  }

  Widget _buildInputBar() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border(
          top: BorderSide(color: Colors.grey.shade300),
        ),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          const Text(
            "Show your sign to the camera...",
            style: TextStyle(color: Colors.black54, fontSize: 16),
          ),
          GestureDetector(
            onTap: _simulateReply,
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
              child: const Icon(Icons.camera_alt, color: Colors.white),
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
          _buildCameraPreview(),
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