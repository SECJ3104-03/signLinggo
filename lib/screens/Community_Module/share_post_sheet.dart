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

  String _getConversationId(String otherUserId) {
    List<String> ids = [widget.currentUserId, otherUserId];
    ids.sort();
    return ids.join('_');
  }

  Future<void> _sendPostToChat(String otherUserId, String chatName) async {
    setState(() => _isSending = true);

    try {
      final conversationId = _getConversationId(otherUserId);
      
      await _sendMessage(
        conversationId: conversationId,
        type: 'shared_post', 
        previewText: 'Shared a post: ${widget.post.title}',
        extraData: {
          'post_id': widget.post.id,
          'post_author': widget.post.author,
          'post_author_image': widget.post.authorProfileImage ?? '',
          'post_initials': widget.post.initials,
          'post_title': widget.post.title,
          'post_content': widget.post.content,
          'post_image': widget.post.imageUrl ?? '',
          'post_video': widget.post.videoUrl ?? '',
          // --- FIX: SEND THE ORIGINAL TIMESTAMP ---
          'post_timestamp': widget.post.timestamp.toIso8601String(), 
        }
      );

      if (mounted) {
        Navigator.pop(context);
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
    required String type,
    required String previewText,
    required Map<String, dynamic> extraData,
  }) async {
    final messageRef = _firestore
        .collection('conversation')
        .doc(conversationId)
        .collection('messages')
        .doc();

    final Map<String, dynamic> messageData = {
      'messageId': messageRef.id,
      'senderId': widget.currentUserId,
      'type': type,
      'content': 'Shared a Post', 
      'isRead': false,
      'createdAt': FieldValue.serverTimestamp(),
      'deletedFor': [],
      ...extraData, 
    };

    await messageRef.set(messageData);

    final conversationDoc = _firestore.collection('conversation').doc(conversationId);
    
    await conversationDoc.set({
      'userIDs': FieldValue.arrayUnion([widget.currentUserId]), 
      'lastMessageFor': {
        widget.currentUserId: previewText,
      },
      'lastMessageAtFor': {
        widget.currentUserId: FieldValue.serverTimestamp(),
      }
    }, SetOptions(merge: true));

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
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Container(
                  width: 40, height: 4,
                  decoration: BoxDecoration(color: Colors.grey[300], borderRadius: BorderRadius.circular(2)),
                ),
              ],
            ),
          ),
          const Padding(
            padding: EdgeInsets.only(bottom: 10),
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
                    
                    final List<dynamic> users = data['userIDs'] ?? [];
                    final String otherId = users.firstWhere(
                      (u) => u != widget.currentUserId, 
                      orElse: () => ''
                    );

                    if (otherId.isEmpty) return const SizedBox.shrink();

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