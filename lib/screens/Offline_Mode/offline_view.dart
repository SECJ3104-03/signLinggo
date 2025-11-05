import 'package:flutter/material.dart';
// --- NEW: Import the package we just added ---
import 'package:scroll_to_index/scroll_to_index.dart';

// --- STEP 1: CREATE A DATA MODEL ---
// This class holds the data for each item, so we don't
// have to hardcode it in the layout.
class _DownloadableItemData {
  final String title;
  final String description;
  final IconData icon; // We pass the icon itself
  final Color iconColor; // The color of the icon
  final Color backgroundColor; // The pastel background color

  const _DownloadableItemData({
    required this.title,
    required this.description,
    required this.icon,
    required this.iconColor,
    required this.backgroundColor,
  });
}

// --- STEP 2: CREATE THE SEARCHDELEGATE CLASS ---
// This class controls the new search screen that will open.
class _DownloadSearchDelegate extends SearchDelegate<_DownloadableItemData> {
  // --- We pass in the full list of items to search through ---
  final List<_DownloadableItemData> searchItems;

  _DownloadSearchDelegate({required this.searchItems});

  // --- This builds the "clear" button (the 'X') on the right ---
  @override
  List<Widget>? buildActions(BuildContext context) {
    return [
      IconButton(
        icon: const Icon(Icons.clear),
        onPressed: () {
          if (query.isEmpty) {
            close(context,
                _DownloadableItemData(title: '', description: '', icon: Icons.error, iconColor: Colors.transparent, backgroundColor: Colors.transparent)); // Return a dummy/empty item
          } else {
            query = '';
          }
        },
      ),
    ];
  }

  // --- This builds the "back" button on the left ---
  @override
  Widget? buildLeading(BuildContext context) {
    return IconButton(
      icon: const Icon(Icons.arrow_back),
      onPressed: () {
        close(context,
            _DownloadableItemData(title: '', description: '', icon: Icons.error, iconColor: Colors.transparent, backgroundColor: Colors.transparent)); // Return a dummy/empty item
      },
    );
  }

  // --- This builds the results AFTER user presses "search" ---
  @override
  Widget buildResults(BuildContext context) {
    return _buildSuggestions(context);
  }

  // --- This builds the list of suggestions as the user types ---
  @override
  Widget buildSuggestions(BuildContext context) {
    return _buildSuggestions(context);
  }

  // --- This is our suggestion-building logic ---
  Widget _buildSuggestions(BuildContext context) {
    final List<_DownloadableItemData> suggestions = searchItems.where((item) {
      final titleLower = item.title.toLowerCase();
      final descriptionLower = item.description.toLowerCase();
      final queryLower = query.toLowerCase();
      return titleLower.contains(queryLower) ||
          descriptionLower.contains(queryLower);
    }).toList();

    return ListView.builder(
      itemCount: suggestions.length,
      itemBuilder: (context, index) {
        final item = suggestions[index];
        return ListTile(
          leading: Icon(item.icon, color: item.iconColor),
          title: Text(item.title),
          subtitle: Text(
            item.description,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          // --- MODIFIED: This is the new tap logic ---
          onTap: () {
            // --- NEW: Close the search and RETURN the tapped item ---
            close(context, item);
          },
        );
      },
    );
  }
}


// --- MODIFIED: STEP 3 is now a StatefulWidget ---
class OfflineMode extends StatefulWidget {
  OfflineMode({super.key});

  @override
  State<OfflineMode> createState() => _OfflineModeState();
}

// --- NEW: This is the State class for OfflineMode ---
class _OfflineModeState extends State<OfflineMode> {
  // --- NEW: We create the special scroll controller here ---
  late AutoScrollController _scrollController;

  // --- NEW: This variable will hold the title of the item to highlight ---
  String? _highlightedTitle;

