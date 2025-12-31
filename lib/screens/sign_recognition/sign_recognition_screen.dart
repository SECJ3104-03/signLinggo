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
  String _recognizedText = "Ready";
  String _confidenceLevel = "";
  
  // Performance tracking
  Stopwatch _fpsTimer = Stopwatch();
  int _frameCounter = 0;
  double _fps = 0.0;
  double _inferenceTime = 0.0;
  int _totalDetections = 0;
  Timer? _performanceTimer;
  
  // UI state
  bool _showSettings = false;
  double _confidenceThreshold = 0.5;
  bool _showDebugInfo = false;

  List<CameraDescription> _cameras = [];
  int _selectedCameraIdx = 0;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    
    // Lock to portrait
    SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]);
    
    isSignToText = widget.isSignToText;
    
    // Load production model
    _initializeModel();
    
    // Setup cameras
    _setupCameras();
    _fpsTimer.start();
    
    // Performance logging
    _performanceTimer = Timer.periodic(Duration(seconds: 5), (_) {
      if (_isScanning && mounted) {
        final metrics = _detector.getPerformanceMetrics();
        print("📊 Performance: ${metrics['fps']} FPS, "
              "Inference: ${metrics['inferenceTime']}ms, "
              "Detections: $_totalDetections");
      }
    });
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.paused) {
      _stopScanning();
    } else if (state == AppLifecycleState.resumed && _controller != null) {
      if (_isScanning) {
        _startStreaming();
      }
    }
  }

  void _initializeModel() async {
    try {
      await _detector.loadModel();
      _detector.setConfidenceThreshold(_confidenceThreshold);
      
      if (mounted) {
        setState(() {
          _recognizedText = "Model Loaded ✓";
        });
      }
    } catch (e) {
      print("❌ Model initialization failed: $e");
      if (mounted) {
        setState(() {
          _recognizedText = "Model Error";
        });
      }
      _showErrorDialog("Model Error", 
          "Failed to load AI model. Please check:\n\n"
          "1. Model file exists: assets/models/best_float32.tflite\n"
          "2. Model exported with simplify=True\n"
          "3. File size ~10-30MB\n\n"
          "Error: $e");
    }
  }

  Future<void> _setupCameras() async {
    try {
      _cameras = await availableCameras();
      
      // Prefer back camera
      _selectedCameraIdx = _cameras.indexWhere(
        (c) => c.lensDirection == CameraLensDirection.back,
      );
      if (_selectedCameraIdx == -1) _selectedCameraIdx = 0;

      _initializeCamera(_cameras[_selectedCameraIdx]);
    } catch (e) {
      print("❌ Camera setup error: $e");
    }
  }
  
  void _initializeCamera(CameraDescription cameraDescription) {
    _controller = CameraController(
      cameraDescription,
      ResolutionPreset.medium, // Good balance for detection
      enableAudio: false,
      imageFormatGroup: Platform.isAndroid 
        ? ImageFormatGroup.yuv420
        : ImageFormatGroup.bgra8888,
    );

    final future = _controller.initialize().then((_) async {
      try {
        await _controller.setFocusMode(FocusMode.auto);
        
        if (mounted) setState(() {});
      } catch (e) {
        print("⚠️ Camera optimization error: $e");
      }
    }).catchError((e) {
      print("❌ Camera initialization failed: $e");
    });

    setState(() {
      _initializeControllerFuture = future;
    });
  }

  Future<void> _onTapSwitchCamera() async {
    if (_cameras.length < 2) return;

    if (_isScanning) {
      await _stopScanning();
    }

    final newIndex = (_selectedCameraIdx + 1) % _cameras.length;
    await _controller.dispose();

    setState(() {
      _selectedCameraIdx = newIndex;
      _initializeControllerFuture = null;
    });
    
    _initializeCamera(_cameras[_selectedCameraIdx]);
  }

  void _toggleScanning() async {
    if (_isScanning) {
      await _stopScanning();
    } else {
      await _startScanning();
    }
  }

  Future<void> _startScanning() async {
    if (!_controller.value.isInitialized) {
      print("❌ Camera not ready");
      return;
    }
    
    setState(() {
      _isScanning = true;
      _recognizedText = "Detecting...";
      _frameCounter = 0;
      _fpsTimer.reset();
      _totalDetections = 0;
    });
    
    await _startStreaming();
  }

  Future<void> _startStreaming() async {
    try {
      await _controller.startImageStream((CameraImage image) {
        _processCameraFrame(image);
      });
    } catch (e) {
      print("❌ Error starting stream: $e");
    }
  }

  void _processCameraFrame(CameraImage image) async {
    // Calculate FPS
    _frameCounter++;
    if (_fpsTimer.elapsedMilliseconds > 1000) {
      _fps = _frameCounter / (_fpsTimer.elapsedMilliseconds / 1000);
      _frameCounter = 0;
      _fpsTimer.reset();
      
      if (mounted) {
        setState(() {});
      }
    }
    
    // Process detection
    final String? result = await _detector.detectFromStream(image);
    
    if (result != null && result.isNotEmpty && mounted && _isScanning) {
      _totalDetections++;
      
      // Update UI
      if (mounted) {
        setState(() {
          _recognizedText = result;
          _confidenceLevel = "High Confidence";
        });
      }
    } else if (_isScanning && mounted) {
      // Update every few seconds when no detection
      if (_frameCounter % 60 == 0) {
        setState(() {
          _recognizedText = "Show your hand";
          _confidenceLevel = "";
        });
      }
    }
  }

  Future<void> _stopScanning() async {
    if (_controller.value.isStreamingImages) {
      try {
        await _controller.stopImageStream();
      } catch (e) {
        print("⚠️ Error stopping stream: $e");
      }
    }
    
    if (mounted) {
      setState(() {
        _isScanning = false;
        _recognizedText = "Ready";
        _confidenceLevel = "";
      });
    }
  }

  void _toggleSettings() {
    setState(() {
      _showSettings = !_showSettings;
    });
  }

  void _updateConfidenceThreshold(double value) {
    setState(() {
      _confidenceThreshold = value;
    });
    _detector.setConfidenceThreshold(value);
  }

  void _toggleDebugInfo() {
    setState(() {
      _showDebugInfo = !_showDebugInfo;
    });
  }

  void _showErrorDialog(String title, String message) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(title),
        content: Text(message),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text("OK"),
          ),
        ],
      ),
    );
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _stopScanning();
    _performanceTimer?.cancel();
    _controller.dispose();
    SystemChrome.setPreferredOrientations([
      DeviceOrientation.landscapeRight,
      DeviceOrientation.landscapeLeft,
      DeviceOrientation.portraitUp,
      DeviceOrientation.portraitDown,
    ]);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final double width = MediaQuery.of(context).size.width;
    final bool isPortrait = MediaQuery.of(context).orientation == Orientation.portrait;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Sign Recognition',
            style: TextStyle(color: Colors.black, fontFamily: 'Arimo')),
        centerTitle: true,
        backgroundColor: Colors.white,
        elevation: 1,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.black),
          onPressed: () {
            _stopScanning();
            if (context.canPop()) context.pop();
            else context.go('/home');
          },
        ),
        actions: [
          IconButton(
            icon: Icon(_showSettings ? Icons.settings : Icons.settings_outlined,
                color: Colors.black),
            onPressed: _toggleSettings,
            tooltip: 'Settings',
          ),
          IconButton(
            icon: Icon(_showDebugInfo ? Icons.info : Icons.info_outline,
                color: Colors.black),
            onPressed: _toggleDebugInfo,
            tooltip: 'Debug Info',
          ),
        ],
      ),
      body: Stack(
        children: [
          // Main content
          SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: Column(
              children: [
                // Mode indicator
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(16),
                    gradient: const LinearGradient(
                        colors: [Color(0xFFAC46FF), Color(0xFF8B2EFF)]),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(isSignToText ? 'Text → Sign' : 'Sign → Text',
                          style: const TextStyle(fontSize: 18, color: Colors.white)),
                      Row(
                        children: [
                          Container(
                            width: 10,
                            height: 10,
                            decoration: BoxDecoration(
                              color: _isScanning ? Colors.green : Colors.red,
                              shape: BoxShape.circle,
                            ),
                          ),
                          const SizedBox(width: 8),
                          Text(
                            _isScanning ? 'LIVE' : 'READY',
                            style: const TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 20),

                // Result display
                Container(
                  padding: const EdgeInsets.all(20),
                  width: double.infinity,
                  decoration: BoxDecoration(
                    color: Colors.purple.shade50,
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: Colors.purple.shade200),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.purple.withOpacity(0.1),
                        blurRadius: 15,
                        offset: const Offset(0, 5),
                      ),
                    ],
                  ),
                  child: Column(
                    children: [
                      const Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.handshake, color: Colors.purple, size: 24),
                          SizedBox(width: 10),
                          Text("DETECTED SIGN",
                              style: TextStyle(
                                  color: Colors.purple,
                                  fontWeight: FontWeight.w700,
                                  fontSize: 16)),
                        ],
                      ),
                      const SizedBox(height: 15),
                      AnimatedSwitcher(
                        duration: const Duration(milliseconds: 300),
                        child: Text(
                          _recognizedText,
                          key: ValueKey(_recognizedText),
                          style: const TextStyle(
                              fontSize: 36,
                              fontWeight: FontWeight.bold,
                              color: Colors.purple),
                          textAlign: TextAlign.center,
                        ),
                      ),
                      if (_confidenceLevel.isNotEmpty) ...[
                        const SizedBox(height: 10),
                        Text(
                          _confidenceLevel,
                          style: TextStyle(
                            color: Colors.purple.shade600,
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                      if (_showDebugInfo) ...[
                        const SizedBox(height: 15),
                        Divider(color: Colors.purple.shade200),
                        const SizedBox(height: 10),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceAround,
                          children: [
                            _buildMetricItem("FPS", "${_fps.toStringAsFixed(1)}"),
                            _buildMetricItem("Detections", "$_totalDetections"),
                            _buildMetricItem("Confidence", "${(_confidenceThreshold * 100).toInt()}%"),
                          ],
                        ),
                      ],
                    ],
                  ),
                ),
                const SizedBox(height: 20),

                // Camera preview
                Container(
                  width: width,
                  height: isPortrait ? 400 : 300,
                  decoration: BoxDecoration(
                    color: Colors.black,
                    borderRadius: BorderRadius.circular(20),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.3),
                        blurRadius: 15,
                        offset: const Offset(0, 8),
                      ),
                    ],
                  ),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(20),
                    child: Stack(
                      fit: StackFit.expand,
                      children: [
                        _initializeControllerFuture == null
                            ? const Center(
                                child: CircularProgressIndicator(
                                  color: Colors.white,
                                ),
                              )
                            : FutureBuilder<void>(
                                future: _initializeControllerFuture,
                                builder: (context, snapshot) {
                                  if (snapshot.connectionState ==
                                      ConnectionState.done &&
                                      !snapshot.hasError) {
                                    return SizedBox.expand(
                                      child: FittedBox(
                                        fit: BoxFit.cover,
                                        child: SizedBox(
                                          width: _controller
                                              .value.previewSize!.height,
                                          height: _controller
                                              .value.previewSize!.width,
                                          child: CameraPreview(_controller),
                                        ),
                                      ),
                                    );
                                  }
                                  return const Center(
                                      child: CircularProgressIndicator(
                                    color: Colors.white,
                                  ));
                                },
                              ),
                        
                        // Detection overlay
                        Center(
                          child: Container(
                            width: 240,
                            height: 240,
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(24),
                              border: Border.all(
                                width: 3,
                                color: _isScanning
                                    ? Colors.green
                                    : Colors.white.withOpacity(0.3),
                              ),
                              boxShadow: _isScanning
                                  ? [
                                      BoxShadow(
                                        color: Colors.green.withOpacity(0.3),
                                        blurRadius: 15,
                                        spreadRadius: 3,
                                      ),
                                    ]
                                  : null,
                            ),
                          ),
                        ),
                        
                        // Camera flip button
                        Positioned(
                          bottom: 20,
                          right: 20,
                          child: FloatingActionButton(
                            heroTag: "flip_btn",
                            backgroundColor: Colors.black.withOpacity(0.7),
                            onPressed: _onTapSwitchCamera,
                            child: const Icon(Icons.flip_camera_ios,
                                color: Colors.white, size: 28),
                          ),
                        ),
                        
                        // Status indicator
                        Positioned(
                          top: 20,
                          right: 20,
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 12, vertical: 8),
                            decoration: BoxDecoration(
                              color: Colors.black.withOpacity(0.7),
                              borderRadius: BorderRadius.circular(20),
                            ),
                            child: Row(
                              children: [
                                Container(
                                  width: 8,
                                  height: 8,
                                  decoration: BoxDecoration(
                                    color: _isScanning ? Colors.green : Colors.red,
                                    shape: BoxShape.circle,
                                  ),
                                ),
                                const SizedBox(width: 6),
                                Text(
                                  _isScanning ? 'DETECTING' : 'IDLE',
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 12,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 32),

                // Start/Stop button
                GestureDetector(
                  onTap: _toggleScanning,
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 300),
                    width: double.infinity,
                    height: 64,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(16),
                      gradient: LinearGradient(
                        colors: _isScanning
                            ? [Colors.red, Colors.redAccent]
                            : [const Color(0xFF00B8DA), const Color(0xFFF6329A)],
                        begin: Alignment.centerLeft,
                        end: Alignment.centerRight,
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: (_isScanning ? Colors.red : const Color(0xFF00B8DA))
                              .withOpacity(0.4),
                          blurRadius: 12,
                          offset: const Offset(0, 6),
                        ),
                      ],
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(_isScanning ? Icons.stop_circle : Icons.play_circle_filled, 
                             color: Colors.white, size: 32),
                        const SizedBox(width: 12),
                        Text(
                          _isScanning ? 'STOP RECOGNITION' : 'START RECOGNITION',
                          style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.w800,
                            fontSize: 20,
                            letterSpacing: 0.5,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 20),

                // Instructions
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.blue.shade50,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: Colors.blue.shade200),
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.lightbulb_outline,
                          color: Colors.blue.shade700, size: 24),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Tips for Best Results:',
                              style: TextStyle(
                                color: Colors.blue.shade800,
                                fontWeight: FontWeight.bold,
                                fontSize: 15,
                              ),
                            ),
                            const SizedBox(height: 6),
                            Text(
                              '• Place hand inside the frame\n'
                              '• Good lighting (face light source)\n'
                              '• Make clear, distinct signs\n'
                              '• Hold for 1-2 seconds\n'
                              '• Keep background simple',
                              style: TextStyle(
                                color: Colors.blue.shade700,
                                fontSize: 14,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 40), // Extra space for settings panel
              ],
            ),
          ),

          // Settings panel (slides up)
          if (_showSettings) ...[
            Positioned(
              bottom: 0,
              left: 0,
              right: 0,
              child: Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: const BorderRadius.only(
                    topLeft: Radius.circular(20),
                    topRight: Radius.circular(20),
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.2),
                      blurRadius: 20,
                      offset: const Offset(0, -5),
                    ),
                  ],
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text(
                          'Detection Settings',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        IconButton(
                          icon: const Icon(Icons.close),
                          onPressed: _toggleSettings,
                        ),
                      ],
                    ),
                    const SizedBox(height: 20),
                    
                    Text(
                      'Confidence Threshold: ${(_confidenceThreshold * 100).toInt()}%',
                      style: const TextStyle(
                        fontWeight: FontWeight.w600,
                        fontSize: 16,
                      ),
                    ),
                    const SizedBox(height: 10),
                    Slider(
                      value: _confidenceThreshold,
                      min: 0.1,
                      max: 0.9,
                      divisions: 8,
                      label: (_confidenceThreshold * 100).toInt().toString(),
                      onChanged: _updateConfidenceThreshold,
                      activeColor: Colors.purple,
                      inactiveColor: Colors.purple.shade200,
                    ),
                    const SizedBox(height: 20),
                    
                    const Text(
                      'Lower = More detections (but may be wrong)\n'
                      'Higher = Fewer detections (more accurate)',
                      style: TextStyle(
                        color: Colors.grey,
                        fontSize: 14,
                      ),
                    ),
                    const SizedBox(height: 20),
                    
                    ElevatedButton.icon(
                      onPressed: () {
                        _detector.setConfidenceThreshold(0.5);
                        _updateConfidenceThreshold(0.5);
                      },
                      icon: const Icon(Icons.restart_alt),
                      label: const Text('Reset to Default'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.purple,
                        minimumSize: const Size(double.infinity, 50),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildMetricItem(String label, String value) {
    return Column(
      children: [
        Text(
          value,
          style: const TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
            color: Colors.purple,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          label,
          style: const TextStyle(
            fontSize: 12,
            color: Colors.grey,
          ),
        ),
      ],
    );
  }
}