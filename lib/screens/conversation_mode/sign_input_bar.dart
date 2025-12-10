import 'dart:async';
import 'dart:io';
import 'dart:typed_data';
import 'dart:developer';
import 'package:flutter/material.dart';
import 'package:camera/camera.dart';
import 'package:video_player/video_player.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:uuid/uuid.dart';

class RecordedVideoData {
  final String path;
  final Uint8List? bytes;
  final bool isWeb;

  RecordedVideoData.fromXFile(XFile xFile)
      : path = xFile.path,
        bytes = null,
        isWeb = false;

  RecordedVideoData.fromWebBytes(this.path, Uint8List data)
      : bytes = data,
        isWeb = true;
}

class SignInputBar extends StatefulWidget {
  final Future<void> Function(String videoUrl) onVideoRecorded;
  final bool isParentRecording;
  final Function(bool isRecording) onRecordingStateChanged;

  const SignInputBar({
    super.key,
    required this.onVideoRecorded,
    required this.isParentRecording,
    required this.onRecordingStateChanged,
  });

  @override
  State<SignInputBar> createState() => _SignInputBarState();
}

class _SignInputBarState extends State<SignInputBar> {
  CameraController? _cameraController;
  List<CameraDescription> _cameras = [];
  bool _isRecording = false; // This state controls visibility of camera preview vs start button
  int _currentDuration = 0;
  static const int _maxDuration = 60;
  Timer? _timer;
  
  XFile? _recordedFile;
  VideoPlayerController? _reviewController;

  Future<void>? _initializeControllerFuture; // Future to track camera initialization
  final SupabaseClient _supabase = Supabase.instance.client;
  final Uuid _uuid = const Uuid();

  bool _isUploading = false;

  @override
  void initState() {
    super.initState();
    _initCamera();
  }

  @override
  void dispose() {
    _timer?.cancel();
    _cameraController?.dispose();
    _reviewController?.dispose();
    super.dispose();
  }

  Future<void> _initCamera() async {
    _cameras = await availableCameras();
    if (_cameras.isNotEmpty) {
      _cameraController = CameraController(
          _cameras.first, ResolutionPreset.medium,
          enableAudio: true); // Initialize the controller
      _initializeControllerFuture = _cameraController!.initialize(); // Assign the future
      if (mounted) setState(() {});
    }
  }

  Future<void> _startRecording() async {
    if (_cameraController == null || !_cameraController!.value.isInitialized) return;
    _resetProgress();
    await _cameraController!.startVideoRecording();
    widget.onRecordingStateChanged(true);
    setState(() => _isRecording = true);

    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      _currentDuration++;
      if (_currentDuration >= _maxDuration) _stopRecording();
      setState(() {});
    });
  }

  Future<void> _stopRecording() async {
    if (!_isRecording) return;
    _timer?.cancel();
    _timer = null;

    _recordedFile = await _cameraController!.stopVideoRecording();
    widget.onRecordingStateChanged(false);
    setState(() => _isRecording = false);

    _reviewController = VideoPlayerController.file(File(_recordedFile!.path))
      ..initialize().then((_) => setState(() {}));

    _showReviewDialog();
  }

  void _flipCamera() async {
    if (_isRecording || _cameras.length < 2) return;

    final newLens = _cameraController!.description.lensDirection == CameraLensDirection.front
        ? CameraLensDirection.back
        : CameraLensDirection.front;

    final newCamera = _cameras.firstWhere((c) => c.lensDirection == newLens);
    await _cameraController!.dispose();
    _cameraController = CameraController(newCamera, ResolutionPreset.medium, enableAudio: true); // Re-initialize controller
    _initializeControllerFuture = _cameraController!.initialize(); // Update the future
    setState(() {});
  }

  void _resetProgress() {
    _currentDuration = 0;
  }

  void _showReviewDialog() {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        content: _reviewController != null && _reviewController!.value.isInitialized
            ? AspectRatio(
                aspectRatio: _reviewController!.value.aspectRatio,
                child: VideoPlayer(_reviewController!),
              )
            : const SizedBox.shrink(),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              _recordedFile = null;
              _reviewController?.dispose();
              _reviewController = null;
            },
            child: const Icon(Icons.delete_rounded),
          ),
          ElevatedButton(
            onPressed: () {
              if (_recordedFile != null) {
                _uploadAndSendVideo(File(_recordedFile!.path));
              }
              Navigator.pop(context);
              _cleanupReview();
            },
            child: const Icon(Icons.send_rounded),
          ),
        ],
      ),
    );
  }

  Future<void> _uploadAndSendVideo(File videoFile) async {
    setState(() => _isUploading = true);
    try {
      const String bucketName = 'videoMessage';
      final String fileExtension = videoFile.path.split('.').last;
      
      final String fileName = '${_uuid.v4()}.$fileExtension';
      final String storagePath = 'user_uploads/$fileName';

      await _supabase.storage.from(bucketName).upload(
            storagePath,
            videoFile,
            fileOptions: const FileOptions(
                contentType: 'video/mp4',
                upsert: false),
          );

      final String publicUrl = _supabase.storage
          .from(bucketName)
          .getPublicUrl(storagePath);

      await widget.onVideoRecorded(publicUrl);
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Video uploaded successfully!')),
        );
      }
      
    } on StorageException catch (e) {
      log('Supabase Storage Error: ${e.message}', name: 'SignInputBar');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Upload failed: ${e.message}')),
        );
      }
    } catch (e) {
      log('General Error: $e', name: 'SignInputBar');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('An unknown error occurred during upload.')),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isUploading = false);
      }
    }
  }

  void _cleanupReview() {
    _recordedFile = null;
    _reviewController?.dispose();
    _reviewController = null;
    if (mounted) {
      setState(() {});
    }
  }

 @override
