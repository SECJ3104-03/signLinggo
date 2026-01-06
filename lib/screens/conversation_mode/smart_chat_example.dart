import 'package:flutter/material.dart';
import 'package:signlinggo/screens/conversation_mode/smart_chat_screen.dart';

/// Example: How to navigate to Smart Chat Screen
/// 
/// This file demonstrates how to use the SmartChatScreen in your app.
/// You can copy this code into your existing navigation logic.

class SmartChatExample {
  
  /// Example 1: Navigate from Chat List
  static void navigateFromChatList(
    BuildContext context, {
    required String chatName,
    required String avatar,
    required String conversationId,
    required String currentUserID,
  }) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => SmartChatScreen(
          chatName: chatName,
          avatar: avatar,
          conversationId: conversationId,
          currentUserID: currentUserID,
        ),
      ),
    );
  }

  /// Example 2: Replace existing ConversationScreen navigation
  /// 
  /// In your chat_list_screen.dart, find the onTap handler (around line 291)
  /// and replace it with this:
  static void replaceExistingNavigation(BuildContext context) {
    // OLD CODE (in chat_list_screen.dart):
    // Navigator.push(
    //   context,
    //   MaterialPageRoute(
    //     builder: (_) => ConversationScreen(
    //       chatName: chatName,
    //       avatar: profileUrl ?? avatar,
    //       conversationId: conversationId,
    //       currentUserID: currentUserID,
    //     ),
    //   ),
    // );

    // NEW CODE:
    // Navigator.push(
    //   context,
    //   MaterialPageRoute(
    //     builder: (_) => SmartChatScreen(
    //       chatName: chatName,
    //       avatar: profileUrl ?? avatar,
    //       conversationId: conversationId,
    //       currentUserID: currentUserID,
    //     ),
    //   ),
    // );
  }

  /// Example 3: Add a "Smart Chat" button to existing chat screen
  /// 
  /// Add this to your ConversationScreen AppBar actions:
  static Widget buildSmartChatButton(
    BuildContext context, {
    required String chatName,
    required String avatar,
    required String conversationId,
    required String currentUserID,
  }) {
    return IconButton(
      icon: const Icon(Icons.auto_awesome, color: Colors.purple),
      tooltip: 'Smart Chat Mode',
      onPressed: () {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => SmartChatScreen(
              chatName: chatName,
              avatar: avatar,
              conversationId: conversationId,
              currentUserID: currentUserID,
            ),
          ),
        );
      },
    );
  }

  /// Example 4: Test with dummy data
  static void testSmartChat(BuildContext context) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => SmartChatScreen(
          chatName: 'Test User',
          avatar: 'T',
          conversationId: 'test_user1_user2',
          currentUserID: 'user1',
        ),
      ),
    );
  }
}

/// Example Widget: Add Smart Chat option to your app
class SmartChatLauncher extends StatelessWidget {
  final String currentUserID;
  
  const SmartChatLauncher({
    super.key,
    required this.currentUserID,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.all(16),
      child: ListTile(
        leading: const CircleAvatar(
          backgroundColor: Color(0xFF5B259F),
          child: Icon(Icons.auto_awesome, color: Colors.white),
        ),
        title: const Text(
          'Smart Chat',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        subtitle: const Text('Chat with Text, Sign Language, or Voice'),
        trailing: const Icon(Icons.arrow_forward_ios, size: 16),
        onTap: () {
          // You would typically select a user here
          // For demo, using test data:
          SmartChatExample.testSmartChat(context);
        },
      ),
    );
  }
}

/// Example: Integration in existing chat_list_screen.dart
/// 
/// Add this method to your _ChatListScreenState class:
/// 
/// void _openSmartChat(String chatName, String avatar, String conversationId) {
///   Navigator.push(
///     context,
///     MaterialPageRoute(
///       builder: (context) => SmartChatScreen(
///         chatName: chatName,
///         avatar: avatar,
///         conversationId: conversationId,
///         currentUserID: currentUserID,
///       ),
///     ),
///   );
/// }
/// 
/// Then in your ListTile (around line 274), you can add a trailing button:
/// 
/// trailing: Row(
///   mainAxisSize: MainAxisSize.min,
///   children: [
///     // Smart Chat button
///     IconButton(
///       icon: const Icon(Icons.auto_awesome, color: Colors.purple, size: 20),
///       onPressed: () => _openSmartChat(chatName, profileUrl ?? avatar, conversationId),
///     ),
///     // Existing menu button
///     if (hasUnread) ...,
///     PopupMenuButton(...),
///   ],
/// ),
