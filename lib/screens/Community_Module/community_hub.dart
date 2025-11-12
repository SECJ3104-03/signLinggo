// lib/screens/Community_Module/community_hub.dart

import 'package:flutter/material.dart';
import 'post_data.dart';
import 'post_card.dart';
import 'create_post_screen.dart';
import 'comment_data.dart';
import 'post_detail_screen.dart';

class CommunityHubEdited extends StatefulWidget {
  const CommunityHubEdited({super.key});

  @override
  State<CommunityHubEdited> createState() => _CommunityHubEditedState();
}

class _CommunityHubEditedState extends State<CommunityHubEdited> {
  
  late List<PostData> _posts;
  String _selectedCategory = 'All';
  
  final TextEditingController _searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _posts = [
      PostData(
        initials: 'SC',
        author: 'Sarah Chen',
        timeAgo: '2h ago',
        tag: 'Learning Tips',
        title: 'How I learned 100 signs in a month',
        content: 'Consistency is key! I practiced 30 minutes daily and used flashcards. The progress tracker really helped me stay motivated.',
        likes: 45,
        commentList: [
          CommentData(author: 'Ahmad', initials: 'AR', content: 'Wow, great job!'),
          CommentData(author: 'Emily', initials: 'EW', content: 'That is so inspiring!'),
        ],
        isLiked: false,
        isFollowed: false,
        videoUrl: 'assets/assets/videos/Bahasa_Isyarat.mp4', // Your asset video
      ),
      const PostData(
        initials: 'AR',
        author: 'Ahmad Rahman',
        timeAgo: '5h ago',
        tag: 'Ask for Help',
        title: 'Struggling with finger spelling',
        content: 'Does anyone have tips for improving finger spelling speed? I can do it slowly but want to be faster.',
        likes: 28,
        commentList: [],
        isLiked: true,
        isFollowed: false,
        videoUrl: null,
      ),
      const PostData(
        initials: 'EW',
        author: 'Emily Wong',
        timeAgo: '1d ago',
        tag: 'Share Experiences',
        title: 'Used SignLinggo at a cafe today!',
        content: 'Had my first real conversation with a deaf barista using this app. It was amazing! Thank you SignEase team! 🙌',
        likes: 152,
        commentList: [],
        isLiked: true,
        showFollowButton: true,
        isFollowed: false,
        videoUrl: null,
      ),
    ];

