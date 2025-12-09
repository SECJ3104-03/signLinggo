import 'dart:io';
import 'package:flutter/material.dart';
import 'package:camera/camera.dart';
import 'package:video_player/video_player.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:signlinggo/services/video_upload_service.dart';

import 'text_input_bar.dart';
import 'sign_input_bar.dart';
import 'voice_input_bar.dart';

class ConversationScreen extends StatefulWidget {
  final String chatName;
  final String avatar;
  final String conversationId;
  final String currentUserID;

  const ConversationScreen({
    super.key,
    required this.chatName,
    required this.avatar,
    required this.conversationId,
    required this.currentUserID,
  });

  @override
  State<ConversationScreen> createState() => _ConversationScreenState();
}

class _ConversationScreenState extends State<ConversationScreen> {
  String _mode = "Text";
  final Map<String, VideoPlayerController> _videoControllers = {};

  CameraController? _cameraController;
  List<CameraDescription> _cameras = [];
  bool _isRecording = false;

  late final String currentUserId;

  @override
  void initState() {
    super.initState();
    currentUserId = widget.currentUserID;
    if (_mode == 'Sign') _initCamera();
  }

  @override
  void dispose() {
    _cameraController?.dispose();
    _videoControllers.forEach((k, v) => v.dispose());
    super.dispose();
  }

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

  Future<void> _sendVideoMessage(File videoFile) async {
    final videoURL = await uploadVideoViaSignedUrl(videoFile);
    if (videoURL == null) return;

    await _sendMessage(videoURL, 'video', 'Sent a video');

    final controller = VideoPlayerController.networkUrl(Uri.parse(videoURL))
      ..initialize().then((_) => setState(() {}));
    _videoControllers[videoURL] = controller;
  }

  Future<void> _updateConversationDocument(String lastMessage) async {
    final conversationIds = widget.conversationId.split('_');

    final otherUserID = conversationIds.firstWhere(
        (id) => id != widget.currentUserID,
        orElse: () => '');

    final updateData = {
      'lastMessage': lastMessage,
      'lastMessageAt': FieldValue.serverTimestamp(),
      'userIDs': conversationIds,
      'otherUserID': otherUserID,
    };

    await FirebaseFirestore.instance
        .collection('conversation')
        .doc(widget.conversationId)
        .set(updateData, SetOptions(merge: true));
  }
  
  Future<String?> _uploadVideoToSupabase(File videoFile) async {
    try {
      final fileName = 'videos/${DateTime.now().millisecondsSinceEpoch}.mp4';

      await Supabase.instance.client.storage
          .from('videoMessage')
          .upload(
            fileName,
            videoFile,
            fileOptions: const FileOptions(upsert: true),
          );

      final url = Supabase.instance.client.storage
          .from('videoMessage')
          .getPublicUrl(fileName);

      debugPrint('Video uploaded: $url');
      return url;
    } catch (e) {
      debugPrint('Video upload exception: $e');
      return null;
    }
  }

  Future<void> _sendMessage(
      String content, String type, String previewText) async {
    final messageRef = FirebaseFirestore.instance
        .collection('conversation')
        .doc(widget.conversationId)
        .collection('messages')
        .doc();

    await messageRef.set({
      'messageId': messageRef.id,
      'senderId': currentUserId,
      'content': content,
      'type': type,
      'isRead': false,
      'createdAt': FieldValue.serverTimestamp(),
    });

    await _updateConversationDocument(previewText);
  }

  Stream<List<Map<String, dynamic>>> _messageStream() {
    return FirebaseFirestore.instance
        .collection('conversation')
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

  Widget _buildCameraOverlay() {
    return const SizedBox.shrink(); 
  }

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
                  fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                  color: isSelected ? Colors.purple[800] : Colors.black87,
                ),
              ),
            ),
          );
        }).toList(),
      ),
    );
  }

  Widget _buildInputBar() {
    switch (_mode) {
      case 'Text':
        return TextInputBar(onSend: _sendMessage);
      case 'Voice':
        return VoiceInputBar(onSend: _sendMessage);
      case 'Sign':
        return SignInputBar(
          isParentRecording: _isRecording,
          cameraController: _cameraController,
          onVideoRecorded: _sendVideoMessage,
          onRecordingStateChanged: (isRecording) {
            setState(() {
              _isRecording = isRecording;
            });
          },
        );
      default:
        return const SizedBox.shrink();
    }
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

  Widget _buildVideoBubble(String videoURL, bool isUser) {
    final controller = _videoControllers[videoURL] ??
        VideoPlayerController.networkUrl(Uri.parse(videoURL))
          ..initialize().then((_) => setState(() {}));
    _videoControllers[videoURL] = controller;

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
        return _buildVideoBubble(msg['content'] as String, isUser);
      case 'voice':
        return _buildVoiceBubble(msg['content'], isUser);
      default:
        return const SizedBox.shrink();
    }
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
        title: Row(children: [
          Stack(
            children: [
              CircleAvatar(
                backgroundColor: Colors.grey,
                child:
                    Text(widget.avatar, style: const TextStyle(color: Colors.white)),
              ),
            ],
          ),
          const SizedBox(width: 12),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(widget.chatName,
                  style: const TextStyle(color: Colors.black, fontSize: 18)),
            ],
          ),
        ]),
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
                    if (!snapshot.hasData) {
                      return const Center(child: CircularProgressIndicator());
                    }
                    final messages = snapshot.data!;
                    return ListView.builder(
                      reverse: true,
                      padding: const EdgeInsets.all(12),
                      itemCount: messages.length,
                      itemBuilder: (context, index) {
                        final msg = messages[index];
                        return _buildUserMessage(msg);
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