import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:signlinggo/screens/conversation_mode/conversation_mode_screen.dart';

class AddChatScreen extends StatefulWidget {
  final String currentUserID;
  const AddChatScreen({required this.currentUserID, super.key});

  @override
  State<AddChatScreen> createState() => _AddChatScreenState();
}

class _AddChatScreenState extends State<AddChatScreen> {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final TextEditingController _searchController = TextEditingController();

  String _searchQuery = '';

  @override
  void initState() {
    super.initState();
    _searchController.addListener(_onSearchChanged);
  }

  @override
  void dispose() {
    _searchController.removeListener(_onSearchChanged);
    _searchController.dispose();
    super.dispose();
  }

  void _onSearchChanged() {
    setState(() {
      _searchQuery = _searchController.text.toLowerCase().trim();
    });
  }

  String getConversationId(String userId1, String userId2) {
    List<String> userIDs = [userId1, userId2]..sort();
    return userIDs.join('_');
  }

  void _startChat(
    BuildContext context,
    String otherUserID,
    String chatName,
    String avatar,
  ) async {
    final conversationId = getConversationId(widget.currentUserID, otherUserID);

    if (context.mounted) {
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder: (context) => ConversationScreen(
            chatName: chatName,
            avatar: avatar,
            conversationId: conversationId,
            currentUserID: widget.currentUserID,
          ),
        ),
      );
    }
  }

  List<DocumentSnapshot> _filterUsers(List<DocumentSnapshot> allUsers) {
    if (_searchQuery.isEmpty) {
      return [];
    }

    return allUsers.where((doc) {
      final userData = doc.data() as Map<String, dynamic>? ?? {};
      final otherUserID = doc.id;

      if (otherUserID == widget.currentUserID) return false;

      final chatName = (userData['name'] as String?)?.toLowerCase() ??
          (userData['email'] as String?)?.toLowerCase() ??
          '';

      return chatName.contains(_searchQuery) || otherUserID.contains(_searchQuery);
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(  
      appBar: AppBar(
      elevation: 1,
      backgroundColor: Colors.white,
      leading: IconButton(
        icon: const Icon(Icons.arrow_back, color: Colors.black87),
        onPressed: () => Navigator.pop(context),
      ),
      title: const Text(
        "New Chat",
        style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold),
      ),
    ),

      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(12.0),
            child: TextField(
              controller: _searchController,
              decoration: InputDecoration(
                hintText: 'Search by name or id',
                hintStyle: TextStyle(color: Colors.grey[600]),
                prefixIcon: Icon(Icons.search, color: Colors.grey[600]),
                suffixIcon: _searchQuery.isNotEmpty
                    ? IconButton(
                        icon: Icon(Icons.clear, color: Colors.grey[600]),
                        onPressed: () {
                          _searchController.clear();
                          setState(() {
                            _searchQuery = '';
                          });
                        },
                      )
                    : null,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(30.0),
                  borderSide: BorderSide.none,
                ),
                contentPadding:
                    const EdgeInsets.symmetric(vertical: 15.0, horizontal: 20.0),
                filled: true,
                fillColor: Colors.grey[100],
              ),
            ),
          ),

          Expanded(
            child: StreamBuilder<QuerySnapshot>(
              stream: _firestore.collection('users').snapshots(),
              builder: (context, snapshot) {
                if (snapshot.hasError) {
                  return Center(
                    child: Text('Error: ${snapshot.error}'),
                  );
                }

                if (snapshot.connectionState == ConnectionState.waiting) {
                  if (_searchQuery.isNotEmpty) {
                    return const Center(child: CircularProgressIndicator());
                  }
                  return const SizedBox.shrink();
                }

                final filteredUsers = _filterUsers(snapshot.data!.docs);

                if (_searchQuery.isEmpty) {
                  return const SizedBox.shrink();
                }

                if (filteredUsers.isEmpty) {
                  return Center(
                    child: Text('No users found for "$_searchQuery".'),
                  );
                }

                return ListView.builder(
                  itemCount: filteredUsers.length,
                  itemBuilder: (context, index) {
                    final userDoc = filteredUsers[index];
                    final userData =
                        userDoc.data() as Map<String, dynamic>? ?? {};
                    final otherUserID = userDoc.id;

                    final chatName =
                        userData['name'] ?? userData['email'] ?? "Unknown User";
                    final avatar =
                        chatName.isNotEmpty ? chatName[0].toUpperCase() : '?';

                    return ListTile(
                      leading: CircleAvatar(
                        backgroundColor: Colors.grey.shade200,
                        child: Text(
                          avatar,
                          style: const TextStyle(color: Colors.black87),
                        ),
                      ),
                      title: Text(chatName),
                      subtitle: Text(userData['email'] ?? ''),
                      onTap: () =>
                          _startChat(context, otherUserID, chatName, avatar),
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