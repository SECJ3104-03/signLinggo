// lib/screens/Offline_Mode/offline_file_list_screen.dart

import 'dart:io';
import 'package:flutter/material.dart';
import 'package:open_file/open_file.dart';
import 'package:path/path.dart' as p; // Import path package

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
  List<FileSystemEntity> _files = [];

  @override
  void initState() {
    super.initState();
    _loadFiles();
  }

  /// Scans the folder path for all files and updates the list
  Future<void> _loadFiles() async {
    setState(() {
      _isLoading = true;
    });

    try {
      final directory = Directory(widget.folderPath);
      // Get all entities, including from sub-folders
      final allEntities = await directory.list(recursive: true).toList();
      
      // Filter out and keep only the files
      final filesOnly = allEntities.whereType<File>().toList();
      
      setState(() {
        _files = filesOnly;
        _isLoading = false;
      });

    } catch (e) {
      print("Error loading files: $e");
      setState(() {
        _isLoading = false;
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error loading files: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  /// --- NEW: Cleans up a filename for display ---
  /// Turns "Minum_2.mp4" into "Minum 2"
  String _beautifyFileName(String path) {
    // 1. Get just the filename, without the extension
    // e.g., "Minum_2"
    String name = p.basenameWithoutExtension(path);
    
    // 2. Replace underscores or hyphens with spaces
    // e.g., "Minum 2"
    name = name.replaceAll('_', ' ').replaceAll('-', ' ');
    
    // 3. Capitalize the first letter (optional, but looks nice)
    if (name.isEmpty) return '';
    return name[0].toUpperCase() + name.substring(1);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      // --- NEW: Added a gradient background ---
      backgroundColor: const Color(0xFFF2E7FE),
      body: Container(
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
        child: CustomScrollView(
          slivers: [
            // --- NEW: Added a flexible AppBar ---
            SliverAppBar(
              floating: true,
              pinned: false,
              backgroundColor: Colors.transparent,
              elevation: 0,
              centerTitle: true,
              leading: IconButton(
                icon: const Icon(Icons.arrow_back, color: Color(0xFF101727)),
                onPressed: () => Navigator.of(context).pop(),
              ),
              title: Text(
                widget.title, // Shows "Basic Greetings & Phrases"
                style: const TextStyle(
                  color: Color(0xFF101727),
                  fontSize: 20,
                  fontFamily: 'Arimo',
                  fontWeight: FontWeight.w400,
                ),
              ),
            ),
            // --- NEW: Add the main body content ---
            _buildBody(),
          ],
        ),
      ),
    );
  }

  // --- MODIFIED: This function now builds the GridView ---
  Widget _buildBody() {
    if (_isLoading) {
      return const SliverFillRemaining(
        child: Center(child: CircularProgressIndicator()),
      );
    }

    if (_files.isEmpty) {
      return const SliverFillRemaining(
        child: Center(
          child: Text(
            'No files found in this folder.',
            style: TextStyle(fontSize: 16, color: Colors.grey),
          ),
        ),
      );
    }

    // --- Use a SliverGrid instead of ListView ---
    return SliverPadding(
      padding: const EdgeInsets.all(16.0),
      sliver: SliverGrid(
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 2, // 2 columns, just like Learn Mode
          crossAxisSpacing: 16,
          mainAxisSpacing: 16,
          childAspectRatio: 0.75, // Adjust this ratio as needed
        ),
        delegate: SliverChildBuilderDelegate(
          (context, index) {
            final file = _files[index] as File;
            return _buildFileCard(file); // Build our new card
          },
          childCount: _files.length,
        ),
      ),
    );
  }

  // --- NEW: This widget builds the card UI ---
  Widget _buildFileCard(File file) {
    final String beautifulName = _beautifyFileName(file.path);

    return GestureDetector(
      onTap: () {
        print("Opening file: ${file.path}");
        OpenFile.open(file.path);
      },
      child: Container(
        decoration: ShapeDecoration(
          color: Colors.white.withOpacity(0.85),
          shape: RoundedRectangleBorder(
            side: const BorderSide(width: 1, color: Color(0x99FFFEFE)),
            borderRadius: BorderRadius.circular(14),
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // 1. The Video/Image placeholder
            Expanded(
              child: Container(
                clipBehavior: Clip.antiAlias,
                decoration: const BoxDecoration(
                  color: Color(0xFFEEEEEE), // Light grey background
                  borderRadius: BorderRadius.only(
                    topLeft: Radius.circular(14),
                    topRight: Radius.circular(14),
                  ),
                ),
                // Stack to place a play button on top
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    // --- Show a video icon ---
                    Icon(
                      Icons.videocam_rounded,
                      color: Colors.black.withOpacity(0.1),
                      size: 60,
                    ),
                    // --- Blue play button (like Learn Mode) ---
                    Container(
                      width: 40,
                      height: 40,
                      decoration: BoxDecoration(
                        color: Colors.blue,
                        shape: BoxShape.circle,
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.2),
                            blurRadius: 4,
                            offset: Offset(0, 2),
                          ),
                        ],
                      ),
                      child: const Icon(
                        Icons.play_arrow,
                        color: Colors.white,
                        size: 28,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            
            // 2. The Text content
            Padding(
              padding: const EdgeInsets.all(12.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    beautifulName, // e.g., "Minum 2"
                    style: const TextStyle(
                      color: Color(0xFF101727),
                      fontSize: 16,
                      fontFamily: 'Arimo',
                      fontWeight: FontWeight.w500,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 4),
                  Text(
                    widget.title, // e.g., "Basic Greetings & Phrases"
                    style: const TextStyle(
                      color: Color(0xFF495565),
                      fontSize: 12,
                      fontFamily: 'Arimo',
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}