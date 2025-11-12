// lib/screens/Community_Module/video_player_widget.dart

import 'dart:io'; // We need this to check for File paths
import 'package:flutter/material.dart';
import 'package:flutter_spinkit/flutter_spinkit.dart';
import 'package:video_player/video_player.dart';
import 'full_screen_video_screen.dart'; 
import 'package:visibility_detector/visibility_detector.dart';

class PostVideoPlayer extends StatefulWidget {
  final String videoUrl;
  final bool isSquare;
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
  bool _isMuted = false;

  @override
  void initState() {
    super.initState();
    
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
      // 3. Load from a local device file (e.g., from the picker)
      _controller = VideoPlayerController.file(
        File(widget.videoUrl),
      );
    }
    // --- *** END OF UPDATE *** ---

    _initializeVideoPlayerFuture = _controller.initialize().then((_) {
      _controller.setLooping(true);
      _controller.setVolume(0.0);
      _isMuted = true;
      widget.onControllerInitialized(_controller);
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _playVideo() {
    setState(() {
      _controller.play();
    });
  }
  
  void _pauseVideo() {
     setState(() {
      _controller.pause();
    });
  }

  void _toggleMute() {
    setState(() {
      _isMuted = !_isMuted; 
      if (_isMuted) {
        _controller.setVolume(0.0); 
      } else {
        _controller.setVolume(1.0);
      }
    });
  }

  void _goToFullScreen() {
    _controller.pause(); 
    
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => FullScreenVideoScreen(videoUrl: widget.videoUrl),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return VisibilityDetector(
      key: Key(widget.videoUrl),
      onVisibilityChanged: (visibilityInfo) {
        if (visibilityInfo.visibleFraction < 0.1 && _controller.value.isPlaying) {
          _controller.pause(); 
        }
      },
      child: FutureBuilder(
        future: _initializeVideoPlayerFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState != ConnectionState.done) {
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
          
          final Widget coreVideoPlayer = VideoPlayer(_controller);
          
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
          
          final Widget playPauseGestureDetector = _controller.value.isPlaying
            ? 
            GestureDetector(
                onTap: _pauseVideo,
                child: Container(
                  color: Colors.transparent, 
                ),
              )
            : 
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

          if (widget.isSquare) {
            return AspectRatio(
              aspectRatio: 1 / 1, 
              child: Container(
                color: Colors.black,
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    FittedBox(
                      fit: BoxFit.contain, 
                      child: SizedBox(
                        width: _controller.value.size.width,
                        height: _controller.value.size.height,
                        child: coreVideoPlayer, 
                      ),
                    ),
                    playPauseGestureDetector, 
                    muteButton,      
                  ],
                ),
              ),
            );
          } else {
            return AspectRatio(
              aspectRatio: _controller.value.aspectRatio,
              child: Stack(
                alignment: Alignment.center,
                children: [
                  coreVideoPlayer,  
                  playPauseGestureDetector,  
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