// lib/screens/Community_Module/create_post_screen.dart

import 'dart:io'; 
import 'dart:core';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart'; 
import 'post_data.dart';
import 'video_player_widget.dart';
import 'package:signlinggo/services/supabase_storage_service.dart'; 
import 'package:firebase_auth/firebase_auth.dart'; 

class CreatePostScreen extends StatefulWidget {
  final PostData? existingPost;
  
  const CreatePostScreen({
    super.key, 
    this.existingPost, 
  });

  @override
  State<CreatePostScreen> createState() => _CreatePostScreenState();
}

class _CreatePostScreenState extends State<CreatePostScreen> {
  final TextEditingController _titleController = TextEditingController();
  final TextEditingController _contentController = TextEditingController();
  final SupabaseStorageService _storageService = SupabaseStorageService();
  final ImagePicker _picker = ImagePicker();

  final List<String> _postTags = ['Learning Tips', 'Ask for Help', 'Share Experiences'];
  String _selectedTag = 'Learning Tips';
  
  File? _videoFile;
  File? _imageFile; 
  bool _isPosting = false;
  late bool _isEditMode;

  // Helper to get Real User Name
  String _getCurrentUserName() {
    final user = FirebaseAuth.instance.currentUser;
    if (user != null) {
      if (user.displayName != null && user.displayName!.isNotEmpty) {
        return user.displayName!;
      }
      if (user.email != null) {
        return user.email!.split('@')[0];
      }
    }
    return "Anonymous";
  }

  String _getInitials(String name) {
    if (name.isEmpty) return "?";
    return name[0].toUpperCase();
  }

  @override
  void initState() {
    super.initState();
    _isEditMode = widget.existingPost != null;
    
    if (_isEditMode) {
      _titleController.text = widget.existingPost!.title;
      _contentController.text = widget.existingPost!.content;
      _selectedTag = widget.existingPost!.tag; 
    }
  }

  Future<void> _pickVideo() async {
    final XFile? pickedFile = await _picker.pickVideo(source: ImageSource.gallery);
    if (pickedFile != null) {
      setState(() {
        _videoFile = File(pickedFile.path);
        _imageFile = null; 
      });
    }
  }

  Future<void> _pickImage() async {
    final XFile? pickedFile = await _picker.pickImage(source: ImageSource.gallery);
    if (pickedFile != null) {
      setState(() {
        _imageFile = File(pickedFile.path);
        _videoFile = null; 
      });
    }
  }

  void _removeMedia() {
    setState(() {
      _videoFile = null;
      _imageFile = null;
    });
  }

  void _submitPost() async {
    final String title = _titleController.text;
    final String content = _contentController.text;

    if (title.isEmpty || content.isEmpty) {
       ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please add a title and content')),
      );
      return;
    }

    setState(() {
      _isPosting = true; 
    });