  // This is our list of data.
  // --- MODIFIED: This is now inside the State class ---
  final List<_DownloadableItemData> _items = [
    _DownloadableItemData(
      title: 'Full BIM Dictionary',
      description: 'The complete collection of all BIM signs | 200 MB',
      icon: Icons.book_outlined,
      iconColor: const Color(0xFF007AFF),
      backgroundColor: const Color(0xFFEBF5FF),
    ),
    _DownloadableItemData(
      title: 'Basic Greetings & Phrases',
      description: 'Essential signs for beginners & daily chat | 15 MB',
      icon: Icons.waving_hand_outlined,
      iconColor: const Color(0xFFE5890A),
      backgroundColor: const Color(0xFFFFF2DE),
    ),
    _DownloadableItemData(
      title: 'Food & Drink Signs',
      description: 'Signs for eating, restaurant, and common foods | 20MB',
      icon: Icons.coffee_outlined,
      iconColor: const Color(0xFFD62F0B),
      backgroundColor: const Color(0xFFFFD6D1),
    ),
    _DownloadableItemData(
      title: 'Medical & Emergency',
      description: 'Critical signs for health, safety, and emergencies | 25MB',
      icon: Icons.medical_services_outlined,
      iconColor: const Color(0xFF34C759),
      backgroundColor: const Color(0xFFD5FFD4),
    ),
    _DownloadableItemData(
      title: 'Family & People',
      description: 'Signs for family members, friends, and relationships | 18 MB',
      icon: Icons.groups_outlined,
      iconColor: const Color(0xFFD60B95),
      backgroundColor: const Color(0xFFFFDFF2),
    ),
    _DownloadableItemData(
      title: 'Travel & Transport',
      description: 'Signs for travel, transport, and common actions | 22 MB',
      icon: Icons.travel_explore_outlined,
      iconColor: const Color(0xFF5E0BD6),
      backgroundColor: const Color(0xFFF5F1FF),
    ),
  ];

  // --- NEW: We initialize the controller when the screen loads ---
  @override
  void initState() {
    super.initState();
    _scrollController = AutoScrollController();
  }

