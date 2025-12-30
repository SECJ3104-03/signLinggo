import 'dart:io';
import 'dart:async'; 

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:camera/camera.dart';
import '../../services/object_detector.dart'; 

class SignRecognitionScreen extends StatefulWidget {
  final CameraDescription camera;
  final bool isSignToText;

  const SignRecognitionScreen({
    super.key, 
    required this.camera, 
    this.isSignToText = false
  });

  @override
  State<SignRecognitionScreen> createState() => _SignRecognitionScreenState();
}

class _SignRecognitionScreenState extends State<SignRecognitionScreen> {
  late CameraController _controller;
  
  // Nullable to prevent "LateInitializationError" crash
  Future<void>? _initializeControllerFuture;
  late bool isSignToText;

  // --- AI & Logic Variables ---
  final ObjectDetector _detector = ObjectDetector();
  bool _isScanning = false;
  String _recognizedText = "Press Start"; 
  
  // --- Camera Management Variables ---
  List<CameraDescription> _cameras = []; 
  int _selectedCameraIdx = 0; 

  @override
  void initState() {
    super.initState();
    isSignToText = widget.isSignToText;
    
    // 1. Initialize the AI
    _detector.loadModel();

    // 2. Setup Cameras
    _setupCameras();
  }

  Future<void> _setupCameras() async {
    try {
      _cameras = await availableCameras();
      
      _selectedCameraIdx = _cameras.indexWhere(
        (c) => c.lensDirection == widget.camera.lensDirection
      );
      if (_selectedCameraIdx == -1) _selectedCameraIdx = 0;

      _initializeCamera(_cameras[_selectedCameraIdx]);
    } catch (e) {
      debugPrint("Error fetching cameras: $e");
    }
  }
  
  void _initializeCamera(CameraDescription cameraDescription) {
    _controller = CameraController(
      cameraDescription, 
      // Medium is the "Sweet Spot". Low is too blurry for AI. High is too slow.
      ResolutionPreset.medium, 
      enableAudio: false,
      imageFormatGroup: Platform.isAndroid 
        ? ImageFormatGroup.yuv420 
        : ImageFormatGroup.bgra8888, 
    );

    final future = _controller.initialize().then((_) async {
      try {
        await _controller.setZoomLevel(1.0);
      } catch (e) {
        debugPrint('Error setting zoom: $e');
      }
      if (mounted) setState(() {});
    });

    setState(() {
      _initializeControllerFuture = future;
    });
  }

  // --- FLIP CAMERA LOGIC ---
  Future<void> _onTapSwitchCamera() async {
    if (_cameras.length < 2) return; 

    if (_isScanning) {
      setState(() { _isScanning = false; });
    }

    final newIndex = (_selectedCameraIdx + 1) % _cameras.length;
    await _controller.dispose();

    setState(() {
      _selectedCameraIdx = newIndex;
      _initializeControllerFuture = null; 
    });
    
    _initializeCamera(_cameras[_selectedCameraIdx]);
  }

  // --- SNAPSHOT SCANNING LOOP ---
  void _toggleScanning() {
    setState(() {
      _isScanning = !_isScanning;
      // FIX 1: Update text immediately
      if (_isScanning) _recognizedText = "Initializing...";
    });

    if (_isScanning) {
      _startDetectionLoop();
    }
  }

  Future<void> _startDetectionLoop() async {
    // While the user wants to scan...
    while (_isScanning && mounted) {
      
      // Safety check
      if (!_controller.value.isInitialized || _controller.value.isTakingPicture) {
        await Future.delayed(const Duration(milliseconds: 50));
        continue;
      }

      try {
        // 1. Capture the image (Snapshot)
        // This takes ~200-300ms. It is the bottleneck, but it guarantees high quality.
        final XFile image = await _controller.takePicture();

        // 2. Run AI
        final String? result = await _detector.detect(image.path);

        // 3. Update the UI
        if (mounted && _isScanning) {
          setState(() {
            // FIX 2: Explicitly show "No Sign Detected" if result is null
            _recognizedText = result ?? "No Sign Detected";
          });
        }

        // 4. Delete temp file to save space
        File(image.path).delete().ignore();

      } catch (e) {
        debugPrint("Error in detection loop: $e");
      }

      // FIX 3: Reduced delay to 100ms. Your Vivo X200 is fast enough for this.
      await Future.delayed(const Duration(milliseconds: 1000));
    }
  }

