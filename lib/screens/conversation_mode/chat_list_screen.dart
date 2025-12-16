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

  Future<void> _deleteConversation(String conversationId) async {
    final bool confirm = await showDialog(
          context: context,
          builder: (context) => AlertDialog(
            title: const Text('Delete Chat'),
            content: const Text(
              'Are you sure you want to permanently delete this conversation? This cannot be undone.',
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(context).pop(false),
                child: const Text('Cancel'),
              ),
              TextButton(
                onPressed: () => Navigator.of(context).pop(true),
                child: const Text('Delete', style: TextStyle(color: Colors.red)),
              ),
            ],
          ),
        ) ??
        false;

    if (!confirm) return;

    try {
      final messagesSnapshot = await _firestore
          .collection('conversation')
          .doc(conversationId)
          .collection('messages')
          .get();

      final batch = _firestore.batch();

      for (final doc in messagesSnapshot.docs) {
        batch.delete(doc.reference);
      }

      batch.delete(_firestore.collection('conversation').doc(conversationId));
      await batch.commit();

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Conversation deleted successfully.')),
        );
      }
    } catch (e) {
      debugPrint('Error deleting conversation: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Failed to delete conversation.')),
        );
      }
    }
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
                final aTime = (a['lastMessageAt'] as Timestamp?)?.toDate() ??
                    DateTime.fromMicrosecondsSinceEpoch(0);
                final bTime = (b['lastMessageAt'] as Timestamp?)?.toDate() ??
                    DateTime.fromMicrosecondsSinceEpoch(0);
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

                  return FutureBuilder<DocumentSnapshot>(
                    future: _firestore.collection('users').doc(otherUserID).get(),
                    builder: (context, userSnapshot) {
                      if (userSnapshot.connectionState ==
                          ConnectionState.waiting) {
                        return ListTile(
                          leading:
                              CircleAvatar(backgroundColor: Colors.grey.shade300),
                          title: Container(
                              height: 10,
                              width: 100,
                              color: Colors.grey.shade200),
                          subtitle: Container(
                              height: 8,
                              width: 150,
                              color: Colors.grey.shade200),
                        );
                      }

                      String chatName = "Unknown User";
                      String avatar = '?';

                      if (userSnapshot.hasData &&
                          userSnapshot.data!.exists) {
                        final userData =
                            userSnapshot.data!.data() as Map<String, dynamic>? ??
                                {};
                        chatName =
                            userData['name'] ?? userData['email'] ?? "Unknown";
                        avatar = chatName.isNotEmpty
                            ? chatName[0].toUpperCase()
                            : '?';
                      }

                      final lastMessage = data['lastMessage'] ?? '';
                      final lastMessageAt = data['lastMessageAt'] != null
                          ? (data['lastMessageAt'] as Timestamp).toDate()
                          : DateTime.fromMicrosecondsSinceEpoch(0);
                      final timeString = _formatLastMessageTime(lastMessageAt);

                      return ListTile(
                        leading: CircleAvatar(
                          backgroundColor: Colors.grey,
                          child: Text(
                            avatar,
                            style: const TextStyle(color: Colors.white),
                          ),
                        ),
                        title: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Expanded(
                              child: Text(
                                chatName,
                                style: const TextStyle(
                                    fontWeight: FontWeight.w600),
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
                        trailing: PopupMenuButton<String>(
                          icon: const Icon(Icons.more_vert, color: Colors.grey),
                          onSelected: (String result) {
                            if (result == 'delete') {
                              _deleteConversation(conversationId);
                            }
                          },
                          itemBuilder: (context) => const [
                            PopupMenuItem<String>(
                              value: 'delete',
                              child: Text(
                                'Delete chat for everyone',
                                style: TextStyle(color: Colors.red),
                              ),
                            ),
                          ],
                        ),
                        onTap: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) => ConversationScreen(
                                chatName: chatName,
                                avatar: avatar,
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
          ),
        );
      },
    );
  }
}