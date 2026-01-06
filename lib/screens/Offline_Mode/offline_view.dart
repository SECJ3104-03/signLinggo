import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart'; 
import 'package:scroll_to_index/scroll_to_index.dart';
import 'dart:io';
import 'dart:async'; 
import 'dart:typed_data'; 
import 'package:dio/dio.dart'; 
import 'package:path_provider/path_provider.dart';
import 'package:archive/archive.dart';

// --- STEP 1: DATA MODEL ---
class _DownloadableItemData {
  final String downloadUrl; 
  final String title;
  final String description;
  final IconData icon;
  final Color iconColor;
  final Color backgroundColor;
  final List<String> includedVideos; 

  const _DownloadableItemData({
    required this.title,
    required this.description,
    required this.icon,
    required this.iconColor,
    required this.backgroundColor,
    required this.downloadUrl, 
    this.includedVideos = const [], 
  });
  
  String get folderName => title.replaceAll(' ', '_').replaceAll('&', 'and');
}

// --- STEP 2: SEARCH DELEGATE ---
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
            close(context, _emptyItem());
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
      onPressed: () => close(context, _emptyItem()),
    );
  }

  _DownloadableItemData _emptyItem() {
    return const _DownloadableItemData(
      title: '', description: '', icon: Icons.error, 
      iconColor: Colors.transparent, backgroundColor: Colors.transparent, 
      downloadUrl: ''
    );
  }

  @override
  Widget buildResults(BuildContext context) => _buildSuggestions(context);

  @override
  Widget buildSuggestions(BuildContext context) => _buildSuggestions(context);

  Widget _buildSuggestions(BuildContext context) {
    final List<_DownloadableItemData> suggestions = searchItems.where((item) {
      final titleLower = item.title.toLowerCase();
      final descriptionLower = item.description.toLowerCase();
      final queryLower = query.toLowerCase();
      return titleLower.contains(queryLower) || descriptionLower.contains(queryLower);
    }).toList();

    return ListView.builder(
      itemCount: suggestions.length,
      itemBuilder: (context, index) {
        final item = suggestions[index];
        return ListTile(
          leading: Icon(item.icon, color: item.iconColor),
          title: Text(item.title),
          subtitle: Text(item.description, maxLines: 1, overflow: TextOverflow.ellipsis),
          onTap: () => close(context, item),
        );
      },
    );
  }
}

// --- STEP 3: MAIN SCREEN ---
class OfflineMode extends StatefulWidget {
  const OfflineMode({super.key});

  @override
  State<OfflineMode> createState() => _OfflineModeState();
}

class _OfflineModeState extends State<OfflineMode> with SingleTickerProviderStateMixin {
  late AutoScrollController _scrollController;
  String? _highlightedTitle;
  late TabController _tabController;
  List<_DownloadableItemData> _downloadedItems = [];

