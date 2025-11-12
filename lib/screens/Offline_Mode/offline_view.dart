import 'package:flutter/material.dart';
import 'package:scroll_to_index/scroll_to_index.dart';

// --- STEP 1: CREATE A DATA MODEL ---
class _DownloadableItemData {
  final String title;
  final String description;
  final IconData icon; 
  final Color iconColor; 
  final Color backgroundColor; 

  const _DownloadableItemData({
    required this.title,
    required this.description,
    required this.icon,
    required this.iconColor,
    required this.backgroundColor,
  });
}

// --- STEP 2: CREATE THE SEARCHDELEGATE CLASS ---
class _DownloadSearchDelegate extends SearchDelegate<_DownloadableItemData> {
  final List<_DownloadableItemData> searchItems;

  _DownloadSearchDelegate({required this.searchItems});

  @override
  List<Widget>? buildActions(BuildContext context) {
    return [
      IconButton(
        icon: const Icon(Icons.clear),
        onPressed: () {
          if (query.isEmpty) {
            close(context,
                _DownloadableItemData(title: '', description: '', icon: Icons.error, iconColor: Colors.transparent, backgroundColor: Colors.transparent)); 
          } else {
            query = '';
          }
        },
      ),
    ];
  }

  @override
  Widget? buildLeading(BuildContext context) {
    return IconButton(
      icon: const Icon(Icons.arrow_back),
      onPressed: () {
        close(context,
            _DownloadableItemData(title: '', description: '', icon: Icons.error, iconColor: Colors.transparent, backgroundColor: Colors.transparent)); 
      },
    );
  }

  @override
  Widget buildResults(BuildContext context) {
    return _buildSuggestions(context);
  }

  @override
  Widget buildSuggestions(BuildContext context) {
    return _buildSuggestions(context);
  }

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
          onTap: () {
            close(context, item);
          },
        );
      },
    );
  }
}


// --- STEP 3: StatefulWidget ---
class OfflineMode extends StatefulWidget {
  OfflineMode({super.key});

  @override
  State<OfflineMode> createState() => _OfflineModeState();
}

class _OfflineModeState extends State<OfflineMode> {
  late AutoScrollController _scrollController;
  String? _highlightedTitle;

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

  @override
  void initState() {
    super.initState();
    _scrollController = AutoScrollController();
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _scrollToItemAndHighlight(
      _DownloadableItemData selectedItem) async {
    final int dataIndex =
        _items.indexWhere((item) => item.title == selectedItem.title);

    if (dataIndex != -1) {
      final int listViewIndex = dataIndex + 1;

      setState(() {
        _highlightedTitle = selectedItem.title;
      });

      await _scrollController.scrollToIndex(
        listViewIndex,
        preferPosition: AutoScrollPosition.middle,
        duration: const Duration(milliseconds: 500), 
      );

      Future.delayed(const Duration(seconds: 2), () {
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
    // --- MODIFIED: The gradient Container is now the PARENT ---
    // This makes the gradient cover the entire screen,
    // including the area behind the status bar and AppBar.
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
        // --- MODIFIED: Scaffold and AppBar are transparent ---
        // This lets them show the gradient from the Container behind them.
        backgroundColor: Colors.transparent, 
        appBar: AppBar(
          backgroundColor: Colors.transparent,
          elevation: 0,
          shadowColor: Colors.transparent, 
          leading: IconButton(
            // --- MODIFIED: Icons are dark to be seen on the light gradient ---
            icon: const Icon(Icons.arrow_back, color: Color(0xFF101727)),
            onPressed: () => Navigator.of(context).pop(),
          ),
          title: const Text(
            'Offline Downloads',
            style: TextStyle(
              // --- MODIFIED: Title is dark ---
              color: Color(0xFF101727),
              fontSize: 20,
              fontFamily: 'Arimo',
              fontWeight: FontWeight.w400,
            ),
          ),
          centerTitle: true,
          actions: [
            IconButton(
              // --- MODIFIED: Icon is dark ---
              icon: const Icon(Icons.search, color: Color(0xFF101727), size: 28),
              onPressed: () async {
                final selectedItem =
                    await showSearch<_DownloadableItemData>(
                  context: context,
                  delegate: _DownloadSearchDelegate(searchItems: _items),
                );

                if (selectedItem != null && selectedItem.title.isNotEmpty) {
                  _scrollToItemAndHighlight(selectedItem);
                }
              },
            ),
            const SizedBox(width: 8),
          ],
        ),
        // --- MODIFIED: The body is now JUST the ListView.builder ---
        // The gradient Container is no longer here.
        body: ListView.builder(
          controller: _scrollController,
          padding: const EdgeInsets.all(20.0),
          itemCount: _items.length + 1,
          itemBuilder: (context, index) {
            // --- The Title Header (Index 0) ---
            if (index == 0) {
              return AutoScrollTag(
                key: ValueKey(index),
                controller: _scrollController,
                index: index,
                child: const Padding(
                  padding: EdgeInsets.only(bottom: 20.0),
                  child: Text(
                    'Downloadable Files',
                    style: TextStyle(
                      color: Color(0xFF101727), 
                      fontSize: 25.15,
                      fontFamily: 'Figtree',
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              );
            }

            // --- The List Items (Index 1+) ---
            final item = _items[index - 1]; 
            final bool isHighlighted = (item.title == _highlightedTitle);

            return AutoScrollTag(
              key: ValueKey(index), 
              controller: _scrollController,
              index: index, 
              child: Padding(
                padding: const EdgeInsets.only(bottom: 20.0),
                child: _DownloadableFileItem(
                  data: item,
                  isHighlighted: isHighlighted,
                ),
              ),
            );
          },
        ),
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
  final bool isHighlighted;

  const _DownloadableFileItem({
    required this.data,
    this.isHighlighted = false, 
  });

  @override
  State<_DownloadableFileItem> createState() => _DownloadableFileItemState();
}

class _DownloadableFileItemState extends State<_DownloadableFileItem>
    with AutomaticKeepAliveClientMixin { 
  
  var _downloadState = DownloadState.idle;

  @override
  bool get wantKeepAlive => true; 

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
    super.build(context); 

    final Color highlightColor = Color(0xFF007AFF); 
    final Color highlightBackgroundColor = Color.fromARGB(255, 235, 245, 255); 

    //Container punya decoration
    return Container(
      padding: const EdgeInsets.all(20.0),
      decoration: ShapeDecoration(
        color:
            widget.isHighlighted ? highlightBackgroundColor : const Color.fromARGB(210, 255, 255, 255).withOpacity(0.85),
        shape: RoundedRectangleBorder(
          side: widget.isHighlighted
              ? BorderSide(width: 2.0, color: highlightColor)
             // : const BorderSide(width: 1, color: Color(0x99FFFEFE)),
              : const BorderSide(width: 1, color: Color.fromARGB(255, 0, 0, 0)),
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