    _searchController.addListener(() {
      setState(() {});
    });
  }
  
  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  // --- All helper functions (_unfocusSearch, _onFollowTapped, etc.) are unchanged ---
  void _unfocusSearch() {
    _searchController.clear(); 
    FocusManager.instance.primaryFocus?.unfocus();
  }
  void _onFollowTapped(int postIndex) {
    final post = _posts[postIndex];
    setState(() {
      _posts[postIndex] = post.copyWith(isFollowed: !post.isFollowed);
    });
  }
  void _onLikeTapped(int postIndex) {
    final post = _posts[postIndex];
    if (post.isLiked) {
      setState(() {
        _posts[postIndex] = post.copyWith(
          isLiked: false,
          likes: post.likes - 1,
        );
      });
    } else {
      setState(() {
        _posts[postIndex] = post.copyWith(
          isLiked: true,
          likes: post.likes + 1,
        );
      });
    }
  }
  void _onDeleteTapped(int postIndex) {
    setState(() {
      _posts.removeAt(postIndex);
    });
  }
  void _onMoreOptionsTapped(int postIndex) {
    showModalBottomSheet(
      context: context,
      useRootNavigator: true, 
      isScrollControlled: true, 
      builder: (context) {
        return Wrap(
          children: [
            ListTile(
              leading: Icon(Icons.edit_outlined),
              title: Text('Edit Post'),
              onTap: () {
                Navigator.pop(context); 
                _navigateToEditPost(postIndex); 
              },
            ),
            ListTile(
              leading: Icon(Icons.delete_outline_rounded, color: Colors.red[600]),
              title: Text(
                'Delete Post', 
                style: TextStyle(color: Colors.red[600]),
              ),
              onTap: () {
                Navigator.pop(context); 
                _onDeleteTapped(postIndex); 
              },
            ),
          ],
        );
      },
    );
  }
  void _onCategoryTapped(String category) {
    setState(() {
      _selectedCategory = category;
    });
  }
  void _navigateAndCreatePost() async {
    _unfocusSearch(); 
    
    final result = await Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => const CreatePostScreen()),
    );

    if (result != null && result is PostData) {
      setState(() {
        _posts.insert(0, result);
      });
    }
  }
  void _navigateToEditPost(int postIndex) async {
    _unfocusSearch(); 
    final PostData postToEdit = _posts[postIndex];

    final updatedPost = await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => CreatePostScreen(existingPost: postToEdit),
      ),
    );
    
    if (updatedPost != null && updatedPost is PostData) {
      setState(() {
        _posts[postIndex] = updatedPost;
      });
    }
  }
  void _navigateToPostDetail(int postIndex) async {
    _unfocusSearch(); 
    
    final PostData postToView = _posts[postIndex];

    final updatedPost = await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => PostDetailScreen(initialPost: postToView),
      ),
    );

    if (updatedPost != null && updatedPost is PostData) {
      setState(() {
        _posts[postIndex] = updatedPost;
      });
    }
  }
  List<PostData> get _filteredPosts {
    List<PostData> categoryFilteredList;
    switch (_selectedCategory) {
      case 'Following':
        categoryFilteredList = _posts.where((post) => post.isFollowed).toList();
        break;
      case 'Tips':
        categoryFilteredList = _posts.where((post) => post.tag == 'Learning Tips').toList();
        break;
      case 'Help':
        categoryFilteredList = _posts.where((post) => post.tag == 'Ask for Help').toList();
        break;
      case 'All':
      default:
        categoryFilteredList = _posts;
    }

    final String query = _searchController.text.trim().toLowerCase();

    if (query.isEmpty) {
      return categoryFilteredList;
    }

    return categoryFilteredList.where((post) {
      final authorName = post.author.toLowerCase();
      return authorName.contains(query);
    }).toList();
  }
  // --- End of unchanged helper functions ---


  @override
  Widget build(BuildContext context) {
    // --- NEW: Wrap the Scaffold in the gradient Container ---
    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment(0.00, 0.00),
          end: Alignment(1.00, 1.00),
          colors: [
            Color(0xFFF2E7FE),
            Color(0xFFFCE6F3),
            Color(0xFFFFECD4),
          ],
        ),
      ),
      child: Scaffold(
        // --- MODIFIED: Make Scaffold transparent ---
        backgroundColor: Colors.transparent,
        floatingActionButton: _buildFloatingAddButton(_navigateAndCreatePost),
        body: SafeArea( 
          child: Column(
            children: [
              _buildAppBar(context),
              _buildSearchBar(),
              const SizedBox(height: 24),
              _buildCategoryTabs(),
              const SizedBox(height: 24),
              
              Expanded(
                child: AnimatedSwitcher(
                  duration: const Duration(milliseconds: 300),
                  child: _buildPostList(),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // --- Helper Methods ---
  
  Widget _buildAppBar(BuildContext context) {
    return Container(
      width: double.infinity,
      height: 61.96,
      padding: const EdgeInsets.only(top: 15.99, left: 24, right: 24),
      // --- MODIFIED: Make AppBar transparent and remove box decoration ---
      decoration: BoxDecoration(color: Colors.transparent),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          InkWell(
            onTap: () {
              // --- This now correctly pops back to HomePage ---
              Navigator.of(context).pop();
            },
            child: Container(
              width: 24,
              height: 24,
              // --- MODIFIED: Icon defaults to dark color, which is correct ---
              child: Icon(Icons.arrow_back, color: Color(0xFF101727)),
            ),
          ),
          Text(
            'Community Hub',
            style: TextStyle(
              // --- This dark color is correct for the light gradient ---
              color: const Color(0xFF101727),
              fontSize: 20,
              fontFamily: 'Arimo',
              fontWeight: FontWeight.w400,
              height: 1.50,
            ),
          ),
          InkWell(
            onTap: () {
              print("Profile icon tapped");
            },
            child: Container(
              width: 24,
              height: 24,
              // --- MODIFIED: Icon defaults to dark color, which is correct ---
              child: Icon(Icons.person_outline, color: Color(0xFF101727)),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSearchBar() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: Container(
        width: double.infinity,
        height: 47.99,
        child: Stack(
          children: [
            Positioned(
              left: 0,
              right: 0, 
              top: 0,
              bottom: 0,
              child: Container(
                clipBehavior: Clip.antiAlias,
                decoration: ShapeDecoration(
                  // --- MODIFIED: Make search bar semi-transparent ---
                  color: const Color(0xFFF9FAFB).withOpacity(0.85),
                  shape: RoundedRectangleBorder(
                    // --- MODIFIED: Use same border as HomePage cards ---
                    side: const BorderSide(width: 1, color: Color(0x99FFFEFE)),
                    borderRadius: BorderRadius.circular(16),
                  ),
                ),
                child: Padding(
                  padding: const EdgeInsets.only(top: 0, left: 44, right: 12, bottom: 0),
                  child: TextField(
                    controller: _searchController,
                    decoration: InputDecoration(
                      hintText: 'Search posts...',
                      border: InputBorder.none,
                      hintStyle: TextStyle(
                        color: const Color(0xFF717182),
                        fontSize: 16,
                        fontFamily: 'Arimo',
                        fontWeight: FontWeight.w400,
                      ),
                    ),
                    style: TextStyle(
                      color: Colors.black,
                      fontSize: 16,
                      fontFamily: 'Arimo',
                      fontWeight: FontWeight.w400,
                    ),
                  ),
                ),
              ),
            ),
            Positioned(
              left: 11.99,
              top: 14.01,
              child: Container(
                width: 19.98,
                height: 19.98,
                child: Icon(Icons.search, color: const Color(0xFF717182)),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCategoryTabs() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: Container(
        width: double.infinity,
        height: 35.99,
        padding: const EdgeInsets.only(right: 0.02),
        decoration: ShapeDecoration(
          // --- MODIFIED: Make tabs background semi-transparent ---
          color: const Color(0xFFF3F4F6).withOpacity(0.85),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
          ),
        ),
        child: Row(
          children: [
            Expanded(
              child: _buildTabItem(
                'All',
                isSelected: _selectedCategory == 'All',
                onTap: () => _onCategoryTapped('All'),
              ),
            ),
            Expanded(
              child: _buildTabItem(
                'Following',
                isSelected: _selectedCategory == 'Following',
                onTap: () => _onCategoryTapped('Following'),
              ),
            ),
            Expanded(
              child: _buildTabItem(
                'Tips',
                isSelected: _selectedCategory == 'Tips',
                onTap: () => _onCategoryTapped('Tips'),
              ),
            ),
            Expanded(
              child: _buildTabItem(
                'Help',
                isSelected: _selectedCategory == 'Help',
                onTap: () => _onCategoryTapped('Help'),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTabItem(String title, {required bool isSelected, required VoidCallback onTap}) {
    return InkWell(
      onTap: onTap,
      child: Container(
        height: 29,
        padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
        decoration: ShapeDecoration(
          // --- MODIFIED: Selected tab is now semi-transparent white ---
          color: isSelected ? Colors.white.withOpacity(0.9) : Colors.transparent,
          shape: RoundedRectangleBorder(
            // --- MODIFIED: Use same border as HomePage cards ---
            side: isSelected 
                ? const BorderSide(width: 1, color: Color(0x99FFFEFE)) 
                : BorderSide.none,
            borderRadius: BorderRadius.circular(14),
          ),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Flexible(
              child: Text(
                title,
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: const Color(0xFF0A0A0A),
                  fontSize: 14,
                  fontFamily: 'Arimo',
                  fontWeight: FontWeight.w400,
                  height: 1.43,
                ),
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPostList() {
    final String listKey = '${_selectedCategory}_${_searchController.text}';

    if (_filteredPosts.isEmpty) {
      return Container(
        key: ValueKey(listKey), 
        child: Center(
          child: Text(
            'No posts found.',
            style: TextStyle(
              color: Colors.grey[600],
              fontSize: 16,
            ),
          ),
        ),
      );
    }

    return ListView.builder(
      key: ValueKey(listKey),
      padding: const EdgeInsets.only(top: 0),
      itemCount: _filteredPosts.length,
      itemBuilder: (context, index) {
        
        final post = _filteredPosts[index];
        final int originalIndex = _posts.indexOf(post);

        return Padding(
          padding: const EdgeInsets.fromLTRB(24, 0, 24, 15.99),
          child: PostCard(
            post: post,
            onFollowTap: () => _onFollowTapped(originalIndex),
            onLikeTap: () => _onLikeTapped(originalIndex),
            onMoreOptionsTap: () => _onMoreOptionsTapped(originalIndex),
            onCommentTap: () => _navigateToPostDetail(originalIndex),
          ),
        );
      },
    );
  }

  Widget _buildFloatingAddButton(VoidCallback onTap) {
    return InkWell(
      onTap: onTap,
      child: Container(
        width: 64,
        height: 64,
        decoration: ShapeDecoration(
          gradient: LinearGradient(
            begin: Alignment(0.00, 0.00),
            end: Alignment(1.00, 1.00),
            colors: [const Color(0xFFF6329A), const Color(0xFFAC46FF), const Color(0xFF4F39F6)],
          ),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(41659800),
          ),
          shadows: [
            BoxShadow(
              color: Color(0x7FAC46FF),
              blurRadius: 50,
              offset: Offset(0, 25),
              spreadRadius: -12,
            )
          ],
        ),
        child: Icon(Icons.add, color: Colors.white, size: 32),
      ),
    );
  }
}