  // --- THE DATA LIST ---
  final List<_DownloadableItemData> _items = [
    // 1. Full BIM Dictionary
    const _DownloadableItemData(
      title: 'Full BIM Dictionary',
      description: 'The complete collection of all BIM signs',
      icon: Icons.book_outlined,
      iconColor: Color(0xFF007AFF),
      backgroundColor: Color(0xFFEBF5FF),
      downloadUrl: 'assets/assets/offline_materials/Full_BIM_Dictionary.zip', 
      includedVideos: ['Over 50+ signs', 'Alphabet Signs', 'Numeric Signs', 'Basic Greetings', 'Food & Drink Signs', 'Family & People Signs', 'Travel & Transport Signs' ],
    ),

     //2. Numeric
      const _DownloadableItemData(
      title: 'Numeric Signs',
      description: 'Signs for numbers ',
      icon: Icons.pin,
      iconColor: Color(0xFF34C759),
      backgroundColor: Color(0xFFD5FFD4),
      downloadUrl: 'assets/assets/offline_materials/Numeric.zip',
      includedVideos: ['0', '1', '2', '3', '4', '5', '6', '7', '8', '9'],
    ),

    // 3. Alphabet Signs
      const _DownloadableItemData(
      title: 'Alphabet Signs',
      description: 'Signs for A-Z Alphabet',
      icon: Icons.text_fields,
      iconColor: Color.fromARGB(255, 191, 138, 5),
      backgroundColor: Color.fromARGB(255, 248, 247, 188),
      downloadUrl: 'assets/assets/offline_materials/alphabet.zip',
      includedVideos: ['A', 'B', 'C', 'D', 'E', 'F', 'G', 'H', 'I', 'J', 'K', 'L', 'M', 'N', 'O', 'P', 'Q', 'R', 'S', 'T', 'U', 'V', 'W', 'X', 'Y', 'Z'],
    ),
    
    
    // 4. Basic Greetings
    const _DownloadableItemData(
      title: 'Basic Greetings & Phrases',
      description: 'Essential signs for beginners & daily chat',
      icon: Icons.waving_hand_outlined,
      iconColor: Color(0xFFE5890A),
      backgroundColor: Color(0xFFFFF2DE),
      downloadUrl: 'assets/assets/offline_materials/basic_greetings.zip', 
      includedVideos: ['Hello', 'I Love You', 'Morning', 'Night', 'No', 'Noon', 'Greet', 'Sorry',  'Thank You', 'Today', 'Yes' ],
    ),

    // 5. Food & Drink (OFFLINE ASSET MODE)
    const _DownloadableItemData(
      title: 'Food & Drink Signs',
      description: 'Signs for eating, restaurant, and common foods',
      icon: Icons.coffee_outlined,
      iconColor: Color(0xFFD62F0B),
      backgroundColor: Color(0xFFFFD6D1),
      downloadUrl: 'assets/assets/offline_materials/Foof_Drink_Signs.zip',
      includedVideos: ['Bread', 'Drink', 'Eat', 'Hungry', 'Juice', 'Thirsty', 'Water'],
    ),

    // 4. Medical
    /* const _DownloadableItemData(
      title: 'Medical & Emergency',
      description: 'Critical signs for health, safety, and emergencies | 25MB',
      icon: Icons.medical_services_outlined,
      iconColor: Color(0xFF34C759),
      backgroundColor: Color(0xFFD5FFD4),
      downloadUrl: 'assets/assets/offline_materials/Medical_Emergency.zip',
      includedVideos: ['Help', 'Hurt', 'Doctor'],
    ),
 */
    

    // 6. Family
    const _DownloadableItemData(
      title: 'Family & People',
      description: 'Signs for family members, friends, and relationships ',
      icon: Icons.groups_outlined,
      iconColor: Color(0xFFD60B95),
      backgroundColor: Color(0xFFFFDFF2),
      downloadUrl: 'assets/assets/offline_materials/Family_People.zip', 
      includedVideos: ['Father', 'Mother', 'Friend', 'Brother', 'Sister', 'I/Me'],
    ),

    // 7. Travel
    const _DownloadableItemData(
      title: 'Travel & Transport',
      description: 'Signs for travel, transport, and common actions',
      icon: Icons.travel_explore_outlined,
      iconColor: Color(0xFF5E0BD6),
      backgroundColor: Color(0xFFF5F1FF),
      downloadUrl: 'assets/assets/offline_materials/Travel_Transport.zip', 
      includedVideos: ['Bus', 'Help', 'Hotel', 'How much?', 'Toilet'],
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
      
      if (await directory.exists() && directory.listSync().isNotEmpty) {
        foundItems.add(item);
      }
    }
    
    setState(() {
      _downloadedItems = foundItems;
    });
  }

  Future<void> _scrollToItemAndHighlight(_DownloadableItemData selectedItem) async {
    final int dataIndex = _items.indexWhere((item) => item.title == selectedItem.title);
    if (dataIndex != -1) {
      final int listViewIndex = dataIndex + 1;
      _tabController.animateTo(0); 
      setState(() => _highlightedTitle = selectedItem.title);

      await _scrollController.scrollToIndex(
        listViewIndex,
        preferPosition: AutoScrollPosition.middle,
        duration: const Duration(milliseconds: 500),
      );

      Future.delayed(const Duration(seconds: 2), () {
        if (mounted) setState(() => _highlightedTitle = null);
      });
    }
  }

