// lib/screens/Community_Module/create_post_screen.dart

import 'dart:io'; // Import this to use the 'File' type
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart'; // Import the package
import 'package:path_provider/path_provider.dart'; // Import path_provider
import 'post_data.dart';

class CreatePostScreen extends StatefulWidget {
  // We add an optional 'existingPost'. If this is provided,
  // we enter "Edit Mode".
  final PostData? existingPost;
  
  const CreatePostScreen({
    super.key, 
    this.existingPost, // Add it to the constructor
  });

  @override
  State<CreatePostScreen> createState() => _CreatePostScreenState();
}

class _CreatePostScreenState extends State<CreatePostScreen> {
  final TextEditingController _titleController = TextEditingController();
  final TextEditingController _contentController = TextEditingController();

  final List<String> _postTags = ['Learning Tips', 'Ask for Help', 'Share Experiences'];
  String? _selectedTag = 'Learning Tips';
  
  File? _videoFile;
  final ImagePicker _picker = ImagePicker();

  bool _isPosting = false;
  
  // This boolean will track if we are in "Edit Mode"
  late bool _isEditMode;

  @override
  void initState() {
    super.initState();
    
    // Check if an 'existingPost' was passed in
    _isEditMode = widget.existingPost != null;
    
    if (_isEditMode) {
      // If it's Edit Mode, pre-fill the fields
      _titleController.text = widget.existingPost!.title;
      _contentController.text = widget.existingPost!.content;
      _selectedTag = widget.existingPost!.tag; // Set the tag
    }
  }

  // This function is called when we tap the "Add Video" button
  Future<void> _pickVideo() async {
    final XFile? pickedFile = await _picker.pickVideo(
      source: ImageSource.gallery,
    );
    
    if (pickedFile != null) {
      setState(() {
        _videoFile = File(pickedFile.path);
      });
    } else {
      print("No video selected.");
    }
  }

  // This function submits the post
  void _submitPost() async {
    final String title = _titleController.text;
    final String content = _contentController.text;

    if (title.isEmpty || content.isEmpty || _selectedTag == null) {
      print("Error: Fields cannot be empty.");
      return;
    }

    // Show loading spinner
    setState(() {
      _isPosting = true;
    });

    try {
      if (_isEditMode) {
        // --- EDIT MODE ---
        // We update the title, content, tag, and set 'isEdited' to true
        final updatedPost = widget.existingPost!.copyWith(
          title: title,
          content: content,
          tag: _selectedTag,
          
          // --- *** THIS IS THE CHANGE *** ---
          isEdited: true,
          // --- *** --- *** --- *** --- ---
        );
        
        if (mounted) {
          Navigator.pop(context, updatedPost);
        }
        
      } else {
        // --- CREATE MODE ---
        // This is the original logic for creating a new post
        
        String? finalVideoPath;
        if (_videoFile != null) {
          final Directory appDir = await getApplicationDocumentsDirectory();
          final String fileExtension = _videoFile!.path.split('.').last;
          final String newFileName = '${DateTime.now().millisecondsSinceEpoch}.$fileExtension';
          final String newPath = '${appDir.path}/$newFileName';
          final File newVideo = await _videoFile!.copy(newPath);
          finalVideoPath = newVideo.path;
        }

        // Create the new post
        final newPost = PostData(
          title: title,
          content: content,
          tag: _selectedTag!,
          author: 'You',
          initials: 'U',
          timeAgo: 'Just now',
          likes: 0,
          commentList: [],
          isLiked: false,
          showFollowButton: false,
          isFollowed: true,
          videoUrl: finalVideoPath, // This is now the unique path
          // 'isEdited' will be false by default
        );
        
        // Go back and send the new post
        if (mounted) {
          Navigator.pop(context, newPost);
        }
      }

    } catch (e) {
      print("Error creating post: $e");
      if (mounted) {
        setState(() {
          _isPosting = false;
        });
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
    return Scaffold(
      appBar: AppBar(
        // Change title based on mode
        title: Text(_isEditMode ? 'Edit Post' : 'Create New Post'),
        backgroundColor: Colors.white,
        elevation: 1,
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            Expanded(
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    
                    // We now show the Tag dropdown in BOTH modes
                    DropdownButtonFormField<String>(
                      value: _selectedTag,
                      decoration: InputDecoration(
                        labelText: 'Select a Tag',
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      items: _postTags.map((String tag) {
                        return DropdownMenuItem<String>(
                          value: tag,
                          child: Text(tag),
                        );
                      }).toList(),
                      onChanged: (String? newValue) {
                        setState(() {
                          _selectedTag = newValue;
                        });
                      },
                    ),
                    const SizedBox(height: 16),
                    
                    // --- Title TextField ---
                    TextField(
                      controller: _titleController,
                      decoration: InputDecoration(
                        labelText: 'Title',
                        hintText: 'e.g., How I learned 100 signs...',
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                    
                    // --- Content TextField ---
                    TextField(
                      controller: _contentController,
                      decoration: InputDecoration(
                        labelText: 'Content',
                        hintText: 'Write your post content here...',
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      maxLines: 8,
                      minLines: 5,
                    ),
                    const SizedBox(height: 20),
                    
                    // We only show the Video picker in CREATE mode
                    if (!_isEditMode)
                      _buildVideoPicker(),
                    
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),
            
            // --- Post Button (with loading logic) ---
            SizedBox(
              width: double.infinity,
              height: 50,
              child: ElevatedButton(
                // Disable button if 'isPosting' is true
                onPressed: _isPosting ? null : _submitPost,
                style: ElevatedButton.styleFrom(
                  backgroundColor: Theme.of(context).primaryColor,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                // Show spinner or text
                child: _isPosting
                    ? const CircularProgressIndicator(
                        valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                      )
                    // Change button text based on mode
                    : Text(
                        _isEditMode ? 'Save Changes' : 'Post',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
              ),
            ),
          ],
        ),
      ),
    );
  }
  
  // This builds the "Add Video" button
  Widget _buildVideoPicker() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        OutlinedButton.icon(
          icon: Icon(Icons.videocam),
          label: Text(_videoFile == null ? 'Add Video (Optional)' : 'Change Video'),
          onPressed: _pickVideo, 
          style: OutlinedButton.styleFrom(
            minimumSize: Size(double.infinity, 50),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
          ),
        ),
        
        if (_videoFile != null)
          Padding(
            padding: const EdgeInsets.only(top: 12.0),
            child: Row(
              children: [
                Icon(Icons.check_circle, color: Colors.green, size: 20),
                SizedBox(width: 8),
                Expanded(
                  child: Flexible(
                    child: Text(
                      'Video selected: ${_videoFile!.path.split('/').last}',
                      style: TextStyle(color: Colors.black87),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ),
              ],
            ),
          ),
      ],
    );
  }
}