import 'package:flutter/material.dart';
import 'package:camera/camera.dart';

class SignRecognitionScreen extends StatefulWidget {
  final CameraDescription camera;

  const SignRecognitionScreen({super.key, required this.camera});

  @override
  State<SignRecognitionScreen> createState() => _SignRecognitionScreenState();
}

class _SignRecognitionScreenState extends State<SignRecognitionScreen> {
  late CameraController _controller;
  late Future<void> _initializeControllerFuture;

  int selectedCameraIdx = 0;
  double _currentZoom = 1.0;
  double _minZoom = 1.0;
  double _maxZoom = 1.0;

  bool isSignToText = false;

  @override
  void initState() {
    super.initState();
    _initializeCamera(widget.camera);
  }
  
  void _initializeCamera(CameraDescription cameraDescription) {
    _controller = CameraController(cameraDescription, ResolutionPreset.medium);
    _initializeControllerFuture = _controller.initialize();

    _initializeControllerFuture = _controller.initialize().then((_) async {
      try {
        _minZoom = await _controller.getMinZoomLevel();
        _maxZoom = await _controller.getMaxZoomLevel();
        _currentZoom = _minZoom.clamp(1.0, _maxZoom);
        await _controller.setZoomLevel(_currentZoom);
      } catch (e) {
        _minZoom = 1.0;
        _maxZoom = 1.0;
        _currentZoom = 1.0;
      }

      if (mounted) {
        setState(() {});
      }
    });
  }

  Future<void> _switchCamera() async {
    final availableCamerasList = await availableCameras();
    if (availableCamerasList.isEmpty) return;

    selectedCameraIdx = (selectedCameraIdx + 1) % availableCamerasList.length;
    final newCamera = availableCamerasList[selectedCameraIdx];

    await _controller.dispose();
    _initializeCamera(newCamera);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final double width = MediaQuery.of(context).size.width;

    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Sign Recognition',
          style: TextStyle(
            color: Colors.black,
            fontFamily: 'Arimo',
          ),
        ),
        centerTitle: true,
        backgroundColor: Colors.white,
        elevation: 1,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.black),
          onPressed: () {
            Navigator.pop(context);
          },
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            //Top Row: "Sign → Text" and Switch Mode
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(16),
                gradient: const LinearGradient(
                  colors: [Color(0xFFAC46FF), Color(0xFF8B2EFF)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    isSignToText ? 'Text → Sign' : 'Sign → Text',
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w600,
                      color: Colors.white,
                    ),
                  ),
                  Row(
                    children: [
                      const Text(
                        'Switch Mode',
                        style: TextStyle(
                          color: Colors.white70,
                          fontSize: 16,
                          fontFamily: 'Arimo',
                        ),
                      ),
                      const SizedBox(width: 8),
                      Switch(
                        value: isSignToText,
                        activeThumbColor: Colors.white,
                        inactiveThumbColor: Colors.white,
                        activeTrackColor: Colors.grey[400],
                        inactiveTrackColor: Colors.grey[400],
                        onChanged: (value) {
                          setState(() {
                            isSignToText = value;
                          });
                        },
                      ),
                    ],
                  ),
                ],
              ),
            ),

            const SizedBox(height: 20),

            //Camera container
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
                    //Camera Preview
                    FutureBuilder<void>(
                      future: _initializeControllerFuture,
                      builder: (context, snapshot) {
                        if (snapshot.connectionState == ConnectionState.done) {
                          return CameraPreview(_controller);
                        } else {
                          return const Center(
                            child: CircularProgressIndicator(),
                          );
                        }
                      },
                    ),

                    //Detection box overlay
                    Center(
                      child: Container(
                        width: 220,
                        height: 220,
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(24),
                          border: Border.all(
                            width: 3,
                            color: Colors.white.withValues(alpha: 0.7),
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: const Color(0xFFAC46FF)
                                  .withValues(alpha: 0.3),
                              blurRadius: 10,
                              spreadRadius: 1,
                            ),
                          ],
                        ),
                      ),
                    ),
                    
                    // Zoom and Flip buttons
                    Positioned(
                      top: 16,
                      right: 16,
                      child: Column(
                        children: [
                          // Zoom in button
                          FloatingActionButton(
                            heroTag: 'zoom',
                            mini: true,
                            backgroundColor: Colors.black45,
                            onPressed: () async {
                              if (!_controller.value.isInitialized) return;

                              const double step = 0.5;
                              final double newZoom = (_currentZoom + step).clamp(_minZoom, _maxZoom);

                              try {
                                await _controller.setZoomLevel(newZoom);
                                _currentZoom = newZoom;
                                setState(() {});
                              } catch (e) {
                                debugPrint('Zoom failed: $e');
                              }
                            },
                            child: const Icon(Icons.zoom_in, color: Colors.white),
                          ),
                          const SizedBox(height: 12),

                          // Flip camera button
                          FloatingActionButton(
                            heroTag: 'flip',
                            mini: true,
                            backgroundColor: Colors.black45,
                            onPressed: _switchCamera,
                            child: const Icon(Icons.flip_camera_ios, color: Colors.white),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 32),

            //Start Recognition Button
            GestureDetector(
              onTap: () {
                // TODO: Add recognition start logic
              },
              child: Container(
                width: double.infinity,
                height: 56,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(16),
                  gradient: const LinearGradient(
                    colors: [
                      Color(0xFFF6329A),
                      Color(0xFF00B8DA),
                    ],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                ),
                child: const Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.camera_alt_outlined, color: Colors.white),
                    SizedBox(width: 8),
                    Text(
                      'Start Recognition',
                      style: TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w600,
                        fontSize: 16,
                      ),
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