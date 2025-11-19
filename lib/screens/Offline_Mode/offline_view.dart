import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart'; 
import 'package:scroll_to_index/scroll_to_index.dart';
import 'dart:io';
import 'package:dio/dio.dart'; 
import 'package:path_provider/path_provider.dart';
import 'package:open_file/open_file.dart'; 
import 'package:archive/archive.dart';

// --- STEP 1: CREATE A DATA MODEL (MODIFIED) ---
class _DownloadableItemData {
  final String downloadUrl; 
  final String title;
  final String description;
  final IconData icon;
  final Color iconColor;
  final Color backgroundColor;
  
  // --- NEW: A list of what's inside the pack ---
  final List<String> includedVideos;

  const _DownloadableItemData({
    required this.title,
    required this.description,
    required this.icon,
    required this.iconColor,
    required this.backgroundColor,
    required this.downloadUrl, 
    this.includedVideos = const [], // --- NEW: Add to constructor ---
  });
  
  String get folderName => title.replaceAll(' ', '_').replaceAll('&', 'and');
}

// --- STEP 2: SEARCHDELEGATE CLASS (Unchanged) ---
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
            close(
              context,
              _DownloadableItemData(
                title: '',
                description: '',
                icon: Icons.error,
                iconColor: Colors.transparent,
                backgroundColor: Colors.transparent,
                downloadUrl: '',
              ),
            );
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
        close(
          context,
          _DownloadableItemData(
            title: '',
            description: '',
            icon: Icons.error,
            iconColor: Colors.transparent,
            backgroundColor: Colors.transparent,
            downloadUrl: '',
          ),
        );
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

// --- OFFLINE MODE SCREEN ---
class OfflineMode extends StatefulWidget {
  OfflineMode({super.key});

  @override
  State<OfflineMode> createState() => _OfflineModeState();
}

class _OfflineModeState extends State<OfflineMode> with SingleTickerProviderStateMixin {
  late AutoScrollController _scrollController;
  String? _highlightedTitle;
  
  late TabController _tabController;
  List<_DownloadableItemData> _downloadedItems = [];

  // --- MODIFIED: Added the 'includedVideos' list to each item ---
  final List<_DownloadableItemData> _items = [
    _DownloadableItemData(
      title: 'Full BIM Dictionary',
      description: 'The complete collection of all BIM signs | 200 MB',
      icon: Icons.book_outlined,
      iconColor: const Color(0xFF007AFF),
      backgroundColor: const Color(0xFFEBF5FF),
      downloadUrl: 'https://raw.githubusercontent.com/Assadi-bit/BimTalk-SignLanguage-Recognition/fd3407305f1636c60389519bfad47bd515e6e495/test/sample6.png', 
      // --- NEW ---
      includedVideos: [
        'Over 200+ signs',
        'Full A-Z Alphabet',
        'Common Verbs (Eat, Drink, Go)',
        '...and many more!',
      ],
    ),
    _DownloadableItemData(
      title: 'Basic Greetings & Phrases',
      description: 'Essential signs for beginners & daily chat | 15 MB',
      icon: Icons.waving_hand_outlined,
      iconColor: const Color(0xFFE5890A),
      backgroundColor: const Color(0xFFFFF2DE),
      downloadUrl: 'https.drive.google.com/uc?export=download&id=1IVY1gC2ebZkIhNT0CYqkbiynAZSulVKQ', 
      // --- NEW: This is where you can add your video names ---
      includedVideos: [
        'Minum (video)',
        'Roti (video)',
        'Hello (video)',
        'Goodbye (video)',
        'Thank You (video)',
      ],
    ),
    _DownloadableItemData(
      title: 'Food & Drink Signs',
      description: 'Signs for eating, restaurant, and common foods | 20MB',
      icon: Icons.coffee_outlined,
      iconColor: const Color(0xFFD62F0B),
      backgroundColor: const Color(0xFFFFD6D1),
      downloadUrl: 'https.files.flutter-demo.org/sample.zip',
      // --- NEW ---
      includedVideos: [
        'Chicken (video)',
        'Rice (video)',
        'Water (video)',
        'Coffee (video)',
      ],
    ),
    _DownloadableItemData(
      title: 'Medical & Emergency',
      description: 'Critical signs for health, safety, and emergencies | 25MB',
      icon: Icons.medical_services_outlined,
      iconColor: const Color(0xFF34C759),
      backgroundColor: const Color(0xFFD5FFD4),
      downloadUrl: 'https.files.flutter-demo.org/sample.zip',
      includedVideos: ['Help (video)', 'Hurt (video)', 'Doctor (video)'],
    ),
    _DownloadableItemData(
      title: 'Family & People',
      description: 'Signs for family members, friends, and relationships | 18 MB',
      icon: Icons.groups_outlined,
      iconColor: const Color(0xFFD60B95),
      backgroundColor: const Color(0xFFFFDFF2),
      downloadUrl: 'https.files.flutter-demo.org/sample.zip',
      includedVideos: ['Father (video)', 'Mother (video)', 'Friend (video)'],
    ),
    _DownloadableItemData(
      title: 'Travel & Transport',
      description: 'Signs for travel, transport, and common actions | 22 MB',
      icon: Icons.travel_explore_outlined,
      iconColor: const Color(0xFF5E0BD6),
      backgroundColor: const Color(0xFFF5F1FF),
      downloadUrl: 'https.files.flutter-demo.org/sample.zip',
      includedVideos: ['Car (video)', 'Train (video)', 'Go (video)'],
    ),
  ];

