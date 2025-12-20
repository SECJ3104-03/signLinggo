// lib/screens/Offline_Mode/offline_file_list_screen.dart

import 'dart:io';
import 'package:flutter/material.dart';
import 'package:path/path.dart' as p;
import 'package:share_plus/share_plus.dart';
import '../Community_Module/full_screen_video_screen.dart';

class OfflineFileListScreen extends StatefulWidget {
  final String folderPath;
  final String title;

  const OfflineFileListScreen({
    super.key,
    required this.folderPath,
    required this.title,
  });

  @override
  State<OfflineFileListScreen> createState() => _OfflineFileListScreenState();
}

class _OfflineFileListScreenState extends State<OfflineFileListScreen> {
  bool _isLoading = true;
  List<FileSystemEntity> _items = []; // Can be File or Directory

  @override
  void initState() {
    super.initState();
    _loadContent();
  }

  Future<void> _loadContent() async {
    setState(() => _isLoading = true);

    try {
      final directory = Directory(widget.folderPath);
      if (await directory.exists()) {
        // --- CHANGE 1: recursive is now FALSE ---
        // We only want to see what is immediately inside this folder
        final allEntities = await directory.list(recursive: false).toList();
        
        // Filter out hidden files (starting with .)
        final visibleItems = allEntities.where((entity) {
          final name = p.basename(entity.path);
          return !name.startsWith('.');
        }).toList();

        // --- CHANGE 2: Sort Folders first, then Files ---
        visibleItems.sort((a, b) {
          if (a is Directory && b is File) return -1;
          if (a is File && b is Directory) return 1;
          return p.basename(a.path).compareTo(p.basename(b.path));
        });

        setState(() {
          _items = visibleItems;
          _isLoading = false;
        });
      } else {
        setState(() {
          _items = [];
          _isLoading = false;
        });
      }
    } catch (e) {
      print("Error loading content: $e");
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _shareFile(File file) async {
    try {
      final String fileName = _beautifyName(file.path);
      await Share.shareXFiles(
        [XFile(file.path)],
        text: 'Learn "$fileName" in Sign Language with SignLinggo!',
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Error sharing: $e")),
      );
    }
  }

  Future<void> _deleteItem(FileSystemEntity item) async {
    bool isFolder = item is Directory;
    
    bool? confirm = await showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(isFolder ? "Delete Folder" : "Delete Video"),
        content: Text(
          isFolder 
            ? "Are you sure you want to delete this folder and all its contents?" 
            : "Remove this video from offline storage?",
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text("Cancel"),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text("Delete", style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );

    if (confirm == true) {
      try {
        await item.delete(recursive: true); // Recursive delete for folders
        _loadContent(); 
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(isFolder ? "Folder deleted" : "Video deleted")),
          );
        }
      } catch (e) {
        print("Error deleting: $e");
      }
    }
  }

