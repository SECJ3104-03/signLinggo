// lib/screens/conversation_mode/sign_input_bar.dart

import 'dart:async';
import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:camera/camera.dart';
import 'package:video_player/video_player.dart';

// --- PLATFORM ABSTRACTION HELPER ---
// This is a necessary abstraction to conform to the File signature on the web.
// Since dart:io.File cannot be used on web, we must use a different way to
// hold the recorded video data (bytes).

class RecordedVideoData {
  final String path;
  final Uint8List? bytes; // Holds video bytes for web
  final bool isWeb;

  RecordedVideoData.fromXFile(XFile xFile)
      : path = xFile.path,
        bytes = null,
        isWeb = false;

  RecordedVideoData.fromWebBytes(this.path, Uint8List data)
      : bytes = data,
        isWeb = true;
}

// --- SIGN INPUT BAR CLASS ---

class SignInputBar extends StatefulWidget {
  final CameraController? cameraController;
  
  // Signature remains File for backward compatibility/preference
  final Future<void> Function(File videoFile) onVideoRecorded;
  
  final bool isParentRecording;
  final Function(bool isRecording) onRecordingStateChanged;

  const SignInputBar({
    super.key,
    required this.cameraController,
    required this.onVideoRecorded,
    required this.isParentRecording,
    required this.onRecordingStateChanged,
  });

  @override
  State<SignInputBar> createState() => _SignInputBarState();
}

class _SignInputBarState extends State<SignInputBar> {
  static const int _maxDurationSeconds = 60;
  Timer? _timer;
  int _currentDurationSeconds = 0;
  
  RecordedVideoData? _recordedVideoData; // Holds the processed video data
  XFile? _recordedXFile; // Holds the raw XFile output

  VideoPlayerController? _reviewController;

  bool get _isRecording => _timer != null;

  @override
  void dispose() {
    _timer?.cancel();
    _reviewController?.dispose();
    super.dispose();
  }

  // --- Recording Logic ---

