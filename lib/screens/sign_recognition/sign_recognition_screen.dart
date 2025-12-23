import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:camera/camera.dart';
// Import your object detector
import '../../services/object_detector.dart'; 

class SignRecognitionScreen extends StatefulWidget {
  final CameraDescription camera;
  final bool isSignToText;

  const SignRecognitionScreen({super.key, required this.camera, this.isSignToText = false});

  @override
  State<SignRecognitionScreen> createState() => _SignRecognitionScreenState();
}

class _SignRecognitionScreenState extends State<SignRecognitionScreen> {
  late CameraController _controller;
  late Future<void> _initializeControllerFuture;
  late bool isSignToText;

  // --- NEW VARIABLES ---
  final ObjectDetector _detector = ObjectDetector();
  bool _isScanning = false;  // Controls the loop
  String _recognizedText = "Press Start"; // Stores result
  // ---------------------

  int selectedCameraIdx = 0;
  double _currentZoom = 1.0;
  double _minZoom = 1.0;
  double _maxZoom = 1.0;

  @override
  void initState() {
    super.initState();
    isSignToText = widget.isSignToText;
    
    // Initialize Camera
    _initializeCamera(widget.camera);
    
    // Initialize AI Model
    _detector.loadModel();
  }
  
  void _initializeCamera(CameraDescription cameraDescription) {
    // Use ImageFormatGroup.nv21 for Qualcomm devices (Oppo/Realme/OnePlus)
    // This fixes the "Invalid format passed: 0x21" error on devices with Adreno GPU
    _controller = CameraController(
      cameraDescription, 
      ResolutionPreset.medium,
      enableAudio: false,
      imageFormatGroup: ImageFormatGroup.nv21, // Critical for Qualcomm devices
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
      // Handle initialization errors gracefully
      debugPrint('Camera initialization error: $error');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Camera error: ${error.toString()}'),
            backgroundColor: Colors.red,
          ),
        );
      }
    });
  }

  // --- NEW FUNCTION: The Loop ---
  void _toggleScanning() async {
    setState(() {
      _isScanning = !_isScanning;
    });

    if (_isScanning) {
      _startDetectionLoop();
    }
  }

  void _startDetectionLoop() async {
    // Keep taking pictures as long as _isScanning is true
    while (_isScanning && mounted) {
      try {
        if (!_controller.value.isInitialized) return;

        // 1. Take a snapshot
        final image = await _controller.takePicture();

        // 2. Run Inference
        final results = await _detector.runInference(image.path);

        // 3. Update UI
        if (mounted) {
          setState(() {
            if (results.isNotEmpty) {
              _recognizedText = "${results[0]['label']} (${results[0]['score']})";
            } else {
              _recognizedText = "No Sign Detected";
            }
          });
        }
        
        // 4. Small delay to prevent freezing the app (approx 2-3 FPS)
        await Future.delayed(const Duration(milliseconds: 100));

      } catch (e) {
        print("Detection Error: $e");
        break; // Stop loop on error
      }
    }
  }

  @override
  void dispose() {
    _isScanning = false; // Stop the loop
    _controller.dispose();
    super.dispose();
  }
  
  // ... (Keep your existing switchCamera code here) ...
  Future<void> _switchCamera() async {
     // ... (Paste your existing _switchCamera logic here)
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
            _isScanning = false; // Stop scanning when leaving
            if (context.canPop()) context.pop();
            else context.go('/home');
          },
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            // ... (Your Existing Top "Switch Mode" Container) ...
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
                  // ... (Switch Widget) ...
                ],
              ),
            ),
            
            const SizedBox(height: 20),

            // --- RECOGNIZED TEXT DISPLAY ---
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

            // Camera Container
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
                    
                    // Detection Overlay Box
                    Center(
                      child: Container(
                        width: 220, height: 220,
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(24),
                          border: Border.all(width: 3, color: _isScanning ? Colors.green : Colors.white.withOpacity(0.7)),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 32),

            // --- UPDATED BUTTON ---
            GestureDetector(
              onTap: _toggleScanning,
              child: Container(
                width: double.infinity,
                height: 56,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(16),
                  gradient: LinearGradient(
                    colors: _isScanning 
                        ? [Colors.red, Colors.redAccent] // Show Red if Stop
                        : [const Color(0xFFF6329A), const Color(0xFF00B8DA)], // Show Color if Start
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