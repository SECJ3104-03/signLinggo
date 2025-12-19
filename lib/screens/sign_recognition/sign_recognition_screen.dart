import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:camera/camera.dart';

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

  int selectedCameraIdx = 0;


  @override
  void initState() {
    super.initState();
    _initializeCamera(widget.camera);
    isSignToText = widget.isSignToText;
  }
  
  void _initializeCamera(CameraDescription cameraDescription) {
    _controller = CameraController(cameraDescription, ResolutionPreset.medium);

    _initializeControllerFuture = _controller.initialize().then((_) async {
      if (mounted) setState(() {});
    }).catchError((error) {
      debugPrint('SignRecognitionScreen: Camera initialization error: $error');
      if (mounted) {
        setState(() {});
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              error is CameraException
                  ? 'Camera error: ${error.description ?? error.code}'
                  : 'Failed to initialize camera: ${error.toString()}',
            ),
            duration: const Duration(seconds: 5),
            action: SnackBarAction(
              label: 'Retry',
              onPressed: () {
                _initializeCamera(cameraDescription);
              },
            ),
          ),
        );
      }
    });
  }

  Future<void> _switchCamera() async {
    try {
      final availableCamerasList = await availableCameras();
      if (availableCamerasList.isEmpty) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('No other cameras available'),
              duration: Duration(seconds: 2),
            ),
          );
        }
        return;
      }

      selectedCameraIdx = (selectedCameraIdx + 1) % availableCamerasList.length;
      final newCamera = availableCamerasList[selectedCameraIdx];

      await _controller.dispose();
      _initializeCamera(newCamera);
    } catch (e) {
      debugPrint('SignRecognitionScreen: Error switching camera: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to switch camera: ${e.toString()}'),
            duration: const Duration(seconds: 3),
          ),
        );
      }
    }
  }

  @override
  void dispose() {
    _controller.dispose().catchError((error) {
      debugPrint('SignRecognitionScreen: Error disposing camera: $error');
    });
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final double width = MediaQuery.of(context).size.width;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Sign Recognition', style: TextStyle(color: Colors.black, fontFamily: 'Arimo',),),
        centerTitle: true,
        backgroundColor: Colors.white,
        elevation: 1,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.black),
          onPressed: () {
            if (context.canPop()) {
              context.pop();
            } else {
              context.go('/home');
            }
          },
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
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
                    style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w600, color: Colors.white,),
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
                        onChanged: (value) async {
                          setState(() => isSignToText = value);

                          if (value) {
                            await _controller.dispose();
                            context.go('/text-to-sign');
                          }
                        },
                      ),
                    ],
                  ),
                ],
              ),
            ),

            const SizedBox(height: 20),

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
                          if (snapshot.hasError) {
                            return Center(
                              child: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  const Icon(
                                    Icons.error_outline,
                                    size: 48,
                                    color: Colors.red,
                                  ),
                                  const SizedBox(height: 16),
                                  Text(
                                    snapshot.error is CameraException
                                        ? 'Camera error: ${(snapshot.error as CameraException).description ?? (snapshot.error as CameraException).code}'
                                        : 'Failed to initialize camera',
                                    textAlign: TextAlign.center,
                                    style: const TextStyle(color: Colors.red),
                                  ),
                                  const SizedBox(height: 16),
                                  ElevatedButton(
                                    onPressed: () {
                                      _initializeCamera(widget.camera);
                                    },
                                    child: const Text('Retry'),
                                  ),
                                ],
                              ),
                            );
                          }
                          if (_controller.value.isInitialized) {
                            return CameraPreview(_controller);
                          } else {
                            return const Center(
                              child: CircularProgressIndicator(),
                            );
                          }
                        } else if (snapshot.connectionState == ConnectionState.waiting) {
                          return const Center(
                            child: CircularProgressIndicator(),
                          );
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