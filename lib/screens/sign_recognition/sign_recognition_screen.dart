import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:camera/camera.dart';
import 'package:flutter/services.dart';

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
  
  // Performance tracking
  int _frameCounter = 0;
  double _fps = 0.0;
  Timer? _fpsTimer;
  
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
    
    // 1. Setup Camera & Model
    _initializeModel();
    _setupCameras();
    
    // 2. Start FPS Timer (Updates every 1 second)
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
    if (state == AppLifecycleState.paused) {
      _stopScanning();
    } else if (state == AppLifecycleState.resumed && _controller.value.isInitialized) {
      if (_isScanning) _startStreaming();
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
      _selectedCameraIdx = _cameras.indexWhere((c) => c.lensDirection == CameraLensDirection.back);
      if (_selectedCameraIdx == -1) _selectedCameraIdx = 0;
      _initializeCamera(_cameras[_selectedCameraIdx]);
    } catch (e) {
      print("Camera Error: $e");
    }
  }
  
  void _initializeCamera(CameraDescription cameraDescription) {
    _controller = CameraController(
      cameraDescription,
      ResolutionPreset.high, // Adjust as needed
      enableAudio: false,
      imageFormatGroup: Platform.isAndroid ? ImageFormatGroup.yuv420 : ImageFormatGroup.bgra8888,
    );

    _initializeControllerFuture = _controller.initialize().then((_) {
      if (mounted) setState(() {});
    });
  }

  Future<void> _onTapSwitchCamera() async {
    if (_cameras.length < 2) return;
    if (_isScanning) await _stopScanning();

    final newIndex = (_selectedCameraIdx + 1) % _cameras.length;
    await _controller.dispose();
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

    _frameCounter++;
    
    // Run Detection
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
                      fontWeight: FontWeight.bold
                    ),
                  ),
                ),
                const SizedBox(height: 20),

                // 2. Camera View
                Container(
                  height: 500, // Increased height for better view
                  width: width,
                  decoration: BoxDecoration(
                    color: Colors.black,
                    borderRadius: BorderRadius.circular(20),
                    boxShadow: [BoxShadow(color: Colors.black26, blurRadius: 10, offset: Offset(0, 5))],
                  ),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(20),
                    child: Stack(
                      fit: StackFit.expand,
                      children: [
                        _initializeControllerFuture == null
                          ? const Center(child: CircularProgressIndicator())
                          : CameraPreview(_controller),
                        
                        // Bounding Boxes Overlay
                        if (_isScanning && _detections.isNotEmpty)
                          CustomPaint(
                            painter: BoundingBoxPainter(
                              detections: _detections,
                              previewSize: _controller.value.previewSize!,
                              screenSize: Size(width, 500), // Match container size
                            ),
                          ),
                        
                        // Flip Button
                        Positioned(
                          bottom: 15, right: 15,
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
                          color: _isScanning ? Colors.red.withOpacity(0.4) : Colors.pink.withOpacity(0.4),
                          blurRadius: 10, offset: const Offset(0, 5)
                        )
                      ],
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(_isScanning ? Icons.stop : Icons.play_arrow, color: Colors.white, size: 30),
                        const SizedBox(width: 10),
                        Text(
                          _isScanning ? "STOP SCANNING" : "START SCANNING",
                          style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold),
                        ),
                      ],
                    ),
                  ),
                ),
                
                // Debug Info
                if (_showSettings) ...[
                   const SizedBox(height: 20),
                   Text("FPS: ${_fps.toStringAsFixed(1)} | Detections: ${_detections.length}", 
                     style: TextStyle(color: Colors.grey.shade600)
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

class BoundingBoxPainter extends CustomPainter {
  final List<Map<String, dynamic>> detections;
  final Size previewSize;
  final Size screenSize;

  BoundingBoxPainter({
    required this.detections,
    required this.previewSize,
    required this.screenSize,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final double scaleX = size.width / previewSize.height; // Swap because of rotation
    final double scaleY = size.height / previewSize.width;

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
      // flutter_vision returns [x1, y1, x2, y2, class_confidence]
      // or similar depending on the model output, but usually it's normalized or pixel coords.
      // Assuming flutter_vision returns pixel coordinates relative to the image size.
      
      // Check flutter_vision documentation or standard output. 
      // Usually it's [x1, y1, x2, y2, confidence]
      
      final double x1 = box[0] * scaleX;
      final double y1 = box[1] * scaleY;
      final double x2 = box[2] * scaleX;
      final double y2 = box[3] * scaleY;

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