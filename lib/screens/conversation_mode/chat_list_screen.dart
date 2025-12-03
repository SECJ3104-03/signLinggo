/* import 'package:flutter/material.dart';
import 'package:signlinggo/screens/conversation_mode/conversation_mode_screen.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class ChatListScreen extends StatefulWidget {
  const ChatListScreen({super.key});

  @override
  State<ChatListScreen> createState() => _ChatListScreenState();
}

class _ChatListScreenState extends State<ChatListScreen> {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<User?>(
      stream: FirebaseAuth.instance.authStateChanges(),
      builder: (context, snapshot) {
        // User not logged in
        if (!snapshot.hasData || snapshot.data == null) {
          return const Scaffold(
            body: Center(
              child: Text('Please log in'),
            ),
          );
        }

        final currentUserID = snapshot.data!.uid;

        return Scaffold(
          appBar: AppBar(
            backgroundColor: Colors.white,
            elevation: 1,
            leading: IconButton(
              icon: const Icon(Icons.arrow_back, color: Colors.black87),
              onPressed: () => Navigator.pop(context),
            ),
            title: const Text(
              "Chats",
              style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold),
            ),
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

              // Sort conversations by lastMessageAt descending
              conversations.sort((a, b) {
                final aTime = (a['lastMessageAt'] as Timestamp?)?.toDate() ?? DateTime.now();
                final bTime = (b['lastMessageAt'] as Timestamp?)?.toDate() ?? DateTime.now();
                return bTime.compareTo(aTime);
              });

              return ListView.builder(
                itemCount: conversations.length,
                itemBuilder: (context, index) {
                  final chatDoc = conversations[index];
                  final data = chatDoc.data() as Map<String, dynamic>? ?? {};
                  final conversationId = chatDoc.id;

                  // Get the other user ID
                  final otherUserID = (data['userIDs'] as List<dynamic>?)
                          ?.firstWhere((id) => id != currentUserID, orElse: () => '')
                          .toString() ??
                      '';

                  if (otherUserID.isEmpty) return const SizedBox.shrink();

                  // Fetch other user's display name from users collection
                  return FutureBuilder<DocumentSnapshot>(
                    future: _firestore.collection('users').doc(otherUserID).get(),
                    builder: (context, userSnapshot) {
                      String chatName = otherUserID; // fallback
                      String avatar = '?';

                      if (userSnapshot.hasData && userSnapshot.data!.exists) {
                        final userData = userSnapshot.data!.data() as Map<String, dynamic>? ?? {};
                        chatName = userData['name'] ?? userData['email'];
                        avatar = chatName.isNotEmpty ? chatName[0].toUpperCase() : '?';
                      }

                      final lastMessage = data['lastMessage'] ?? '';
                      final lastMessageAt = data['lastMessageAt'] != null
                          ? (data['lastMessageAt'] as Timestamp).toDate()
                          : DateTime.now();
                      final timeString =
                          "${lastMessageAt.hour.toString().padLeft(2, '0')}:${lastMessageAt.minute.toString().padLeft(2, '0')}";

                      return ListTile(
                        leading: CircleAvatar(
                          backgroundColor: const Color(0xFF980FFA),
                          child: Text(
                            avatar,
                            style: const TextStyle(color: Colors.white),
                          ),
                        ),
                        title: Text(
                          chatName,
                          style: const TextStyle(fontWeight: FontWeight.w600),
                        ),
                        subtitle: Text(
                          lastMessage,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(color: Colors.grey),
                        ),
                        trailing: Text(
                          timeString,
                          style: const TextStyle(color: Colors.grey, fontSize: 12),
                        ),
                        onTap: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) => ConversationScreen(
                                chatName: chatName,
                                avatar: avatar,
                                isOnline: true,
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
} */

// lib/screens/conversation_mode/chat_list_screen.dart

