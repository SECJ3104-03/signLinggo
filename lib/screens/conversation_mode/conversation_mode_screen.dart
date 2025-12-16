import 'dart:developer';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:camera/camera.dart';
import 'package:path_provider/path_provider.dart';
import 'package:video_player/video_player.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:just_audio/just_audio.dart';
import 'package:audio_session/audio_session.dart';

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
  final Map<String, AudioPlayer> _audioPlayers = {}; // Using just_audio AudioPlayer
  final Map<String, String> _audioLocalPaths = {};
  late final String currentUserId;
  
  bool _isRecording = false; 

  @override
  void initState() {
    super.initState();
    currentUserId = widget.currentUserID;
  }
  
  // Clean up all controllers to prevent memory leaks
  @override
  void dispose() {
    for (var controller in _videoControllers.values) {
      controller.dispose();
    }
    for (var player in _audioPlayers.values) {
      player.dispose();
    }
    _audioPlayers.clear();
    super.dispose();
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

  Future<void> _sendVideoMessage(String videoUrl) async {
    await _sendMessage(videoUrl, 'video', 'Sent a video');
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
    if (!_videoControllers.containsKey(videoURL)) {
      _videoControllers[videoURL] = VideoPlayerController.networkUrl(Uri.parse(videoURL))
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
                      child: AspectRatio(
                        aspectRatio: controller.value.aspectRatio,
                        child: VideoPlayer(controller),
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
                    )
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
      
      // Initialize the player
      Future.microtask(() async {
        try {
          await player.setUrl(audioUrl);
          
          // Handle playback completion
          player.playerStateStream.listen((state) {
            if (state.processingState == ProcessingState.completed) {
              // Reset to start when completed
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
        margin: const EdgeInsets.symmetric(vertical: 6),
        constraints: BoxConstraints(
          maxWidth: MediaQuery.of(context).size.width * 0.75,
        ),
        decoration: BoxDecoration(
          color: isUser ? Colors.blue[50] : Colors.grey[200],
          borderRadius: BorderRadius.circular(16),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
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
                          // Check if we're at the end
                          final position = audioPlayer.position;
                          final duration = audioPlayer.duration ?? Duration.zero;
                          
                          if (position >= duration - const Duration(milliseconds: 100)) {
                            await audioPlayer.seek(Duration.zero);
                          }
                          await audioPlayer.play();
                        }
                      },
                    );
                  },
                ),

                Expanded(
                  child: StreamBuilder<Duration>(
                    stream: audioPlayer.positionStream,
                    initialData: Duration.zero,
                    builder: (context, positionSnapshot) {
                      return StreamBuilder<Duration?>(
                        stream: audioPlayer.durationStream,
                        initialData: Duration.zero,
                        builder: (context, durationSnapshot) {
                          final position = positionSnapshot.data ?? Duration.zero;
                          final duration = durationSnapshot.data ?? Duration.zero;
                          
                          double progress = 0;
                          if (duration.inMilliseconds > 0) {
                            progress = position.inMilliseconds / duration.inMilliseconds;
                          }
                          
                          return LinearProgressIndicator(
                            value: progress,
                            backgroundColor: Colors.black26,
                            valueColor: const AlwaysStoppedAnimation<Color>(Colors.purple),
                          );
                        },
                      );
                    },
                  ),
                ),
              ],
            ),

            const SizedBox(height: 6),
            StreamBuilder<Duration>(
              stream: audioPlayer.positionStream,
              initialData: Duration.zero,
              builder: (context, positionSnapshot) {
                return StreamBuilder<Duration?>(
                  stream: audioPlayer.durationStream,
                  initialData: Duration.zero,
                  builder: (context, durationSnapshot) {
                    final position = positionSnapshot.data ?? Duration.zero;
                    final duration = durationSnapshot.data ?? Duration.zero;
                    
                    String fmt(Duration d) =>
                        "${d.inMinutes}:${(d.inSeconds % 60).toString().padLeft(2, '0')}";

                    return Text(
                      "${fmt(position)} / ${fmt(duration)}",
                      style: const TextStyle(fontSize: 12),
                    );
                  },
                );
              },
            ),
          ],
        ),
      ),
    );
  }
          
  Widget _buildUserMessage(Map<String, dynamic> msg) {
    final bool isUser = msg['isUser'];

    // Clean up player if message is not voice but has one associated
    if (msg['type'] != 'voice' && _audioPlayers.containsKey(msg['content'])) {
      _audioPlayers.remove(msg['content'])?.dispose();
    }
    
    switch (msg['type']) {
      case 'text':
        return _buildTextBubble(msg['content'] ?? '', isUser);
      case 'video':
        return _buildVideoBubble(msg['content'] as String, isUser);
      case 'voice':
        return _buildVoiceBubble(msg['content'] ?? '', isUser);
      default:
        return const SizedBox.shrink();
    }
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
            onTap: () => setState(() => _mode = mode),
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
          onVideoRecorded: _sendVideoMessage,
          isParentRecording: false,
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

  Future<String> downloadToLocalFile(String url) async {
    final tempDir = await getTemporaryDirectory();
    final filePath = "${tempDir.path}/${DateTime.now().millisecondsSinceEpoch}.m4a";

    final response = await HttpClient().getUrl(Uri.parse(url));
    final result = await response.close();

    final file = File(filePath);
    final sink = file.openWrite();

    await result.forEach((chunk) => sink.add(chunk));
    await sink.close();

    return file.path;
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
              backgroundColor: Colors.grey,
              child: Text(
                widget.avatar.isNotEmpty ? widget.avatar[0].toUpperCase() : '?', 
                style: const TextStyle(color: Colors.white)
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    widget.chatName,
                    style: const TextStyle(color: Colors.black, fontSize: 18),
                    overflow: TextOverflow.ellipsis,
                    maxLines: 1,
                  ),
                ],
              ),
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
                    if (!snapshot.hasData) {
                      return const Center(child: CircularProgressIndicator());
                    }
                    final messages = snapshot.data!;
                    return ListView.builder(
                      reverse: true,
                      padding: const EdgeInsets.only(bottom: 100),
                      itemCount: messages.length,
                      itemBuilder: (context, index) =>
                          _buildUserMessage(messages[index]),
                    );
                  },
                ),
              ),
            ],
          ),

          Positioned(
            left: 0,
            right: 0,
            bottom: 0,
            top: _isRecording ? 0 : null,
            child: _buildInputBar(),
          ),
        ],
      ),
    );
  }
}