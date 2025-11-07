import 'package:flutter/material.dart';

class ConversationModeVoice extends StatefulWidget {
  const ConversationModeVoice({super.key});

  @override
  State<ConversationModeVoice> createState() => _ConversationModeVoiceState();
}

class _ConversationModeVoiceState extends State<ConversationModeVoice>
    with SingleTickerProviderStateMixin {
  bool _isRecording = false;
  late AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(milliseconds: 600),
      vsync: this,
      lowerBound: 0.8,
      upperBound: 1.2,
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _toggleRecording() {
    setState(() {
      _isRecording = !_isRecording;
    });
    if (_isRecording) {
      _controller.repeat(reverse: true);
    } else {
      _controller.stop();
      _controller.value = 1.0;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 2,
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
          // Mode selector
          Container(
            padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
            color: const Color(0xFFEFF6FF),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                _buildModeButton("Text", false),
                _buildModeButton("Sign", false),
                _buildModeButton("Voice", true),
              ],
            ),
          ),

          // Chat area
          Expanded(
            child: ListView(
              padding: const EdgeInsets.all(16),
              children: [
                _buildIncoming("Show sign", "🤟 Sign detected", "10:30 AM"),
                _buildOutgoing("Got it! Voice mode active", "10:31 AM"),
                _buildIncoming("Hide sign", "🎧 Listening...", "10:32 AM"),
              ],
            ),
          ),

          // Bottom mic bar
          Container(
            decoration: BoxDecoration(
              border: Border(top: BorderSide(color: Colors.grey.shade300)),
              color: Colors.white,
            ),
            padding: const EdgeInsets.symmetric(vertical: 12),
            child: Center(
              child: ScaleTransition(
                scale: _controller,
                child: GestureDetector(
                  onTap: _toggleRecording,
                  child: Container(
                    width: 64,
                    height: 64,
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        colors: [Color(0xFFAC46FF), Color(0xFFE50076)],
                      ),
                      shape: BoxShape.circle,
                      boxShadow: const [
                        BoxShadow(
                          color: Color(0x19000000),
                          blurRadius: 10,
                          offset: Offset(0, 6),
                        ),
                      ],
                    ),
                    child: Icon(
                      _isRecording ? Icons.mic : Icons.mic_none,
                      color: Colors.white,
                      size: 32,
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildModeButton(String label, bool selected) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 8),
      decoration: BoxDecoration(
        color: selected ? const Color(0xFFEBEBEB) : Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: selected ? Colors.purple : Colors.transparent,
          width: 1.2,
        ),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: Colors.black87,
          fontSize: 14,
          fontWeight: selected ? FontWeight.bold : FontWeight.normal,
        ),
      ),
    );
  }

  Widget _buildIncoming(String title, String content, String time) {
    return Align(
      alignment: Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.only(bottom: 16),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: const Color(0xFFF3F4F6),
          borderRadius: BorderRadius.circular(14),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title,
                style: const TextStyle(
                    color: Color(0xFF980FFA),
                    fontSize: 16,
                    fontWeight: FontWeight.w500)),
            const SizedBox(height: 8),
            Text(content, style: const TextStyle(fontSize: 15)),
            const SizedBox(height: 6),
            Text(time,
                style: const TextStyle(color: Colors.grey, fontSize: 12)),
          ],
        ),
      ),
    );
  }

  Widget _buildOutgoing(String content, String time) {
    return Align(
      alignment: Alignment.centerRight,
      child: Container(
        margin: const EdgeInsets.only(bottom: 16),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: const Color(0xFF155DFC),
          borderRadius: BorderRadius.circular(14),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Text(content,
                style: const TextStyle(color: Colors.white, fontSize: 15)),
            const SizedBox(height: 6),
            Text(time,
                style: const TextStyle(color: Colors.white70, fontSize: 12)),
          ],
        ),
      ),
    );
  }
}