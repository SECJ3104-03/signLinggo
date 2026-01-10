// lib/screens/Community_Module/post_card.dart

import 'dart:io';
import 'dart:core';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:video_player/video_player.dart';
import 'package:share_plus/share_plus.dart';
import 'package:path_provider/path_provider.dart';
import 'package:http/http.dart' as http;
import 'package:firebase_auth/firebase_auth.dart';
import 'post_data.dart';
import 'video_player_widget.dart';
import 'package:signlinggo/screens/conversation_mode/conversation_mode_screen.dart';
import 'real_time_widget.dart';
import 'share_post_sheet.dart'; // <--- Import the new sheet

class PostCard extends StatefulWidget {
  final PostData post;
  final VoidCallback? onFollowTap;
  final VoidCallback? onLikeTap;
  final VoidCallback? onMoreOptionsTap;
  final VoidCallback? onCommentTap;

  const PostCard({
    super.key,
    required this.post,
    this.onFollowTap,
    this.onLikeTap,
    this.onMoreOptionsTap,
    this.onCommentTap,
  });

  @override
  State<PostCard> createState() => _PostCardState();
}

class _PostCardState extends State<PostCard> {
  VideoPlayerController? _videoController;
  bool _isSharing = false;

  bool get _isOwner {
    final currentUser = FirebaseAuth.instance.currentUser;
    return currentUser != null && widget.post.authorId == currentUser.uid;
  }

  void _navigateToCommentScreen() {
    if (_videoController != null && _videoController!.value.isPlaying) {
      _videoController!.pause();
    }
    if (widget.onCommentTap != null) {
      widget.onCommentTap!();
    }
  }