  String _beautifyName(String path) {
    String name = p.basenameWithoutExtension(path);
    name = name.replaceAll('_', ' ').replaceAll('-', ' ');
    name = name.replaceAll(RegExp(r'^\d+\s*'), ''); 
    if (name.isEmpty) return '';
    return name[0].toUpperCase() + name.substring(1);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF2E7FE),
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment(0.00, 0.00),
            end: Alignment(1.00, 1.00),
            colors: [Color(0xFFF2E7FE), Color(0xFFFCE6F3), Color(0xFFFFECD4)],
          ),
        ),
        child: CustomScrollView(
          slivers: [
            SliverAppBar(
              floating: true,
              backgroundColor: Colors.transparent,
              elevation: 0,
              centerTitle: true,
              iconTheme: const IconThemeData(color: Color(0xFF101727)),
              title: Text(
                widget.title,
                style: const TextStyle(
                  color: Color(0xFF101727),
                  fontSize: 20,
                  fontFamily: 'Arimo',
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
            _buildBody(),
          ],
        ),
      ),
    );
  }

  Widget _buildBody() {
    if (_isLoading) {
      return const SliverFillRemaining(child: Center(child: CircularProgressIndicator()));
    }

    if (_items.isEmpty) {
      return SliverFillRemaining(
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.folder_open_rounded, size: 60, color: Colors.grey.withOpacity(0.5)),
              const SizedBox(height: 16),
              const Text(
                'Folder is empty.',
                style: TextStyle(fontSize: 16, color: Colors.grey),
              ),
            ],
          ),
        ),
      );
    }

    return SliverPadding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 40),
      sliver: SliverGrid(
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 2,
          crossAxisSpacing: 16,
          mainAxisSpacing: 16,
          childAspectRatio: 0.8, 
        ),
        delegate: SliverChildBuilderDelegate(
          (context, index) {
            final item = _items[index];
            
            if (item is Directory) {
              return _buildFolderCard(item);
            } else if (item is File) {
              return _buildFileCard(item);
            }
            return const SizedBox.shrink();
          },
          childCount: _items.length,
        ),
      ),
    );
  }

  // --- NEW: FOLDER CARD ---
  Widget _buildFolderCard(Directory dir) {
    final String folderName = p.basename(dir.path); // Keep name simple

    return GestureDetector(
      onTap: () {
        // --- NAVIGATE DEEPER ---
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => OfflineFileListScreen(
              folderPath: dir.path,
              title: folderName, // Update title to folder name
            ),
          ),
        );
      },
      onLongPress: () => _deleteItem(dir),
      child: Container(
        decoration: ShapeDecoration(
          color: const Color(0xFFFFF8E1), // Light Yellow for folders
          shape: RoundedRectangleBorder(
            side: const BorderSide(width: 1, color: Color(0xFFFFECB3)),
            borderRadius: BorderRadius.circular(16),
          ),
          shadows: [
            BoxShadow(
              color: Colors.orange.withOpacity(0.1),
              blurRadius: 10, offset: const Offset(0, 4),
            )
          ],
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.folder, size: 50, color: Color(0xFFFFC107)),
            const SizedBox(height: 12),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12.0),
              child: Text(
                folderName,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  color: Color(0xFF101727),
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                ),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
      ),
    );
  }

  // --- VIDEO CARD (Same as before) ---
  Widget _buildFileCard(File file) {
    final String beautifulName = _beautifyName(file.path);

    return GestureDetector(
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => FullScreenVideoScreen(videoUrl: file.path),
          ),
        );
      },
      onLongPress: () => _deleteItem(file),
      child: Container(
        decoration: ShapeDecoration(
          color: Colors.white.withOpacity(0.9),
          shape: RoundedRectangleBorder(
            side: const BorderSide(width: 1, color: Colors.white),
            borderRadius: BorderRadius.circular(16),
          ),
          shadows: [
            BoxShadow(
              color: Colors.purple.withOpacity(0.05),
              blurRadius: 10, offset: const Offset(0, 4),
            )
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Expanded(
              child: Container(
                decoration: const BoxDecoration(
                  color: Color(0xFFF0F0F0),
                  borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
                ),
                child: Stack(
                  children: [
                    const Center(child: Icon(Icons.play_circle_outline_rounded, size: 48, color: Colors.black12)),
                    
                    Positioned(
                      top: 4, right: 4,
                      child: PopupMenuButton<String>(
                        icon: const Icon(Icons.more_vert, color: Colors.black54),
                        onSelected: (value) {
                          if (value == 'share') _shareFile(file);
                          else if (value == 'delete') _deleteItem(file);
                        },
                        itemBuilder: (context) => [
                          const PopupMenuItem(value: 'share', child: Row(children: [Icon(Icons.share_outlined, size: 20), SizedBox(width: 12), Text("Share")])),
                          const PopupMenuItem(value: 'delete', child: Row(children: [Icon(Icons.delete_outline, size: 20, color: Colors.red), SizedBox(width: 12), Text("Delete", style: TextStyle(color: Colors.red))])),
                        ],
                      ),
                    ),
                    
                    Positioned(
                      bottom: 8, right: 8,
                      child: Container(
                        padding: const EdgeInsets.all(6),
                        decoration: const BoxDecoration(color: Colors.white, shape: BoxShape.circle),
                        child: const Icon(Icons.play_arrow, size: 16, color: Colors.black),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            
            Padding(
              padding: const EdgeInsets.all(12.0),
              child: Text(
                beautifulName,
                style: const TextStyle(color: Color(0xFF101727), fontSize: 15, fontWeight: FontWeight.w600),
                maxLines: 1, overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
      ),
    );
  }
}