    try {
      String? finalVideoUrl;
      String? finalImageUrl;

      if (_videoFile != null) {
        finalVideoUrl = await _storageService.uploadFile(_videoFile!, 'vid');
        if (finalVideoUrl == null) throw Exception("Video upload failed");
      }
      
      if (_imageFile != null) {
        finalImageUrl = await _storageService.uploadFile(_imageFile!, 'img');
        if (finalImageUrl == null) throw Exception("Image upload failed");
      }

      // --- GET REAL USER INFO ---
      final String realAuthor = _getCurrentUserName();
      final String realInitials = _getInitials(realAuthor);
      // --- GET USER ID ---
      final String currentUserId = FirebaseAuth.instance.currentUser?.uid ?? '';

      if (_isEditMode) {
        PostData updatedPost;

        if (finalVideoUrl != null || finalImageUrl != null) {
          updatedPost = PostData(
            id: widget.existingPost!.id,
            authorId: widget.existingPost!.authorId, // Keep original ID
            initials: widget.existingPost!.initials,
            author: widget.existingPost!.author,
            timestamp: widget.existingPost!.timestamp,
            likes: widget.existingPost!.likes,
            commentList: widget.existingPost!.commentList,
            isLiked: widget.existingPost!.isLiked,
            showFollowButton: widget.existingPost!.showFollowButton,
            profileGradient: widget.existingPost!.profileGradient,
            isFollowed: widget.existingPost!.isFollowed,
            commentCount: widget.existingPost!.commentCount,
            
            title: title,
            content: content,
            tag: _selectedTag,
            isEdited: true,
            videoUrl: finalVideoUrl,
            imageUrl: finalImageUrl, 
          );
        } else {
          updatedPost = widget.existingPost!.copyWith(
            title: title,
            content: content,
            tag: _selectedTag,
            isEdited: true,
          );
        }

        if (mounted) Navigator.pop(context, updatedPost);
        
      } else {
        // --- NEW POST ---
        final newPost = PostData(
          id: DateTime.now().millisecondsSinceEpoch.toString(), 
          authorId: currentUserId, // <--- SAVE UID HERE
          title: title,
          content: content,
          tag: _selectedTag,
          author: realAuthor,      
          initials: realInitials, 
          timestamp: DateTime.now(),
          likes: 0,
          commentCount: 0,
          commentList: [],
          isLiked: false,
          showFollowButton: true, // Everyone else can follow
          isFollowed: false,
          videoUrl: finalVideoUrl, 
          imageUrl: finalImageUrl, 
        );
        
        if (mounted) Navigator.pop(context, newPost);
      }

    } catch (e) {
      print("Error creating/editing post: $e");
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e')),
        );
        setState(() => _isPosting = false);
      }
    } 
  }

  @override
  void dispose() {
    _titleController.dispose();
    _contentController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    Widget? mediaPreview;
    
    if (_videoFile != null) {
      mediaPreview = _buildVideoPreview();
    } else if (_imageFile != null) {
      mediaPreview = _buildImagePreview();
    } else if (_isEditMode) {
      if (widget.existingPost!.videoUrl != null) {
        mediaPreview = _buildExistingVideoPreview(widget.existingPost!.videoUrl!);
      } else if (widget.existingPost!.imageUrl != null) {
        mediaPreview = _buildExistingImagePreview(widget.existingPost!.imageUrl!);
      }
    }

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: _buildAppBar(),
      body: Column(
        children: [
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(20.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildUserHeader(),
                  const SizedBox(height: 20),
                  
                  TextField(
                    controller: _titleController,
                    style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: Colors.black87),
                    decoration: const InputDecoration(
                      hintText: 'Give your post a title...',
                      hintStyle: TextStyle(color: Colors.grey, fontSize: 22, fontWeight: FontWeight.bold),
                      border: InputBorder.none,
                      contentPadding: EdgeInsets.zero,
                    ),
                    textCapitalization: TextCapitalization.sentences,
                  ),
                  
                  const SizedBox(height: 12),
                  
                  TextField(
                    controller: _contentController,
                    style: const TextStyle(fontSize: 16, height: 1.5, color: Colors.black87),
                    decoration: const InputDecoration(
                      hintText: 'What do you want to share today?',
                      hintStyle: TextStyle(color: Colors.grey, fontSize: 16),
                      border: InputBorder.none,
                      contentPadding: EdgeInsets.zero,
                    ),
                    maxLines: null,
                    keyboardType: TextInputType.multiline,
                    textCapitalization: TextCapitalization.sentences,
                  ),
                  
                  const SizedBox(height: 20),

                  if (mediaPreview != null) mediaPreview,
                ],
              ),
            ),
          ),
          
          _buildBottomToolbar(),
        ],
      ),
    );
  }

  PreferredSizeWidget _buildAppBar() {
    return AppBar(
      backgroundColor: Colors.white,
      elevation: 0,
      leading: IconButton(
        icon: const Icon(Icons.close, color: Colors.black),
        onPressed: () => Navigator.pop(context),
      ),
      title: Text(
        _isEditMode ? 'Edit Post' : 'New Post',
        style: const TextStyle(color: Colors.black, fontWeight: FontWeight.bold, fontSize: 18),
      ),
      centerTitle: true,
      actions: [
        Padding(
          padding: const EdgeInsets.only(right: 16.0, top: 10, bottom: 10),
          child: ElevatedButton(
            onPressed: _isPosting ? null : _submitPost,
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF155DFC), 
              foregroundColor: Colors.white,
              elevation: 0,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
              padding: const EdgeInsets.symmetric(horizontal: 20),
            ),
            child: _isPosting
                ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                : const Text('Post', style: TextStyle(fontWeight: FontWeight.bold)),
          ),
        ),
      ],
    );
  }

  Widget _buildUserHeader() {
    final String currentName = _getCurrentUserName();
    final String currentInitials = _getInitials(currentName);

    return Row(
      children: [
        Container(
          width: 44, height: 44,
          decoration: const BoxDecoration(
            gradient: LinearGradient(colors: [Color(0xFF155CFB), Color(0xFF980FFA)]),
            shape: BoxShape.circle,
          ),
          child: Center(child: Text(currentInitials, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold))),
        ),
        const SizedBox(width: 12),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(currentName, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: Colors.black)),
            const SizedBox(height: 2),
            Container(
              height: 26,
              padding: const EdgeInsets.symmetric(horizontal: 8),
              decoration: BoxDecoration(
                border: Border.all(color: const Color(0xFF155DFC).withOpacity(0.3)),
                borderRadius: BorderRadius.circular(20),
                color: const Color(0xFF155DFC).withOpacity(0.05),
              ),
              child: DropdownButtonHideUnderline(
                child: DropdownButton<String>(
                  value: _selectedTag,
                  icon: const Icon(Icons.keyboard_arrow_down, size: 16, color: Color(0xFF155DFC)),
                  style: const TextStyle(color: Color(0xFF155DFC), fontSize: 12, fontWeight: FontWeight.bold),
                  isDense: true,
                  items: _postTags.map((String tag) {
                    return DropdownMenuItem<String>(value: tag, child: Text(tag));
                  }).toList(),
                  onChanged: (newValue) {
                    setState(() { if (newValue != null) _selectedTag = newValue; });
                  },
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildVideoPreview() {
    return Stack(
      alignment: Alignment.topRight,
      children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(16),
          child: SizedBox(
            height: 300, 
            width: double.infinity,
            child: PostVideoPlayer(
              videoUrl: _videoFile!.path,
              isSquare: false,
              onControllerInitialized: (controller) {
                controller.setVolume(1.0);
              },
            ),
          ),
        ),
        _buildRemoveButton(),
      ],
    );
  }

  Widget _buildImagePreview() {
    return Stack(
      alignment: Alignment.topRight,
      children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(16),
          child: Image.file(
            _imageFile!,
            width: double.infinity,
            fit: BoxFit.cover,
          ),
        ),
        _buildRemoveButton(),
      ],
    );
  }

  Widget _buildExistingVideoPreview(String url) {
    return Stack(
      alignment: Alignment.topRight,
      children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(16),
          child: SizedBox(
            height: 300, 
            width: double.infinity,
            child: PostVideoPlayer(
              videoUrl: url, 
              isSquare: false,
              onControllerInitialized: (_) {},
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildExistingImagePreview(String url) {
    return Stack(
      alignment: Alignment.topRight,
      children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(16),
          child: AspectRatio(
            aspectRatio: 4/3,
            child: url.startsWith('assets/') 
              ? Image.asset(url, fit: BoxFit.cover) 
              : (url.startsWith('http') ? Image.network(url, fit: BoxFit.cover) : Image.file(File(url), fit: BoxFit.cover)),
          ),
        ),
      ],
    );
  }

  Widget _buildRemoveButton() {
    return Padding(
      padding: const EdgeInsets.all(8.0),
      child: GestureDetector(
        onTap: _removeMedia,
        child: Container(
          padding: const EdgeInsets.all(6),
          decoration: BoxDecoration(color: Colors.black.withOpacity(0.6), shape: BoxShape.circle),
          child: const Icon(Icons.close, color: Colors.white, size: 18),
        ),
      ),
    );
  }

  Widget _buildBottomToolbar() {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border(top: BorderSide(color: Colors.grey[200]!, width: 1)),
      ),
      padding: EdgeInsets.only(
        left: 16, right: 16, top: 12, 
        bottom: MediaQuery.of(context).viewPadding.bottom + 12
      ),
      child: Row(
        children: [
          InkWell(
            onTap: _pickVideo,
            borderRadius: BorderRadius.circular(8),
            child: Padding(
              padding: const EdgeInsets.all(8.0),
              child: Icon(Icons.videocam_outlined, color: _videoFile != null ? const Color(0xFF155DFC) : Colors.grey[600], size: 28),
            ),
          ),
          const SizedBox(width: 8),
          InkWell(
            onTap: _pickImage,
            borderRadius: BorderRadius.circular(8),
            child: Padding(
              padding: const EdgeInsets.all(8.0),
              child: Icon(Icons.image_outlined, color: _imageFile != null ? const Color(0xFF155DFC) : Colors.grey[600], size: 26),
            ),
          ),
          const Spacer(),
        ],
      ),
    );
  }
}