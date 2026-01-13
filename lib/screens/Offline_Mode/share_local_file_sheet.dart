// lib/screens/Offline_Mode/share_local_file_sheet.dart

import 'dart:io';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:uuid/uuid.dart';

class ShareLocalFileSheet extends StatefulWidget {
  final File file;
  final String currentUserId;

  const ShareLocalFileSheet({
    super.key,
    required this.file,
    required this.currentUserId,
  });

  @override
  State<ShareLocalFileSheet> createState() => _ShareLocalFileSheetState();
}

class _ShareLocalFileSheetState extends State<ShareLocalFileSheet> {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final SupabaseClient _supabase = Supabase.instance.client;
  bool _isSending = false;

  Future<void> _uploadAndSend(String otherUserId, String chatName) async {
    setState(() => _isSending = true);

    try {
      // 1. UPLOAD VIDEO TO SUPABASE
      final String fileName = '${const Uuid().v4()}.mp4';
      final String storagePath = 'offline_shares/$fileName'; 

      await _supabase.storage.from('videoMessage').upload(
        storagePath,
        widget.file,
        fileOptions: const FileOptions(contentType: 'video/mp4', upsert: false),
      );

      final String publicUrl = _supabase.storage.from('videoMessage').getPublicUrl(storagePath);

      // 2. SEND MESSAGE TO FIRESTORE
      final conversationId = _getConversationId(widget.currentUserId, otherUserId);
      
      await _sendMessage(
        conversationId: conversationId,
        type: 'video', 
        content: publicUrl,
        previewText: 'Sent a video',
      );

      if (mounted) {
        Navigator.pop(context); // Close the sheet
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Sent to $chatName')),
        );
      }
    } catch (e) {
      print("Error sharing file: $e");
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Failed to send. Check internet connection.')),
        );
      }
    } finally {
      if (mounted) setState(() => _isSending = false);
    }
  }

  String _getConversationId(String id1, String id2) {
    List<String> ids = [id1, id2];
    ids.sort();
    return ids.join('_');
  }

  Future<void> _sendMessage({
    required String conversationId,
    required String type,
    required String content,
    required String previewText,
  }) async {
    final messageRef = _firestore
        .collection('conversation')
        .doc(conversationId)
        .collection('messages')
        .doc();

    await messageRef.set({
      'messageId': messageRef.id,
      'senderId': widget.currentUserId,
      'type': type,
      'content': content,
      'isRead': false,
      'createdAt': FieldValue.serverTimestamp(),
      'deletedFor': [],
    });

    final conversationDoc = _firestore.collection('conversation').doc(conversationId);
    
    await conversationDoc.set({
      'userIDs': FieldValue.arrayUnion([widget.currentUserId]),
    }, SetOptions(merge: true));

     await conversationDoc.set({
         'lastMessageFor': { widget.currentUserId: previewText },
         'lastMessageAtFor': { widget.currentUserId: FieldValue.serverTimestamp() },
     }, SetOptions(merge: true));
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      height: MediaQuery.of(context).size.height * 0.6,
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.only(topLeft: Radius.circular(20), topRight: Radius.circular(20)),
      ),
      child: Column(
        children: [
          const SizedBox(height: 16),
          Container(width: 40, height: 4, decoration: BoxDecoration(color: Colors.grey[300], borderRadius: BorderRadius.circular(2))),
          const SizedBox(height: 16),
          const Text("Send to...", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
          const Divider(),
          Expanded(
            child: _isSending 
              ? const Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min, 
                    children: [
                      CircularProgressIndicator(color: Color(0xFFAC46FF)), 
                      SizedBox(height: 16), 
                      Text("Uploading & Sending...")
                    ]
                  )
                )
              : StreamBuilder<QuerySnapshot>(
                  stream: _firestore
                      .collection('conversation')
                      .where('userIDs', arrayContains: widget.currentUserId)
                      .snapshots(),
                  builder: (context, snapshot) {
                    if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());
                    final docs = snapshot.data!.docs;
                    if (docs.isEmpty) return const Center(child: Text("No chats found"));

                    return ListView.builder(
                      // --- FIX: Add padding at the bottom so the last item is visible above nav bar ---
                      padding: EdgeInsets.only(bottom: MediaQuery.of(context).padding.bottom + 20),
                      itemCount: docs.length,
                      itemBuilder: (context, index) {
                        final data = docs[index].data() as Map<String, dynamic>;
                        final users = data['userIDs'] as List<dynamic>? ?? [];
                        
                        final otherId = users.firstWhere(
                          (u) => u != widget.currentUserId, 
                          orElse: () => ''
                        );
                        
                        if (otherId == '') return const SizedBox.shrink();

                        return FutureBuilder<DocumentSnapshot>(
                          future: _firestore.collection('users').doc(otherId).get(),
                          builder: (context, userSnap) {
                            if (!userSnap.hasData) return const SizedBox.shrink();
                            
                            final userData = userSnap.data!.data() as Map<String, dynamic>? ?? {};
                            final name = userData['fullName'] ?? userData['username'] ?? 'User';
                            final image = userData['profileUrl'];
                            final initial = name.isNotEmpty ? name[0].toUpperCase() : '?';

                            return ListTile(
                              leading: CircleAvatar(
                                backgroundColor: Colors.grey[200],
                                backgroundImage: image != null ? NetworkImage(image) : null,
                                child: image == null ? Text(initial) : null,
                              ),
                              title: Text(name),
                              trailing: ElevatedButton(
                                onPressed: () => _uploadAndSend(otherId, name),
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