// lib/screens/Community_Module/post_card.dart

import 'package:flutter/material.dart';
import 'package:video_player/video_player.dart';
import 'package:share_plus/share_plus.dart'; 
import 'post_data.dart'; 
import 'video_player_widget.dart'; 

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

  void _navigateToCommentScreen() {
    if (_videoController != null && _videoController!.value.isPlaying) {
      _videoController!.pause();
    }
    
    if (widget.onCommentTap != null) {
      widget.onCommentTap!();
    }
  }

  void _sharePost() {
    final String shareText = '${widget.post.title}\n\n${widget.post.content}';
    Share.share(shareText, subject: 'Check out this post!');
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
            // --- MODIFIED: Make card background semi-transparent ---
            color: Colors.white.withOpacity(0.85),
            shape: RoundedRectangleBorder(
              // --- MODIFIED: Use same border as HomePage cards ---
              side: const BorderSide(width: 1, color: Color(0x99FFFEFE)),
              borderRadius: BorderRadius.circular(14),
            ),
          ),
          child: Stack(
            clipBehavior: Clip.none,
            children: [
              Positioned(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  mainAxisAlignment: MainAxisAlignment.start,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildHeader(),
                    _buildContent(),
                    
                    Divider(
                      height: 1.24,
                      thickness: 1.24,
                      // --- MODIFIED: Make divider match new border ---
                      color: const Color(0x99FFFEFE),
                      indent: 21.22,
                      endIndent: 21.22,
                    ),

                    _buildFooter(), 
                  ],
                ),
              ),
              if (widget.post.author == 'You')
                _buildMoreOptionsButton()
              else if (widget.post.showFollowButton)
                _buildFollowButton(),
            ],
          ),
        ),
      ),
    );
  }

  // --- Helper Methods ---
  // (No changes needed in the helper methods _buildHeader, 
  // _buildFollowButton, _buildMoreOptionsButton, _buildContent,
  // _buildFooter, or _buildFooterIcon)
  // ... (All helper methods remain the same) ...
  Widget _buildHeader() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(21.22, 21.22, 0, 0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
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
                style: TextStyle(
                  color: const Color(0xFF0A0A0A),
                  fontSize: 16,
                  fontFamily: 'Arimo',
                  fontWeight: FontWeight.w400,
                  height: 1.50,
                ),
              ),
            ),
          ),
          const SizedBox(width: 12),
          
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  widget.post.author,
                  style: TextStyle(
                    color: const Color(0xFF101727),
                    fontSize: 18,
                    fontFamily: 'Arimo',
                    fontWeight: FontWeight.w400,
                    height: 1.50,
                  ),
                ),
                Row(
                  children: [
                    Text(
                      widget.post.timeAgo,
                      style: TextStyle(
                        color: const Color(0xFF495565),
                        fontSize: 16,
                        fontFamily: 'Arimo',
                        fontWeight: FontWeight.w400,
                        height: 1.50,
                      ),
                    ),
                    
                    if (widget.post.isEdited)
                      Padding(
                        padding: const EdgeInsets.only(left: 7.99),
                        child: Text(
                          '(edited)',
                          style: TextStyle(
                            color: const Color(0xFF495565),
                            fontSize: 15,
                            fontFamily: 'Arimo',
                            fontWeight: FontWeight.w400,
                            fontStyle: FontStyle.italic,
                            height: 1.50,
                          ),
                        ),
                      ),
                    
                    const SizedBox(width: 7.99),
                    Text(
                      '•',
                      style: TextStyle(
                        color: const Color(0xFF99A1AE),
                        fontSize: 16,
                        fontFamily: 'Arimo',
                        fontWeight: FontWeight.w400,
                        height: 1.50,
                      ),
                    ),
                    const SizedBox(width: 7.99),
                    
                    Flexible(
                      child: Text(
                        widget.post.tag,
                        style: TextStyle(
                          color: const Color(0xFF155CFB),
                          fontSize: 16,
                          fontFamily: 'Arimo',
                          fontWeight: FontWeight.w400,
                          height: 1.50,
                        ),
                        overflow: TextOverflow.ellipsis,
                        maxLines: 1,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          
          const SizedBox(width: 54),
        ],
      ),
    );
  }

  Widget _buildFollowButton() {
    return Positioned(
      right: 21.22,
      top: 22.06,
      child: InkWell(
        onTap: widget.onFollowTap,
        child: Container(
          height: 26,
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          decoration: ShapeDecoration(
            color: widget.post.isFollowed ? Color(0xFFF3F4F6) : const Color(0xFF155DFC),
            shape: RoundedRectangleBorder(
              side: BorderSide(width: 1.24, color: Colors.transparent),
              borderRadius: BorderRadius.circular(10),
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Text(
                widget.post.isFollowed ? 'Followed' : 'Follow',
                style: TextStyle(
                  color: widget.post.isFollowed ? Color(0xFF495565) : Colors.white,
                  fontSize: 14,
                  fontFamily: 'Arimo',
                  fontWeight: FontWeight.w400,
                  height: 1.43,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildMoreOptionsButton() {
    return Positioned(
      right: 21.22,
      top: 22.06,
      child: InkWell(
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

          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 21.22),
            child: Text(
              widget.post.title,
              style: TextStyle(
                color: const Color(0xFF101727),
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
                style: TextStyle(
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
              label: widget.post.commentList.length.toString(),
              color: const Color(0xFF495565),
              onTap: _navigateToCommentScreen,
            ),
            
            const Spacer(),
            
            InkWell(
              onTap: _sharePost,
              child: Container(
                width: 19.98,
                height: 19.98,
                child: Icon(Icons.share_outlined, color: const Color(0xFF495565)),
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
          Container(
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