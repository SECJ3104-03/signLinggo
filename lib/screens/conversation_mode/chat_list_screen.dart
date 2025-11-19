import 'package:flutter/material.dart';
import 'package:signlinggo/screens/conversation_mode/conversation_mode_screen.dart';


class ChatListScreen extends StatefulWidget {
  const ChatListScreen({super.key});


  @override
  State<ChatListScreen> createState() => _ChatListScreenState();
}


class _ChatListScreenState extends State<ChatListScreen> {
  // Dummy data
  final List<Map<String, dynamic>> _chats = [
    {
      'name': 'John Doe',
      'avatar': 'JD',
      'lastMessage': 'See you later!',
      'time': '9:45 AM',
      'isOnline': true,
    },
    {
      'name': 'Clark Vo',
      'avatar': 'CV',
      'lastMessage': 'Sure, send me the file.',
      'time': 'Yesterday',
      'isOnline': false,
    },
    {
      'name': 'Tang Wei',
      'avatar': 'TW',
      'lastMessage': 'Can we meet tomorrow?',
      'time': 'Mon',
      'isOnline': true,
    },
  ];


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
        title: const Text(
          "Chats",
          style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold),
        ),
      ),
      backgroundColor: Colors.white,
      body: ListView.builder(
        itemCount: _chats.length,
        itemBuilder: (context, index) {
          final chat = _chats[index];
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
              );
            },
          );
        },
      ),
    );
  }
}