  Future<void> _startRecording() async {
    if (widget.cameraController == null ||
        !widget.cameraController!.value.isInitialized) return;

    _resetReviewState();

    try {
      await widget.cameraController!.pausePreview();
      await widget.cameraController!.startVideoRecording();
      widget.onRecordingStateChanged(true);

      setState(() {
        _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
          _currentDurationSeconds++;
          if (_currentDurationSeconds >= _maxDurationSeconds) {
            _stopRecording(autoStop: true);
          }
          setState(() {});
        });
      });
    } catch (e) {
      debugPrint('Error starting recording: $e');
    }
  }

  Future<void> _stopRecording({bool autoStop = false}) async {
    if (!_isRecording) return;

    _timer?.cancel();
    _timer = null;
    widget.onRecordingStateChanged(false);

    try {
      _recordedXFile = await widget.cameraController!.stopVideoRecording();
      await widget.cameraController!.resumePreview();

      if (!kIsWeb) {
        // NATIVE: Use dart:io.File for VideoPlayerController and create RecordedVideoData
        final videoFile = File(_recordedXFile!.path);
        _recordedVideoData = RecordedVideoData.fromXFile(_recordedXFile!);
        
        _reviewController = VideoPlayerController.file(videoFile)
          ..initialize().then((_) {
            if (mounted) setState(() {});
            if (autoStop) _showVideoReviewDialog();
          });
      } else {
        // WEB: Read bytes directly from XFile and create RecordedVideoData
        final bytes = await _recordedXFile!.readAsBytes();
        final path = _recordedXFile!.path.split('/').last;
        _recordedVideoData = RecordedVideoData.fromWebBytes(path, bytes);
        
        // No VideoPlayerController for review on web with this setup
        if (autoStop) _showVideoReviewDialog();
      }

      if (!mounted) return;
      setState(() {});

      if (!autoStop) _showVideoReviewDialog();
    } catch (e) {
      debugPrint('Error stopping recording: $e');
    }
  }

  void _sendVideo() {
    if (_recordedXFile == null || _recordedVideoData == null) return;
    
    // Create a MemoryFile or IOFile depending on the platform, 
    // but the type passed is always dart:io.File
    final videoFile = kIsWeb
        ? _MemoryBackedFile(_recordedVideoData!.path, _recordedVideoData!.bytes!)
        : File(_recordedXFile!.path);

    widget.onVideoRecorded(videoFile); 
    
    _resetReviewState();
    Navigator.of(context).pop(); 
  }

  void _deleteVideo() {
    _resetReviewState();
    Navigator.of(context).pop(); 
  }

  void _resetReviewState() {
    _reviewController?.dispose();
    _reviewController = null;
    _recordedXFile = null;
    _recordedVideoData = null;
    _currentDurationSeconds = 0;
    if (mounted) setState(() {});
  }

  // --- UI Components ---
  
  // _buildRecordingButton() remains the same as previous version...
  Widget _buildRecordingButton() {
    final double progress = _currentDurationSeconds / _maxDurationSeconds;
    final buttonIcon = _isRecording ? Icons.stop : Icons.videocam;
    final buttonGradient = _isRecording
        ? [Colors.red[600]!, Colors.red[900]!]
        : [const Color(0xFFAC46FF), const Color(0xFFE50076)];
    final buttonAction = _isRecording ? _stopRecording : _startRecording;

    return Container(
      padding: const EdgeInsets.all(12),
      color: Colors.white,
      child: GestureDetector(
        onTap: buttonAction as void Function(),
        child: Stack(
          alignment: Alignment.center,
          children: [
            SizedBox(
              width: double.infinity,
              height: 56,
              child: CircularProgressIndicator(
                value: progress,
                strokeWidth: 4.0,
                backgroundColor: _isRecording ? Colors.red[100] : Colors.grey[200],
                valueColor: AlwaysStoppedAnimation<Color>(Colors.green[600]!),
              ),
            ),
            Container(
              width: double.infinity,
              height: 56,
              margin: const EdgeInsets.all(4),
              decoration: BoxDecoration(
                gradient: LinearGradient(colors: buttonGradient),
                borderRadius: BorderRadius.circular(20),
              ),
              alignment: Alignment.center,
              child: Icon(buttonIcon, color: Colors.white, size: 28),
            ),
            if (_isRecording)
              Positioned(
                right: 20,
                child: Text(
                  '${_maxDurationSeconds - _currentDurationSeconds}s',
                  style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                      fontSize: 14),
                ),
              ),
          ],
        ),
      ),
    );
  }

  // _buildCameraPreviewBubble() remains the same as previous version...
  Widget _buildCameraPreviewBubble() {
    if (widget.cameraController == null ||
        !widget.cameraController!.value.isInitialized) {
      return const SizedBox.shrink();
    }
    final double progress = _currentDurationSeconds / _maxDurationSeconds;
    return Container(
      width: 204,
      height: 204,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        border: Border.all(
          color: Colors.green[600]!,
          width: 4 * progress,
        ),
        boxShadow: const [
          BoxShadow(color: Colors.black26, blurRadius: 6, offset: Offset(0, 3))
        ],
      ),
      child: ClipOval(
        child: CameraPreview(widget.cameraController!),
      ),
    );
  }

  // _showVideoReviewDialog() updated to handle web review status
  void _showVideoReviewDialog() {
    showGeneralDialog(
      context: context,
      barrierDismissible: false,
      barrierLabel: 'Video Review',
      transitionDuration: const Duration(milliseconds: 300),
      pageBuilder: (context, animation1, animation2) {
        final bool canPlayVideo = !kIsWeb && _reviewController != null && _reviewController!.value.isInitialized;
        
        return Center(
          child: Material(
            color: Colors.transparent,
            child: Container(
              width: MediaQuery.of(context).size.width * 0.9,
              height: MediaQuery.of(context).size.height * 0.6,
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(20),
                boxShadow: const [
                  BoxShadow(
                    color: Colors.black26,
                    blurRadius: 10,
                    offset: Offset(0, 4),
                  ),
                ],
              ),
              child: Column(
                children: [
                  const Text(
                    'Review Video Message',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 12),
                  Expanded(
                    child: canPlayVideo
                        ? AspectRatio(
                            aspectRatio: _reviewController!.value.aspectRatio,
                            child: Stack(
                              alignment: Alignment.center,
                              children: [
                                VideoPlayer(_reviewController!),
                                IconButton(
                                  icon: Icon(
                                    _reviewController!.value.isPlaying
                                        ? Icons.pause_circle
                                        : Icons.play_circle,
                                    size: 64,
                                    color: Colors.white70,
                                  ),
                                  onPressed: () {
                                    setState(() {
                                      _reviewController!.value.isPlaying
                                          ? _reviewController!.pause()
                                          : _reviewController!.play();
                                    });
                                  },
                                ),
                              ],
                            ),
                          )
                        : const Center(
                            child: Text(
                              // Show message if on Web or video is loading/failed
                              kIsWeb ? 'Review is unavailable on Web. Send or Delete.' : 'Video Loading...',
                              style: TextStyle(color: Colors.black54),
                            ),
                          ),
                  ),
                  const SizedBox(height: 12),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    children: [
                      TextButton(
                        onPressed: _deleteVideo,
                        child: const Text('Delete', style: TextStyle(color: Colors.red)),
                      ),
                      ElevatedButton(
                        onPressed: _sendVideo,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.green,
                          foregroundColor: Colors.white,
                        ),
                        child: const Text('Send'),
                      ),
                    ],
                  )
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisAlignment: MainAxisAlignment.end,
      children: [
        Expanded(
          child: Center(
            child: _isRecording 
                ? _buildCameraPreviewBubble() 
                : const SizedBox.shrink(),
          ),
        ),
        _buildRecordingButton(),
      ],
    );
  }
}

// --- MOCK FILE CLASS FOR WEB ---
// This class is a minimal implementation of dart:io.File that only implements
// the methods necessary for the parent's upload function to get the bytes
// when running on the web.

class _MemoryBackedFile implements File {
  final String _path;
  final Uint8List _bytes;

  _MemoryBackedFile(this._path, this._bytes);

  @override
  String get path => _path;

  @override
  Future<Uint8List> readAsBytes() async => _bytes;

  // The remaining methods from the File interface are not needed 
  // for this specific upload logic, so they are implemented to throw 
  // an UnsupportedError to prevent misuse on the web.

  @override
  noSuchMethod(Invocation invocation) {
    // Only allow methods like 'path' and 'readAsBytes'
    if (invocation.memberName == #path || invocation.memberName == #readAsBytes) {
      return super.noSuchMethod(invocation);
    }
    throw UnsupportedError('Operation not supported on web-backed File: ${invocation.memberName}');
  }
}