import 'dart:async';
import 'dart:io';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:camera/camera.dart';
import 'package:flutter/services.dart';

// Ensure this path matches your project structure
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
  bool _isSwitching = false; // Flag to prevent race conditions during model switch

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
    SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]);
    
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
    if (!_controller.value.isInitialized) return;
    
    if (state == AppLifecycleState.inactive) {
      _controller.dispose();
    } else if (state == AppLifecycleState.resumed) {
      _initializeCamera();
    }
  }

  Future<void> _initializeCamera() async {
    _controller = CameraController(
      widget.camera,
      ResolutionPreset.high,
      enableAudio: false,
      imageFormatGroup: Platform.isAndroid
          ? ImageFormatGroup.yuv420
          : ImageFormatGroup.bgra8888,
    );

    _initializeControllerFuture = _controller.initialize().then((_) async {
      if (!mounted) return;
      await _controller.setFocusMode(FocusMode.auto); // Fix for blurry camera
      setState(() {});
      
      _controller.startImageStream((image) async {
        if (_isScanning && _modelLoaded && !_detector.isBusy) {
          _processFrame(image);
        }
      });
    });
  }

  Future<void> _loadModel() async {
      if (mounted) setState(() => _modelLoaded = false);

      String modelPath = "";
      String labelsPath = "";
      bool isQuantized = false;

      // Select Model based on Mode
      switch (_currentMode) {
        case SignMode.alphabets:
          modelPath = "assets/models/ahmed_best_int8.tflite"; 
          labelsPath = "assets/models/labels.txt";
          isQuantized = true; 
          break;
        case SignMode.numbers:
          modelPath = "assets/models/numbers2_best_int8.tflite";
          labelsPath = "assets/models/numbers_labels.txt";
          isQuantized = true;
          break;
        case SignMode.words:
          modelPath = "assets/models/words_best_float32.tflite";
          labelsPath = "assets/models/words_labels.txt";
          isQuantized = false;
          break;
      }

      try {
        await _detector.loadModel(
          modelPath: modelPath,
          labelsPath: labelsPath,
          isQuantized: isQuantized
        );
        
        if (mounted) {
          setState(() {
            _modelLoaded = true;
            _detections = [];
          });
        }
      } catch (e) {
        print("Failure loading model: $e");
      }
    }

  void _processFrame(CameraImage image) async {
    if (_isSwitching || !_modelLoaded) return;

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

  Future<void> _changeMode(SignMode mode) async {
    if (_currentMode == mode || _isSwitching) return;

    setState(() {
      _isSwitching = true;
      _currentMode = mode;
      _isScanning = false;
      _detections = [];
    });

    if (_controller.value.isStreamingImages) {
      await _controller.stopImageStream();
    }

    await _loadModel();

    if (!_controller.value.isStreamingImages) {
      await _controller.startImageStream((image) async {
        if (_isScanning && _modelLoaded && !_detector.isBusy) {
           _processFrame(image);
        }
      });
    }

    if (mounted) {
      setState(() => _isSwitching = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    // 1. Get Screen Size and Camera Size
    final size = MediaQuery.of(context).size;
    final previewSize = _controller.value.previewSize ?? const Size(1280, 720);

    // 2. Calculate Scaling Factor for "Aspect Fill"
    // This ensures the camera covers the width of the screen without distortion.
    // If the math results in a scale < 1, we invert it to ensure we always zoom IN (cover), not out.
    var scale = size.aspectRatio * previewSize.aspectRatio;
    if (scale < 1) scale = 1 / scale;

    return Scaffold(
      appBar: AppBar(
        title: const Text("Sign Recognition"),
        centerTitle: true,
        actions: [
          IconButton(
            icon: const Icon(Icons.settings),
            onPressed: () => setState(() => _showSettings = !_showSettings),
          ),
        ],
      ),
      body: SingleChildScrollView(
        child: Column(
          children: [
            // --- Mode Selection ---
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 5.0),
              child: Column(
                children: [
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
                            selectedColor: const Color(0xFF00B8DA),
                            labelStyle: TextStyle(
                              color: isSelected ? Colors.white : Colors.black,
                              fontWeight: FontWeight.bold
                            ),
                            onSelected: (selected) {
                              if (selected) _changeMode(mode);
                            },
                          ),
                        );
                      }).toList(),
                    ),
                  ),
                  const SizedBox(height: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    decoration: BoxDecoration(
                      color: _modelLoaded ? Colors.green.shade50 : Colors.red.shade50,
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: _modelLoaded ? Colors.green : Colors.red),
                    ),
                    child: Text(
                      _isSwitching
                          ? "Switching Model..."
                          : (_modelLoaded ? "Ready: ${_currentMode.name.toUpperCase()}" : "Loading Model..."),
                      style: TextStyle(
                          color: _modelLoaded ? Colors.green.shade800 : Colors.red.shade800,
                          fontWeight: FontWeight.bold),
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 10),

            // --- TRIMMED CAMERA VIEW (Fixed Height) ---
            SizedBox(
              height: size.height * 0.55, // 55% of Screen Height
              width: double.infinity,
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(20),
                  child: Container(
                    color: Colors.black,
                    child: Stack(
                      fit: StackFit.expand,
                      alignment: Alignment.center, 
                      children: [
                        if (_initializeControllerFuture == null)
                          const Center(child: CircularProgressIndicator())
                        else
                          // Scale the camera to fill the width (Trim top/bottom)
                          Transform.scale(
                            scale: scale, 
                            child: Center(
                              child: CameraPreview(_controller),
                            ),
                          ),

                        if (_isScanning && _detections.isNotEmpty && !_isSwitching)
                           // Apply EXACT SAME scale to bounding boxes so they match
                           Transform.scale(
                            scale: scale,
                            child: CustomPaint(
                              painter: BoundingBoxPainter(
                                detections: _detections,
                                previewSize: _controller.value.previewSize!,
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
                ),
              ),
            ),

            const SizedBox(height: 30),

            // --- Start/Stop Button ---
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
      ),
    );
  }
}

// --- PAINTER CLASS (No changes needed here, logic is handled by Transform.scale above) ---
class BoundingBoxPainter extends CustomPainter {
  final List<Map<String, dynamic>> detections;
  final Size previewSize;

  BoundingBoxPainter({
    required this.detections,
    required this.previewSize,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final double scaleX = size.width / previewSize.height;
    final double scaleY = size.height / previewSize.width;

    final Paint paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3.0
      ..color = Colors.green;

    final TextStyle textStyle = const TextStyle(
      color: Colors.white,
      fontSize: 16,
      fontWeight: FontWeight.bold,
      backgroundColor: Colors.green,
    );

    for (var detection in detections) {
      final box = detection['box'];
      final double x1 = box[0] * scaleX;
      final double y1 = box[1] * scaleY;
      final double x2 = box[2] * scaleX;
      final double y2 = box[3] * scaleY;

      final rect = Rect.fromLTRB(x1, y1, x2, y2);
      canvas.drawRect(rect, paint);
      
      String tag = detection['tag'] ?? "Unknown";
      String conf = ((detection['box'][4] ?? 0.0) * 100).toStringAsFixed(0);

      final String label = "$tag $conf%";
      final TextSpan span = TextSpan(text: label, style: textStyle);
      final TextPainter tp = TextPainter(
        text: span,
        textAlign: TextAlign.left,
        textDirection: TextDirection.ltr,
      );
      tp.layout();
      tp.paint(canvas, Offset(x1, y1 - 22));
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) {
    return true;
  }
}