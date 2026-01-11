import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:camera/camera.dart';
import 'package:flutter/services.dart';

import '../../services/object_detector.dart';

enum SignMode { alphabets, numbers, words }

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
  late ObjectDetector _detector;
  
  bool _isScanning = false;
  bool _modelLoaded = false;
  List<Map<String, dynamic>> _detections = [];
  SignMode _currentMode = SignMode.alphabets;
  
  // Performance monitoring
  double _fps = 0.0;
  int _frameCount = 0;
  int _lastFrameTime = 0;
  bool _showSettings = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _detector = ObjectDetector();
    _initializeCamera();
    _loadModel();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _controller.dispose();
    _detector.dispose();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (!_controller.value.isInitialized) {
      return;
    }
    if (state == AppLifecycleState.inactive) {
      _controller.dispose();
    } else if (state == AppLifecycleState.resumed) {
      _initializeCamera();
    }
  }

  Future<void> _initializeCamera() async {
    _controller = CameraController(
      widget.camera,
      ResolutionPreset.medium,
      enableAudio: false,
      imageFormatGroup: Platform.isAndroid
          ? ImageFormatGroup.yuv420
          : ImageFormatGroup.bgra8888,
    );

    _initializeControllerFuture = _controller.initialize().then((_) {
      if (!mounted) return;
      setState(() {});
      // Start image stream for detection
      _controller.startImageStream((image) async {
        if (_isScanning && _modelLoaded && !_detector.isBusy) {
          _processFrame(image);
        }
      });
    });
  }

  Future<void> _loadModel() async {
    setState(() {
      _modelLoaded = false;
    });

    String modelPath = "";
    String labelsPath = "";

    switch (_currentMode) {
      case SignMode.alphabets:
        modelPath = "assets/models/ahmed_best_int8.tflite";
        labelsPath = "assets/models/labels.txt";
        break;
      case SignMode.numbers:
        modelPath = "assets/models/numbers_best_int8.tflite";
        labelsPath = "assets/models/numbers_labels.txt";
        break;
      case SignMode.words:
        modelPath = "assets/models/words_best_int8.tflite";
        labelsPath = "assets/models/words_labels.txt";
        break;
    }

    try {
      await _detector.loadModel(modelPath: modelPath, labelsPath: labelsPath);
      setState(() {
        _modelLoaded = true;
      });
    } catch (e) {
      print("Error loading model for $_currentMode: $e");
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Failed to load model: $e")),
        );
      }
    }
  }

  void _processFrame(CameraImage image) async {
    int startTime = DateTime.now().millisecondsSinceEpoch;
    
    final results = await _detector.yoloOnFrame(image);
    
    if (!mounted) return;
    
    setState(() {
      _detections = results;
      
      // Calculate FPS
      _frameCount++;
      int currentTime = DateTime.now().millisecondsSinceEpoch;
      if (currentTime - _lastFrameTime >= 1000) {
        _fps = _frameCount * 1000 / (currentTime - _lastFrameTime);
        _frameCount = 0;
        _lastFrameTime = currentTime;
      }
    });
  }

  void _toggleScanning() {
    setState(() {
      _isScanning = !_isScanning;
      if (!_isScanning) {
        _detections = [];
      }
    });
  }

  void _onTapSwitchCamera() {
    // Implement camera switching logic if needed
    // This usually requires re-initializing the controller with a different camera description
    print("Switch camera not implemented yet");
  }

  void _changeMode(SignMode mode) {
    if (_currentMode != mode) {
      setState(() {
        _currentMode = mode;
        _isScanning = false;
        _detections = [];
      });
      _loadModel();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Sign Recognition"),
        actions: [
          IconButton(
            icon: const Icon(Icons.settings),
            onPressed: () {
              setState(() {
                _showSettings = !_showSettings;
              });
            },
          ),
        ],
      ),
      body: Column(
        children: [
          // 1. Mode Selection & Status
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 5.0),
            child: Column(
              children: [
                // Mode Selector
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: SignMode.values.map((mode) {
                      bool isSelected = _currentMode == mode;
                      return Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 4.0),
                        child: ChoiceChip(
                          label: Text(mode.name.toUpperCase()),
                          selected: isSelected,
                          onSelected: (selected) {
                            if (selected) _changeMode(mode);
                          },
                        ),
                      );
                    }).toList(),
                  ),
                ),
                const SizedBox(height: 8),
                // Status Indicator
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  decoration: BoxDecoration(
                    color: _modelLoaded ? Colors.green.shade50 : Colors.red.shade50,
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: _modelLoaded ? Colors.green : Colors.red),
                  ),
                  child: Text(
                    _modelLoaded ? "Ready: ${_currentMode.name.toUpperCase()}" : "Loading Model...",
                    style: TextStyle(
                        color: _modelLoaded ? Colors.green.shade800 : Colors.red.shade800,
                        fontWeight: FontWeight.bold),
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 10),

          // 2. Camera View
          Expanded(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Container(
                width: double.infinity,
                decoration: BoxDecoration(
                  color: Colors.black,
                  borderRadius: BorderRadius.circular(20),
                  boxShadow: const [
                    BoxShadow(color: Colors.black26, blurRadius: 10, offset: Offset(0, 5))
                  ],
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(20),
                  child: Stack(
                    fit: StackFit.expand,
                    children: [
                      _initializeControllerFuture == null
                          ? const Center(child: CircularProgressIndicator())
                          : CameraPreview(_controller),

                      if (_isScanning && _detections.isNotEmpty)
                        CustomPaint(
                          painter: BoundingBoxPainter(
                            detections: _detections,
                            previewSize: _controller.value.previewSize!,
                          ),
                        ),

                      Positioned(
                        bottom: 15,
                        right: 15,
                        child: FloatingActionButton.small(
                          heroTag: "switch_camera",
                          backgroundColor: Colors.white24,
                          onPressed: _onTapSwitchCamera,
                          child: const Icon(Icons.flip_camera_ios, color: Colors.white),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),

          const SizedBox(height: 20),

          // 3. Start/Stop Button
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
            child: GestureDetector(
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
          ),

          if (_showSettings) ...[
            Text(
              "FPS: ${_fps.toStringAsFixed(1)} | Detections: ${_detections.length}",
              style: TextStyle(color: Colors.grey.shade600),
            ),
            const SizedBox(height: 10),
          ]
        ],
      ),
    );
  }
}

class BoundingBoxPainter extends CustomPainter {
  final List<Map<String, dynamic>> detections;
  final Size previewSize;

  BoundingBoxPainter({
    required this.detections,
    required this.previewSize,
  });

  @override
  void paint(Canvas canvas, Size size) {
    // Calculate scaling factors
    // Camera preview is usually rotated 90 degrees on phones, so we might need to swap width/height
    // or adjust based on aspect ratio. For now, assuming standard scaling.
    final double scaleX = size.width / previewSize.height; // Swapped for portrait mode usually
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
      
      // Bounding box coordinates from YOLO are usually [x1, y1, x2, y2]
      // We need to scale them to the screen size
      final double x1 = box[0] * scaleX;
      final double y1 = box[1] * scaleY;
      final double x2 = box[2] * scaleX;
      final double y2 = box[3] * scaleY;

      final rect = Rect.fromLTRB(x1, y1, x2, y2);
      canvas.drawRect(rect, paint);

      final String label =
          "${detection['tag']} ${(detection['box'][4] * 100).toStringAsFixed(0)}%";
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