  @override
  void initState() {
    super.initState();
    _scrollController = AutoScrollController();
    _tabController = TabController(length: 2, vsync: this);
    _refreshDownloadedList();
  }

  @override
  void dispose() {
    _scrollController.dispose();
    _tabController.dispose(); 
    super.dispose();
  }

  Future<void> _refreshDownloadedList() async {
    final Directory appDir = await getApplicationDocumentsDirectory();
    List<_DownloadableItemData> foundItems = [];
    
    for (final item in _items) {
      final String folderPath = '${appDir.path}/${item.folderName}';
      final directory = Directory(folderPath);
      
      if (await directory.exists()) {
        foundItems.add(item);
      }
    }
    
    setState(() {
      _downloadedItems = foundItems;
    });
  }

  Future<void> _scrollToItemAndHighlight(
    _DownloadableItemData selectedItem,
  ) async {
    final int dataIndex = _items.indexWhere(
      (item) => item.title == selectedItem.title,
    );

    if (dataIndex != -1) {
      final int listViewIndex = dataIndex + 1;
      _tabController.animateTo(0);
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
    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment(0.00, 0.00),
          end: Alignment(1.00, 1.00),
          colors: [Color(0xFFF2E7FE), Color(0xFFFCE6F3), Color(0xFFFFECD4)],
        ),
      ),
      child: Scaffold(
        backgroundColor: Colors.transparent,
        appBar: AppBar(
          backgroundColor: Colors.transparent,
          elevation: 0,
          shadowColor: Colors.transparent,
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
              onPressed: () async {
                final selectedItem = await showSearch<_DownloadableItemData>(
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
          
          bottom: TabBar(
            controller: _tabController,
            labelColor: Color(0xFF101727), 
            unselectedLabelColor: Colors.grey[700], 
            indicatorColor: Color(0xFF007AFF), 
            tabs: const [
              Tab(text: 'AVAILABLE'),
              Tab(text: 'DOWNLOADED'),
            ],
          ),
        ),
        
        body: TabBarView(
          controller: _tabController,
          children: [
            _buildAvailableTab(),
            _buildDownloadedTab(),
          ],
        ),
      ),
    );
  }

  Widget _buildAvailableTab() {
    return ListView.builder(
      controller: _scrollController,
      padding: const EdgeInsets.all(20.0),
      itemCount: _items.length + 1,
      itemBuilder: (context, index) {
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

        final item = _items[index - 1]; 
        final bool isHighlighted = (item.title == _highlightedTitle);

        return AutoScrollTag(
          key: ValueKey(index), 
          controller: _scrollController,
          index: index, 
          child: Padding(
            padding: const EdgeInsets.only(bottom: 20.0),
            child: _DownloadableFileItem(
              key: ValueKey(item.title), 
              data: item,
              isHighlighted: isHighlighted,
              onDownloadComplete: _refreshDownloadedList,
            ),
          ),
        );
      },
    );
  }
  
