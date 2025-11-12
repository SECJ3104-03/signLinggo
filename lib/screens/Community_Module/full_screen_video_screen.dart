// lib/screens/Community_Module/full_screen_video_screen.dart

import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart'; 
import 'package:video_player/video_player.dart';

class FullScreenVideoScreen extends StatefulWidget {
  final String videoUrl;

  const FullScreenVideoScreen({super.key, required this.videoUrl});

  @override
  State<FullScreenVideoScreen> createState() => _FullScreenVideoScreenState();
}

class _FullScreenVideoScreenState extends State<FullScreenVideoScreen> {
  late VideoPlayerController _controller;
  late Future<void> _initializeVideoPlayerFuture;

  @override
  void initState() {
    super.initState();

    SystemChrome.setPreferredOrientations([
      DeviceOrientation.landscapeLeft,
      DeviceOrientation.landscapeRight,
    ]);
    
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);

    // --- *** THIS IS THE UPDATED LOGIC *** ---
    if (widget.videoUrl.startsWith('http') || widget.videoUrl.startsWith('https')) {
      // 1. Load from the internet
      _controller = VideoPlayerController.networkUrl(
        Uri.parse(widget.videoUrl),
      );
    } else if (widget.videoUrl.startsWith('assets/')) {
      // 2. --- NEW: Load from app assets ---
      _controller = VideoPlayerController.asset(
        widget.videoUrl,
      );
    } else {
      // 3. Load from a local device file
      _controller = VideoPlayerController.file(
        File(widget.videoUrl),
      );
    }
    // --- *** END OF UPDATE *** ---

    _initializeVideoPlayerFuture = _controller.initialize().then((_) {
      _controller.play();
      _controller.setLooping(true);
      setState(() {}); 
    });
  }

  @override
  void dispose() {
    SystemChrome.setPreferredOrientations([
      DeviceOrientation.portraitUp,
    ]);
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
    _controller.dispose();
    super.dispose();
  }

  void _togglePlayPause() {
    setState(() {
      if (_controller.value.isPlaying) {
        _controller.pause();
      } else {
        _controller.play();
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black, 
      body: Center(
        child: FutureBuilder(
          future: _initializeVideoPlayerFuture,
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.done) {
              return AspectRatio(
                aspectRatio: _controller.value.aspectRatio,
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    VideoPlayer(_controller),
                    GestureDetector(
                      onTap: _togglePlayPause,
                      child: Container(
                        color: Colors.transparent, 
                        child: Center(
                          child: Icon(
                            _controller.value.isPlaying ? null : Icons.play_arrow,
                            color: Colors.white.withOpacity(0.8),
                            size: 60.0,
                          ),
                        ),
                      ),
                    ),
                    Positioned(
                      top: 16,
                      left: 16,
                      child: IconButton(
                        icon: Icon(
                          Icons.close, 
                          color: Colors.white.withOpacity(0.9),
                          size: 30.0,
                        ),
                        onPressed: () => Navigator.pop(context),
                      ),
                    ),
                  ],
                ),
              );
            } else {
              return const CircularProgressIndicator();
            }
          },
        ),
      ),
    );
  }
}