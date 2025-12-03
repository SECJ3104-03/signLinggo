import 'dart:io';
import 'package:flutter/material.dart';
import 'package:camera/camera.dart';
import 'package:video_player/video_player.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:supabase_flutter/supabase_flutter.dart'; 

class ConversationScreen extends StatefulWidget {
  final String chatName;
  final String avatar;
  final bool isOnline;
  final String conversationId;
  final String currentUserID;

  const ConversationScreen({
    super.key,
    required this.chatName,
    required this.avatar,
    required this.conversationId,
    required this.currentUserID,
    this.isOnline = false,
  });


  @override
  State<ConversationScreen> createState() => _ConversationScreenState();
}


class _ConversationScreenState extends State<ConversationScreen> {
  String _mode = "Text";
  final TextEditingController _textController = TextEditingController();


  CameraController? _cameraController;
  List<CameraDescription> _cameras = [];
  bool _isRecording = false;
  final Map<String, VideoPlayerController> _videoControllers = {};

  late final String currentUserId;

  @override
  void initState() {
    super.initState();
    currentUserId = FirebaseAuth.instance.currentUser?.uid ?? "user1"; // Initialize Firebase Auth user ID
    if (_mode == 'Sign') _initCamera();
  }

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
      _initCamera();
    }
  }

  Future<void> _initCamera() async {
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

  // ---------------- Firestore Message Stream ----------------
  Stream<List<Map<String, dynamic>>> _messageStream() {
    return FirebaseFirestore.instance
        .collection('conversations')
        .doc(widget.conversationId)
        .collection('messages')
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map((snapshot) => snapshot.docs.map((doc) {
              final data = doc.data();
              data['isUser'] = data['senderId'] == currentUserId;
              return data;
            }).toList());
  }

  // ---------------- Message Handling ----------------
  void _sendTextMessage() async {
    final text = _textController.text.trim();
    if (text.isEmpty) return;

    final messageRef = FirebaseFirestore.instance
        .collection('conversations')
        .doc(widget.conversationId)
        .collection('messages')
        .doc();

    await messageRef.set({
      'messageId': messageRef.id,
      'senderId': currentUserId,
      'content': text,
      'type': 'text',
      'isRead': false,
      'createdAt': FieldValue.serverTimestamp(),
    });

    // Update conversation lastMessage
    await FirebaseFirestore.instance
        .collection('conversations')
        .doc(widget.conversationId)
        .set({
      'lastMessage': text,
      'lastMessageAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));

    _textController.clear();
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

  final videoFile = File(video.path);

  //Upload video to Supabase
  final videoURL = await _uploadVideoToSupabase(videoFile);
  if (videoURL == null) return;

  //Store message in Firestore
  final messageRef = FirebaseFirestore.instance
      .collection('conversations')
      .doc(widget.conversationId)
      .collection('messages')
      .doc();

  await messageRef.set({
    'messageId': messageRef.id,
    'senderId': currentUserId,
    'content': videoURL,
    'type': 'video',
    'isRead': false,
    'createdAt': FieldValue.serverTimestamp(),
  });

  //Initialize video controller to play
  final controller = VideoPlayerController.networkUrl(Uri.parse(videoURL))
    ..initialize().then((_) => setState(() {}));
  _videoControllers[videoURL] = controller;
}

  void _sendVoiceMessage() async {
    // Implement voice recording + upload if needed
    // For now, just a placeholder message
    final messageRef = FirebaseFirestore.instance
        .collection('conversations')
        .doc(widget.conversationId)
        .collection('messages')
        .doc();

    await messageRef.set({
      'messageId': messageRef.id,
      'senderId': currentUserId,
      'content': '[Voice]',
      'type': 'voice',
      'isRead': false,
      'createdAt': FieldValue.serverTimestamp(),
    });
  }

  Future<String?> _uploadVideoToSupabase(File videoFile) async {
    try {
      final fileName = 'videos/${DateTime.now().millisecondsSinceEpoch}.mp4';

      await Supabase.instance.client.storage
          .from('videoMessage')
          .upload(fileName, videoFile);

      final url = Supabase.instance.client.storage
          .from('videoMessage')
          .getPublicUrl(fileName);

      return url;
    } catch (e) {
      debugPrint('Supabase upload exception: $e');
      return null;
    }
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
              padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 28),
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
                    borderSide: const BorderSide(color: Color(0xFFE5E7EB), width: 1.2),
                  ),
                ),
              ),
            ),
            const SizedBox(width: 16),
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
        child: GestureDetector(
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
              _isRecording ? Icons.stop : Icons.videocam,
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

  Widget _buildVideoBubble(VideoPlayerController controller, bool isUser) {
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
        child: SizedBox(
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
      ),
    );
  }

  Widget _buildVoiceBubble(String content, bool isUser) {
    return Align(
      alignment: isUser ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        margin: const EdgeInsets.symmetric(vertical: 6),
        decoration: BoxDecoration(
          color: isUser ? Colors.blue[50] : Colors.grey[200],
          borderRadius: BorderRadius.circular(16),
        ),
        child: Text(content),
      ),
    );
  }

  Widget _buildUserMessage(Map<String, dynamic> msg) {
    final bool isUser = msg['isUser'];
    switch (msg['type']) {
      case 'text':
        return _buildTextBubble(msg['content'], isUser);
      case 'video':
        final videoURL = msg['content'] as String;
        final controller = _videoControllers[videoURL] ??
            VideoPlayerController.network(videoURL)
              ..initialize().then((_) => setState(() {}));
        _videoControllers[videoURL] = controller;
        return _buildVideoBubble(controller, isUser);
      case 'voice':
        return _buildVoiceBubble(msg['content'], isUser);
      default:
        return const SizedBox.shrink();
    }
  }

  Widget _buildBotMessage(Map<String, dynamic> msg) {
    return _buildUserMessage(msg); // Treat other user messages the same way
  }

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
          children: [
            Stack(
              children: [
                CircleAvatar(
                  backgroundColor: const Color(0xFF980FFA),
                  child: Text(widget.avatar, style: const TextStyle(color: Colors.white)),
                ),
                if (widget.isOnline)
                  Positioned(
                    bottom: 0,
                    right: 0,
                    child: Container(
                      width: 12,
                      height: 12,
                      decoration: BoxDecoration(
                        color: Colors.green,
                        shape: BoxShape.circle,
                        border: Border.all(color: Colors.white, width: 2),
                      ),
                    ),
                  ),
              ],
            ),
            const SizedBox(width: 12),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(widget.chatName, style: const TextStyle(color: Colors.black, fontSize: 18)),
                Text(widget.isOnline ? "Online" : "Offline",
                    style: const TextStyle(color: Colors.grey, fontSize: 14)),
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
                child: StreamBuilder<List<Map<String, dynamic>>>(
                  stream: _messageStream(),
                  builder: (context, snapshot) {
                    if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());
                    final messages = snapshot.data!;
                    return ListView.builder(
                      reverse: true,
                      padding: const EdgeInsets.all(12),
                      itemCount: messages.length,
                      itemBuilder: (context, index) {
                        final msg = messages[index];
                        return msg['isUser'] ? _buildUserMessage(msg) : _buildBotMessage(msg);
                      },
                    );
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