  void _navigateToDirectMessage() {
    if (_videoController != null && _videoController!.value.isPlaying) {
      _videoController!.pause();
    }

    final currentUser = FirebaseAuth.instance.currentUser;
    if (currentUser == null) return;

    if (currentUser.uid == widget.post.authorId) {
       ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("That's you!")),
      );
      return;
    }

    final String currentUserId = currentUser.uid;
    final String targetUserId = widget.post.authorId;

    // Generate consistent Conversation ID
    final List<String> ids = [currentUserId, targetUserId];
    ids.sort();
    final String conversationId = ids.join("_");

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => ConversationScreen(
          chatName: widget.post.author,
          avatar: widget.post.authorProfileImage ?? (widget.post.initials.isNotEmpty ? widget.post.initials : '?'),
          conversationId: conversationId,
          currentUserID: currentUserId,
        ),
      ),
    );
  }

  // --- CHANGED: Renamed from _sharePost to _shareSystem ---
  Future<void> _shareSystem() async {
    final String shareText = '${widget.post.title}\n\n${widget.post.content}\n\nSent via SignLinggo App';
    final String? mediaPath = widget.post.videoUrl ?? widget.post.imageUrl;

    if (mediaPath == null) {
      Share.share(shareText);
    } else {
      setState(() { _isSharing = true; });
      try {
        XFile fileToShare;
        if (mediaPath.startsWith('http') || mediaPath.startsWith('https')) {
          final response = await http.get(Uri.parse(mediaPath));
          final tempDir = await getTemporaryDirectory();
          final String fileExtension = mediaPath.split('.').last.split('?').first;
          final File tempFile = File('${tempDir.path}/shared_file.$fileExtension');
          await tempFile.writeAsBytes(response.bodyBytes);
          fileToShare = XFile(tempFile.path);
        } else if (mediaPath.startsWith('assets/')) {
          final byteData = await rootBundle.load(mediaPath);
          final tempDir = await getTemporaryDirectory();
          final String fileName = mediaPath.split('/').last;
          final File tempFile = File('${tempDir.path}/$fileName');
          await tempFile.writeAsBytes(byteData.buffer.asUint8List(
            byteData.offsetInBytes,
            byteData.lengthInBytes
          ));
          fileToShare = XFile(tempFile.path);
        } else {
          fileToShare = XFile(mediaPath);
        }
        await Share.shareXFiles([fileToShare], text: shareText);
      } catch (e) {
        print("Error sharing file: $e");
        Share.share(shareText);
      } finally {
        if (mounted) setState(() { _isSharing = false; });
      }
    }
  }

  // --- NEW: Shows options to share via system or internal chat ---
  void _onShareButtonTapped() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true, // Optional: helps if content is long
      builder: (context) => Container(
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.only(
            topLeft: Radius.circular(20), 
            topRight: Radius.circular(20)
          ),
        ),
        // --- FIX: Wrap content in SafeArea to avoid overlap with nav bar ---
        child: SafeArea(
          child: Wrap(
            children: [
              Padding(
                padding: const EdgeInsets.all(16.0),
                child: Center(
                  child: Container(
                    width: 40, height: 4, 
                    decoration: BoxDecoration(
                      color: Colors.grey[300], 
                      borderRadius: BorderRadius.circular(2)
                    ),
                  ),
                ),
              ),
              ListTile(
                leading: const Icon(Icons.send_rounded, color: Color(0xFFAC46FF)),
                title: const Text('Send in SignLinggo'),
                onTap: () {
                  Navigator.pop(context); 
                  
                  final user = FirebaseAuth.instance.currentUser;
                  if (user != null) {
                    showModalBottomSheet(
                      context: context,
                      isScrollControlled: true,
                      backgroundColor: Colors.transparent,
                      builder: (context) => SharePostSheet(
                        post: widget.post, 
                        currentUserId: user.uid
                      ),
                    );
                  } else {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text("Please login first"))
                    );
                  }
                },
              ),
              ListTile(
                leading: const Icon(Icons.share_outlined, color: Colors.black87),
                title: const Text('Share via...'),
                onTap: () {
                  Navigator.pop(context);
                  _shareSystem(); 
                },
              ),
              // Add a little bottom padding for extra breathing room if needed
              const SizedBox(height: 10),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: _navigateToCommentScreen,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(14),
        child: Container(
          width: double.infinity,
          decoration: ShapeDecoration(
            color: Colors.white.withOpacity(0.85),
            shape: RoundedRectangleBorder(
              side: const BorderSide(width: 1, color: Color(0x99FFFEFE)),
              borderRadius: BorderRadius.circular(14),
            ),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            mainAxisAlignment: MainAxisAlignment.start,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildHeader(),
              _buildContent(),
              const Divider(
                height: 1.24,
                thickness: 1.24,
                color: Color(0x99FFFEFE),
                indent: 21.22,
                endIndent: 21.22,
              ),
              _buildFooter(),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(21.22, 21.22, 21.22, 0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 1. CLICKABLE AVATAR
          GestureDetector(
            onTap: _navigateToDirectMessage,
            child: (widget.post.authorProfileImage != null && widget.post.authorProfileImage!.isNotEmpty)
              ? Container(
                  width: 39.98,
                  height: 39.98,
                  clipBehavior: Clip.antiAlias,
                  decoration: const BoxDecoration(
                    shape: BoxShape.circle,
                  ),
                  child: Image.network(
                    widget.post.authorProfileImage!,
                    fit: BoxFit.cover,
                    errorBuilder: (context, error, stackTrace) {
                      return Container(
                        decoration: ShapeDecoration(
                          gradient: widget.post.profileGradient,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(41659800)),
                        ),
                        child: Center(
                          child: Text(
                            widget.post.initials,
                            style: const TextStyle(color: Color(0xFF0A0A0A), fontSize: 16),
                          ),
                        ),
                      );
                    },
                  ),
                )
              : Container(
                  width: 39.98,
                  height: 39.98,
                  clipBehavior: Clip.antiAlias,
                  decoration: ShapeDecoration(
                    gradient: widget.post.profileGradient,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(41659800),
                    ),
                  ),
                  child: Center(
                    child: Text(
                      widget.post.initials,
                      style: const TextStyle(
                        color: Color(0xFF0A0A0A),
                        fontSize: 16,
                        fontFamily: 'Arimo',
                        fontWeight: FontWeight.w400,
                        height: 1.50,
                      ),
                    ),
                  ),
                ),
          ),
          
          const SizedBox(width: 12),

          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // 2. CLICKABLE NAME
                GestureDetector(
                  onTap: _navigateToDirectMessage,
                  child: Text(
                    widget.post.author,
                    style: const TextStyle(
                      color: Color(0xFF101727),
                      fontSize: 18,
                      fontFamily: 'Arimo',
                      fontWeight: FontWeight.w400,
                      height: 1.50,
                    ),
                  ),
                ),
                
                // 3. TAGS & TIMESTAMP
                Wrap(
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    RealTimeTimestamp(
                      timestamp: widget.post.timestamp,
                      style: const TextStyle(
                        color: Color(0xFF495565),
                        fontSize: 16,
                        fontFamily: 'Arimo',
                        fontWeight: FontWeight.w400,
                        height: 1.50,
                      ),
                    ),
                    if (widget.post.isEdited)
                      const Padding(
                        padding: EdgeInsets.only(left: 7.99),
                        child: Text(
                          '(edited)',
                          style: TextStyle(
                            color: Color(0xFF495565),
                            fontSize: 15,
                            fontFamily: 'Arimo',
                            fontWeight: FontWeight.w400,
                            fontStyle: FontStyle.italic,
                            height: 1.50,
                          ),
                        ),
                      ),
                    const SizedBox(width: 7.99),
                    const Text(
                      '•',
                      style: TextStyle(
                        color: Color(0xFF99A1AE),
                        fontSize: 16,
                        fontFamily: 'Arimo',
                        fontWeight: FontWeight.w400,
                        height: 1.50,
                      ),
                    ),
                    const SizedBox(width: 7.99),
                    Text(
                      widget.post.tag,
                      style: const TextStyle(
                        color: Color(0xFF155CFB),
                        fontSize: 16,
                        fontFamily: 'Arimo',
                        fontWeight: FontWeight.w400,
                        height: 1.50,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ],
            ),
          ),

          if (_isOwner)
            InkWell(
              onTap: widget.onMoreOptionsTap,
              borderRadius: BorderRadius.circular(20),
              child: Container(
                padding: const EdgeInsets.all(4.0),
                child: Icon(
                  Icons.more_horiz,
                  color: Colors.grey[700],
                  size: 24,
                ),
              ),
            )
          else if (widget.post.showFollowButton)
            InkWell(
              onTap: widget.onFollowTap,
              child: Container(
                height: 26,
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                decoration: ShapeDecoration(
                  color: widget.post.isFollowed ? const Color(0xFFF3F4F6) : const Color(0xFF155DFC),
                  shape: RoundedRectangleBorder(
                    side: const BorderSide(width: 1.24, color: Colors.transparent),
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
                child: Text(
                  widget.post.isFollowed ? 'Followed' : 'Follow',
                  style: TextStyle(
                    color: widget.post.isFollowed ? const Color(0xFF495565) : Colors.white,
                    fontSize: 14,
                    fontFamily: 'Arimo',
                    fontWeight: FontWeight.w400,
                    height: 1.43,
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildContent() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(0, 20, 0, 0),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (widget.post.videoUrl != null)
            Padding(
              padding: const EdgeInsets.only(bottom: 20.0),
              child: PostVideoPlayer(
                key: ValueKey(widget.post.videoUrl!),
                videoUrl: widget.post.videoUrl!,
                isSquare: true,
                onControllerInitialized: (controller) {
                  _videoController = controller;
                },
              ),
            ),

          if (widget.post.imageUrl != null)
            Padding(
              padding: const EdgeInsets.only(bottom: 20.0),
              child: AspectRatio(
                aspectRatio: 4 / 3,
                child: _buildImageWidget(widget.post.imageUrl!),
              ),
            ),

          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 21.22),
            child: Text(
              widget.post.title,
              style: const TextStyle(
                color: Color(0xFF101727),
                fontSize: 18,
                fontFamily: 'Arimo',
                fontWeight: FontWeight.bold,
                height: 1.50,
              ),
            ),
          ),

          const SizedBox(height: 12),

          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 21.22),
            child: SizedBox(
              width: double.infinity,
              child: Text(
                widget.post.content,
                style: const TextStyle(
                  color: Colors.black87,
                  fontSize: 15,
                  fontFamily: 'Arimo',
                  fontWeight: FontWeight.w400,
                  height: 1.50,
                ),
              ),
            ),
          ),

          const SizedBox(height: 40),
        ],
      ),
    );
  }

  Widget _buildImageWidget(String path) {
    if (path.startsWith('http') || path.startsWith('https')) {
      return Image.network(
        path,
        fit: BoxFit.cover,
        loadingBuilder: (context, child, loadingProgress) {
          if (loadingProgress == null) return child;
          return Center(child: CircularProgressIndicator());
        },
        errorBuilder: (context, error, stackTrace) {
          return Center(child: Icon(Icons.error, color: Colors.red));
        },
      );
    } else if (path.startsWith('assets/')) {
      return Image.asset(path, fit: BoxFit.cover);
    } else {
      return Image.file(File(path), fit: BoxFit.cover);
    }
  }

  Widget _buildFooter() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 21.22),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 12.0),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.start,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            _buildFooterIcon(
              icon: widget.post.isLiked ? Icons.favorite : Icons.favorite_border,
              label: widget.post.likes.toString(),
              color: widget.post.isLiked ? const Color(0xFFFA2B36) : const Color(0xFF495565),
              onTap: widget.onLikeTap,
            ),

            const SizedBox(width: 24),

            _buildFooterIcon(
              icon: Icons.chat_bubble_outline,
              label: (widget.post.commentCount < 0 ? 0 : widget.post.commentCount).toString(),
              color: const Color(0xFF495565),
              onTap: _navigateToCommentScreen,
            ),

            if (!_isOwner) ...[
              const SizedBox(width: 24),
              InkWell(
                onTap: _navigateToDirectMessage,
                child: Row(
                  children: [
                    const Icon(Icons.send_outlined, color: Color(0xFF495565), size: 20),
                  ],
                ),
              ),
            ],

            const Spacer(),

            // --- CHANGED: Use new share button handler ---
            InkWell(
              onTap: _isSharing ? null : _onShareButtonTapped, 
              child: SizedBox(
                width: 19.98,
                height: 19.98,
                child: _isSharing
                    ? const SizedBox(
                        width: 14,
                        height: 14,
                        child: CircularProgressIndicator(strokeWidth: 2, color: Colors.grey)
                      )
                    : const Icon(Icons.share_outlined, color: Color(0xFF495565)),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFooterIcon({
    required IconData icon,
    required String label,
    required Color color,
    required VoidCallback? onTap,
  }) {
    return InkWell(
      onTap: onTap,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        mainAxisAlignment: MainAxisAlignment.start,
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          SizedBox(
            width: 19.98,
            height: 19.98,
            child: Icon(icon, color: color, size: 19.98),
          ),
          const SizedBox(width: 7.99),
          Text(
            label,
            style: TextStyle(
              color: color,
              fontSize: 16,
              fontFamily: 'Arimo',
              fontWeight: FontWeight.w400,
              height: 1.50,
            ),
          ),
        ],
      ),
    );
  }
}