// lib/screens/Community_Module/post_detail_screen.dart

import 'dart:io'; 
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart'; 
import 'package:cloud_firestore/cloud_firestore.dart'; // Added for fetching user data
import 'post_data.dart';
import 'comment_data.dart';
import 'video_player_widget.dart';
import 'real_time_widget.dart'; 
import 'firestore_service.dart'; 

class PostDetailScreen extends StatefulWidget {
  final PostData initialPost;

  const PostDetailScreen({super.key, required this.initialPost});

  @override
  State<PostDetailScreen> createState() => _PostDetailScreenState();
}

class _PostDetailScreenState extends State<PostDetailScreen> {
  final TextEditingController _commentController = TextEditingController();
  final FocusNode _commentFocusNode = FocusNode();
  
  final FirestoreService _firestoreService = FirestoreService();
  late PostData _post;

  String? _replyingToName;
  String? _replyingToId; 
  int _currentCommentCount = 0;

  // --- NEW: Variables to store current user's real profile ---
  String _myRealName = "Loading...";
  String _myInitials = "?";
  String? _myProfileImage;

  @override
  void initState() {
    super.initState();
    _post = widget.initialPost;
    _loadCurrentUser(); // Load the correct profile data immediately
  }

  // --- NEW: Fetch "Fluffy" and profileUrl from Firestore ---
  Future<void> _loadCurrentUser() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    try {
      final doc = await FirebaseFirestore.instance.collection('users').doc(user.uid).get();
      if (doc.exists) {
        final data = doc.data()!;
        final String fullName = data['fullName'] ?? data['username'] ?? user.displayName ?? "User";
        final String? profileUrl = data['profileUrl'] ?? user.photoURL;
        
        if (mounted) {
          setState(() {
            _myRealName = fullName;
            _myInitials = fullName.isNotEmpty ? fullName[0].toUpperCase() : "?";
            _myProfileImage = profileUrl;
          });
        }
      } else {
        // Fallback
        if (mounted) {
          setState(() {
            _myRealName = user.displayName ?? "User";
            _myInitials = _myRealName.isNotEmpty ? _myRealName[0].toUpperCase() : "?";
            _myProfileImage = user.photoURL;
          });
        }
      }
    } catch (e) {
      print("Error loading user profile for comments: $e");
    }
  }

  @override
  void dispose() {
    _commentController.dispose();
    _commentFocusNode.dispose();
    super.dispose();
  }

  void _syncCommentCount(int realCount) {
    if (_post.commentCount != realCount) {
      _post = _post.copyWith(commentCount: realCount);
      _firestoreService.updatePostCommentCount(_post.id, realCount);
    }
  }

  void _addComment() {
    final String text = _commentController.text;
    if (text.isEmpty) return;

    final String myUid = FirebaseAuth.instance.currentUser?.uid ?? '';

    // --- UPDATED: Use the loaded real profile data ---
    final newComment = CommentData(
      authorId: myUid, 
      author: _myRealName, // Uses "Fluffy"
      initials: _myInitials,
      content: text,
      timestamp: DateTime.now(), 
      likeCount: 0,
      isReply: _replyingToId != null,
      authorProfileImage: _myProfileImage, // Saves the picture!
    );

    _firestoreService.addComment(
      postId: _post.id, 
      postAuthorId: _post.authorId, 
      comment: newComment,
      replyToUserId: _replyingToId,
    );
    
    _commentController.clear();
    FocusManager.instance.primaryFocus?.unfocus();
    
    setState(() {
      _replyingToName = null;
      _replyingToId = null;
    });
  }

  void _confirmDeleteComment(CommentData comment) {
    if (comment.id == null) return;

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text("Delete Comment"),
        content: const Text("Are you sure you want to delete this comment?"),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text("Cancel", style: TextStyle(color: Colors.grey)),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              _firestoreService.deleteComment(_post.id, comment.id!);
            },
            child: const Text("Delete", style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
  }

  void _toggleLike(CommentData comment) {
    if (comment.id == null) return;
    
    _firestoreService.toggleCommentLike(
      postId: _post.id, 
      commentId: comment.id!, 
      commentAuthorId: comment.authorId, 
      isLiked: comment.isLiked,
    );
  }

  void _replyToComment(CommentData comment) {
    setState(() {
      _replyingToName = comment.author;
      _replyingToId = comment.authorId; 
    });
    FocusScope.of(context).requestFocus(_commentFocusNode);
  }
  
  void _cancelReply() {
    setState(() {
      _replyingToName = null;
      _replyingToId = null;
    });
    FocusManager.instance.primaryFocus?.unfocus();
  }

  void _onBackPressed() {
    Navigator.pop(context, _currentCommentCount);
  }

  @override
  Widget build(BuildContext context) {
    return WillPopScope(
      onWillPop: () async {
        _onBackPressed();
        return false; 
      },
      child: Scaffold(
        backgroundColor: Colors.white,
        appBar: AppBar(
          backgroundColor: Colors.white,
          elevation: 0.5,
          title: const Text("Post", style: TextStyle(color: Colors.black, fontSize: 18, fontWeight: FontWeight.w600)),
          leading: IconButton(
            icon: const Icon(Icons.arrow_back, color: Colors.black),
            onPressed: _onBackPressed, 
          ),
        ),
        
        body: Column(
          children: [
            Expanded(
              child: ListView(
                children: [
                  _buildPostContent(),
                  const Divider(height: 1, thickness: 1, color: Color(0xFFEEEEEE)),
                  
                  StreamBuilder<List<CommentData>>(
                    stream: _firestoreService.getCommentsStream(_post.id),
                    builder: (context, snapshot) {
                      if (snapshot.hasError) {
                        return const Padding(
                          padding: EdgeInsets.all(20),
                          child: Text("Error loading comments"),
                        );
                      }
                      if (snapshot.connectionState == ConnectionState.waiting) {
                        return const Padding(
                          padding: EdgeInsets.all(40),
                          child: Center(child: CircularProgressIndicator()),
                        );
                      }

                      final comments = snapshot.data ?? [];
                      _currentCommentCount = comments.length;

                      WidgetsBinding.instance.addPostFrameCallback((_) {
                        _syncCommentCount(comments.length);
                      });

                      return Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _buildCommentSectionHeader(comments.length),
                          _buildCommentList(comments),
                        ],
                      );
                    },
                  ),
                ],
              ),
            ),
            _buildInputArea(),
          ],
        ),
      ),
    );
  }

  Widget _buildPostContent() {
    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              if (_post.authorProfileImage != null && _post.authorProfileImage!.isNotEmpty)
                 Container(
                  width: 40, height: 40,
                  decoration: const BoxDecoration(shape: BoxShape.circle),
                  clipBehavior: Clip.antiAlias,
                  child: Image.network(
                    _post.authorProfileImage!,
                    fit: BoxFit.cover,
                    errorBuilder: (context, error, stackTrace) {
                      return Container(
                        decoration: BoxDecoration(gradient: _post.profileGradient, shape: BoxShape.circle),
                        child: Center(child: Text(_post.initials, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14))),
                      );
                    },
                  ),
                )
              else
                Container(
                  width: 40, height: 40,
                  decoration: BoxDecoration(gradient: _post.profileGradient, shape: BoxShape.circle),
                  child: Center(child: Text(_post.initials, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14))),
                ),
              const SizedBox(width: 10),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(_post.author, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 16)),
                  RealTimeTimestamp(timestamp: _post.timestamp, style: TextStyle(color: Colors.grey[600], fontSize: 12)),
                ],
              ),
            ],
          ),

          if (_post.videoUrl != null)
            Padding(
              padding: const EdgeInsets.only(top: 16.0),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: PostVideoPlayer(
                  key: ValueKey(_post.videoUrl!),
                  videoUrl: _post.videoUrl!,
                  isSquare: true, 
                  onControllerInitialized: (_) {},
                ),
              ),
            ),

          if (_post.imageUrl != null)
            Padding(
              padding: const EdgeInsets.only(top: 16.0),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: AspectRatio(
                  aspectRatio: 4 / 3,
                  child: _post.imageUrl!.startsWith('assets/') 
                    ? Image.asset(_post.imageUrl!, fit: BoxFit.cover) 
                    : (_post.imageUrl!.startsWith('http') ? Image.network(_post.imageUrl!, fit: BoxFit.cover) : Image.file(File(_post.imageUrl!), fit: BoxFit.cover)),
                ),
              ),
            ),

          const SizedBox(height: 16),
          Text(_post.title, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
          const SizedBox(height: 8),
          Text(_post.content, style: const TextStyle(fontSize: 15, height: 1.4, color: Colors.black87)),
          const SizedBox(height: 16),
        ],
      ),
    );
  }

  Widget _buildCommentSectionHeader(int count) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
      child: Text("Comments ($count)", style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: Colors.black54)),
    );
  }

  Widget _buildCommentList(List<CommentData> comments) {
    if (comments.isEmpty) {
      return Padding(padding: const EdgeInsets.all(40.0), child: Center(child: Column(children: [Icon(Icons.chat_bubble_outline, size: 48, color: Colors.grey[300]), const SizedBox(height: 12), Text('No comments yet.', style: TextStyle(color: Colors.grey[500])), Text('Start the conversation.', style: TextStyle(color: Colors.grey[400], fontSize: 12))])));
    }
    return ListView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: comments.length,
      itemBuilder: (context, index) {
        return _buildInstagramStyleComment(comments[index]);
      },
    );
  }

  Widget _buildInstagramStyleComment(CommentData comment) {
    final double leftPadding = comment.isReply ? 54.0 : 16.0;
    final double avatarRadius = comment.isReply ? 12.0 : 16.0;
    
    // We check if it is "my comment" by checking author name, but using UID is safer if you have it.
    // For now we check name as in original code, or you could update to check UID if available in CommentData.
    final currentUserUid = FirebaseAuth.instance.currentUser?.uid;
    final bool isMyComment = comment.authorId == currentUserUid;

    return Padding(
      padding: EdgeInsets.fromLTRB(leftPadding, 12, 16, 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // --- UPDATED: Show Commenter's Profile Image ---
          if (comment.authorProfileImage != null && comment.authorProfileImage!.isNotEmpty)
            CircleAvatar(
              radius: avatarRadius,
              backgroundImage: NetworkImage(comment.authorProfileImage!),
              backgroundColor: Colors.grey[200],
            )
          else
            CircleAvatar(
              radius: avatarRadius,
              backgroundColor: Colors.grey[200],
              child: Text(comment.initials, style: TextStyle(fontSize: avatarRadius * 0.75, color: Colors.black87, fontWeight: FontWeight.bold)),
            ),
          // ----------------------------------------------
          const SizedBox(width: 12),
          
          Expanded(
            child: GestureDetector(
              onLongPress: () {
                if (isMyComment) {
                  _confirmDeleteComment(comment);
                }
              },
              child: Container(
                color: Colors.transparent, 
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    RichText(
                      text: TextSpan(
                        children: [
                          TextSpan(text: "${comment.author}  ", style: const TextStyle(color: Colors.black, fontWeight: FontWeight.bold, fontSize: 14)),
                          TextSpan(text: comment.content, style: const TextStyle(color: Colors.black87, fontSize: 14, height: 1.3)),
                        ],
                      ),
                    ),
                    const SizedBox(height: 6),
                    Row(
                      children: [
                        RealTimeTimestamp(timestamp: comment.timestamp, style: TextStyle(color: Colors.grey[600], fontSize: 12)),
                        const SizedBox(width: 16),
                        InkWell(
                          onTap: () => _replyToComment(comment),
                          child: Text("Reply", style: TextStyle(color: Colors.grey[600], fontSize: 12, fontWeight: FontWeight.w600)),
                        ),
                        const SizedBox(width: 16),
                        if (comment.likeCount > 0)
                          Text("${comment.likeCount} likes", style: TextStyle(color: Colors.grey[500], fontSize: 12)),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),
          
          GestureDetector(
            onTap: () => _toggleLike(comment),
            child: Padding(
              padding: const EdgeInsets.only(top: 4.0, left: 8.0),
              child: Icon(
                comment.isLiked ? Icons.favorite : Icons.favorite_border, 
                size: 16, 
                color: comment.isLiked ? Colors.red : Colors.grey[500]
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInputArea() {
    return Container(
      decoration: BoxDecoration(color: Colors.white, border: Border(top: BorderSide(color: Colors.grey[200]!, width: 1))),
      padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewPadding.bottom),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (_replyingToName != null)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              color: Colors.grey[100],
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text("Replying to $_replyingToName", style: TextStyle(color: Colors.grey[600], fontSize: 12)),
                  InkWell(
                    onTap: _cancelReply,
                    child: Icon(Icons.close, size: 16, color: Colors.grey[600]),
                  )
                ],
              ),
            ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 12.0),
            child: Row(
              children: [
                // --- UPDATED: Show Current User's Profile Image in Input ---
                if (_myProfileImage != null && _myProfileImage!.isNotEmpty)
                  CircleAvatar(
                    radius: 18,
                    backgroundImage: NetworkImage(_myProfileImage!),
                    backgroundColor: Colors.grey[200],
                  )
                else
                  CircleAvatar(
                    radius: 18, 
                    backgroundColor: const Color(0xFFF2E7FE), 
                    child: Text(_myInitials, style: const TextStyle(fontSize: 14, color: Color(0xFF980FFA)))
                  ),
                // -----------------------------------------------------------
                const SizedBox(width: 12),
                Expanded(
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    decoration: BoxDecoration(color: const Color(0xFFF3F4F6), borderRadius: BorderRadius.circular(24)),
                    child: TextField(
                      controller: _commentController,
                      focusNode: _commentFocusNode,
                      decoration: const InputDecoration(hintText: 'Add a comment...', border: InputBorder.none, contentPadding: EdgeInsets.symmetric(vertical: 10), isDense: true),
                      minLines: 1, maxLines: 5,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                TextButton(
                  onPressed: _addComment,
                  style: TextButton.styleFrom(minimumSize: Size.zero, padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8), tapTargetSize: MaterialTapTargetSize.shrinkWrap),
                  child: const Text('Post', style: TextStyle(color: Color(0xFF155DFC), fontWeight: FontWeight.bold, fontSize: 16)),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}