Widget build(BuildContext context) {
  final double previewSize = MediaQuery.of(context).size.width * 0.7;

  return LayoutBuilder(builder: (context, constraints) {
    return SizedBox(
      height: _isRecording ? constraints.maxHeight : 104,
      child: Stack(
        children: [
          // ---------- CAMERA PREVIEW ----------
          if (_isRecording && _cameraController != null && _initializeControllerFuture != null)
            Center(
              child: Stack(
                alignment: Alignment.center,
                children: [
                  // Circular progress ring
                  if (_isRecording)
                    TweenAnimationBuilder<double>(
                      tween: Tween<double>(end: _currentDuration / _maxDuration),
                      duration: const Duration(milliseconds: 500),
                      builder: (context, value, child) {
                        return SizedBox(
                          width: previewSize + 16,
                          height: previewSize + 16,
                          child: CircularProgressIndicator(
                            value: value,
                            strokeWidth: 6,
                            color: Colors.green,
                            backgroundColor: const Color.fromRGBO(33, 148, 26, 0.3),
                          ),
                        );
                      },
                    ),
    
                  // Camera preview
                  FutureBuilder<void>(
                    future: _initializeControllerFuture,
                    builder: (context, snapshot) {
                      if (snapshot.connectionState == ConnectionState.done) {
                        // If the Future is complete, display the preview.
                        return ClipOval(
                          child: SizedBox(
                            width: previewSize,
                            height: previewSize,
                            child: CameraPreview(_cameraController!),
                          ),
                        );
                      } else {
                        // Otherwise, display a loading indicator.
                        return const Center(child: CircularProgressIndicator());
                      }
                    },
                  ),
    
                  // Timer overlay
                  if (_isRecording)
                    Positioned(
                      top: -40,
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                        decoration: BoxDecoration(
                          color: Colors.black54,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Text(
                          '${_currentDuration.toString().padLeft(2, '0')}:${(_maxDuration - _currentDuration).toString().padLeft(2, '0')}',
                          style: const TextStyle(color: Colors.white, fontSize: 16),
                        ),
                      ),
                    ),
                ],
              ),
            ),
    
          // ---------- FLIP & STOP BUTTONS (overlay) ----------
          if (_isRecording)
            Positioned(
              bottom: 120,
              left: 0,
              right: 0,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  FloatingActionButton(
                    heroTag: 'flipCamera',
                    backgroundColor: Colors.purpleAccent,
                    onPressed: _flipCamera,
                    child: const Icon(Icons.cameraswitch),
                  ),
                  const SizedBox(width: 40),
                  FloatingActionButton(
                    heroTag: 'stopRecording',
                    backgroundColor: Colors.red,
                    onPressed: _stopRecording,
                    child: const Icon(Icons.stop),
                  ),
                ],
              ),
            ),
    
          // ---------- START RECORDING BUTTON (bottom of screen) ----------
          if (!_isRecording)
            Positioned(
              left: 20,
              right: 20,
              bottom: 20,
              child: ClipRRect(
                borderRadius: BorderRadius.circular(24),
                child: Container(
                  height: 64,
                  decoration: const BoxDecoration(
                    gradient: LinearGradient(
                      colors: [Color(0xFFAC46FF), Color(0xFFE50076)],
                      begin: Alignment.centerLeft,
                      end: Alignment.centerRight,
                    ),
                  ),
                  child: GestureDetector(
                    onTap: _isUploading ? null : _startRecording,
                    child: Container(
                      width: 56,
                      height: 56,
                      decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        colors: [Color(0xFFAC46FF), Color(0xFFE50076)],
                      ),
                      borderRadius: BorderRadius.circular(24),
                    ),
                    child: _isUploading
                        ? const CircularProgressIndicator(color: Colors.white)
                        : const Icon(Icons.videocam, color: Colors.white, size: 28),
                  ),
                ),
              ),
            ),
            ),
        ],
      ),
    );
  });
}
}