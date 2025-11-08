import 'dart:io';
import 'package:flutter/material.dart';
import 'package:camera/camera.dart';
import 'package:video_player/video_player.dart';

class ConversationScreen extends StatefulWidget {
  const ConversationScreen({super.key});

  @override
  State<ConversationScreen> createState() => _ConversationScreenState();
}

class _ConversationScreenState extends State<ConversationScreen> {
  String _mode = "Text";
  final List<Map<String, dynamic>> _messages = [];
  final TextEditingController _textController = TextEditingController();

  CameraController? _cameraController;
  List<CameraDescription> _cameras = [];
  bool _isRecording = false;
  final Map<String, VideoPlayerController> _videoControllers = {};

  @override
  void dispose() {
    _cameraController?.dispose();
    _videoControllers.forEach((k, v) => v.dispose());
    _textController.dispose();
    super.dispose();
  }

  // ---------------- Mode Switching ----------------
  void _switchMode(String mode) async {
    if (_mode == mode) return;

    if (_mode == 'Sign') {
      await _cameraController?.dispose();
      _cameraController = null;
      _cameras = [];
      _isRecording = false;
    }

    setState(() => _mode = mode);

    if (_mode == 'Sign') {
      try {
        _cameras = await availableCameras();
        if (_cameras.isNotEmpty) {
          _cameraController =
              CameraController(_cameras.first, ResolutionPreset.medium);
          await _cameraController?.initialize();
          if (mounted) setState(() {});
        }
      } catch (e) {
        debugPrint("Error initializing camera: $e");
      }
    }
  }

  // ---------------- Message Handling ----------------
  void _sendTextMessage() {
    final text = _textController.text.trim();
    if (text.isEmpty) return;

    setState(() {
      _messages.add({
        'type': 'text',
        'content': text,
        'isUser': true,
      });
      _textController.clear();
    });

    _botReply(text);
  }

  Future<void> _startSignRecording() async {
    if (_cameraController == null || _isRecording) return;
    await _cameraController!.startVideoRecording();
    setState(() => _isRecording = true);
  }

  Future<void> _stopSignRecording() async {
    if (_cameraController == null || !_isRecording) return;
    final video = await _cameraController!.stopVideoRecording();
    setState(() => _isRecording = false);

    final controller = VideoPlayerController.file(File(video.path))
      ..initialize().then((_) => setState(() {}));
    _videoControllers[video.path] = controller;

    setState(() {
      _messages.add({
        'type': 'video',
        'video': video,
        'controller': controller,
        'translation': 'Translated text of your sign',
        'isUser': true,
      });
    });

    _botReply('Bot reply for sign video');
  }

  void _sendVoiceMessage() {
    setState(() {
      _messages.add({
        'type': 'voice',
        'content': '[Voice]',
        'translation': 'Transcribed voice text',
        'isUser': true,
      });
    });

    _botReply('[Bot reply for voice]');
  }

  void _botReply(String userMsg) {
    setState(() {
      _messages.add({
        'type': 'bot',
        'text': userMsg,
        'signVideo': null,
        'isUser': false,
      });
    });
  }