import 'package:flutter/material.dart';
import 'package:signlinggo/screens/conversation_mode/conversation_mode_screen.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class ChatListScreen extends StatefulWidget {
  const ChatListScreen({super.key});

  @override
  State<ChatListScreen> createState() => _ChatListScreenState();
}

class _ChatListScreenState extends State<ChatListScreen> {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<User?>(
      stream: FirebaseAuth.instance.authStateChanges(),
      builder: (context, snapshot) {
        // User not logged in
        if (!snapshot.hasData || snapshot.data == null) {
          return const Scaffold(
            body: Center(
              child: Text('Please log in'),
            ),
          );
        }

        final currentUserID = snapshot.data!.uid;

        return Scaffold(
          appBar: AppBar(
            backgroundColor: Colors.white,
            elevation: 1,
            leading: IconButton(
              icon: const Icon(Icons.arrow_back, color: Colors.black87),
              onPressed: () => Navigator.pop(context),
            ),
            title: const Text(
              "Chats",
              style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold),
            ),
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

              // Sort conversations by lastMessageAt descending
              conversations.sort((a, b) {
                final aTime = (a['lastMessageAt'] as Timestamp?)?.toDate() ?? DateTime.now();
                final bTime = (b['lastMessageAt'] as Timestamp?)?.toDate() ?? DateTime.now();
                return bTime.compareTo(aTime);
              });

              return ListView.builder(
                itemCount: conversations.length,
                itemBuilder: (context, index) {
                  final chatDoc = conversations[index];
                  final data = chatDoc.data() as Map<String, dynamic>? ?? {};
                  final conversationId = chatDoc.id;

                  // Get the other user ID
                  final otherUserID = (data['userIDs'] as List<dynamic>?)
                          ?.firstWhere((id) => id != currentUserID, orElse: () => '')
                          .toString() ??
                      '';

                  if (otherUserID.isEmpty) return const SizedBox.shrink();

                  // Fetch other user's display name from users collection
                  return FutureBuilder<DocumentSnapshot>(
                    future: _firestore.collection('users').doc(otherUserID).get(),
                    builder: (context, userSnapshot) {
                      
                      // --- FIX: Show placeholder while loading name ---
                      if (userSnapshot.connectionState == ConnectionState.waiting) {
                        return const ListTile(
                          leading: CircleAvatar(
                            backgroundColor: Colors.grey,
                            child: SizedBox(width: 10, height: 10, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white)),
                          ),
                          title: Text("Loading..."), 
                          subtitle: Text("..."),
                        );
                      }
                      // ------------------------------------------------

                      String chatName = "Unknown User"; 
                      String avatar = '?';

                      if (userSnapshot.hasData && userSnapshot.data!.exists) {
                        final userData = userSnapshot.data!.data() as Map<String, dynamic>? ?? {};
                        chatName = userData['name'] ?? userData['email'] ?? "Unknown";
                        avatar = chatName.isNotEmpty ? chatName[0].toUpperCase() : '?';
                      }

                      final lastMessage = data['lastMessage'] ?? '';
                      final lastMessageAt = data['lastMessageAt'] != null
                          ? (data['lastMessageAt'] as Timestamp).toDate()
                          : DateTime.now();
                      final timeString =
                          "${lastMessageAt.hour.toString().padLeft(2, '0')}:${lastMessageAt.minute.toString().padLeft(2, '0')}";

                      return ListTile(
                        leading: CircleAvatar(
                          backgroundColor: const Color(0xFF980FFA),
                          child: Text(
                            avatar,
                            style: const TextStyle(color: Colors.white),
                          ),
                        ),
                        title: Text(
                          chatName,
                          style: const TextStyle(fontWeight: FontWeight.w600),
                        ),
                        subtitle: Text(
                          lastMessage,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(color: Colors.grey),
                        ),
                        trailing: Text(
                          timeString,
                          style: const TextStyle(color: Colors.grey, fontSize: 12),
                        ),
                        onTap: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) => ConversationScreen(
                                chatName: chatName,
                                avatar: avatar,
                                isOnline: true,
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