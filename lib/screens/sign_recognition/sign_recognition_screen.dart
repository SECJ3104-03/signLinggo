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

  // --- NEW: Category State ---
  String _selectedCategory = 'Alphabets'; // Default selection

  // 1. Exact matches for your numbers (from your labels.txt)
  final List<String> _numberLabels = [
    '1', '2', '3', '4', '5', '6', '7', '8', '9'
  ];

  // 2. Exact matches for your words (from your labels.txt)
  final List<String> _wordLabels = [
    'Bread', 'Brother', 'Bus', 'Drink', 'Eat', 'Elder sister',
    'Father', 'Help', 'Hotel', 'How much', 'Hungry', 'Mother',
    'No', 'Sorry', 'Thirsty', 'Toilet', 'Water', 'Yes'
  ];
  // ---------------------------

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

    _initializeModel();
    _setupCameras();

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
    } else if (state == AppLifecycleState.resumed &&
        _controller.value.isInitialized) {
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
      _selectedCameraIdx =
          _cameras.indexWhere((c) => c.lensDirection == CameraLensDirection.back);
      if (_selectedCameraIdx == -1) _selectedCameraIdx = 0;
      _initializeCamera(_cameras[_selectedCameraIdx]);
    } catch (e) {
      print("Camera Error: $e");
    }
  }

  void _initializeCamera(CameraDescription cameraDescription) {
    _controller = CameraController(
      cameraDescription,
      ResolutionPreset.high,
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

  // --- MODIFIED: Filtering Logic ---
void _processCameraFrame(CameraImage image) async {
    if (_detector.isBusy) return;

    _frameCounter++;
    final results = await _detector.yoloOnFrame(image);

    // --- DEBUG LOGGING --- 
    // This prints exactly what the model sees to your bottom console
    for (var result in results) {
      print("AI DETECTED: '${result['tag']}'"); 
    }
    // ---------------------

    List<Map<String, dynamic>> filteredResults = [];

    if (_selectedCategory == 'Alphabets') {
      filteredResults = results.where((result) {
        String tag = result['tag'].toString().trim(); // Remove spaces
        
        // Check if it's a Number
        bool isNumber = _numberLabels.any((label) => label.toLowerCase() == tag.toLowerCase());
        // Check if it's a Word
        bool isWord = _wordLabels.any((label) => label.toLowerCase() == tag.toLowerCase());

        // Show ONLY if it is NOT a number AND NOT a word
        return !isNumber && !isWord;
      }).toList();

    } else if (_selectedCategory == 'Numbers') {
      filteredResults = results.where((result) {
        String tag = result['tag'].toString().trim();
        // Smart Check: Ignore case and spaces
        return _numberLabels.any((label) => label.toLowerCase() == tag.toLowerCase());
      }).toList();

    } else if (_selectedCategory == 'Words') {
      filteredResults = results.where((result) {
        String tag = result['tag'].toString().trim();
        // Smart Check: Ignore case and spaces
        return _wordLabels.any((label) => label.toLowerCase() == tag.toLowerCase());
      }).toList();
    }

    if (mounted && _isScanning) {
      setState(() {
        _detections = filteredResults;
      });
    }
  }
  // -------------------------------

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
      body: SafeArea(
        child: Column(
          children: [
            // --- NEW: Category Selector ---
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              child: Row(
                children: ['Alphabets', 'Numbers', 'Words'].map((category) {
                  final isSelected = _selectedCategory == category;
                  return Padding(
                    padding: const EdgeInsets.only(right: 8.0),
                    child: ChoiceChip(
                      label: Text(category),
                      selected: isSelected,
                      onSelected: (bool selected) {
                        if (selected) {
                          setState(() {
                            _selectedCategory = category;
                          });
                        }
                      },
                      // Colors match your Start/Stop gradient blue
                      selectedColor: const Color(0xFF00B8DA),
                      backgroundColor: Colors.grey.shade200,
                      labelStyle: TextStyle(
                        color: isSelected ? Colors.white : Colors.black,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  );
                }).toList(),
              ),
            ),
            // -----------------------------

            // 1. Status Chip
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 5.0),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                decoration: BoxDecoration(
                  color: _modelLoaded ? Colors.green.shade50 : Colors.red.shade50,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: _modelLoaded ? Colors.green : Colors.red),
                ),
                child: Text(
                  _modelLoaded ? "Ready: $_selectedCategory" : "Loading Model...",
                  style: TextStyle(
                      color: _modelLoaded ? Colors.green.shade800 : Colors.red.shade800,
                      fontWeight: FontWeight.bold),
                ),
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
                    boxShadow: [
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
    final double scaleX = size.width / previewSize.height;
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