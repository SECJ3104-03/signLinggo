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

import '../../services/object_detector.dart';
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

  // ===== Sign Mode (Camera + YOLO) =====
  CameraController? _cameraController;
  Future<void>? _initializeControllerFuture;
  final ObjectDetector _detector = ObjectDetector();
  bool _isScanning = false;
  List<Map<String, dynamic>> _detections = [];
  bool _modelLoaded = false;
  
  // Stability Buffer for Sign Detection
  final Map<String, int> _detectionBuffer = {};
  static const int _stabilityThreshold = 5; 
  String _lastStableWord = '';
  
  // Performance tracking
  DateTime? _lastRunTime;
  List<CameraDescription> _cameras = [];
  int _selectedCameraIdx = 0;

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
    
    _initializeModel();
    _setupCameras();
    _initializeSpeech();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.paused) {
      _stopScanning();
    }
  }

  void _initializeModel() async {
    await _detector.loadModel();
    if (mounted) {
      setState(() {
        _modelLoaded = _detector.isLoaded;
      });
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

  void _initializeCamera() {
    if (_cameras.isEmpty) return;
    
    _cameraController = CameraController(
      _cameras[_selectedCameraIdx],
      ResolutionPreset.high,
      enableAudio: false,
      imageFormatGroup: Platform.isAndroid
          ? ImageFormatGroup.yuv420
          : ImageFormatGroup.bgra8888,
    );

    _initializeControllerFuture = _cameraController!.initialize().then((_) {
      if (mounted) setState(() {});
      _startScanning();
    });
  }

  Future<void> _initializeSpeech() async {
      _speech = stt.SpeechToText();
      await _speech!.initialize();
  }

  // ===== Sign Mode: YOLO Detection =====
  Future<void> _startScanning() async {
    if (_cameraController == null || !_cameraController!.value.isInitialized) {
      return;
    }
    setState(() {
      _isScanning = true;
      _detections = [];
      _detectionBuffer.clear();
    });
    await _startStreaming();
  }

  Future<void> _startStreaming() async {
    try {
      await _cameraController!.startImageStream((CameraImage image) {
        _processCameraFrame(image);
      });
    } catch (e) {
      debugPrint("Stream Error: $e");
    }
  }

  void _processCameraFrame(CameraImage image) async {
    if (_detector.isBusy) return;

    final now = DateTime.now();
    if (_lastRunTime != null &&
        now.difference(_lastRunTime!).inMilliseconds < 500) {
      return;
    }
    _lastRunTime = now;

    final results = await _detector.yoloOnFrame(image);

    if (mounted && _isScanning) {
      setState(() {
        _detections = results;
      });

      if (results.isNotEmpty) {
        final detection = results.first;
        final String word = detection['tag'];
        
        _detectionBuffer[word] = (_detectionBuffer[word] ?? 0) + 1;
        _detectionBuffer.removeWhere((key, value) => key != word);
        
        if (_detectionBuffer[word]! >= _stabilityThreshold && word != _lastStableWord) {
          _lastStableWord = word;
          _insertWordToTextField(word);
          _detectionBuffer.clear();
        }
      }
    }
  }

  void _insertWordToTextField(String word) {
    final currentText = _textController.text;
    final newText = currentText.isEmpty ? word : '$currentText $word';
    _textController.text = newText;
    _textController.selection = TextSelection.fromPosition(
      TextPosition(offset: newText.length),
    );
  }

  Future<void> _stopScanning() async {
    if (_cameraController != null && _cameraController!.value.isStreamingImages) {
      await _cameraController!.stopImageStream();
    }
    if (mounted) {
      setState(() {
        _isScanning = false;
        _detections = [];
        _detectionBuffer.clear();
      });
    }
  }

  // ===== Voice Mode =====
  void _startListening() async {
    if (_speech == null || !_speech!.isAvailable) return;
    
    setState(() {
      _isListening = true;
      _voiceText = '';
     });

    await _speech!.listen(
      onResult: (result) {
        setState(() {
          _voiceText = result.recognizedWords;
          _textController.text = _voiceText;
        });
       },
    );
  }

  void _stopListening() async {
    if (_speech != null) {
      await _speech!.stop();
    }
    
    setState(() {
      _isListening = false;
    });
  }

  // ===== Firebase: Send Message =====
  Future<void> _sendMessage() async {
    final text = _textController.text.trim();
    if (text.isEmpty) return;

    final messageRef = FirebaseFirestore.instance
        .collection('conversation')
        .doc(widget.conversationId)
        .collection('messages')
        .doc();

    await messageRef.set({
      'messageId': messageRef.id,
      'senderId': widget.currentUserID,
      'content': text,
      'type': 'text',
      'isRead': false,
      'createdAt': FieldValue.serverTimestamp(),
      'deletedFor': [],
    });

    await _updateConversationDocument(text);

    _textController.clear();
    setState(() {
      _lastStableWord = ''; 
    });
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
        padding: const EdgeInsets.all(12),
        margin: const EdgeInsets.symmetric(vertical: 6, horizontal: 12),
        decoration: BoxDecoration(
          color: isUser ? const Color(0xFFF2E7FE) : Colors.grey[200],
          borderRadius: BorderRadius.circular(16),
        ),
        child: AspectRatio(
          aspectRatio: controller.value.aspectRatio,
          child: Stack(
            alignment: Alignment.center,
            children: [
              VideoPlayer(controller),
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
          ),
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

  // ===== SHARED POST BUBBLE =====
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
          _buildModeButton('Sign', '📷'),
          _buildModeButton('Voice', '🎤'),
        ],
      ),
    );
  }

  Widget _buildModeButton(String mode, String emoji) {
    final isSelected = _inputMode == mode;
    return GestureDetector(
      onTap: () {
        setState(() {
          if (_inputMode == 'Sign') {
            _stopScanning();
          } else if (_inputMode == 'Voice') {
            _stopListening();
          }

          _inputMode = mode;

          if (mode == 'Sign' && _cameraController == null) {
            _initializeCamera();
          }
        });
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

  // ===== UI: Dynamic Input Area with SAFEAREA FIX =====
  Widget _buildInputArea() {
    switch (_inputMode) {
      case 'Text':
        return _buildTextInput();
      case 'Sign':
        return _buildSignInput();
      case 'Voice':
        return _buildVoiceInput();
      default:
        return const SizedBox.shrink();
    }
  }

  Widget _buildTextInput() {
    // --- FIX: Added SafeArea to Text Input ---
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border(top: BorderSide(color: Colors.grey.shade200)),
      ),
      child: SafeArea(
        top: false, // Only safe area at bottom
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

  Widget _buildSignInput() {
    return Container(
      height: 350,
      decoration: BoxDecoration(
        color: Colors.black,
        border: Border(
          top: BorderSide(color: Colors.grey.shade200, width: 2),
        ),
      ),
      child: Stack(
        children: [
          // Camera Preview
          if (_cameraController != null && _cameraController!.value.isInitialized)
            Positioned.fill(
              child: _buildCameraPreview(),
            )
          else
            const Center(
              child: CircularProgressIndicator(color: Colors.white),
            ),

          Positioned(
            top: 12, left: 12,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: _modelLoaded ? Colors.green : Colors.red,
                borderRadius: BorderRadius.circular(20),
              ),
              child: Text(
                _modelLoaded ? 'AI Active' : 'Loading...',
                style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold),
              ),
            ),
          ),

          if (_detections.isNotEmpty)
            Positioned(
              top: 12, right: 12,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: Colors.blue.withOpacity(0.8),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  'Detected: ${_detections.first['tag']}',
                  style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold),
                ),
              ),
            ),

          // --- FIX: Added SafeArea to Sign Input Text Field ---
          Positioned(
            bottom: 0, left: 0, right: 0,
            child: Container(
              color: Colors.white,
              child: SafeArea(
                top: false,
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: _textController,
                          decoration: InputDecoration(
                            hintText: 'Detected signs will appear here...',
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
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCameraPreview() {
    if (_cameraController == null || !_cameraController!.value.isInitialized) {
      return const SizedBox.shrink();
    }

    return LayoutBuilder(
      builder: (context, constraints) {
        final size = Size(constraints.maxWidth, constraints.maxHeight);
        return Stack(
          fit: StackFit.expand,
          children: [
            FittedBox(
              fit: BoxFit.cover,
              child: SizedBox(
                width: _cameraController!.value.previewSize!.height,
                height: _cameraController!.value.previewSize!.width,
                child: CameraPreview(_cameraController!),
              ),
            ),
            if (_isScanning && _detections.isNotEmpty)
              CustomPaint(
                painter: BoundingBoxPainter(
                  detections: _detections,
                  previewSize: _cameraController!.value.previewSize!,
                  screenSize: size,
                  isFrontCamera: _cameras[_selectedCameraIdx].lensDirection == CameraLensDirection.front,
                ),
              ),
          ],
        );
      }
    );
  }

  Widget _buildVoiceInput() {
    // --- FIX: Added SafeArea to Voice Input ---
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
                onLongPressEnd: (_) {
                  _stopListening();
                  if (_textController.text.isNotEmpty) {
                    _sendMessage();
                  }
                },
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
              
              if (!_isListening)
                Padding(
                  padding: const EdgeInsets.only(top: 8),
                  child: Text(
                    'Note: Add speech_to_text package to enable',
                    style: TextStyle(fontSize: 12, color: Colors.grey[500], fontStyle: FontStyle.italic),
                  ),
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
    _stopScanning();
    _detector.dispose();
    _cameraController?.dispose();
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
                        Text('Start chatting using Text, Sign, or Voice!', style: TextStyle(fontSize: 14, color: Colors.grey[400])),
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

          // --- FIX: Optional Safety wrapper for the input area call itself ---
          _buildInputArea(),
        ],
      ),
    );
  }
}

class BoundingBoxPainter extends CustomPainter {
  final List<Map<String, dynamic>> detections;
  final Size previewSize;
  final Size screenSize;
  final bool isFrontCamera;

  BoundingBoxPainter({
    required this.detections,
    required this.previewSize,
    required this.screenSize,
    required this.isFrontCamera,
  });

  @override
  void paint(Canvas canvas, Size size) {
    double scaleX = size.width / previewSize.height;
    double scaleY = size.height / previewSize.width;
    final double scale = math.max(scaleX, scaleY);
    double offsetX = (size.width - (previewSize.height * scale)) / 2;
    double offsetY = (size.height - (previewSize.width * scale)) / 2;

    final Paint paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3.0
      ..color = Colors.green;

    final TextStyle textStyle = TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold, backgroundColor: Colors.green);

    for (var detection in detections) {
      final box = detection['box'];
      double x1 = box[0] * scale + offsetX;
      double y1 = box[1] * scale + offsetY;
      double x2 = box[2] * scale + offsetX;
      double y2 = box[3] * scale + offsetY;

      if (isFrontCamera) {
        double tempX1 = size.width - x2;
        double tempX2 = size.width - x1;
        x1 = tempX1;
        x2 = tempX2;
      }

      final rect = Rect.fromLTRB(x1, y1, x2, y2);
      canvas.drawRect(rect, paint);

      final String label = "${detection['tag']} ${(detection['box'][4] * 100).toStringAsFixed(0)}%";
      final TextSpan span = TextSpan(text: label, style: textStyle);
      final TextPainter tp = TextPainter(text: span, textAlign: TextAlign.left, textDirection: TextDirection.ltr);
      tp.layout();
      tp.paint(canvas, Offset(x1, y1 - 20));
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) {
    return true;
  }
}