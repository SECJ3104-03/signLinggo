// lib/screens/Community_Module/video_player_widget.dart

import 'dart:io'; // We need this to check for File paths
import 'package:flutter/material.dart';
import 'package:flutter_spinkit/flutter_spinkit.dart';
import 'package:video_player/video_player.dart';
import 'full_screen_video_screen.dart'; 
import 'package:visibility_detector/visibility_detector.dart';

class PostVideoPlayer extends StatefulWidget {
  final String videoUrl;
  
  // This bool decides if the video is forced to a 1:1 square
  final bool isSquare;
  
  // This function will pass the controller up to the parent widget
  final Function(VideoPlayerController) onControllerInitialized;
  
  const PostVideoPlayer({
    super.key, 
    required this.videoUrl,
    required this.onControllerInitialized,
    this.isSquare = false,
  });

  @override
  State<PostVideoPlayer> createState() => _PostVideoPlayerState();
}

class _PostVideoPlayerState extends State<PostVideoPlayer> {
  late VideoPlayerController _controller;
  late Future<void> _initializeVideoPlayerFuture;

  // This tracks the mute state
  bool _isMuted = false;

  @override
  void initState() {
    super.initState();
    
    // Logic to load from internet or from local file
    if (widget.videoUrl.startsWith('http') || widget.videoUrl.startsWith('https')) {
      _controller = VideoPlayerController.networkUrl(
        Uri.parse(widget.videoUrl),
      );
    } else {
      _controller = VideoPlayerController.file(
        File(widget.videoUrl),
      );
    }

    // We initialize, THEN we pass the controller to the parent
    _initializeVideoPlayerFuture = _controller.initialize().then((_) {
      _controller.setLooping(true);
      _controller.setVolume(0.0);
      _isMuted = true;
      
      // Pass the fully initialized controller back up
      widget.onControllerInitialized(_controller);
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  // This function plays the video
  void _playVideo() {
    setState(() {
      _controller.play();
    });
  }
  
  // This function pauses the video
  void _pauseVideo() {
     setState(() {
      _controller.pause();
    });
  }

  // This function toggles the mute state
  void _toggleMute() {
    setState(() {
      _isMuted = !_isMuted; // Flip the boolean
      if (_isMuted) {
        _controller.setVolume(0.0); // Mute
      } else {
        _controller.setVolume(1.0); // Unmute (full volume)
      }
    });
  }

  // This navigates to our new full-screen player
  void _goToFullScreen() {
    _controller.pause(); // Pause the current video
    
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => FullScreenVideoScreen(videoUrl: widget.videoUrl),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    // This 'VisibilityDetector' will watch for scrolling
    return VisibilityDetector(
      key: Key(widget.videoUrl),
      onVisibilityChanged: (visibilityInfo) {
        // If the video is not visible AND it is playing,
        // we must pause it.
        if (visibilityInfo.visibleFraction < 0.1 && _controller.value.isPlaying) {
          _controller.pause(); // Just pause, no need for setState
        }
      },
      child: FutureBuilder(
        future: _initializeVideoPlayerFuture,
        builder: (context, snapshot) {
          // If the video is still loading
          if (snapshot.connectionState != ConnectionState.done) {
            // Show a black 1:1 box while loading
            return AspectRatio(
              aspectRatio: 1 / 1,
              child: Container(
                color: Colors.black,
                child: Center(
                  child: SpinKitFadingCircle(
                    color: Colors.white,
                    size: 50.0,
                  ),
                ),
              ),
            );
          }

          // If the video has an error
          if (snapshot.hasError) {
            return AspectRatio(
              aspectRatio: 1/1,
              child: Container(
                color: Colors.black,
                child: Center(
                  child: Text(
                    'Error loading video',
                    style: TextStyle(color: Colors.white),
                  ),
                ),
              ),
            );
          }

          // --- If the video is loaded, build the player ---
          
          // 1. Create the CORE video player (JUST the video)
          final Widget coreVideoPlayer = VideoPlayer(_controller);
          
          // 2. Create the Mute Button
          final Widget muteButton = Positioned(
            bottom: 8,
            right: 8,
            child: IconButton(
              icon: Icon(
                _isMuted ? Icons.volume_off : Icons.volume_up,
                color: Colors.white.withOpacity(0.9),
                size: 24.0,
              ),
              onPressed: _toggleMute,
            ),
          );
          
          // 3. Create the Full-Screen Button
          final Widget fullScreenButton = widget.isSquare
              ? SizedBox.shrink()
              : Positioned(
                  bottom: 8,
                  left: 8,
                  child: IconButton(
                    icon: Icon(
                      Icons.fullscreen,
                      color: Colors.white.withOpacity(0.9),
                      size: 28.0,
                    ),
                    onPressed: _goToFullScreen,
                  ),
                );
          
          // 4. Create a single, smart play/pause button
          final Widget playPauseGestureDetector = _controller.value.isPlaying
            ? 
            // If PLAYING: Show an invisible button to PAUSE
            GestureDetector(
                onTap: _pauseVideo,
                child: Container(
                  color: Colors.transparent, 
                ),
              )
            : 
            // If PAUSED: Show a visible button to PLAY
            GestureDetector(
                onTap: _playVideo,
                child: Container(
                  color: Colors.black.withOpacity(0.3),
                  child: Center(
                    child: Icon(
                      Icons.play_arrow,
                      color: Colors.white.withOpacity(0.9),
                      size: 60.0,
                    ),
                  ),
                ),
              );

          // --- 5. Build the final layout ---
          
          if (widget.isSquare) {
            // For the feed AND detail screen (isSquare == true)
            return AspectRatio(
              aspectRatio: 1 / 1, // 1:1 Square
              child: Container(
                // We add a black background to the container
                // This will create the "black bars"
                color: Colors.black,
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    // The FittedBox now contains the video
                    FittedBox(
                      // --- *** THIS IS THE FIX *** ---
                      // It shrinks the video to FIT, not COVER
                      fit: BoxFit.contain, 
                      // --- *** --- *** --- *** --- *** ---
                      child: SizedBox(
                        width: _controller.value.size.width,
                        height: _controller.value.size.height,
                        child: coreVideoPlayer, // Just the video
                      ),
                    ),
                    playPauseGestureDetector, // Add the smart play/pause button
                    muteButton,      // Add mute button
                  ],
                ),
              ),
            );
          } else {
            // For the (now unused) non-square version
            return AspectRatio(
              aspectRatio: _controller.value.aspectRatio,
              child: Stack(
                alignment: Alignment.center,
                children: [
                  coreVideoPlayer,  // Just the video
                  playPauseGestureDetector,  // Add the smart play/pause button
                  muteButton,
                  fullScreenButton,
                ],
              ),
            );
          }
        },
      ),
    );
  }
}