import 'dart:async';
import 'dart:io';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:camera/camera.dart';
import 'package:flutter/services.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:video_player/video_player.dart';
import 'package:just_audio/just_audio.dart';
import 'package:speech_to_text/speech_to_text.dart' as stt;
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as p;

import '../Community_Module/post_detail_screen.dart';
import '../Community_Module/post_data.dart';

class SmartChatScreen extends StatefulWidget {
  final String chatName;
  final String avatar;
  final String conversationId;
  final String currentUserID;

  const SmartChatScreen({
    super.key,
    required this.chatName,
    required this.avatar,
    required this.conversationId,
    required this.currentUserID,
  });

  @override
  State<SmartChatScreen> createState() => _SmartChatScreenState();
}

class _SmartChatScreenState extends State<SmartChatScreen>
    with WidgetsBindingObserver {
  // ===== Input Mode State =====
  String _inputMode = 'Text'; 

  // ===== Text Mode =====
  final TextEditingController _textController = TextEditingController();

  // ===== Video Mode =====
  CameraController? _cameraController;
  Future<void>? _initializeControllerFuture;
  List<CameraDescription> _cameras = [];
  int _selectedCameraIdx = 0;
  bool _isRecordingVideo = false;
  Timer? _recordingTimer;
  int _recordingDuration = 0;

  // ===== Voice Mode =====
  stt.SpeechToText? _speech;
  bool _isListening = false;
  String _voiceText = '';

  // ===== Chat History =====
  final Map<String, VideoPlayerController> _videoControllers = {};
  final Map<String, AudioPlayer> _audioPlayers = {};

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]);
    
    _setupCameras();
    _initializeSpeech();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.paused) {
      if (_isRecordingVideo) {
        _stopVideoRecording(cancel: true);
      }
      _cameraController?.dispose();
      _cameraController = null;
    } else if (state == AppLifecycleState.resumed) {
      if (_inputMode == 'Video') {
        _initializeCamera();
      }
    }
  }

  Future<void> _setupCameras() async {
    try {
      _cameras = await availableCameras();
      _selectedCameraIdx = _cameras.indexWhere(
        (c) => c.lensDirection == CameraLensDirection.back,
      );
      if (_selectedCameraIdx == -1) _selectedCameraIdx = 0;
    } catch (e) {
      debugPrint("Camera Error: $e");
    }
  }

  Future<void> _initializeCamera() async {
    if (_cameras.isEmpty) return;
    
    final status = await Permission.camera.request();
    final audioStatus = await Permission.microphone.request();
    if (!status.isGranted || !audioStatus.isGranted) return;

    _cameraController = CameraController(
      _cameras[_selectedCameraIdx],
      ResolutionPreset.medium,
      enableAudio: true,
      imageFormatGroup: ImageFormatGroup.jpeg,
    );

    try {
      _initializeControllerFuture = _cameraController!.initialize();
      await _initializeControllerFuture;
      if (mounted) setState(() {});
    } catch (e) {
      debugPrint("Camera Init Error: $e");
    }
  }

  Future<void> _initializeSpeech() async {
    _speech = stt.SpeechToText();
    await _speech!.initialize();
  }

  // ===== Supabase Storage Integration =====
  Future<String?> _uploadFileToSupabase(File file, String folder) async {
    try {
      final fileName = '${DateTime.now().millisecondsSinceEpoch}_${p.basename(file.path)}';
      final path = 'user_uploads/$fileName';

      final storage = Supabase.instance.client.storage.from('videoMessage');
      
      await storage.upload(path, file, 
        fileOptions: const FileOptions(cacheControl: '3600', upsert: false));
          
      final String publicUrl = storage.getPublicUrl(path);
          
      return publicUrl;
    } catch (e) {
      debugPrint("Upload Error: $e");
      return null;
    }
  }

  // ===== Video Recording =====
  Future<void> _startVideoRecording() async {
    if (_cameraController == null || !_cameraController!.value.isInitialized) return;
    if (_cameraController!.value.isRecordingVideo) return;

    try {
      await _cameraController!.startVideoRecording();
      setState(() {
        _isRecordingVideo = true;
        _recordingDuration = 0;
      });
      _startTimer();
    } catch (e) {
      debugPrint("Start Video Error: $e");
    }
  }

  Future<void> _stopVideoRecording({bool cancel = false}) async {
    if (_cameraController == null || !_cameraController!.value.isRecordingVideo) return;

    try {
      final XFile videoFile = await _cameraController!.stopVideoRecording();
      _stopTimer();
      setState(() {
        _isRecordingVideo = false;
      });

      if (!cancel) {
        _showVideoPreview(videoFile);
      }
    } catch (e) {
      debugPrint("Stop Video Error: $e");
    }
  }

  void _showVideoPreview(XFile videoFile) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => VideoPreviewDialog(
        videoFile: videoFile,
        onSend: (file) async {
          final url = await _uploadFileToSupabase(File(file.path), 'user_uploads');
          
          if (url != null) {
            // 2. Create Message in Firebase with the Supabase URL
            await _sendMediaMessage(url, 'video');
            if (mounted) Navigator.pop(context);
          } else {
            if (mounted) {
              Navigator.pop(context);
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text("Failed to upload video.")),
              );
            }
          }
        },
        onDiscard: () {
          Navigator.pop(context);
          File(videoFile.path).delete().catchError((e) => debugPrint("Delete error: $e"));
        },
      ),
    );
  }

  // ===== Voice Mode =====
  void _startListening() async {
    if (_speech == null || !_speech!.isAvailable) return;
    
    final status = await Permission.microphone.request();
    if (!status.isGranted) return;

    setState(() {
      _isListening = true;
      _voiceText = '';
    });

    await _speech!.listen(
      onResult: (result) {
        setState(() {
          _voiceText = result.recognizedWords;
          _textController.text = _voiceText;
          _textController.selection = TextSelection.fromPosition(
            TextPosition(offset: _textController.text.length),
          );
        });
      },
      listenMode: stt.ListenMode.dictation,
      partialResults: true,
    );
  }

  void _stopListening() async {
    if (_speech != null) {
      await _speech!.stop();
    }
    setState(() {
      _isListening = false;
    });
    if (_textController.text.isNotEmpty) {
      _sendMessage();
    }
  }

  void _startTimer() {
    _recordingTimer?.cancel();
    _recordingTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      setState(() {
        _recordingDuration++;
      });
    });
  }

  void _stopTimer() {
    _recordingTimer?.cancel();
    _recordingTimer = null;
  }

  String _formatDuration(int seconds) {
    final minutes = (seconds / 60).floor();
    final remainingSeconds = seconds % 60;
    return '${minutes.toString().padLeft(2, '0')}:${remainingSeconds.toString().padLeft(2, '0')}';
  }

  // ===== Firebase: Send Message =====
  Future<void> _sendMessage() async {
    final text = _textController.text.trim();
    if (text.isEmpty) return;
    await _sendMediaMessage(text, 'text');
    _textController.clear();
  }

  Future<void> _sendMediaMessage(String content, String type) async {
    final messageRef = FirebaseFirestore.instance
        .collection('conversation')
        .doc(widget.conversationId)
        .collection('messages')
        .doc();

    await messageRef.set({
      'messageId': messageRef.id,
      'senderId': widget.currentUserID,
      'content': content,
      'type': type,
      'isRead': false,
      'createdAt': FieldValue.serverTimestamp(),
      'deletedFor': [],
    });

    String lastMsgText = type == 'text' ? content : '[${type[0].toUpperCase()}${type.substring(1)}]';
    await _updateConversationDocument(lastMsgText);
  }

  Future<void> _updateConversationDocument(String lastMessage) async {
    final conversationDoc = FirebaseFirestore.instance
        .collection('conversation')
        .doc(widget.conversationId);
    final snapshot = await conversationDoc.get();

    List<String> userIDs;
    if (snapshot.exists) {
      final data = snapshot.data()!;
      userIDs = List<String>.from(data['userIDs'] ?? []);
    } else {
      userIDs = widget.conversationId.split('_');
    }

    Map<String, dynamic> lastMessageFor = {};
    Map<String, dynamic> lastMessageAtFor = {};

    for (var userId in userIDs) {
      lastMessageFor[userId] = lastMessage;
      lastMessageAtFor[userId] = FieldValue.serverTimestamp();
    }

    await conversationDoc.set({
      'lastMessageFor': lastMessageFor,
      'lastMessageAtFor': lastMessageAtFor,
      'userIDs': userIDs,
    }, SetOptions(merge: true));
  }

  // ===== Firebase: Message Stream =====
  Stream<List<Map<String, dynamic>>> _messageStream() {
    return FirebaseFirestore.instance
        .collection('conversation')
        .doc(widget.conversationId)
        .collection('messages')
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map((snapshot) {
      return snapshot.docs.map((doc) {
        final data = doc.data();
        final deletedFor = List<String>.from(data['deletedFor'] ?? []);
        if (deletedFor.contains(widget.currentUserID)) {
          return {"hidden": true};
        }
        data['isUser'] = data['senderId'] == widget.currentUserID;
        data['messageId'] = doc.id;
        return data;
      }).where((msg) => msg["hidden"] != true).toList();
    });
  }

  // ===== UI: Message Bubbles =====
  Widget _buildTextBubble(String text, bool isUser) {
    return Align(
      alignment: isUser ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        padding: const EdgeInsets.all(12),
        margin: const EdgeInsets.symmetric(vertical: 6, horizontal: 12),
        decoration: BoxDecoration(
          color: isUser ? const Color(0xFFF2E7FE) : Colors.grey[100],
          borderRadius: BorderRadius.circular(16),
        ),
        child: Text(
          text,
          style: TextStyle(
            fontSize: 15,
            color: isUser ? const Color(0xFF5B259F) : Colors.black87,
          ),
        ),
      ),
    );
  }

  Widget _buildVideoBubble(String videoURL, bool isUser) {
    if (!_videoControllers.containsKey(videoURL)) {
      _videoControllers[videoURL] =
          VideoPlayerController.networkUrl(Uri.parse(videoURL))
            ..initialize().then((_) {
              if (mounted) setState(() {});
            });
    }

    final controller = _videoControllers[videoURL]!;
    final width = MediaQuery.of(context).size.width * 0.55;

    return Align(
    alignment: isUser ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        width: width,
        height: width,
        margin: const EdgeInsets.symmetric(vertical: 6, horizontal: 12),
        decoration: BoxDecoration(
          color: isUser ? const Color(0xFFF2E7FE) : Colors.grey[200],
          borderRadius: BorderRadius.circular(16),
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(16),
          child: controller.value.isInitialized
              ? Stack(
                  alignment: Alignment.center,
                  children: [
                    SizedBox.expand(
                      child: FittedBox(
                        fit: BoxFit.cover,
                        child: SizedBox(
                          width: controller.value.size.width,
                          height: controller.value.size.height,
                          child: VideoPlayer(controller),
                        ),
                      ),
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
                    ),
                  ],
                )
              : const Center(child: CircularProgressIndicator()),
        ),
      ),
    );
  }

  Widget _buildVoiceBubble(String audioUrl, bool isUser) {
    if (!_audioPlayers.containsKey(audioUrl)) {
      final player = AudioPlayer();
      _audioPlayers[audioUrl] = player;

      Future.microtask(() async {
        try {
          await player.setUrl(audioUrl);
          player.playerStateStream.listen((state) {
            if (state.processingState == ProcessingState.completed) {
              player.seek(Duration.zero);
              if (mounted) setState(() {});
            }
          });
          if (mounted) setState(() {});
        } catch (e) {
          debugPrint("Error setting audio URL: $e");
        }
      });
    }

    final audioPlayer = _audioPlayers[audioUrl]!;

    return Align(
      alignment: isUser ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 12),
        margin: const EdgeInsets.symmetric(vertical: 6, horizontal: 12),
        constraints: BoxConstraints(
          maxWidth: MediaQuery.of(context).size.width * 0.75,
        ),
        decoration: BoxDecoration(
          color: isUser ? const Color(0xFFF2E7FE) : Colors.grey[200],
          borderRadius: BorderRadius.circular(16),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            StreamBuilder<PlayerState>(
              stream: audioPlayer.playerStateStream,
              builder: (context, snapshot) {
                final state = snapshot.data;
                final isPlaying = state?.playing ?? false;

                return IconButton(
                  iconSize: 36,
                  icon: Icon(
                    isPlaying
                        ? Icons.pause_circle_filled
                        : Icons.play_circle_fill,
                    color: Colors.black87,
                  ),
                  onPressed: () async {
                    if (isPlaying) {
                      await audioPlayer.pause();
                    } else {
                      await audioPlayer.play();
                    }
                  },
                );
              },
            ),
            const SizedBox(width: 8),
            const Icon(Icons.graphic_eq, color: Colors.purple),
          ],
        ),
      ),
    );
  }

  Widget _buildSharedPostBubble(Map<String, dynamic> msg, bool isUser) {
    final String postTitle = msg['post_title'] ?? '';
    final String postContent = msg['post_content'] ?? '';
    final String postAuthor = msg['post_author'] ?? 'Unknown';
    final String postImage = msg['post_image'] ?? '';
    final String postVideo = msg['post_video'] ?? '';
    final String authorImage = msg['post_author_image'] ?? '';
    final String authorInitials = msg['post_initials'] ?? '?';
    final String postId = msg['post_id'] ?? '';
    
    final String tsString = msg['post_timestamp'] ?? '';
    final DateTime postDate = tsString.isNotEmpty 
        ? DateTime.tryParse(tsString) ?? DateTime.now() 
        : DateTime.now(); 

    return Align(
      alignment: isUser ? Alignment.centerRight : Alignment.centerLeft,
      child: GestureDetector(
        onTap: () {
          final post = PostData(
            id: postId,
            authorId: '',
            author: postAuthor,
            initials: authorInitials,
            authorProfileImage: authorImage.isNotEmpty ? authorImage : null,
            timestamp: postDate,
            tag: 'Shared', 
            title: postTitle,
            content: postContent,
            likes: 0, 
            commentCount: 0, 
            imageUrl: postImage.isNotEmpty ? postImage : null,
            videoUrl: postVideo.isNotEmpty ? postVideo : null,
            isLiked: false, 
            isFollowed: false,
          );

          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => PostDetailScreen(initialPost: post),
            ),
          );
        },
        child: Container(
          width: MediaQuery.of(context).size.width * 0.7,
          margin: const EdgeInsets.symmetric(vertical: 8, horizontal: 12),
          decoration: BoxDecoration(
            color: isUser ? const Color(0xFFF2E7FE) : Colors.grey[100], 
            borderRadius: BorderRadius.circular(16),
            boxShadow: [
              if (!isUser) 
                BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 4, offset: const Offset(0, 2))
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(12, 8, 12, 4),
                child: Text(
                  "Shared a post",
                  style: TextStyle(
                    fontSize: 12,
                    color: isUser ? const Color(0xFF5B259F).withOpacity(0.6) : Colors.grey[600],
                    fontStyle: FontStyle.italic,
                  ),
                ),
              ),
              
              Container(
                margin: const EdgeInsets.all(4),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.grey.shade200),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Padding(
                      padding: const EdgeInsets.all(8.0),
                      child: Row(
                        children: [
                           CircleAvatar(
                              radius: 10,
                              backgroundColor: Colors.grey.shade300,
                              backgroundImage: (authorImage.isNotEmpty) ? NetworkImage(authorImage) : null,
                              child: (authorImage.isEmpty) ? Text(authorInitials, style: const TextStyle(fontSize: 8)) : null,
                           ),
                           const SizedBox(width: 8),
                           Expanded(
                             child: Text(
                               postAuthor,
                               style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                               maxLines: 1, overflow: TextOverflow.ellipsis,
                             ),
                           )
                        ],
                      ),
                    ),
      
                    if (postImage.isNotEmpty)
                      AspectRatio(
                        aspectRatio: 16/9,
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(4),
                          child: Image.network(postImage, fit: BoxFit.cover, errorBuilder: (_,__,___) => Container(color: Colors.grey)),
                        ),
                      )
                    else if (postVideo.isNotEmpty)
                       Container(
                         height: 120,
                         width: double.infinity,
                         color: Colors.black,
                         child: const Center(child: Icon(Icons.play_circle_fill, color: Colors.white, size: 40)),
                       ),
      
                    Padding(
                      padding: const EdgeInsets.all(10.0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          if (postTitle.isNotEmpty)
                            Text(postTitle, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14), maxLines: 1, overflow: TextOverflow.ellipsis),
                          if (postTitle.isNotEmpty) const SizedBox(height: 4),
                          Text(
                            postContent,
                            style: TextStyle(fontSize: 12, color: Colors.grey.shade800),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      ),
                    )
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildUserMessage(Map<String, dynamic> msg) {
    final bool isUser = msg['isUser'];
    final String type = msg['type'];
    final String content = msg['content'];

    Widget messageBubble;

    switch (type) {
      case 'text':
        messageBubble = _buildTextBubble(content, isUser);
        break;
      case 'video':
        messageBubble = _buildVideoBubble(content, isUser);
        break;
      case 'voice':
        messageBubble = _buildVoiceBubble(content, isUser);
        break;
      case 'shared_post':
        messageBubble = _buildSharedPostBubble(msg, isUser);
        break;
      default:
        messageBubble = const SizedBox.shrink();
    }

    return messageBubble;
  }

  Widget _buildModeSelector() {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border(
          top: BorderSide(color: Colors.grey.shade200),
        ),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: [
          _buildModeButton('Text', '⌨️'),
          _buildModeButton('Video', '📹'),
          _buildModeButton('Voice', '🎤'),
        ],
      ),
    );
  }

  Widget _buildModeButton(String mode, String emoji) {
    final isSelected = _inputMode == mode;
    return GestureDetector(
      onTap: () async {
        if (_inputMode == mode) return;

        // Cleanup previous mode
        if (_inputMode == 'Video') {
          await _stopVideoRecording(cancel: true);
          await _cameraController?.dispose();
          _cameraController = null;
        } else if (_inputMode == 'Voice') {
          _stopListening();
        }

        setState(() {
          _inputMode = mode;
        });

        // Initialize new mode
        if (mode == 'Video') {
          _initializeCamera();
        }
      },
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 20),
        decoration: BoxDecoration(
          color: isSelected ? const Color(0xFF5B259F) : Colors.grey[100],
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: isSelected ? const Color(0xFF5B259F) : Colors.grey.shade300,
            width: 1.5,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              emoji,
              style: const TextStyle(fontSize: 18),
            ),
            const SizedBox(width: 6),
            Text(
              mode,
              style: TextStyle(
                fontSize: 14,
                fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                color: isSelected ? Colors.white : Colors.black87,
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ===== UI: Dynamic Input Area =====
  Widget _buildInputArea() {
    switch (_inputMode) {
      case 'Text':
        return _buildTextInput();
      case 'Video':
        return _buildVideoInput();
      case 'Voice':
        return _buildVoiceInput();
      default:
        return const SizedBox.shrink();
    }
  }

  Widget _buildTextInput() {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border(top: BorderSide(color: Colors.grey.shade200)),
      ),
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          child: Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _textController,
                  decoration: InputDecoration(
                    hintText: 'Type a message...',
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(25),
                      borderSide: BorderSide.none,
                    ),
                    filled: true,
                    fillColor: Colors.grey[100],
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 10,
                    ),
                  ),
                  maxLines: null,
                ),
              ),
              const SizedBox(width: 8),
              CircleAvatar(
                backgroundColor: const Color(0xFF5B259F),
                child: IconButton(
                  icon: const Icon(Icons.send, color: Colors.white),
                  onPressed: _sendMessage,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildVideoInput() {
    return Container(
      height: 380,
      decoration: const BoxDecoration(
        color: Colors.black,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: ClipRRect(
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
        child: Stack(
          children: [
            if (_cameraController != null && _cameraController!.value.isInitialized)
              SizedBox.expand( // Fill the entire container
              child: FittedBox(
                fit: BoxFit.cover, // This crops the sides to fill the square/rect
                child: SizedBox(
                  width: _cameraController!.value.previewSize!.height,
                  height: _cameraController!.value.previewSize!.width,
                  child: CameraPreview(_cameraController!),
                ),
              ),
            )
            else
              const Center(child: CircularProgressIndicator(color: Colors.white)),

            if (_isRecordingVideo)
              Positioned(
                top: 20,
                left: 0,
                right: 0,
                child: Center(
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    decoration: BoxDecoration(
                      color: Colors.black.withOpacity(0.5),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: Colors.red.withOpacity(0.5), width: 1),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.circle, color: Colors.white, size: 12),
                        const SizedBox(width: 8),
                        Text(
                          _formatDuration(_recordingDuration),
                          style: const TextStyle(
                            color: Colors.white, 
                            fontWeight: FontWeight.w600,
                            letterSpacing: 1.2
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
      
            Positioned(
              bottom: 30,
              left: 0,
              right: 0,
              child: Center(
                child: GestureDetector(
                  onTap: () => _isRecordingVideo ? _stopVideoRecording() : _startVideoRecording(),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 300),
                    width: 80,
                    height: 80,
                    padding: EdgeInsets.all(_isRecordingVideo ? 20 : 5),
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      border: Border.all(color: Colors.white, width: 4),
                    ),
                    child: Container(
                      decoration: BoxDecoration(
                        color: Colors.red,
                        borderRadius: BorderRadius.circular(_isRecordingVideo ? 8 : 40),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildVoiceInput() {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border(top: BorderSide(color: Colors.grey.shade200)),
      ),
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (_isListening)
                Container(
                  height: 60,
                  margin: const EdgeInsets.only(bottom: 20),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: List.generate(
                      5,
                      (index) => Container(
                        width: 4,
                        margin: const EdgeInsets.symmetric(horizontal: 2),
                        decoration: BoxDecoration(
                          color: const Color(0xFF5B259F),
                          borderRadius: BorderRadius.circular(2),
                        ),
                      ),
                    ),
                  ),
                ),

              GestureDetector(
                onLongPressStart: (_) => _startListening(),
                onLongPressEnd: (_) => _stopListening(),
                child: Container(
                  width: 80, height: 80,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: _isListening ? Colors.red : const Color(0xFF5B259F),
                    boxShadow: [
                      BoxShadow(
                        color: (_isListening ? Colors.red : const Color(0xFF5B259F)).withOpacity(0.3),
                        blurRadius: 20, spreadRadius: 5,
                      ),
                    ],
                  ),
                  child: Icon(
                    _isListening ? Icons.mic : Icons.mic_none,
                    color: Colors.white, size: 40,
                  ),
                ),
              ),
              const SizedBox(height: 12),
              Text(
                _isListening ? 'Listening...' : 'Hold to Speak',
                style: TextStyle(fontSize: 16, color: Colors.grey[700], fontWeight: FontWeight.w500),
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _textController.dispose();
    _cameraController?.dispose();
    _recordingTimer?.cancel();
    for (var controller in _videoControllers.values) {
      controller.dispose();
    }
    for (var player in _audioPlayers.values) {
      player.dispose();
    }
    super.dispose();
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
            CircleAvatar(
              backgroundColor: Colors.grey.shade300,
              backgroundImage: (widget.avatar.isNotEmpty && Uri.tryParse(widget.avatar)?.hasAbsolutePath == true)
                  ? NetworkImage(widget.avatar)
                  : null,
              child: (widget.avatar.isEmpty || Uri.tryParse(widget.avatar)?.hasAbsolutePath != true)
                  ? Text(
                      widget.chatName.isNotEmpty ? widget.chatName[0].toUpperCase() : '?',
                      style: const TextStyle(color: Colors.white),
                    )
                  : null,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                widget.chatName,
                style: const TextStyle(color: Colors.black, fontSize: 18, fontWeight: FontWeight.w600),
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
      ),
      backgroundColor: Colors.white,
      body: Column(
        children: [
          Expanded(
            child: StreamBuilder<List<Map<String, dynamic>>>(
              stream: _messageStream(),
              builder: (context, snapshot) {
                if (!snapshot.hasData) {
                  return const Center(child: CircularProgressIndicator());
                }
                final messages = snapshot.data!;
                
                if (messages.isEmpty) {
                  return Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.chat_bubble_outline, size: 64, color: Colors.grey[300]),
                        const SizedBox(height: 16),
                        Text('No messages yet', style: TextStyle(fontSize: 16, color: Colors.grey[500])),
                        const SizedBox(height: 8),
                        Text('Start chatting using Text, Video, or Voice!', style: TextStyle(fontSize: 14, color: Colors.grey[400])),
                      ],
                    ),
                  );
                }
                
                return ListView.builder(
                  reverse: true,
                  padding: const EdgeInsets.only(bottom: 8, top: 8),
                  itemCount: messages.length,
                  itemBuilder: (context, index) => _buildUserMessage(messages[index]),
                );
              },
            ),
          ),

          _buildModeSelector(),
          _buildInputArea(),
        ],
      ),
    );
  }
}

class VideoPreviewDialog extends StatefulWidget {
  final XFile videoFile;
  final Function(XFile) onSend;
  final VoidCallback onDiscard;

  const VideoPreviewDialog({
    super.key,
    required this.videoFile,
    required this.onSend,
    required this.onDiscard,
  });

  @override
  State<VideoPreviewDialog> createState() => _VideoPreviewDialogState();
}

class _VideoPreviewDialogState extends State<VideoPreviewDialog> {
  late VideoPlayerController _controller;
  bool _initialized = false;

  @override
  void initState() {
    super.initState();
    _controller = VideoPlayerController.file(File(widget.videoFile.path))
      ..initialize().then((_) {
        setState(() {
          _initialized = true;
        });
        _controller.play();
        _controller.setLooping(true);
      });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          ClipRRect(
            borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
            child: AspectRatio(
              aspectRatio: 1.0,
              child: _initialized 
                ? FittedBox(
                  fit: BoxFit.cover, 
                  child: SizedBox(
                    width: _controller.value.size.width,
                    height: _controller.value.size.height,
                    child: VideoPlayer(_controller),
                  ),
                )
                : const Center(child: CircularProgressIndicator()),
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                TextButton.icon(
                  onPressed: widget.onDiscard,
                  icon: const Icon(Icons.delete, color: Colors.red),
                  label: const Text('Discard', style: TextStyle(color: Colors.red)),
                ),
                ElevatedButton.icon(
                  onPressed: () => widget.onSend(widget.videoFile),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF5B259F),
                    foregroundColor: Colors.white,
                  ),
                  icon: const Icon(Icons.send),
                  label: const Text('Send'),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}