  // --- NEW: Function to handle Deletion ---
  Future<void> _confirmAndDelete(_DownloadableItemData item) async {
    final bool? confirm = await showDialog<bool>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text("Delete Download"),
          content: Text("Are you sure you want to delete '${item.title}' from your offline library?"),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: const Text("Cancel", style: TextStyle(color: Colors.grey)),
            ),
            TextButton(
              onPressed: () => Navigator.of(context).pop(true),
              child: const Text("Delete", style: TextStyle(color: Colors.red)),
            ),
          ],
        );
      },
    );

    if (confirm == true) {
      try {
        final Directory appDir = await getApplicationDocumentsDirectory();
        final String folderPath = '${appDir.path}/${item.folderName}';
        final directory = Directory(folderPath);

        if (await directory.exists()) {
          await directory.delete(recursive: true);
          
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text("${item.title} deleted"), duration: const Duration(seconds: 2)),
            );
          }
          // Refresh list to remove the item from screen
          await _refreshDownloadedList();
        }
      } catch (e) {
        print("Error deleting: $e");
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text("Error deleting file: $e"), backgroundColor: Colors.red),
          );
        }
      }
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
          leading: IconButton(
            icon: const Icon(Icons.arrow_back, color: Color(0xFF101727)),
            // onPressed: () => Navigator.of(context).pop(),
            onPressed: () => context.go('/home'),
          ),
          title: const Text(
            'Offline Downloads',
            style: TextStyle(color: Color(0xFF101727), fontSize: 20, fontFamily: 'Arimo'),
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
            labelColor: const Color(0xFF101727), 
            unselectedLabelColor: Colors.grey[700], 
            indicatorColor: const Color(0xFF007AFF), 
            tabs: const [Tab(text: 'AVAILABLE'), Tab(text: 'DOWNLOADED')],
          ),
        ),
        body: TabBarView(
          controller: _tabController,
          children: [_buildAvailableTab(), _buildDownloadedTab()],
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
                  color: Color(0xFF101727), fontSize: 25, fontFamily: 'Figtree', fontWeight: FontWeight.w700,
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
        child: Text('No downloaded files yet.', style: TextStyle(color: Colors.grey[700], fontSize: 16)),
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
            borderRadius: BorderRadius.circular(30.18),
            // --- MODIFIED: Added Long Press Logic ---
            onLongPress: () => _confirmAndDelete(item),
            onTap: () async {
              try {
                final Directory appDir = await getApplicationDocumentsDirectory();
                final String folderPath = '${appDir.path}/${item.folderName}';
                
                context.pushNamed('offline-files', extra: {
                  'path': folderPath,
                  'title': item.title,
                });
              } catch (e) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red),
                );
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
                    width: 50.29, height: 50.29,
                    decoration: ShapeDecoration(
                      color: item.backgroundColor,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(17.60)),
                    ),
                    child: Center(child: Icon(item.icon, color: item.iconColor, size: 28)),
                  ),
                  const SizedBox(width: 15.09),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          item.title,
                          style: const TextStyle(
                            color: Colors.black, fontSize: 20, fontFamily: 'Figtree', fontWeight: FontWeight.w600,
                          ),
                          maxLines: 2, overflow: TextOverflow.ellipsis,
                        ),
                        const Text(
                          'Ready for offline use',
                          style: TextStyle(
                            color: Color(0xFF34C759), fontSize: 16, fontFamily: 'Figtree', fontWeight: FontWeight.w400,
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

// --- STEP 4: DOWNLOAD ITEM LOGIC ---
enum DownloadState { idle, downloading, downloaded }

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

class _DownloadableFileItemState extends State<_DownloadableFileItem> with AutomaticKeepAliveClientMixin {
  var _downloadState = DownloadState.idle;
  final Dio _dio = Dio();
  double _downloadProgress = 0.0;

  @override
  bool get wantKeepAlive => true;

  @override
  void initState() {
    super.initState();
    _checkIfFolderExists();
  }

  // --- NEW: Re-check status if the list updates (e.g. after a delete) ---
  @override
  void didUpdateWidget(_DownloadableFileItem oldWidget) {
    super.didUpdateWidget(oldWidget);
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
      bool exists = await directory.exists() && directory.listSync().isNotEmpty;
      
      if (mounted) {
        setState(() {
          _downloadState = exists ? DownloadState.downloaded : DownloadState.idle;
        });
      }
    } catch (e) {
      print("Error checking folder: $e");
    }
  }

  Future<void> _startDownload() async {
    setState(() {
      _downloadState = DownloadState.downloading;
      _downloadProgress = 0.0;
    });

    try {
      final Directory appDir = await getApplicationDocumentsDirectory();
      final String pathOrUrl = widget.data.downloadUrl;
      final String zipFileName = pathOrUrl.split('/').last; 
      final String zipSavePath = '${appDir.path}/$zipFileName';

      // CHECK: Is it HTTP (Web) or Asset (Local)?
      if (pathOrUrl.startsWith('http') || pathOrUrl.startsWith('https')) {
        // --- SCENARIO A: WEB DOWNLOAD (Real speed) ---
        await _dio.download(
          pathOrUrl,
          zipSavePath, 
          onReceiveProgress: (received, total) {
            if (total != -1) {
              setState(() {
                _downloadProgress = received / total;
              });
            }
          },
        );
      } else {
        // --- SCENARIO B: LOCAL ASSET COPY (Simulated Delay) ---
        for (int i = 0; i <= 100; i+=2) {
          if (!mounted) return; 
          
          setState(() {
            _downloadProgress = i / 100;
          });
          
          await Future.delayed(const Duration(milliseconds: 20));
        }

        final ByteData data = await DefaultAssetBundle.of(context).load(pathOrUrl);
        final List<int> bytes = data.buffer.asUint8List();
        await File(zipSavePath).writeAsBytes(bytes);
      }

      // --- COMMON STEP: UNZIP THE FILE ---
      final bytes = await File(zipSavePath).readAsBytes();
      final archive = ZipDecoder().decodeBytes(bytes);

      final String folderName = _getTargetFolderName();
      final String folderPath = '${appDir.path}/$folderName';
      await Directory(folderPath).create(recursive: true);

      for (final file in archive) {
        final String filename = '$folderPath/${file.name}';
        if (file.isFile) {
          final data = file.content as List<int>;
          await File(filename).create(recursive: true);
          await File(filename).writeAsBytes(data);
        } else { 
          await Directory(filename).create(recursive: true);
        }
      }

      await File(zipSavePath).delete();

      if (mounted) {
        setState(() {
          _downloadState = DownloadState.downloaded;
        });
        widget.onDownloadComplete();
      }

    } catch (e) {
      print("Error downloading/extracting: $e");
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error: Could not load file. $e'),
            backgroundColor: Colors.red,
          ),
        );
        setState(() {
          _downloadState = DownloadState.idle;
          _downloadProgress = 0.0;
        });
      }
    }
  } 
  
  Future<void> _showContentsDialog() async {
    await showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Text(widget.data.title),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text("Included in this pack:", style: TextStyle(fontWeight: FontWeight.bold)),
                const SizedBox(height: 10),
                ...widget.data.includedVideos.map((videoName) {
                  return Padding(
                    padding: const EdgeInsets.symmetric(vertical: 4.0),
                    child: Row(
                      children: [
                        const Icon(Icons.check_circle_outline, color: Colors.green, size: 20),
                        const SizedBox(width: 8),
                        Expanded(child: Text(videoName)),
                      ],
                    ),
                  );
                }),
              ],
            ),
          ),
          actions: [
            TextButton(child: const Text("Close"), onPressed: () => Navigator.of(context).pop()),
          ],
        );
      },
    );
  }

  Widget _buildDownloadIcon() {
    switch (_downloadState) {
      case DownloadState.idle:
        return IconButton(
          icon: const Icon(Icons.download_outlined, color: Color(0xFF007AFF), size: 30),
          onPressed: _startDownload,
        );
      case DownloadState.downloading:
        return Container(
          width: 48, height: 48, padding: const EdgeInsets.all(9.0),
          child: Stack(
            alignment: Alignment.center,
            children: [
              CircularProgressIndicator(strokeWidth: 2.5, color: const Color(0xFF007AFF), value: _downloadProgress > 0 ? _downloadProgress : null),
              Text('${(_downloadProgress * 100).toInt()}%', style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w600, color: Color(0xFF007AFF)))
            ],
          ),
        );
      case DownloadState.downloaded:
        return IconButton(
          icon: const Icon(Icons.check_circle, color: Color(0xFF34C759), size: 30),
          onPressed: _showContentsDialog,
        );
    }
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    final Color highlightColor = const Color(0xFF007AFF);
    final Color highlightBackgroundColor = const Color.fromARGB(255, 235, 245, 255);

    return Container(
      padding: const EdgeInsets.all(20.0),
      decoration: ShapeDecoration(
        color: widget.isHighlighted ? highlightBackgroundColor : Colors.white.withOpacity(0.85),
        shape: RoundedRectangleBorder(
          side: widget.isHighlighted ? BorderSide(width: 2.0, color: highlightColor) : const BorderSide(width: 1, color: Color(0x99FFFEFE)),
          borderRadius: BorderRadius.circular(30.18),
        ),
      ),
      child: Row(
        children: [
          Expanded(
            child: GestureDetector(
              onTap: _showContentsDialog,
              child: Container(
                color: Colors.transparent,
                child: Row(
                  children: [
                    Container(
                      width: 50.29, height: 50.29,
                      decoration: ShapeDecoration(
                        color: widget.data.backgroundColor,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(17.60)),
                      ),
                      child: Center(child: Icon(widget.data.icon, color: widget.data.iconColor, size: 28)),
                    ),
                    const SizedBox(width: 15.09),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            widget.data.title,
                            style: const TextStyle(color: Colors.black, fontSize: 20, fontFamily: 'Figtree', fontWeight: FontWeight.w600),
                            maxLines: 2, overflow: TextOverflow.ellipsis,
                          ),
                          const SizedBox(height: 5),
                          Text(
                            widget.data.description,
                            style: const TextStyle(color: Color(0xFFA5A5A5), fontSize: 17, fontFamily: 'Figtree', fontWeight: FontWeight.w400),
                            maxLines: 2, overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          const SizedBox(width: 12.0),
          _buildDownloadIcon(),
        ],
      ),
    );
  }
}