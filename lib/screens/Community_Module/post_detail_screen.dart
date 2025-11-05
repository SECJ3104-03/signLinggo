// lib/screens/Community_Module/post_detail_screen.dart

import 'package:flutter/material.dart';
import 'post_data.dart';
import 'comment_data.dart';
import 'video_player_widget.dart'; // Import the video player

class PostDetailScreen extends StatefulWidget {
  // We pass in the post we want to view
  final PostData initialPost;

  const PostDetailScreen({super.key, required this.initialPost});

  @override
  State<PostDetailScreen> createState() => _PostDetailScreenState();
}

class _PostDetailScreenState extends State<PostDetailScreen> {
  // This controller is for the new comment text field
  final TextEditingController _commentController = TextEditingController();
  
  // We make a *copy* of the comment list so we can add to it.
  late List<CommentData> _comments;
  
  // This will hold our post data
  late PostData _post;

  @override
  void initState() {
    super.initState();
    _post = widget.initialPost;
    // We create a new, *modifiable* list from the *unmodifiable* one.
    _comments = List<CommentData>.from(_post.commentList);
  }

  @override
  void dispose() {
    _commentController.dispose();
    super.dispose();
  }

  // This function adds the new comment to our local list
  void _addComment() {
    final String text = _commentController.text;
    if (text.isEmpty) {
      return; // Don't add empty comments
    }

    // Create a new comment (using "You" as the author)
    final newComment = CommentData(
      author: 'You',
      initials: 'U',
      content: text,
    );

    // Call setState to rebuild the UI with the new comment
    setState(() {
      _comments.add(newComment);
    });
    
    // Clear the text field
    _commentController.clear();
    // Hide the keyboard
    FocusManager.instance.primaryFocus?.unfocus();
  }

  @override
  Widget build(BuildContext context) {
    // This 'WillPopScope' intercepts the "back" button.
    return WillPopScope(
      onWillPop: () async {
        // When the user presses back, we 'pop' the screen
        // and send back the post with its new comment list.
        Navigator.pop(context, _post.copyWith(commentList: _comments));
        return false;
      },
      child: Scaffold(
        backgroundColor: Colors.white,
        appBar: AppBar(
          backgroundColor: Colors.white,
          elevation: 1.0,
          title: Text("Post"),
          leading: IconButton(
            icon: Icon(Icons.arrow_back),
            onPressed: () {
              Navigator.pop(context, _post.copyWith(commentList: _comments));
            },
          ),
        ),
        
        body: Column(
          children: [
            // This 'Expanded' widget will contain our scrollable content
            Expanded(
              child: ListView(
                children: [
                  // 1. The Post Content
                  _buildPostContent(),
                  
                  // 2. A divider
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16.0),
                    child: Divider(thickness: 1),
                  ),
                  
                  // 3. The Comment List title
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
                    child: Text(
                      "Comments (${_comments.length})",
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                        color: Colors.black87,
                      ),
                    ),
                  ),

                  // 4. The list of comments
                  _buildCommentList(),
                ],
              ),
            ),

            // The comment input field
            _buildCommentInputField(),
          ],
        ),
      ),
    );
  }

  // --- Helper Methods for this Screen ---

  Widget _buildPostContent() {
    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Author
          Row(
            children: [
              CircleAvatar(
                child: Text(_post.initials),
              ),
              SizedBox(width: 12),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    _post.author, 
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)
                  ),
                  Text(
                    _post.timeAgo, 
                    style: TextStyle(color: Colors.grey[600], fontSize: 13)
                  ),
                ],
              ),
            ],
          ),

          // If a video exists, show it here.
          if (_post.videoUrl != null)
            Padding(
              padding: const EdgeInsets.only(top: 20.0), // Add space
              child: PostVideoPlayer(
                key: ValueKey(_post.videoUrl!), // Use a key
                videoUrl: _post.videoUrl!,
                
                // --- *** THIS IS THE ONLY CHANGE *** ---
                // We set 'isSquare' to true to match the main feed.
                isSquare: true, 
                // --- *** --- *** --- *** --- *** --- *** ---
                
                // We still need this callback, even if it does nothing
                onControllerInitialized: (controller) {
                  // do nothing
                },
              ),
            ),

          SizedBox(height: 20),
          // Title
          Text(
            _post.title,
            style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
          ),
          SizedBox(height: 12),
          // Content
          Text(
            _post.content,
            style: TextStyle(fontSize: 16, height: 1.5),
          ),
        ],
      ),
    );
  }

  // This builds the scrollable list of comments
  Widget _buildCommentList() {
    // If there are no comments, show a message
    if (_comments.isEmpty) {
      return Padding(
        padding: const EdgeInsets.all(32.0),
        child: Center(
          child: Text(
            'No comments yet.',
            style: TextStyle(color: Colors.grey[600]),
          ),
        ),
      );
    }
    
    // If there are comments, build the list
    return ListView.builder(
      shrinkWrap: true,
      physics: NeverScrollableScrollPhysics(),
      itemCount: _comments.length,
      itemBuilder: (context, index) {
        final comment = _comments[index];
        return _buildCommentItem(comment);
      },
    );
  }

  // This builds a single, nicely-styled comment row
  Widget _buildCommentItem(CommentData comment) {
    // We use 'ListTile' for a clean, standard layout
    return ListTile(
      leading: CircleAvatar(
        radius: 18,
        child: Text(comment.initials),
      ),
      title: Text(
        comment.author,
        style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
      ),
      subtitle: Text(
        comment.content,
        style: TextStyle(fontSize: 15),
      ),
    );
  }

  // This builds the text field at the bottom
  Widget _buildCommentInputField() {
    // We wrap the field in a Container to give it style and
    // padding that respects the phone's bottom "safe area" (the home bar).
    return Container(
      padding: EdgeInsets.only(
        left: 16.0,
        right: 8.0,
        top: 8.0,
        bottom: 8.0 + MediaQuery.of(context).viewPadding.bottom, // Adds padding for home bar
      ),
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withOpacity(0.3),
            spreadRadius: 1,
            blurRadius: 5,
            offset: Offset(0, -2), // Shadow at the top
          ),
        ],
      ),
      child: Row(
        children: [
          // The text field takes up the available space
          Expanded(
            child: TextField(
              controller: _commentController,
              decoration: InputDecoration(
                hintText: 'Add a comment...',
                border: InputBorder.none,
                filled: true,
                fillColor: Colors.grey[100],
                contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(30),
                  borderSide: BorderSide(color: Colors.transparent),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(30),
                  borderSide: BorderSide(color: Colors.transparent),
                ),
              ),
            ),
          ),
          // The send button
          IconButton(
            icon: Icon(Icons.send),
            color: Theme.of(context).primaryColor,
            onPressed: _addComment,
          ),
        ],
      ),
    );
  }
}