  // ---------------- UI Components ----------------
  Widget _buildModeSelector() {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 16),
      color: const Color(0xFFEFF6FF),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: ['Text', 'Sign', 'Voice'].map((mode) {
          final isSelected = _mode == mode;
          return GestureDetector(
            onTap: () => _switchMode(mode),
            child: Container(
              padding:
                  const EdgeInsets.symmetric(vertical: 10, horizontal: 24),
              decoration: BoxDecoration(
                color: isSelected ? Colors.purple[50] : Colors.white,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(
                    color: isSelected ? Colors.purple : Colors.transparent,
                    width: 1.5),
              ),
              child: Text(
                mode,
                style: TextStyle(
                  fontSize: 15,
                  fontWeight:
                      isSelected ? FontWeight.bold : FontWeight.normal,
                  color: isSelected ? Colors.purple[800] : Colors.black87,
                ),
              ),
            ),
          );
        }).toList(),
      ),
    );
  }

  Widget _buildCameraOverlay() {
    if (!_isRecording || _cameraController == null || !_cameraController!.value.isInitialized) {
    return const SizedBox.shrink();
  }

  return Center(
    child: Container(
      width: 200,
      height: 200,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        border: Border.all(color: Colors.white70, width: 3),
        boxShadow: [
          BoxShadow(color: Colors.black26, blurRadius: 6, offset: Offset(0, 3))
        ],
      ),
      child: ClipOval(
        child: CameraPreview(_cameraController!),
      ),
    ),
  );
}

  Widget _buildInputBar() {
    if (_mode == 'Text') {
      return Container(
        padding: const EdgeInsets.all(12),
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
                    borderSide:
                        const BorderSide(color: Color(0xFFE5E7EB), width: 1.2),
                  ),
                ),
              ),
            ),
            const SizedBox(width: 8),
            GestureDetector(
              onTap: _sendTextMessage,
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
    } else if (_mode == 'Voice') {
      return Container(
        padding: const EdgeInsets.all(12),
        color: Colors.white,
        child:GestureDetector(
          onTap: _sendVoiceMessage,
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
    } else if (_mode == 'Sign') {
      return Container(
        padding: const EdgeInsets.all(12),
        color: Colors.white,
        child: GestureDetector(
          onTap: _isRecording ? _stopSignRecording : _startSignRecording,
          child: Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(vertical: 16),
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              colors: [Color(0xFFAC46FF), Color(0xFFE50076)],
            ),
            borderRadius: BorderRadius.circular(20),
          ),
          alignment: Alignment.center,
          child: Icon(
            _isRecording ? Icons.stop : Icons.videocam, // change icon based on state
            color: Colors.white,
            size: 28,
          ),
        ),
      ),
    );
  }
    return const SizedBox.shrink();
  }

  Widget _buildTextBubble(String text, bool isUser) {
    return Align(
      alignment: isUser ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        padding: const EdgeInsets.all(12),
        margin: const EdgeInsets.symmetric(vertical: 6),
        decoration: BoxDecoration(
          color: isUser ? Colors.blue[50] : Colors.grey[200],
          borderRadius: BorderRadius.circular(16),
        ),
        child: Text(
          text,
          style: TextStyle(
              fontSize: 15, color: isUser ? Colors.blue[900] : Colors.black87),
        ),
      ),
    );
  }

  Widget _buildVideoBubble(
      VideoPlayerController controller, String translation, bool isUser) {
    final width = MediaQuery.of(context).size.width * 0.55;
    return Align(
      alignment: isUser ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        width: width,
        padding: const EdgeInsets.all(6),
        margin: const EdgeInsets.symmetric(vertical: 6),
        decoration: BoxDecoration(
          color: isUser ? Colors.blue[50] : Colors.grey[200],
          borderRadius: BorderRadius.circular(16),
        ),
        child: Column(
          crossAxisAlignment:
              isUser ? CrossAxisAlignment.end : CrossAxisAlignment.start,
          children: [
            SizedBox(
              height: 150,
              child: controller.value.isInitialized
                  ? Stack(
                      alignment: Alignment.center,
                      children: [
                        ClipRRect(
                          borderRadius: BorderRadius.circular(16),
                          child: VideoPlayer(controller),
                        ),
                        IconButton(
                          icon: Icon(
                            controller.value.isPlaying
                                ? Icons.pause_circle
                                : Icons.play_circle,
                            size: 48,
                            color: Colors.white70,
                          ),
                          onPressed: () {
                            setState(() {
                              controller.value.isPlaying
                                  ? controller.pause()
                                  : controller.play();
                            });
                          },
                        )
                      ],
                    )
                  : const Center(child: CircularProgressIndicator()),
            ),
            if (translation.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(top: 4),
                child: Text(
                  translation,
                  style: const TextStyle(fontSize: 13, color: Colors.grey),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildVoiceBubble(String content, String translation, bool isUser) {
    return Align(
      alignment: isUser ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        margin: const EdgeInsets.symmetric(vertical: 6),
        decoration: BoxDecoration(
          color: isUser ? Colors.blue[50] : Colors.grey[200],
          borderRadius: BorderRadius.circular(16),
        ),
        child: Column(
          crossAxisAlignment:
              isUser ? CrossAxisAlignment.end : CrossAxisAlignment.start,
          children: [
            Text(
              content,
              style: TextStyle(
                  fontSize: 15,
                  color: isUser ? Colors.blue[900] : Colors.black87),
            ),
            if (translation.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(top: 4),
                child: Text(
                  translation,
                  style: const TextStyle(fontSize: 13, color: Colors.grey),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildUserMessage(Map<String, dynamic> msg) {
    if (msg['type'] == 'text') {
      return _buildTextBubble(msg['content'], true);
    } else if (msg['type'] == 'video') {
      return _buildVideoBubble(msg['controller'], msg['translation'], true);
    } else if (msg['type'] == 'voice') {
      return _buildVoiceBubble(msg['content'], msg['translation'], true);
    }
    return const SizedBox.shrink();
  }

  Widget _buildBotMessage(Map<String, dynamic> msg) {
    msg.putIfAbsent('showSign', () => false);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildTextBubble(msg['text'], false),
        if (msg['showSign'] && msg['signVideo'] != null)
          _buildVideoBubble(msg['signVideo'], '', false),
        Container(
          margin: const EdgeInsets.only(top: 4),
          child: GestureDetector(
            onTap: () {
              setState(() {
                msg['showSign'] = !(msg['showSign'] ?? false);
                if (msg['showSign'] && msg['signVideo'] == null) {
                  final controller = VideoPlayerController.asset(
                      'assets/sample_sign.mp4') // replace with actual sign video
                    ..initialize().then((_) => setState(() {}));
                  _videoControllers['bot_${msg.hashCode}'] = controller;
                  msg['signVideo'] = controller;
                }
              });
            },
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              child: Text(
                msg['showSign'] == true ? 'Hide Sign' : 'Show Sign',
                style: const TextStyle(
                    color: Color(0xFFAC46FF)),
              ),
            ),
          ),
        ),
      ],
    );
  }

  // ---------------- Build ----------------
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 1,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.black87),
          onPressed: () => Navigator.pop(context),
        ),
        title: Row(
          children: const [
            CircleAvatar(
              backgroundColor: Color(0xFF980FFA),
              child: Text("JD", style: TextStyle(color: Colors.black)),
            ),
            SizedBox(width: 12),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text("John Doe",
                    style: TextStyle(color: Colors.black, fontSize: 18)),
                Text("Online",
                    style: TextStyle(color: Colors.grey, fontSize: 14)),
              ],
            ),
          ],
        ),
      ),
      backgroundColor: Colors.white,
      body: Stack(
        children: [
          Column(
            children: [
              _buildModeSelector(),
              Expanded(
                child: ListView.builder(
                  reverse: true,
                  padding: const EdgeInsets.all(12),
                  itemCount: _messages.length,
                  itemBuilder: (context, index) {
                    final reversedIndex = _messages.length - 1 - index;
                    final msg = _messages[reversedIndex];
                    return msg['isUser']
                        ? _buildUserMessage(msg)
                        : _buildBotMessage(msg);
                  },
                ),
              ),
              _buildInputBar(),
            ],
          ),
          if (_mode == 'Sign') _buildCameraOverlay(),
        ],
      ),
    );
  }
}