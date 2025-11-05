// lib/screens/Community_Module/full_screen_video_screen.dart

import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart'; // We need this to control device orientation
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

    // --- Force the phone into landscape mode ---
    SystemChrome.setPreferredOrientations([
      DeviceOrientation.landscapeLeft,
      DeviceOrientation.landscapeRight,
    ]);
    
    // --- Hide the top/bottom system UI (status bar, nav bar) ---
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);

    // Create and initialize the video controller
    if (widget.videoUrl.startsWith('http') || widget.videoUrl.startsWith('https')) {
      _controller = VideoPlayerController.networkUrl(
        Uri.parse(widget.videoUrl),
      );
    } else {
      _controller = VideoPlayerController.file(
        File(widget.videoUrl),
      );
    }

    _initializeVideoPlayerFuture = _controller.initialize().then((_) {
      // Once loaded, play the video and make it loop
      _controller.play();
      _controller.setLooping(true);
      setState(() {}); // Update UI
    });
  }

  @override
  void dispose() {
    // --- IMPORTANT ---
    // When we leave this screen, we must:
    
    // 1. Put the orientation back to normal (portrait)
    SystemChrome.setPreferredOrientations([
      DeviceOrientation.portraitUp,
    ]);
    
    // 2. Show the system UI again
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
    
    // 3. Dispose of the controller
    _controller.dispose();
    
    super.dispose();
  }

  // This function toggles the play/pause state
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
      backgroundColor: Colors.black, // Full-screen player is always black
      body: Center(
        child: FutureBuilder(
          future: _initializeVideoPlayerFuture,
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.done) {
              // If the video is loaded, show it
              return AspectRatio(
                aspectRatio: _controller.value.aspectRatio,
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    // The video itself
                    VideoPlayer(_controller),
                    
                    // A play/pause button on tap
                    GestureDetector(
                      onTap: _togglePlayPause,
                      child: Container(
                        color: Colors.transparent, // Invisible tap area
                        child: Center(
                          child: Icon(
                            _controller.value.isPlaying ? null : Icons.play_arrow,
                            color: Colors.white.withOpacity(0.8),
                            size: 60.0,
                          ),
                        ),
                      ),
                    ),

                    // The "Close" button to exit full-screen
                    Positioned(
                      top: 16,
                      left: 16,
                      child: IconButton(
                        icon: Icon(
                          Icons.close, 
                          color: Colors.white.withOpacity(0.9),
                          size: 30.0,
                        ),
                        // 'Navigator.pop' closes this screen
                        onPressed: () => Navigator.pop(context),
                      ),
                    ),
                  ],
                ),
              );
            } else {
              // While loading, show a spinner
              return const CircularProgressIndicator();
            }
          },
        ),
      ),
    );
  }
}