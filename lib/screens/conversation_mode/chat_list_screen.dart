import 'package:flutter/material.dart';
import 'package:signlinggo/screens/conversation_mode/conversation_mode_screen.dart';
import 'package:signlinggo/screens/conversation_mode/add_chat_screen.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class ChatListScreen extends StatefulWidget {
  const ChatListScreen({super.key});

  @override
  State<ChatListScreen> createState() => _ChatListScreenState();
}

class _ChatListScreenState extends State<ChatListScreen> {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  String _formatLastMessageTime(DateTime lastMessageAt) {
    final now = DateTime.now();
    final isToday = lastMessageAt.year == now.year &&
        lastMessageAt.month == now.month &&
        lastMessageAt.day == now.day;

    if (isToday) {
      return "${lastMessageAt.hour.toString().padLeft(2, '0')}:${lastMessageAt.minute.toString().padLeft(2, '0')}";
    } else {
      return "${lastMessageAt.day.toString().padLeft(2, '0')}/${lastMessageAt.month.toString().padLeft(2, '0')}/${lastMessageAt.year % 100}";
    }
  }

  Future<void> _deleteConversationForMe(String conversationId, String currentUserID) async {
    final docRef = FirebaseFirestore.instance.collection('conversation').doc(conversationId);

    await docRef.update({
      'userIDs': FieldValue.arrayRemove([currentUserID]),
      'lastMessageFor.$currentUserID': FieldValue.delete(),
      'lastMessageAtFor.$currentUserID': FieldValue.delete(),
    });

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Conversation deleted for you.')),
    );
  }

  Future<void> _deleteConversationForEveryone(String conversationId) async {
    final docRef = FirebaseFirestore.instance.collection('conversation').doc(conversationId);

    // Delete all messages subcollection
    final messagesSnapshot = await docRef.collection('messages').get();
    final batch = FirebaseFirestore.instance.batch();
    for (var doc in messagesSnapshot.docs) {
      batch.delete(doc.reference);
    }

    // Delete the conversation document
    batch.delete(docRef);
    await batch.commit();

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Conversation deleted for everyone.')),
    );
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<User?>(
      stream: FirebaseAuth.instance.authStateChanges(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        }

        if (!snapshot.hasData || snapshot.data == null) {
          return const Scaffold(
            body: Center(child: Text('Please log in')),
          );
        }

        final currentUserID = snapshot.data!.uid;

        return Scaffold(
          appBar: AppBar(
            backgroundColor: Colors.white,
            elevation: 1,
            title: const Text(
              "Chats",
              style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold),
            ),
            actions: [
              Padding(
                padding: const EdgeInsets.only(right: 16.0),
                child: GestureDetector(
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) =>
                            AddChatScreen(currentUserID: currentUserID),
                      ),
                    );
                  },
                  child: CircleAvatar(
                    radius: 18,
                    backgroundColor: const Color(0xFF980FFA),
                    child: const Icon(Icons.add, color: Colors.white, size: 24),
                  ),
                ),
              ),
            ],
          ),
          backgroundColor: Colors.white,
          body: StreamBuilder<QuerySnapshot>(
            stream: _firestore
                .collection('conversation')
                .where('userIDs', arrayContains: currentUserID)
                .snapshots(),
            builder: (context, snapshot) {
              if (snapshot.hasError) {
                return Center(child: Text('Error: ${snapshot.error}'));
              }

              if (!snapshot.hasData) {
                return const Center(child: CircularProgressIndicator());
              }

              final conversations = snapshot.data!.docs;

              if (conversations.isEmpty) {
                return const Center(child: Text('No chats yet'));
              }

              conversations.sort((a, b) {
              final aData = a.data() as Map<String, dynamic>? ?? {};
              final bData = b.data() as Map<String, dynamic>? ?? {};

              final aLastAt = Map<String, dynamic>.from(aData['lastMessageAtFor'] ?? {})[currentUserID];
              final bLastAt = Map<String, dynamic>.from(bData['lastMessageAtFor'] ?? {})[currentUserID];

              final aTime = aLastAt != null ? (aLastAt as Timestamp).toDate() : DateTime.fromMicrosecondsSinceEpoch(0);
              final bTime = bLastAt != null ? (bLastAt as Timestamp).toDate() : DateTime.fromMicrosecondsSinceEpoch(0);

              return bTime.compareTo(aTime);
            });


              return ListView.builder(
                itemCount: conversations.length,
                itemBuilder: (context, index) {
                  final chatDoc = conversations[index];
                  final data = chatDoc.data() as Map<String, dynamic>? ?? {};
                  final conversationId = chatDoc.id;

                  final otherUserID = (data['userIDs'] as List<dynamic>?)
                          ?.firstWhere(
                            (id) => id != currentUserID,
                            orElse: () => '',
                          )
                          .toString() ??
                      '';

                  if (otherUserID.isEmpty) return const SizedBox.shrink();

                  return FutureBuilder<QuerySnapshot<Map<String, dynamic>>>(
                    future: _firestore.collection('users').where('uid', isEqualTo: otherUserID).limit(1).get(),
                    builder: (context, userSnapshot) {
                      if (userSnapshot.connectionState == ConnectionState.waiting) {
                        return const ListTile(
                          leading: CircleAvatar(backgroundColor: Colors.grey),
                          title: SizedBox(height: 10),
                          subtitle: SizedBox(height: 8),
                        );
                      }

                      String chatName = "Unknown User";
                      String avatar = '?';
                      String? profileUrl;

                      if (userSnapshot.hasData && userSnapshot.data!.docs.isNotEmpty) {
                        final userData = userSnapshot.data!.docs.first.data() as Map<String, dynamic>;
                        chatName = userData['name'] ?? userData['username'] ?? userData['fullName'] ?? "Unknown";
                        avatar = chatName.isNotEmpty ? chatName[0].toUpperCase() : '?';
                        profileUrl = userData['profileUrl'];
                      }

                      final lastMessage = (data['lastMessageFor'] as Map?)?[currentUserID] ?? '';
                      final lastMessageAt = (data['lastMessageAtFor'] as Map?)?[currentUserID] != null
                          ? (data['lastMessageAtFor'][currentUserID] as Timestamp).toDate()
                          : DateTime.fromMillisecondsSinceEpoch(0);

                      final timeString = _formatLastMessageTime(lastMessageAt);

                      return StreamBuilder<QuerySnapshot>(
                        stream: _firestore
                            .collection('conversation')
                            .doc(conversationId)
                            .collection('messages')
                            .where('isRead', isEqualTo: false)
                            .snapshots(),
                        builder: (context, msgSnapshot) {
                          bool hasUnread = false;
                          if (msgSnapshot.hasData && msgSnapshot.data!.docs.isNotEmpty) {
                            hasUnread = msgSnapshot.data!.docs.any((msgDoc) {
                              final msgData = msgDoc.data() as Map<String, dynamic>;
                              return msgData['senderId'] != currentUserID;
                            });
                          }

                          return ListTile(
                            leading: CircleAvatar(
                              backgroundColor: Colors.grey.shade300,
                              backgroundImage: profileUrl != null ? NetworkImage(profileUrl) : null,
                              child: (profileUrl == null) ? Text(avatar, style: const TextStyle(color: Colors.white)) : null,
                            ),
                            title: Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Expanded(
                                  child: Text(
                                    chatName,
                                    style: const TextStyle(fontWeight: FontWeight.w600),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Text(
                                  timeString,
                                  style: const TextStyle(color: Colors.grey, fontSize: 12),
                                ),
                              ],
                            ),
                            subtitle: Text(
                              lastMessage,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(color: Colors.grey),
                            ),
                            trailing: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                if (hasUnread)
                                  Container(
                                    width: 12,
                                    height: 12,
                                    decoration: const BoxDecoration(
                                      color: Colors.green,
                                      shape: BoxShape.circle,
                                    ),
                                  ),
                                const SizedBox(width: 8),
                                PopupMenuButton<String>(
                                  icon: const Icon(Icons.more_vert, color: Colors.grey),
                                  onSelected: (String result) {
                                    if (result == 'delete_for_me') {
                                      _deleteConversationForMe(conversationId, currentUserID);
                                    } else if (result == 'delete_for_everyone') {
                                      _deleteConversationForEveryone(conversationId);
                                    }
                                  },
                                  itemBuilder: (context) => [
                                    const PopupMenuItem<String>(
                                      value: 'delete_for_me',
                                      child: Text('Delete for me'),
                                    ),
                                    const PopupMenuItem<String>(
                                      value: 'delete_for_everyone',
                                      child: Text('Delete for everyone', style: TextStyle(color: Colors.red)),
                                    )
                                  ],
                                ),
                              ],
                            ),
                            onTap: () async {
                              final unreadMessages = await _firestore
                                  .collection('conversation')
                                  .doc(conversationId)
                                  .collection('messages')
                                  .where('isRead', isEqualTo: false)
                                  .get();

                              for (var msgDoc in unreadMessages.docs) {
                                final msgData = msgDoc.data() as Map<String, dynamic>;
                                if (msgData['senderId'] != currentUserID) {
                                  await msgDoc.reference.update({'isRead': true});
                                }
                              }

                              if (!mounted) return;

                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (_) => ConversationScreen(
                                    chatName: chatName,
                                    avatar: profileUrl ?? avatar,
                                    conversationId: conversationId,
                                    currentUserID: currentUserID,
                                  ),
                                ),
                              );
                            },
                          );
                        },
                      );
                    },
                  );
                },
              );
            },
          ),
        );
      },
    );
  }
}