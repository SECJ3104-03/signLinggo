// lib/screens/Community_Module/share_post_sheet.dart

import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'post_data.dart';

class SharePostSheet extends StatefulWidget {
  final PostData post;
  final String currentUserId;

  const SharePostSheet({
    super.key,
    required this.post,
    required this.currentUserId,
  });

  @override
  State<SharePostSheet> createState() => _SharePostSheetState();
}

class _SharePostSheetState extends State<SharePostSheet> {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  bool _isSending = false;

  // Helper to generate the conversation ID consistently
  String _getConversationId(String otherUserId) {
    List<String> ids = [widget.currentUserId, otherUserId];
    ids.sort();
    return ids.join('_');
  }

  Future<void> _sendPostToChat(String otherUserId, String chatName) async {
    setState(() => _isSending = true);

    try {
      final conversationId = _getConversationId(otherUserId);
      
      // 1. Send the Text Part (Title + Content)
      final String textContent = "Shared a post:\n\n*${widget.post.title}*\n${widget.post.content}";
      
      await _sendMessage(
        conversationId: conversationId,
        content: textContent,
        type: 'text',
        previewText: 'Shared a post: ${widget.post.title}',
      );

      // 2. Send Media (if any)
      if (widget.post.videoUrl != null) {
        await _sendMessage(
          conversationId: conversationId,
          content: widget.post.videoUrl!,
          type: 'video',
          previewText: 'Sent a video',
        );
      } else if (widget.post.imageUrl != null) {
        await _sendMessage(
          conversationId: conversationId,
          content: widget.post.imageUrl!,
          type: 'image', // Requires support in ConversationScreen
          previewText: 'Sent an image',
        );
      }

      if (mounted) {
        Navigator.pop(context); // Close the sheet
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Sent to $chatName')),
        );
      }
    } catch (e) {
      print("Error sending post: $e");
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Failed to send')),
        );
      }
    } finally {
      if (mounted) setState(() => _isSending = false);
    }
  }

  Future<void> _sendMessage({
    required String conversationId,
    required String content,
    required String type,
    required String previewText,
  }) async {
    final messageRef = _firestore
        .collection('conversation')
        .doc(conversationId)
        .collection('messages')
        .doc();

    // Write message
    await messageRef.set({
      'messageId': messageRef.id,
      'senderId': widget.currentUserId,
      'content': content,
      'type': type,
      'isRead': false,
      'createdAt': FieldValue.serverTimestamp(),
      'deletedFor': [],
    });

    // Update Conversation Summary
    final conversationDoc = _firestore.collection('conversation').doc(conversationId);
    
    // Use set with merge to ensure basic fields exist
    await conversationDoc.set({
      'userIDs': FieldValue.arrayUnion([widget.currentUserId]), 
      'lastMessageFor': {
        widget.currentUserId: previewText,
      },
      'lastMessageAtFor': {
        widget.currentUserId: FieldValue.serverTimestamp(),
      }
    }, SetOptions(merge: true));

    // Also update for others (simple approach)
    final docSnap = await conversationDoc.get();
    if(docSnap.exists) {
       final data = docSnap.data()!;
       final List<dynamic> users = data['userIDs'] ?? [];
       Map<String, dynamic> lastMsgMap = {};
       Map<String, dynamic> lastTimeMap = {};
       
       for(var u in users) {
         lastMsgMap[u.toString()] = previewText;
         lastTimeMap[u.toString()] = FieldValue.serverTimestamp();
       }
       
       await conversationDoc.update({
         'lastMessageFor': lastMsgMap,
         'lastMessageAtFor': lastTimeMap,
       });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      height: MediaQuery.of(context).size.height * 0.6,
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.only(
          topLeft: Radius.circular(20),
          topRight: Radius.circular(20),
        ),
      ),
      child: Column(
        children: [
          const Padding(
            padding: EdgeInsets.all(16.0),
            child: Text(
              "Send to...",
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
          ),
          const Divider(height: 1),
          Expanded(
            child: StreamBuilder<QuerySnapshot>(
              stream: _firestore
                  .collection('conversation')
                  .where('userIDs', arrayContains: widget.currentUserId)
                  .snapshots(),
              builder: (context, snapshot) {
                if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());
                
                final docs = snapshot.data!.docs;
                if (docs.isEmpty) return const Center(child: Text("No chats found"));

                return ListView.builder(
                  itemCount: docs.length,
                  itemBuilder: (context, index) {
                    final data = docs[index].data() as Map<String, dynamic>;
                    
                    // Find the other user ID
                    final List<dynamic> users = data['userIDs'] ?? [];
                    final String otherId = users.firstWhere(
                      (u) => u != widget.currentUserId, 
                      orElse: () => ''
                    );

                    if (otherId.isEmpty) return const SizedBox.shrink();

                    // Fetch Other User Details
                    return FutureBuilder<DocumentSnapshot>(
                      future: _firestore.collection('users').doc(otherId).get(),
                      builder: (context, userSnap) {
                        if (!userSnap.hasData) {
                          return const ListTile(
                            leading: CircleAvatar(backgroundColor: Colors.grey),
                            title: Text("Loading..."),
                          );
                        }
                        
                        final userData = userSnap.data!.data() as Map<String, dynamic>? ?? {};
                        final name = userData['fullName'] ?? userData['username'] ?? 'User';
                        final image = userData['profileUrl'];
                        final initial = name.isNotEmpty ? name[0].toUpperCase() : '?';

                        return ListTile(
                          leading: CircleAvatar(
                            backgroundImage: image != null ? NetworkImage(image) : null,
                            backgroundColor: Colors.grey[200],
                            child: image == null ? Text(initial) : null,
                          ),
                          title: Text(name),
                          trailing: ElevatedButton(
                            onPressed: _isSending ? null : () => _sendPostToChat(otherId, name),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(0xFFAC46FF),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                            ),
                            child: const Text("Send", style: TextStyle(color: Colors.white)),
                          ),
                        );
                      },
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}