  // --- NEW: We dispose of the controller when the screen closes ---
  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  // --- NEW: This is the function that handles scrolling and highlighting ---
  Future<void> _scrollToItemAndHighlight(
      _DownloadableItemData selectedItem) async {
    // 1. Find the index of the selected item in our data list
    final int dataIndex =
        _items.indexWhere((item) => item.title == selectedItem.title);

    if (dataIndex != -1) {
      // 2. The item's index in the ListView is dataIndex + 1
      //    (because our ListView index 0 is the "Downloadable Files" header)
      final int listViewIndex = dataIndex + 1;

      // 3. Set the state to highlight this item
      setState(() {
        _highlightedTitle = selectedItem.title;
      });

      // 4. Tell the controller to scroll to that item's index
      await _scrollController.scrollToIndex(
        listViewIndex,
        // --- NEW: This centers the item on the screen, which is nice ---
        preferPosition: AutoScrollPosition.middle,
        duration: const Duration(milliseconds: 500), // Animate the scroll
      );

      // 5. Wait for 2 seconds, then remove the highlight
      Future.delayed(const Duration(seconds: 2), () {
        // 'mounted' checks if the widget is still on screen
        if (mounted) {
          setState(() {
            _highlightedTitle = null;
          });
        }
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 1,
        shadowColor: Colors.black.withOpacity(0.1),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Color(0xFF101727)),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: const Text(
          'Offline Downloads',
          style: TextStyle(
            color: Color(0xFF101727),
            fontSize: 20,
            fontFamily: 'Arimo',
            fontWeight: FontWeight.w400,
          ),
        ),
        centerTitle: true,
        actions: [
          IconButton(
            icon: const Icon(Icons.search, color: Color(0xFF101727), size: 28),
            // --- MODIFIED: The search button is now async ---
            onPressed: () async {
              // --- NEW: We 'await' the result from showSearch ---
              // It will return the _DownloadableItemData that the user tapped
              final selectedItem =
                  await showSearch<_DownloadableItemData>(
                context: context,
                delegate: _DownloadSearchDelegate(searchItems: _items),
              );

              // --- NEW: If we got a real item back, scroll to it ---
              if (selectedItem != null && selectedItem.title.isNotEmpty) {
                _scrollToItemAndHighlight(selectedItem);
              }
            },
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: ListView.builder(
        // --- NEW: Assign the controller to the ListView ---
        controller: _scrollController,
        padding: const EdgeInsets.all(20.0),
        itemCount: _items.length + 1,
        itemBuilder: (context, index) {
          // --- The Title Header (Index 0) ---
          if (index == 0) {
            // --- NEW: We must wrap *every* item in an AutoScrollTag ---
            return AutoScrollTag(
              key: ValueKey(index),
              controller: _scrollController,
              index: index,
              child: const Padding(
                padding: EdgeInsets.only(bottom: 20.0),
                child: Text(
                  'Downloadable Files',
                  style: TextStyle(
                    color: Colors.black,
                    fontSize: 25.15,
                    fontFamily: 'Figtree',
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            );
          }

          // --- The List Items (Index 1+) ---
          final item = _items[index - 1]; // Get data (index - 1)

          // --- NEW: Check if this item should be highlighted ---
          final bool isHighlighted = (item.title == _highlightedTitle);

          // --- NEW: Wrap the item in the AutoScrollTag ---
          return AutoScrollTag(
            key: ValueKey(index), // Use the list index
            controller: _scrollController,
            index: index, // This is the ListView index
            child: Padding(
              padding: const EdgeInsets.only(bottom: 20.0),
              child: _DownloadableFileItem(
                data: item,
                // --- NEW: Pass the highlight flag to the card ---
                isHighlighted: isHighlighted,
              ),
            ),
          );
        },
      ),
    );
  }
}

// --- Define the different states for our download button ---
enum DownloadState {
  idle,
  downloading,
  downloaded,
}

// --- This is our stateful item card ---
class _DownloadableFileItem extends StatefulWidget {
  final _DownloadableItemData data;
  // --- NEW: Add a parameter to receive the highlight state ---
  final bool isHighlighted;

  const _DownloadableFileItem({
    required this.data,
    this.isHighlighted = false, // Default to not highlighted
  });

  @override
  State<_DownloadableFileItem> createState() => _DownloadableFileItemState();
}

class _DownloadableFileItemState extends State<_DownloadableFileItem> {
  var _downloadState = DownloadState.idle;

  void _startDownload() {
    setState(() {
      _downloadState = DownloadState.downloading;
    });
    Future.delayed(const Duration(seconds: 3), () {
      if (mounted) {
        setState(() {
          _downloadState = DownloadState.downloaded;
        });
      }
    });
  }

  Widget _buildDownloadIcon() {
    switch (_downloadState) {
      case DownloadState.idle:
        return IconButton(
          icon: const Icon(
            Icons.download_outlined,
            color: Color(0xFF007AFF),
            size: 30,
          ),
          onPressed: _startDownload,
        );
      case DownloadState.downloading:
        return Container(
          padding: const EdgeInsets.all(9.0),
          width: 48,
          height: 48,
          child: const CircularProgressIndicator(
            strokeWidth: 2.5,
            color: Color(0xFF007AFF),
          ),
        );
      case DownloadState.downloaded:
        return const Icon(
          Icons.check_circle,
          color: Color(0xFF34C759),
          size: 30,
        );
    }
  }

  @override
  Widget build(BuildContext context) {
    // --- NEW: Define highlight colors ---
    final Color highlightColor = Color(0xFF007AFF); // Blue
    final Color highlightBackgroundColor = Color(0xFFEBF5FF); // Light Blue

    return Container(
      padding: const EdgeInsets.all(20.0),
      // --- MODIFIED: The decoration now changes if highlighted ---
      decoration: ShapeDecoration(
        // --- NEW: Use highlight color or default white ---
        color:
            widget.isHighlighted ? highlightBackgroundColor : Colors.white,
        shape: RoundedRectangleBorder(
          // --- NEW: Use highlight border or default grey ---
          side: widget.isHighlighted
              ? BorderSide(width: 2.0, color: highlightColor)
              : const BorderSide(width: 1.26, color: Color(0xFFEBEBEB)),
          borderRadius: BorderRadius.circular(30.18),
        ),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Expanded(
            child: Row(
              children: [
                Container(
                  width: 50.29,
                  height: 50.29,
                  decoration: ShapeDecoration(
                    color: widget.data.backgroundColor,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(17.60),
                    ),
                  ),
                  child: Center(
                    child: Icon(
                      widget.data.icon,
                      color: widget.data.iconColor,
                      size: 28,
                    ),
                  ),
                ),
                const SizedBox(width: 15.09),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        widget.data.title,
                        style: const TextStyle(
                          color: Colors.black,
                          fontSize: 20.12,
                          fontFamily: 'Figtree',
                          fontWeight: FontWeight.w600,
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 5.03),
                      Text(
                        widget.data.description,
                        style: const TextStyle(
                          color: Color(0xFFA5A5A5),
                          fontSize: 17.60,
                          fontFamily: 'Figtree',
                          fontWeight: FontWeight.w400,
                        ),
                        maxLines: 3,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 12.0),
          _buildDownloadIcon(),
        ],
      ),
    );
  }
}