  @override
  void dispose() {
    _isScanning = false;
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final double width = MediaQuery.of(context).size.width;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Sign Recognition', style: TextStyle(color: Colors.black, fontFamily: 'Arimo')),
        centerTitle: true,
        backgroundColor: Colors.white,
        elevation: 1,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.black),
          onPressed: () {
            _isScanning = false;
            if (context.canPop()) context.pop();
            else context.go('/home');
          },
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
             Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(16),
                gradient: const LinearGradient(colors: [Color(0xFFAC46FF), Color(0xFF8B2EFF)]),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(isSignToText ? 'Text → Sign' : 'Sign → Text', style: const TextStyle(fontSize: 18, color: Colors.white)),
                ],
              ),
            ),
            
            const SizedBox(height: 20),

            // Result Display
            Container(
              padding: const EdgeInsets.all(12),
              width: double.infinity,
              decoration: BoxDecoration(
                color: Colors.purple.shade50,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.purple.shade200)
              ),
              child: Column(
                children: [
                  const Text("Detected Sign:", style: TextStyle(color: Colors.grey)),
                  Text(
                    _recognizedText,
                    style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: Colors.purple),
                  ),
                ],
              ),
            ),
            
            const SizedBox(height: 20),

            // --- CAMERA PREVIEW SECTION ---
            Container(
              width: width,
              height: 400,
              decoration: BoxDecoration(
                color: const Color(0xFFF3F4F6),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: const Color(0xFFE5E7EB)),
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(16),
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    // CHECK: Is Camera Ready?
                    _initializeControllerFuture == null 
                    ? const Center(child: CircularProgressIndicator())
                    : FutureBuilder<void>(
                      future: _initializeControllerFuture,
                      builder: (context, snapshot) {
                        if (snapshot.connectionState == ConnectionState.done) {
                          return SizedBox.expand(
                            child: FittedBox(
                              fit: BoxFit.cover,
                              child: SizedBox(
                                width: _controller.value.previewSize!.height,
                                height: _controller.value.previewSize!.width,
                                child: CameraPreview(_controller),
                              ),
                            ),
                          );
                        } else {
                          return const Center(child: CircularProgressIndicator());
                        }
                      },
                    ),
                    
                    // Overlay Box
                    Center(
                      child: Container(
                        width: 220, height: 220,
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(24),
                          border: Border.all(width: 3, color: _isScanning ? Colors.green : Colors.white.withOpacity(0.7)),
                        ),
                      ),
                    ),

                    // Flip Camera Button
                    Positioned(
                      bottom: 16,
                      right: 16,
                      child: FloatingActionButton.small(
                        heroTag: "flip_btn",
                        backgroundColor: Colors.white.withOpacity(0.8),
                        onPressed: _onTapSwitchCamera,
                        child: const Icon(Icons.flip_camera_ios, color: Colors.black),
                      ),
                    ),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 32),

            // Start/Stop Button
            GestureDetector(
              onTap: _toggleScanning,
              child: Container(
                width: double.infinity,
                height: 56,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(16),
                  gradient: LinearGradient(
                    colors: _isScanning 
                        ? [Colors.red, Colors.redAccent] 
                        : [const Color(0xFFF6329A), const Color(0xFF00B8DA)],
                  ),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(_isScanning ? Icons.stop : Icons.camera_alt_outlined, color: Colors.white),
                    const SizedBox(width: 8),
                    Text(
                      _isScanning ? 'Stop Recognition' : 'Start Recognition',
                      style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w600, fontSize: 16),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}