import 'dart:async';
import 'dart:io';
import 'dart:math' as math; // Import math for rotation calculations

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:camera/camera.dart';
import 'package:flutter/services.dart';

// Assuming this is your existing import path
import '../../services/object_detector.dart';

class SignRecognitionScreen extends StatefulWidget {
  final CameraDescription camera;
  final bool isSignToText;

  const SignRecognitionScreen({
    super.key,
    required this.camera,
    this.isSignToText = false,
  });

  @override
  State<SignRecognitionScreen> createState() => _SignRecognitionScreenState();
}

class _SignRecognitionScreenState extends State<SignRecognitionScreen>
    with WidgetsBindingObserver {
  late CameraController _controller;
  Future<void>? _initializeControllerFuture;
  late bool isSignToText;

  final ObjectDetector _detector = ObjectDetector();
  bool _isScanning = false;
  List<Map<String, dynamic>> _detections = [];

  // Performance & Throttling
  int _frameCounter = 0;
  double _fps = 0.0;
  Timer? _fpsTimer;
  int _lastRunTime = 0; // To control detection speed

  // UI state
  bool _showSettings = false;
  bool _modelLoaded = false;

  List<CameraDescription> _cameras = [];
  int _selectedCameraIdx = 0;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]);
    isSignToText = widget.isSignToText;

    _initializeModel();
    _setupCameras();

    // FPS Timer
    _fpsTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (mounted && _isScanning) {
        setState(() {
          _fps = _frameCounter.toDouble();
          _frameCounter = 0;
        });
      }
    });
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    // Re-initialize camera on resume to prevent black screen
    if (_controller.value.isInitialized == false) return;
    
    if (state == AppLifecycleState.inactive) {
      _stopScanning();
      _controller.dispose();
    } else if (state == AppLifecycleState.resumed) {
      _initializeCamera(_cameras[_selectedCameraIdx]);
    }
  }

  void _initializeModel() async {
    await _detector.loadModel();
    if (mounted) {
      setState(() {
        _modelLoaded = _detector.isLoaded;
      });
    }
  }

  Future<void> _setupCameras() async {
    try {
      _cameras = await availableCameras();
      // Try to find the camera passed in widget, otherwise default to back
      _selectedCameraIdx = _cameras.indexWhere(
          (c) => c.lensDirection == widget.camera.lensDirection);
      if (_selectedCameraIdx == -1) _selectedCameraIdx = 0;
      _initializeCamera(_cameras[_selectedCameraIdx]);
    } catch (e) {
      print("Camera Error: $e");
    }
  }

  void _initializeCamera(CameraDescription cameraDescription) {
    _controller = CameraController(
      cameraDescription,
      ResolutionPreset.medium, // Changed to MEDIUM for faster processing
      enableAudio: false,
      imageFormatGroup: Platform.isAndroid
          ? ImageFormatGroup.yuv420
          : ImageFormatGroup.bgra8888,
    );

    _initializeControllerFuture = _controller.initialize().then((_) {
      if (mounted) setState(() {});
    });
  }

  Future<void> _onTapSwitchCamera() async {
    if (_cameras.length < 2) return;
    await _stopScanning();
    await _controller.dispose();

    final newIndex = (_selectedCameraIdx + 1) % _cameras.length;
    
    setState(() {
      _selectedCameraIdx = newIndex;
      _initializeControllerFuture = null;
    });
    
    _initializeCamera(_cameras[_selectedCameraIdx]);
  }

  void _toggleScanning() async {
    if (!_modelLoaded) return;
    if (_isScanning) {
      await _stopScanning();
    } else {
      await _startScanning();
    }
  }

  Future<void> _startScanning() async {
    if (!_controller.value.isInitialized) return;
    setState(() {
      _isScanning = true;
      _detections = [];
    });
    await _startStreaming();
  }

  Future<void> _startStreaming() async {
    try {
      await _controller.startImageStream((CameraImage image) {
        _processCameraFrame(image);
      });
    } catch (e) {
      print("Stream Error: $e");
    }
  }

  void _processCameraFrame(CameraImage image) async {
    if (_detector.isBusy) return;

    // --- FIX: Throttle Detection (Prevents Lag) ---
    // Only run detection every 500ms (approx 2 times per second)
    int currentTime = DateTime.now().millisecondsSinceEpoch;
    if (currentTime - _lastRunTime < 500) {
      return; 
    }
    _lastRunTime = currentTime;
    // ----------------------------------------------

    _frameCounter++;

    final results = await _detector.yoloOnFrame(image);

    if (mounted && _isScanning) {
      setState(() {
        _detections = results;
      });
    }
  }

  Future<void> _stopScanning() async {
    if (_controller.value.isStreamingImages) {
      await _controller.stopImageStream();
    }
    if (mounted) {
      setState(() {
        _isScanning = false;
        _detections = [];
      });
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _stopScanning();
    _fpsTimer?.cancel();
    _detector.dispose();
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final double width = MediaQuery.of(context).size.width;
    // We define a fixed height for the camera container
    final double containerHeight = 500; 

    return Scaffold(
      appBar: AppBar(
        title: const Text('Sign Recognition', style: TextStyle(color: Colors.black)),
        centerTitle: true,
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.black),
          onPressed: () {
            _stopScanning();
            context.pop();
          },
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.settings, color: Colors.black),
            onPressed: () => setState(() => _showSettings = !_showSettings),
          ),
        ],
      ),
      body: Stack(
        children: [
          SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: Column(
              children: [
                // 1. Status Chip
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  decoration: BoxDecoration(
                    color: _modelLoaded ? Colors.green.shade50 : Colors.red.shade50,
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: _modelLoaded ? Colors.green : Colors.red),
                  ),
                  child: Text(
                    _modelLoaded ? "AI Active (YOLOv8)" : "Loading Model...",
                    style: TextStyle(
                        color: _modelLoaded ? Colors.green.shade800 : Colors.red.shade800,
                        fontWeight: FontWeight.bold),
                  ),
                ),
                const SizedBox(height: 20),

                // 2. Camera View (FIXED STRETCHING)
                Container(
                  height: containerHeight,
                  width: width,
                  decoration: BoxDecoration(
                    color: Colors.black,
                    borderRadius: BorderRadius.circular(20),
                    boxShadow: [
                      BoxShadow(color: Colors.black26, blurRadius: 10, offset: Offset(0, 5))
                    ],
                  ),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(20),
                    child: Stack(
                      fit: StackFit.expand,
                      children: [
                        if (_initializeControllerFuture == null)
                          const Center(child: CircularProgressIndicator())
                        else
                          // --- FIX: Aspect Ratio Handling ---
                          FittedBox(
                            fit: BoxFit.cover,
                            child: SizedBox(
                              width: _controller.value.previewSize!.height,
                              height: _controller.value.previewSize!.width,
                              child: CameraPreview(_controller),
                            ),
                          ),
                        // ----------------------------------

                        // Bounding Boxes Overlay
                        if (_isScanning && _detections.isNotEmpty)
                          CustomPaint(
                            painter: BoundingBoxPainter(
                              detections: _detections,
                              // IMPORTANT: Pass the logic to check for front camera
                              isFrontCamera: _cameras.isNotEmpty && 
                                  _cameras[_selectedCameraIdx].lensDirection == CameraLensDirection.front,
                              previewSize: _controller.value.previewSize!,
                              screenSize: Size(width, containerHeight),
                            ),
                          ),

                        // Flip Button
                        Positioned(
                          bottom: 15,
                          right: 15,
                          child: FloatingActionButton.small(
                            backgroundColor: Colors.white24,
                            onPressed: _onTapSwitchCamera,
                            child: const Icon(Icons.flip_camera_ios, color: Colors.white),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 30),

                // 3. Start/Stop Button
                GestureDetector(
                  onTap: _toggleScanning,
                  child: Container(
                    height: 60,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(15),
                      gradient: LinearGradient(
                        colors: _isScanning
                            ? [Colors.red.shade400, Colors.red.shade700]
                            : [const Color(0xFF00B8DA), const Color(0xFFF6329A)],
                      ),
                      boxShadow: [
                        BoxShadow(
                            color: _isScanning
                                ? Colors.red.withOpacity(0.4)
                                : Colors.pink.withOpacity(0.4),
                            blurRadius: 10,
                            offset: const Offset(0, 5))
                      ],
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(_isScanning ? Icons.stop : Icons.play_arrow,
                            color: Colors.white, size: 30),
                        const SizedBox(width: 10),
                        Text(
                          _isScanning ? "STOP SCANNING" : "START SCANNING",
                          style: const TextStyle(
                              color: Colors.white,
                              fontSize: 18,
                              fontWeight: FontWeight.bold),
                        ),
                      ],
                    ),
                  ),
                ),

                // Debug Info
                if (_showSettings) ...[
                  const SizedBox(height: 20),
                  Text(
                    "FPS: ${_fps.toStringAsFixed(1)} | Detections: ${_detections.length}",
                    style: TextStyle(color: Colors.grey.shade600),
                  ),
                ]
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// --- UPDATED PAINTER ---
class BoundingBoxPainter extends CustomPainter {
  final List<Map<String, dynamic>> detections;
  final Size previewSize;
  final Size screenSize;
  final bool isFrontCamera; // Added to handle mirroring

  BoundingBoxPainter({
    required this.detections,
    required this.previewSize,
    required this.screenSize,
    this.isFrontCamera = false,
  });

  @override
  void paint(Canvas canvas, Size size) {
    // We calculate scales based on the FittedBox logic (BoxFit.cover)
    // The camera image (previewSize) is likely rotated 90deg on phones, so we swap width/height logic
    double scaleX = size.width / previewSize.height;
    double scaleY = size.height / previewSize.width;
    
    // Use the larger scale to ensure BoxFit.cover behavior matches the preview
    final double scale = math.max(scaleX, scaleY);

    // Calculate the offset to center the drawing area
    double offsetX = (size.width - (previewSize.height * scale)) / 2;
    double offsetY = (size.height - (previewSize.width * scale)) / 2;

    final Paint paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3.0
      ..color = Colors.green;

    final TextStyle textStyle = TextStyle(
      color: Colors.white,
      fontSize: 16,
      fontWeight: FontWeight.bold,
      backgroundColor: Colors.green,
    );

    for (var detection in detections) {
      final box = detection['box'];
      
      // Standard output from many models: [x1, y1, x2, y2, confidence]
      // Coordinates are usually based on the PreviewSize
      double x1 = box[0] * scale + offsetX;
      double y1 = box[1] * scale + offsetY;
      double x2 = box[2] * scale + offsetX;
      double y2 = box[3] * scale + offsetY;

      // --- FIX: Mirror Front Camera ---
      if (isFrontCamera) {
        // Flip the X coordinates relative to the screen width
        double tempX1 = size.width - x2;
        double tempX2 = size.width - x1;
        x1 = tempX1;
        x2 = tempX2;
      }
      // --------------------------------

      final rect = Rect.fromLTRB(x1, y1, x2, y2);
      canvas.drawRect(rect, paint);

      final String label = "${detection['tag']} ${(detection['box'][4] * 100).toStringAsFixed(0)}%";
      final TextSpan span = TextSpan(text: label, style: textStyle);
      final TextPainter tp = TextPainter(
        text: span,
        textAlign: TextAlign.left,
        textDirection: TextDirection.ltr,
      );
      tp.layout();
      tp.paint(canvas, Offset(x1, y1 - 20));
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) {
    return true;
  }
}