  Widget _buildDownloadedTab() {
    if (_downloadedItems.isEmpty) {
      return Center(
        child: Text(
          'No downloaded files yet.',
          style: TextStyle(color: Colors.grey[700], fontSize: 16),
        ),
      );
    }
    
    return ListView.builder(
      padding: const EdgeInsets.all(20.0),
      itemCount: _downloadedItems.length,
      itemBuilder: (context, index) {
        final item = _downloadedItems[index];
        
        return Padding(
          padding: const EdgeInsets.only(bottom: 20.0),
          child: InkWell(
            onTap: () async {
              try {
                final Directory appDir = await getApplicationDocumentsDirectory();
                final String folderPath = '${appDir.path}/${item.folderName}';
                
                // --- We pass the folder path AND title to the new screen ---
                final Map<String, String> params = {
                  'path': folderPath,
                  'title': item.title,
                };
                
                print("Navigating to /offline-files with params: $params");
                context.pushNamed('offline-files', extra: params);

              } catch (e) {
                print("Error navigating to file list: $e");
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('Could not open file list: $e'),
                      backgroundColor: Colors.red,
                    ),
                  );
                }
              }
            },
            child: Container(
              padding: const EdgeInsets.all(20.0),
              decoration: ShapeDecoration(
                color: Colors.white.withOpacity(0.85),
                shape: RoundedRectangleBorder(
                  side: const BorderSide(width: 1, color: Color(0x99FFFEFE)),
                  borderRadius: BorderRadius.circular(30.18),
                ),
              ),
              child: Row(
                children: [
                  Container(
                    width: 50.29,
                    height: 50.29,
                    decoration: ShapeDecoration(
                      color: item.backgroundColor,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(17.60),
                      ),
                    ),
                    child: Center(
                      child: Icon(
                        item.icon,
                        color: item.iconColor,
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
                          item.title,
                          style: const TextStyle(
                            color: Colors.black,
                            fontSize: 20.12,
                            fontFamily: 'Figtree',
                            fontWeight: FontWeight.w600,
                          ),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                        Text(
                          'Ready for offline use',
                          style: const TextStyle(
                            color: Color(0xFF34C759),
                            fontSize: 16,
                            fontFamily: 'Figtree',
                            fontWeight: FontWeight.w400,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const Icon(Icons.arrow_forward_ios, color: Colors.grey),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}

// --- Define the different states for our download button ---
enum DownloadState { idle, downloading, downloaded }

// --- This is our stateful item card ---
class _DownloadableFileItem extends StatefulWidget {
  final _DownloadableItemData data;
  final bool isHighlighted;
  final VoidCallback onDownloadComplete;

  const _DownloadableFileItem({
    super.key, 
    required this.data,
    this.isHighlighted = false,
    required this.onDownloadComplete,
  });

  @override
  State<_DownloadableFileItem> createState() => _DownloadableFileItemState();
}

class _DownloadableFileItemState extends State<_DownloadableFileItem>
    with AutomaticKeepAliveClientMixin {
  
  var _downloadState = DownloadState.idle;
  String? _localFolderPath;
  final Dio _dio = Dio();
  double _downloadProgress = 0.0;

  @override
  bool get wantKeepAlive => true;

  @override
  void initState() {
    super.initState();
    _checkIfFolderExists();
  }

  String _getTargetFolderName() {
    return widget.data.folderName;
  }

  Future<void> _checkIfFolderExists() async {
    try {
      final Directory appDir = await getApplicationDocumentsDirectory();
      final String folderName = _getTargetFolderName();
      final String folderPath = '${appDir.path}/$folderName';

      final directory = Directory(folderPath);
      if (await directory.exists()) {
        if (mounted) {
          setState(() {
            _downloadState = DownloadState.downloaded;
            _localFolderPath = folderPath;
          });
        }
      }
    } catch (e) {
      print("Error in _checkIfFolderExists: $e");
    }
  }

  Future<void> _startDownload() async {
    setState(() {
      _downloadState = DownloadState.downloading;
      _downloadProgress = 0.0;
    });

    try {
      final Directory appDir = await getApplicationDocumentsDirectory();
      final String url = widget.data.downloadUrl;
      final String zipFileName = Uri.parse(url).pathSegments.last;
      final String zipSavePath = '${appDir.path}/$zipFileName';
      
      await _dio.download(
        url,
        zipSavePath, 
        onReceiveProgress: (received, total) {
          if (total != -1) {
            setState(() {
              _downloadProgress = received / total;
            });
          }
        },
      );

      final bytes = await File(zipSavePath).readAsBytes();
      
      try {
        final archive = ZipDecoder().decodeBytes(bytes);

        final String folderName = _getTargetFolderName();
        final String folderPath = '${appDir.path}/$folderName';
        await Directory(folderPath).create(recursive: true);

        for (final file in archive) {
          final String filename = '${appDir.path}/$folderName/${file.name}';
          if (file.isFile) {
            final data = file.content as List<int>;
            await File(filename).writeAsBytes(data);
          } else { 
            await Directory(filename).create(recursive: true);
          }
        }
        await File(zipSavePath).delete();

      } catch (e) {
        print("Failed to unzip file. Is it a valid .zip file? Error: $e");
        final String folderName = _getTargetFolderName();
        final String folderPath = '${appDir.path}/$folderName';
        await Directory(folderPath).create(recursive: true);
        await File(zipSavePath).rename('$folderPath/$zipFileName');
      }

      if (mounted) {
        setState(() {
          _downloadState = DownloadState.downloaded;
          _localFolderPath = '${appDir.path}/${_getTargetFolderName()}'; 
        });
        
        widget.onDownloadComplete();
      }

    } catch (e) {
      print("Error downloading file: $e");
      if (mounted) {
        setState(() {
          _downloadState = DownloadState.idle;
          _downloadProgress = 0.0;
        });
      }
    }
  } 
  
  // --- NEW: This function shows the "What's Inside" dialog ---
  Future<void> _showContentsDialog() async {
    // Show a pop-up dialog
    await showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Text("What's Inside?"),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              // Build a list of items from our data
              children: widget.data.includedVideos.map((videoName) {
                return Padding(
                  padding: const EdgeInsets.symmetric(vertical: 4.0),
                  child: Row(
                    children: [
                      Icon(Icons.check_circle_outline, color: Colors.green, size: 20),
                      SizedBox(width: 8),
                      Expanded(child: Text(videoName)),
                    ],
                  ),
                );
              }).toList(),
            ),
          ),
          actions: [
            TextButton(
              child: Text("Close"),
              onPressed: () {
                Navigator.of(context).pop();
              },
            ),
          ],
        );
      },
    );
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
          width: 48,
          height: 48,
          padding: const EdgeInsets.all(9.0),
          child: Stack(
            alignment: Alignment.center,
            children: [
              CircularProgressIndicator(
                strokeWidth: 2.5,
                color: Color(0xFF007AFF),
                value: _downloadProgress > 0 ? _downloadProgress : null,
              ),
              Text(
                '${(_downloadProgress * 100).toInt()}%',
                style: TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.w600,
                  color: Color(0xFF007AFF),
                ),
              )
            ],
          ),
        );
        
      case DownloadState.downloaded:
        return IconButton(
          icon: const Icon(
            Icons.check_circle,
            color: Color(0xFF34C759),
            size: 30,
          ),
          // --- MODIFIED: Tapping the green check now also shows the dialog ---
          onPressed: _showContentsDialog,
        );
    }
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);

    final Color highlightColor = Color(0xFF007AFF);
    final Color highlightBackgroundColor = Color.fromARGB(255, 235, 245, 255);

    return Container(
      padding: const EdgeInsets.all(20.0),
      decoration: ShapeDecoration(
        color: widget.isHighlighted
            ? highlightBackgroundColor
            : Colors.white.withOpacity(0.85),
        shape: RoundedRectangleBorder(
          side: widget.isHighlighted
              ? BorderSide(width: 2.0, color: highlightColor)
              : const BorderSide(width: 1, color: Color(0x99FFFEFE)),
          borderRadius: BorderRadius.circular(30.18),
        ),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          // --- MODIFIED: Wrap the text/icon area in a GestureDetector ---
          Expanded(
            child: GestureDetector(
              onTap: _showContentsDialog, // <-- NEW: Tap to show info
              child: Container( // Wrap in a container to make the tap area work
                color: Colors.transparent, // Makes the tap area fill the space
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
            ),
          ),
          // --- END MODIFICATION ---
          
          const SizedBox(width: 12.0),
          _buildDownloadIcon(), // This is the download button
        ],
      ),
    );
  }
}