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
  bool _isRecording = false;
  int _currentDuration = 0;
  static const int _maxDuration = 60;
  Timer? _timer;
  
  XFile? _recordedFile;

  Future<void>? _initializeControllerFuture;
  final SupabaseClient _supabase = Supabase.instance.client;
  final Uuid _uuid = const Uuid();

  bool _isUploading = false;
  bool _isFrontCamera = false;

  @override
  void initState() {
    super.initState();
    _initCamera();
  }

  @override
  void dispose() {
    _timer?.cancel();
    _cameraController?.dispose();
    super.dispose();
  }

  Future<void> _initCamera() async {
    _cameras = await availableCameras();
    if (_cameras.isNotEmpty) {
      _setCamera(_cameras.first);
    }
  }

  Future<void> _setCamera(CameraDescription cameraDescription) async {
    final prevController = _cameraController;
    
    final newController = CameraController(
      cameraDescription,
      ResolutionPreset.medium,
      enableAudio: true,
    );
    
    _cameraController = newController;
    
    _initializeControllerFuture = _cameraController!.initialize().then((_) {
       if (mounted) {
         setState(() {
           _isFrontCamera = cameraDescription.lensDirection == CameraLensDirection.front;
         });
       }
    });

    if (prevController != null) {
      await prevController.dispose();
    }
    
    if (mounted) setState(() {});
  }

  Future<void> _startRecording() async {
    if (_cameraController == null || !_cameraController!.value.isInitialized) return;
    _resetProgress();
    
    try {
      await _cameraController!.startVideoRecording();
      widget.onRecordingStateChanged(true);
      setState(() => _isRecording = true);

      _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
        _currentDuration++;
        if (_currentDuration >= _maxDuration) _stopRecording();
        setState(() {});
      });
    } catch (e) {
      debugPrint("Error starting recording: $e");
    }
  }

  Future<void> _stopRecording() async {
    if (!_isRecording) return;
    _timer?.cancel();
    _timer = null;

    try {
      _recordedFile = await _cameraController!.stopVideoRecording();
      widget.onRecordingStateChanged(false);
      setState(() => _isRecording = false);
      _showSendCancelDialog();
    } catch (e) {
      debugPrint("Error stopping recording: $e");
    }
  }

  void _flipCamera() async {
    if (_cameras.length < 2) return;

    final newLens = _isFrontCamera 
        ? CameraLensDirection.back 
        : CameraLensDirection.front;

    final newCamera = _cameras.firstWhere(
      (c) => c.lensDirection == newLens,
      orElse: () => _cameras.first,
    );

    await _setCamera(newCamera);
    
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(newLens == CameraLensDirection.front ? "Selfie Mode" : "Back Camera"),
          duration: const Duration(seconds: 1),
        ),
      );
    }
  }

  void _resetProgress() {
    _currentDuration = 0;
  }

  void _showSendCancelDialog() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => AlertDialog(
        title: const Text('Video recorded'),
        content: const Text('Do you want to send this video?'),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              _cleanupRecordedFile();
            },
            child: const Text('Cancel', style: TextStyle(color: Colors.red)),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              if (_recordedFile != null) {
                _uploadAndSendVideo(File(_recordedFile!.path));
              }
              _cleanupRecordedFile();
            },
            child: const Text('Send'),
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
      
    } on StorageException catch (e) {
      log('Supabase Storage Error: ${e.message}', name: 'SignInputBar');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Upload failed: ${e.message}')),
        );
      }
    } catch (e) {
      log('General Error: $e', name: 'SignInputBar');
    } finally {
      if (mounted) {
        setState(() => _isUploading = false);
      }
    }
  }

  void _cleanupRecordedFile() {
    _recordedFile = null;
    if (mounted) { setState(() {}); }
  }

  @override
  Widget build(BuildContext context) {
    final double previewSize = MediaQuery.of(context).size.width * 0.7;

    return LayoutBuilder(builder: (context, constraints) {
      return SizedBox(
        height: _isRecording ? constraints.maxHeight : 104,
        child: Stack(
          children: [
            if (_isRecording && _cameraController != null && _cameraController!.value.isInitialized)
              Center(
                child: Stack(
                  alignment: Alignment.center,
                  children: [
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
                    ClipOval(
                      child: SizedBox(
                        width: previewSize,
                        height: previewSize,
                        child: CameraPreview(_cameraController!),
                      ),
                    ),
    
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

            if (_isRecording)
              Positioned(
                bottom: 120,
                left: 0,
                right: 0,
                child: Center(
                  child: FloatingActionButton(
                    heroTag: 'stopRecording',
                    backgroundColor: Colors.red,
                    onPressed: _stopRecording,
                    child: const Icon(Icons.stop),
                  ),
                ),
              ),
    
            if (!_isRecording)
              Positioned(
                left: 20,
                right: 20,
                bottom: 20,
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Container(
                      decoration: BoxDecoration(
                        color: Colors.grey[200],
                        shape: BoxShape.circle,
                      ),
                      child: IconButton(
                        icon: Icon(
                          _isFrontCamera ? Icons.camera_front : Icons.camera_rear,
                          color: Colors.black87,
                        ),
                        onPressed: _flipCamera,
                      ),
                    ),
                    Expanded(
                      child: Center(
                        child: GestureDetector(
                          onTap: _isUploading ? null : _startRecording,
                          child: Container(
                            width: 64,
                            height: 64,
                            decoration: BoxDecoration(
                              gradient: const LinearGradient(
                                colors: [Color(0xFFAC46FF), Color(0xFFE50076)],
                                begin: Alignment.centerLeft,
                                end: Alignment.centerRight,
                              ),
                              borderRadius: BorderRadius.circular(32),
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.pink.withValues(alpha:0.3),
                                  blurRadius: 8,
                                  offset: const Offset(0, 4),
                                )
                              ],
                            ),
                            child: _isUploading
                                ? const Padding(
                                    padding: EdgeInsets.all(16.0),
                                    child: CircularProgressIndicator(
                                        color: Colors.white, strokeWidth: 3),
                                  )
                                : const Icon(Icons.videocam,
                                    color: Colors.white, size: 32),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 48), 
                  ],
                ),
              ),
          ],
        ),
      );
    });
  }
}