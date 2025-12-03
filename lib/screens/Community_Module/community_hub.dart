// lib/screens/Community_Module/community_hub.dart

import 'package:flutter/material.dart';
import 'post_data.dart';
import 'post_card.dart';
import 'create_post_screen.dart';
import 'post_detail_screen.dart';
import 'package:signlinggo/screens/conversation_mode/chat_list_screen.dart';
import 'firestore_service.dart'; 

class CommunityHubEdited extends StatefulWidget {
  const CommunityHubEdited({super.key});

  @override
  State<CommunityHubEdited> createState() => _CommunityHubEditedState();
}

class _CommunityHubEditedState extends State<CommunityHubEdited> {
  final FirestoreService _firestoreService = FirestoreService();
  final TextEditingController _searchController = TextEditingController();
  
  String _selectedCategory = 'All';

  @override
  void initState() {
    super.initState();
    _searchController.addListener(() {
      setState(() {});
    });
  }
  
  void _seedDummyData() {
    final List<PostData> dummyPosts = [
      PostData(
        id: 'post_001', 
        initials: 'SC',
        author: 'Sarah Chen',
        timestamp: DateTime.now().subtract(const Duration(hours: 2)),
        tag: 'Learning Tips',
        title: 'How I learned 100 signs in a month',
        content: 'Consistency is key! I practiced 30 minutes daily and used flashcards.',
        likes: 45,
        videoUrl: 'assets/assets/videos/Bahasa_Isyarat.mp4', 
      ),
      PostData(
        id: 'post_002', 
        initials: 'AR',
        author: 'Ahmad Rahman',
        timestamp: DateTime.now().subtract(const Duration(hours: 5)),
        tag: 'Ask for Help',
        title: 'Struggling with finger spelling',
        content: 'Does anyone have tips for improving finger spelling speed?',
        likes: 28,
        isLiked: true,
        videoUrl: null,
      ),
      PostData(
        id: 'post_003', 
        initials: 'EW',
        author: 'Emily Wong',
        timestamp: DateTime.now().subtract(const Duration(days: 1)),
        tag: 'Share Experiences',
        title: 'Used SignLinggo at a cafe today!',
        content: 'Had my first real conversation with a deaf barista using this app.',
        likes: 152,
        isLiked: true,
        showFollowButton: true,
        videoUrl: null,
      ),
    ];

    for (var post in dummyPosts) {
      _firestoreService.createPost(post);
    }
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  void _unfocusSearch() {
    _searchController.clear(); 
    FocusManager.instance.primaryFocus?.unfocus();
  }

  // --- ACTIONS ---

  // --- UPDATED: Toggle Follow via Firebase ---
  void _onFollowTapped(PostData post) {
    _firestoreService.togglePostFollow(post.id, post.isFollowed);
  }

  void _onLikeTapped(PostData post) {
    _firestoreService.togglePostLike(post.id, post.isLiked, post.likes);
  }

  void _onDeleteTapped(String postId) {
    _firestoreService.deletePost(postId);
  }

  void _onMoreOptionsTapped(String postId) {
    showModalBottomSheet(
      context: context,
      useRootNavigator: true, 
      isScrollControlled: true, 
      builder: (context) {
        return Wrap(
          children: [
            ListTile(
              leading: const Icon(Icons.edit_outlined),
              title: const Text('Edit Post'),
              onTap: () {
                Navigator.pop(context); 
                // Edit logic omitted for brevity
              },
            ),
            ListTile(
              leading: Icon(Icons.delete_outline_rounded, color: Colors.red[600]),
              title: Text('Delete Post', style: TextStyle(color: Colors.red[600])),
              onTap: () {
                Navigator.pop(context); 
                _onDeleteTapped(postId); 
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
      _firestoreService.createPost(result);
    }
  }

  void _navigateToPostDetail(PostData post) {
    _unfocusSearch(); 
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => PostDetailScreen(initialPost: post),
      ),
    );
  }

  // --- FILTER LOGIC ---
  List<PostData> _filterPosts(List<PostData> allPosts) {
    List<PostData> categoryFilteredList;
    
    switch (_selectedCategory) {
      case 'Following':
        categoryFilteredList = allPosts.where((post) => post.isFollowed).toList();
        break;
      case 'Tips':
        categoryFilteredList = allPosts.where((post) => post.tag == 'Learning Tips').toList();
        break;
      case 'Help':
        categoryFilteredList = allPosts.where((post) => post.tag == 'Ask for Help').toList();
        break;
      case 'All':
      default:
        categoryFilteredList = allPosts;
    }

    final String query = _searchController.text.trim().toLowerCase();
    if (query.isEmpty) return categoryFilteredList;

    return categoryFilteredList.where((post) {
      final authorName = post.author.toLowerCase();
      return authorName.contains(query);
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
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
                child: StreamBuilder<List<PostData>>(
                  stream: _firestoreService.getPostsStream(),
                  builder: (context, snapshot) {
                    if (snapshot.connectionState == ConnectionState.waiting) {
                      return const Center(child: CircularProgressIndicator());
                    }
                    
                    if (snapshot.hasError) {
                      return const Center(child: Text("Error loading posts"));
                    }

                    final allPosts = snapshot.data ?? [];

                    // --- EMPTY STATE ---
                    if (allPosts.isEmpty) {
                      return Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            const Text("No posts found."),
                            const SizedBox(height: 10),
                            ElevatedButton(
                              onPressed: _seedDummyData, 
                              child: const Text("Initialize Mock Data")
                            ),
                          ],
                        ),
                      );
                    }

                    final displayPosts = _filterPosts(allPosts);

                    return ListView.builder(
                      padding: const EdgeInsets.only(top: 0),
                      itemCount: displayPosts.length,
                      itemBuilder: (context, index) {
                        final post = displayPosts[index];
                        return Padding(
                          padding: const EdgeInsets.fromLTRB(24, 0, 24, 15.99),
                          child: PostCard(
                            post: post,
                            // --- CONNECTED BUTTON ---
                            onFollowTap: () => _onFollowTapped(post),
                            onLikeTap: () => _onLikeTapped(post),
                            onMoreOptionsTap: () => _onMoreOptionsTapped(post.id),
                            onCommentTap: () => _navigateToPostDetail(post),
                          ),
                        );
                      },
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildAppBar(BuildContext context) {
    return Container(
      width: double.infinity,
      height: 61.96,
      padding: const EdgeInsets.only(top: 15.99, left: 24, right: 24),
      decoration: const BoxDecoration(color: Colors.transparent),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          InkWell(
            onTap: () {
              Navigator.of(context).pop();
            },
            child: const SizedBox(
              width: 24,
              height: 24,
              child: Icon(Icons.arrow_back, color: Color(0xFF101727)),
            ),
          ),
          const Text(
            'Community Hub',
            style: TextStyle(
              color: Color(0xFF101727),
              fontSize: 20,
              fontFamily: 'Arimo',
              fontWeight: FontWeight.w400,
              height: 1.50,
            ),
          ),
          InkWell(
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => const ChatListScreen()),
              );
            },
            child: const SizedBox(
              width: 24,
              height: 24,
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
      child: SizedBox(
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
                  color: const Color(0xFFF9FAFB).withOpacity(0.85),
                  shape: RoundedRectangleBorder(
                    side: const BorderSide(width: 1, color: Color(0x99FFFEFE)),
                    borderRadius: BorderRadius.circular(16),
                  ),
                ),
                child: Padding(
                  padding: const EdgeInsets.only(top: 0, left: 44, right: 12, bottom: 0),
                  child: TextField(
                    controller: _searchController,
                    decoration: const InputDecoration(
                      hintText: 'Search posts...',
                      border: InputBorder.none,
                      hintStyle: TextStyle(
                        color: Color(0xFF717182),
                        fontSize: 16,
                        fontFamily: 'Arimo',
                        fontWeight: FontWeight.w400,
                      ),
                    ),
                    style: const TextStyle(
                      color: Colors.black,
                      fontSize: 16,
                      fontFamily: 'Arimo',
                      fontWeight: FontWeight.w400,
                    ),
                  ),
                ),
              ),
            ),
            const Positioned(
              left: 11.99,
              top: 14.01,
              child: SizedBox(
                width: 19.98,
                height: 19.98,
                child: Icon(Icons.search, color: Color(0xFF717182)),
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
          color: isSelected ? Colors.white.withOpacity(0.9) : Colors.transparent,
          shape: RoundedRectangleBorder(
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
                style: const TextStyle(
                  color: Color(0xFF0A0A0A),
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

  Widget _buildFloatingAddButton(VoidCallback onTap) {
    return InkWell(
      onTap: onTap,
      child: Container(
        width: 64,
        height: 64,
        decoration: ShapeDecoration(
          gradient: const LinearGradient(
            begin: Alignment(0.00, 0.00),
            end: Alignment(1.00, 1.00),
            colors: [Color(0xFFF6329A), Color(0xFFAC46FF), Color(0xFF4F39F6)],
          ),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(41659800),
          ),
          shadows: const [
            BoxShadow(
              color: Color(0x7FAC46FF),
              blurRadius: 50,
              offset: Offset(0, 25),
              spreadRadius: -12,
            )
          ],
        ),
        child: const Icon(Icons.add, color: Colors.white, size: 32),
      ),
    );
  }
}