import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:camera/camera.dart';
// Keep your existing ObjectDetector import
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
  late Future<void> _initializeControllerFuture;
  late bool isSignToText;

  // --- AI & Logic Variables ---
  final ObjectDetector _detector = ObjectDetector();
  bool _isScanning = false;
  String _recognizedText = "Press Start"; 
  
  // --- Camera Management Variables ---
  List<CameraDescription> _cameras = []; // Stores all available cameras
  int _selectedCameraIdx = 0; // Tracks which camera is active
  double _currentZoom = 1.0;
  double _minZoom = 1.0;
  double _maxZoom = 1.0;

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
      // Fetch all cameras (Front & Back)
      _cameras = await availableCameras();
      
      // Find the index of the camera passed from the previous screen
      // Default to 0 if not found
      _selectedCameraIdx = _cameras.indexWhere(
        (c) => c.lensDirection == widget.camera.lensDirection
      );
      if (_selectedCameraIdx == -1) _selectedCameraIdx = 0;

      // Initialize the selected camera
      _initializeCamera(_cameras[_selectedCameraIdx]);
    } catch (e) {
      debugPrint("Error fetching cameras: $e");
    }
  }
  
  void _initializeCamera(CameraDescription cameraDescription) {
    // NV21 format is safer for Android/Qualcomm devices
    _controller = CameraController(
      cameraDescription, 
      ResolutionPreset.medium,
      enableAudio: false,
      imageFormatGroup: ImageFormatGroup.nv21, 
    );

    _initializeControllerFuture = _controller.initialize().then((_) async {
      try {
        _minZoom = await _controller.getMinZoomLevel();
        _maxZoom = await _controller.getMaxZoomLevel();
        _currentZoom = _minZoom.clamp(1.0, _maxZoom);
        await _controller.setZoomLevel(_currentZoom);
      } catch (e) {
        debugPrint('Error setting zoom: $e');
      }
      if (mounted) setState(() {});
    }).catchError((error) {
      debugPrint('Camera initialization error: $error');
    });
  }

  // --- FLIP CAMERA LOGIC ---
  Future<void> _onTapSwitchCamera() async {
    if (_cameras.length < 2) return; // Need at least 2 cameras to switch

    // Stop scanning if active
    if (_isScanning) {
      setState(() {
        _isScanning = false; 
      });
    }

    // Calculate new index
    final newIndex = (_selectedCameraIdx + 1) % _cameras.length;
    
    // Dispose old controller
    await _controller.dispose();

    // Initialize new camera
    setState(() {
      _selectedCameraIdx = newIndex;
    });
    _initializeCamera(_cameras[_selectedCameraIdx]);
  }

  // --- SCANNING LOOP ---
  void _toggleScanning() async {
    setState(() {
      _isScanning = !_isScanning;
    });

    if (_isScanning) {
      _startDetectionLoop();
    }
  }

  void _startDetectionLoop() async {
    while (_isScanning && mounted) {
      try {
        if (!_controller.value.isInitialized) return;

        final image = await _controller.takePicture();
        final results = await _detector.runInference(image.path);

        if (mounted) {
          setState(() {
            if (results.isNotEmpty) {
              _recognizedText = "${results[0]['label']} (${results[0]['score']})";
            } else {
              _recognizedText = "No Sign Detected";
            }
          });
        }
        // Small delay to keep UI smooth
        await Future.delayed(const Duration(milliseconds: 100));

      } catch (e) {
        debugPrint("Detection Error: $e");
        break; 
      }
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
            // Mode Switcher Header
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
                  // Add your Switch widget here if needed
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
                    // 1. Camera Feed
                     FutureBuilder<void>(
                      future: _initializeControllerFuture,
                      builder: (context, snapshot) {
                        if (snapshot.connectionState == ConnectionState.done) {
                          return CameraPreview(_controller);
                        } else {
                          return const Center(child: CircularProgressIndicator());
                        }
                      },
                    ),
                    
                    // 2. Overlay Box
                    Center(
                      child: Container(
                        width: 220, height: 220,
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(24),
                          border: Border.all(width: 3, color: _isScanning ? Colors.green : Colors.white.withOpacity(0.7)),
                        ),
                      ),
                    ),

                    // 3. FLIP CAMERA BUTTON
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