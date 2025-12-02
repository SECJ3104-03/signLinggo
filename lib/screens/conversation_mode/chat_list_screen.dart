// lib/screens/conversation_mode/chat_list_screen.dart

import 'package:flutter/material.dart';
import 'package:signlinggo/screens/conversation_mode/conversation_mode_screen.dart';
// 1. IMPORT THE SERVICE
import 'mock_chat_service.dart'; 

class ChatListScreen extends StatefulWidget {
  const ChatListScreen({super.key});

  @override
  State<ChatListScreen> createState() => _ChatListScreenState();
}

class _ChatListScreenState extends State<ChatListScreen> {
  // 2. REMOVE THE OLD HARDCODED LIST HERE
  
  @override
  Widget build(BuildContext context) {
    // 3. GET THE DATA FROM OUR SERVICE
    final List<Map<String, dynamic>> currentChats = MockChatService.chats;

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
      body: ListView.builder(
        itemCount: currentChats.length, // Use currentChats
        itemBuilder: (context, index) {
          final chat = currentChats[index]; // Use currentChats
          return ListTile(
            leading: Stack(
              children: [
                CircleAvatar(
                  backgroundColor: const Color(0xFF980FFA),
                  child: Text(
                    chat['avatar'],
                    style: const TextStyle(color: Colors.white),
                  ),
                ),
                if (chat['isOnline'])
                  Positioned(
                    bottom: 0,
                    right: 0,
                    child: Container(
                      width: 12,
                      height: 12,
                      decoration: BoxDecoration(
                        color: Colors.green,
                        shape: BoxShape.circle,
                        border: Border.all(color: Colors.white, width: 2),
                      ),
                    ),
                  ),
              ],
            ),
            title: Text(
              chat['name'],
              style: const TextStyle(fontWeight: FontWeight.w600),
            ),
            subtitle: Text(
              chat['lastMessage'],
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(color: Colors.grey),
            ),
            trailing: Text(
              chat['time'],
              style: const TextStyle(color: Colors.grey, fontSize: 12),
            ),
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => ConversationScreen(
                    chatName: chat['name'],
                    avatar: chat['avatar'],
                    isOnline: chat['isOnline'],
                  ),
                ),
              ).then((_) {
                 // Optional: When coming back from chat, refresh this list
                 setState(() {});
              });
            },
          );
        },
      ),
    );
  }
}