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
      'deletedFor': [],
    });

    await _updateConversationDocumentForAllUsers(previewText);
  }

  Future<void> _updateConversationDocumentForAllUsers(String lastMessage) async {
    final conversationDoc =
        FirebaseFirestore.instance.collection('conversation').doc(widget.conversationId);
    final snapshot = await conversationDoc.get();
 
    List<String> userIDs;
 
    if (snapshot.exists) {
      final data = snapshot.data()!;
      userIDs = List<String>.from(data['userIDs'] ?? []);
    } else {
      // If conversation doesn't exist, create it with participants from conversationId
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
        .map((snapshot) {
          return snapshot.docs.map((doc) {
            final data = doc.data();

            // Skip messages deleted FOR ME
            final deletedFor = List<String>.from(data['deletedFor'] ?? []);
            if (deletedFor.contains(currentUserId)) {
              return {"hidden": true}; // Skip rendering
            }

            data['isUser'] = data['senderId'] == currentUserId;
            data['messageId'] = doc.id;
            return data;
          }).where((msg) => msg["hidden"] != true).toList();
        });
  }

  Future<void> _deleteForMe(String messageId) async {
    final ref = FirebaseFirestore.instance
        .collection('conversation')
        .doc(widget.conversationId)
        .collection('messages')
        .doc(messageId);

    await ref.update({
      'deletedFor': FieldValue.arrayUnion([currentUserId]),
    });

    final snap = await ref.get();
    final data = snap.data();
    if (data == null) return;

    final deletedFor = List<String>.from(data['deletedFor'] ?? []);
    final participants = widget.conversationId.split('_');  

    final bothDeleted =
        deletedFor.contains(participants[0]) &&
        deletedFor.contains(participants[1]);

    if (bothDeleted) {
      await ref.delete();
    }
    await _refreshConversationPreviewAfterDeletion(forEveryone: false);
  }

  Future<void> _deleteForEveryone(String messageId, String type, String content) async {
    final messageRef = FirebaseFirestore.instance
        .collection('conversation')
        .doc(widget.conversationId)
        .collection('messages')
        .doc(messageId);

    await messageRef.delete();

    if (type == 'video' && _videoControllers.containsKey(content)) {
      _videoControllers[content]!.dispose();
      _videoControllers.remove(content);
    }

    if (type == 'voice' && _audioPlayers.containsKey(content)) {
      _audioPlayers[content]!.dispose();
      _audioPlayers.remove(content);
    }

    await _refreshConversationPreviewAfterDeletion(forEveryone: true);
  }

  Future<void> _refreshConversationPreviewAfterDeletion({required bool forEveryone}) async {
    final messagesSnapshot = await FirebaseFirestore.instance
        .collection('conversation')
        .doc(widget.conversationId)
        .collection('messages')
        .orderBy('createdAt', descending: true)
        .get();

    String newLastMessage = "";

    // Find the latest relevant message
    for (var doc in messagesSnapshot.docs) {
      final data = doc.data();
      final deletedFor = List<String>.from(data['deletedFor'] ?? []);

      if (forEveryone) {
        // Pick the first message not deleted for ANYONE
        if (deletedFor.isEmpty) {
          newLastMessage = _getPreviewText(data['type'], data['content']);
          break;
        }
      } else {
        // Pick the first message not deleted for CURRENT user
        if (!deletedFor.contains(currentUserId)) {
          newLastMessage = _getPreviewText(data['type'], data['content']);
          break;
        }
      }
    }

    final conversationRef = FirebaseFirestore.instance
        .collection('conversation')
        .doc(widget.conversationId);

    final snapshot = await conversationRef.get();
    if (!snapshot.exists) return;

    final data = snapshot.data()!;
    final userIDs = List<String>.from(data['userIDs'] ?? []);
    final lastMessageFor = Map<String, dynamic>.from(data['lastMessageFor'] ?? {});
    final lastMessageAtFor = Map<String, dynamic>.from(data['lastMessageAtFor'] ?? {});

    if (forEveryone) {
      // Update lastMessage for all users
      for (var userId in userIDs) {
        lastMessageFor[userId] = newLastMessage;
        lastMessageAtFor[userId] = FieldValue.serverTimestamp();
      }
    } else {
      // Update lastMessage only for current user
      lastMessageFor[currentUserId] = newLastMessage;
      lastMessageAtFor[currentUserId] = FieldValue.serverTimestamp();
    }

    await conversationRef.set({
      'lastMessageFor': lastMessageFor,
      'lastMessageAtFor': lastMessageAtFor,
    }, SetOptions(merge: true));
  }

  String _getPreviewText(String type, String content) {
    switch (type) {
      case 'text':
        return content;
      case 'voice':
        return "Voice message";
      case 'video':
        return "Video";
      default:
        return "";
    }
  }

  Widget _buildTextBubble(String text, bool isUser) {
    return Align(
      alignment: isUser ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        padding: const EdgeInsets.all(12),
        margin: const EdgeInsets.symmetric(vertical: 6, horizontal: 12),
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
        margin: const EdgeInsets.symmetric(vertical: 6, horizontal: 12),
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
        margin: const EdgeInsets.symmetric(vertical: 6, horizontal: 12),
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
    final String messageId = msg['messageId'];
    final String senderId = msg['senderId'];
    final String type = msg['type'];
    final String content = msg['content'];

    Widget messageBubble;

    if (msg['type'] != 'voice' && _audioPlayers.containsKey(msg['content'])) {
      _audioPlayers.remove(msg['content'])?.dispose();
    }
    
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
      default:
        messageBubble = const SizedBox.shrink();
    }

    return GestureDetector(
      onLongPress: () {
        _showDeleteDialog(
          messageId,
          senderId,
          type,
          content,
        );
      },
      child: messageBubble,
    );
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

  void _showDeleteDialog(String messageId, String senderId, String type, String content) {
    final bool isUserMessage = senderId == currentUserId;

    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text("Delete message"),
          actions: [
            // DELETE FOR ME
            TextButton(
              child: const Text("Delete for me"),
              onPressed: () {
                Navigator.pop(context);
                _deleteForMe(messageId);
              },
            ),

            // DELETE FOR EVERYONE (only sender can do this)
            if (isUserMessage)
              TextButton(
                child: const Text("Delete for everyone", style: TextStyle(color: Colors.red)),
                onPressed: () {
                  Navigator.pop(context);
                  _deleteForEveryone(messageId, type, content);
                },
              ),

            TextButton(
              child: const Text("Cancel"),
              onPressed: () => Navigator.pop(context),
            ),
          ],
        );
      },
    );
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
              backgroundImage: widget.avatar.startsWith('')
                  ? NetworkImage(widget.avatar)
                  : null,
              child: !widget.avatar.startsWith('')
                  ? Text(
                      widget.avatar.isNotEmpty ? widget.avatar[0].toUpperCase() : '?',
                      style: const TextStyle(color: Colors.white))
                  : null,
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