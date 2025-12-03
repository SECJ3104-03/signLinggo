// lib/screens/conversation_mode/mock_chat_service.dart

class MockChatService {
  // This static list acts as your "Database"
  static final List<Map<String, dynamic>> _chats = [
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

  // Getter to retrieve the list
  static List<Map<String, dynamic>> get chats => _chats;

  // Function to add a new chat if it doesn't exist yet
  static void startChat(String name, String initials) {
    // 1. Check if this person is already in the list
    final existingIndex = _chats.indexWhere((chat) => chat['name'] == name);

    if (existingIndex == -1) {
      // 2. If not, add them to the top of the list
      _chats.insert(0, {
        'name': name,
        'avatar': initials,
        'lastMessage': 'New conversation', // Default message
        'time': 'Just now',
        'isOnline': true, // Assuming online for now
      });
    } else {
      // 3. If they exist, move them to the top (optional)
      final existingChat = _chats.removeAt(existingIndex);
      _chats.insert(0, existingChat);
    }
  }
}