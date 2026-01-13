import 'dart:async';
import 'dart:io';
import 'dart:math' as math; 
import 'package:speech_to_text/speech_to_text.dart' as stt;
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:camera/camera.dart';
import 'package:flutter/services.dart';

import '../../services/object_detector.dart'; 

class TextTranslationScreen extends StatefulWidget {
  const TextTranslationScreen({super.key});

  @override
  State<TextTranslationScreen> createState() => _TextTranslationScreenState();
}

class _TextTranslationScreenState extends State<TextTranslationScreen> with WidgetsBindingObserver {
  // --- UI STATE ---
  final TextEditingController _textController = TextEditingController();
  String _translatedText = '';
  bool isSignToText = false; // false = Text→Sign, true = Sign→Text

  // ===== Voice Mode Variables =====
  stt.SpeechToText? _speech;
  bool _isListening = false;
  String _voiceText = '';

  // --- CAMERA & AI STATE ---
  CameraController? _cameraController;
  final ObjectDetector _detector = ObjectDetector();
  bool _isScanning = false;
  bool _modelLoaded = false;
  bool _isSwitching = false; // Prevent crashes while switching models
  List<Map<String, dynamic>> _detections = [];
  String _currentDetectedSign = "Waiting...";

  // Categories
  String _selectedCategory = 'Alphabets';
  
  // Mapping for Text-to-Sign (Image Display)
  final List<String> _wordLabels = [
    'Bread', 'Brother', 'Bus', 'Drink', 'Eat', 'Elder sister',
    'Father', 'Help', 'Hotel', 'How much', 'Hungry', 'Mother',
    'No', 'Sorry', 'Thirsty', 'Toilet', 'Water', 'Yes'
  ];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    // Initialize Speech
    _initializeSpeech();
    // Pre-load default model (Alphabets)
    _loadSpecificModel('Alphabets');
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _stopCamera(); 
    _detector.dispose();
    _textController.dispose();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (_cameraController == null || !_cameraController!.value.isInitialized) return;
    if (state == AppLifecycleState.inactive) {
      _stopCamera();
    } else if (state == AppLifecycleState.resumed && isSignToText) {
      _startCamera();
    }
  }

  // --- SPEECH LOGIC ---
  Future<void> _initializeSpeech() async {
    _speech = stt.SpeechToText();
    try {
      await _speech!.initialize();
    } catch (e) {
      debugPrint("Speech init error: $e");
    }
  }

  void _startListening() async {
    if (_speech == null || !_speech!.isAvailable) {
      debugPrint("Speech recognition not available");
      return;
    }
    setState(() {
      _isListening = true;
      _voiceText = '';
    });
    await _speech!.listen(
      onResult: (result) {
        setState(() {
          _voiceText = result.recognizedWords;
          _textController.text = _voiceText;
          _textController.selection = TextSelection.fromPosition(
            TextPosition(offset: _textController.text.length),
          );
        });
      },
    );
  }

  void _stopListening() async {
    if (_speech != null) await _speech!.stop();
    if (mounted) setState(() => _isListening = false);
  }

  // --- AI MODEL MANAGEMENT ---
  Future<void> _loadSpecificModel(String category) async {
    setState(() {
      _isSwitching = true;
      _modelLoaded = false;
    });

    String modelPath = "";
    String labelsPath = "";
    bool isQuantized = false;

    // EXACT same logic as your SignRecognitionScreen
    switch (category) {
      case 'Alphabets':
        modelPath = "assets/models/ahmed_best_int8.tflite"; 
        labelsPath = "assets/models/labels.txt";
        isQuantized = true; 
        break;
      case 'Numbers':
        modelPath = "assets/models/numbers2_best_int8.tflite";
        labelsPath = "assets/models/numbers_labels.txt";
        isQuantized = true;
        break;
      case 'Words':
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
          _isSwitching = false;
          _selectedCategory = category;
        });
      }
    } catch (e) {
      print("Error loading model: $e");
    }
  }

  Future<void> _changeCategory(String category) async {
    if (_selectedCategory == category || _isSwitching) return;
    
    // Stop stream temporarily
    if (_cameraController != null && _cameraController!.value.isStreamingImages) {
      await _cameraController!.stopImageStream();
    }

    await _loadSpecificModel(category);

    // Restart stream if we are in camera mode
    if (isSignToText && _cameraController != null) {
       _startStreaming();
    }
  }

  // --- CAMERA LIFECYCLE ---
  Future<void> _startCamera() async {
    final cameras = await availableCameras();
    if (cameras.isEmpty) return;

    final camera = cameras.firstWhere(
      (c) => c.lensDirection == CameraLensDirection.back,
      orElse: () => cameras.first,
    );

    _cameraController = CameraController(
      camera,
      ResolutionPreset.medium, // Medium for better compatibility
      enableAudio: false,
    );

    await _cameraController!.initialize();
    if (!mounted) return;
    
    // Auto Focus fix
    await _cameraController!.setFocusMode(FocusMode.auto);

    setState(() {}); 
    _startStreaming();
  }

  Future<void> _stopCamera() async {
    if (_cameraController != null) {
      if (_cameraController!.value.isStreamingImages) {
        await _cameraController!.stopImageStream();
      }
      await _cameraController!.dispose();
      _cameraController = null;
    }
  }

  Future<void> _startStreaming() async {
    if (_cameraController == null || !_cameraController!.value.isInitialized) return;

    setState(() => _isScanning = true);

    try {
      await _cameraController!.startImageStream((CameraImage image) {
        if (_modelLoaded && !_detector.isBusy && !_isSwitching) {
           _processCameraFrame(image);
        }
      });
    } catch (e) {
      print("Stream Error: $e");
    }
  }

  void _processCameraFrame(CameraImage image) async {
    final results = await _detector.yoloOnFrame(image);

    if (mounted && isSignToText) {
      setState(() {
        _detections = results;
        if (results.isNotEmpty) {
           // Get the tag with highest confidence
           var best = results.first;
           // Format confidence
           String conf = ((best['box'][4] ?? 0.0) * 100).toStringAsFixed(0);
           _currentDetectedSign = "${best['tag']} ($conf%)";
        } else {
           _currentDetectedSign = "Scanning...";
        }
      });
    }
  }

  // --- TEXT TRANSLATION LOGIC ---
  void _translateText() {
    setState(() {
      _translatedText = _textController.text.isEmpty
          ? 'Please enter text first.'
          : '(Sign translation of "${_textController.text}")';
    });
  }

  List<String> _getAssetPaths(String input) {
    if (input.trim().isEmpty) return [];

    String word = input.trim().toLowerCase();

    if (RegExp(r'^\d+$').hasMatch(word)) {
      if (word == "10") return ['assets/assets/sign_images/numbers/10.png'];
      return word.split('').map((digit) => 'assets/assets/sign_images/numbers/$digit.png').toList();
    }

    if (word.length == 1 && RegExp(r'[a-zA-Z]').hasMatch(word)) {
      return ['assets/assets/sign_images/alphabets/${word.toUpperCase()}.png'];
    }

    bool isKnownWord = _wordLabels.any((w) => w.toLowerCase() == word.toLowerCase());
    if (isKnownWord) {
      String fileName = _wordLabels.firstWhere((w) => w.toLowerCase() == word.toLowerCase());
      return ['assets/assets/sign_images/words/$fileName.png'];
    }

    return [];
  }

  Widget _buildDisplayImage() {
    final List<String> paths = _getAssetPaths(_textController.text);

    if (paths.isEmpty) {
      return _buildPlaceholder();
    }

    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: paths.map((path) {
        return Expanded(
          child: Padding(
            padding: const EdgeInsets.all(8.0),
            child: Image.asset(
              path,
              fit: BoxFit.contain,
              errorBuilder: (context, error, stackTrace) => _buildPlaceholder(),
            ),
          ),
        );
      }).toList(),
    );
  }

  Widget _buildPlaceholder() {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Icon(Icons.sign_language, size: 80, color: Colors.grey[300]),
        const SizedBox(height: 10),
        const Text(
          "No sign found for this input",
          style: TextStyle(color: Colors.grey, fontSize: 14),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      resizeToAvoidBottomInset: false, // Prevents keyboard from squashing UI
      appBar: AppBar(
        title: const Text('Translator', style: TextStyle(color: Colors.black, fontFamily: 'Arimo')),
        centerTitle: true,
        backgroundColor: Colors.white,
        elevation: 1,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.black),
          onPressed: () {
            if (context.canPop()) context.pop();
            else context.go('/home');
          },
        ),
      ),
      body: SafeArea(
        child: Column(
          children: [
            // --- 1. MODE SWITCHER ---
            Padding(
              padding: const EdgeInsets.all(16.0),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(16),
                  gradient: const LinearGradient(
                    colors: [Color(0xFFAC46FF), Color(0xFF8B2EFF)],
                  ),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      isSignToText ? 'Sign → Text' : 'Text → Sign',
                      style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w600, color: Colors.white),
                    ),
                    Row(
                      children: [
                        const Text('Switch Mode', style: TextStyle(color: Colors.white70, fontSize: 14)),
                        const SizedBox(width: 8),
                        Switch(
                          value: isSignToText,
                          activeThumbColor: Colors.white,
                          activeTrackColor: Colors.grey[400],
                          onChanged: (value) async {
                            setState(() => isSignToText = value);
                            if (value) {
                              await _startCamera(); 
                            } else {
                              await _stopCamera(); 
                            }
                          },
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),

            // --- 2. MAIN CONTENT AREA ---
            Expanded(
              child: isSignToText 
                  ? _buildSignToTextMode() 
                  : _buildTextToSignMode(), 
            ),
          ],
        ),
      ),
    );
  }

  // --- VIEW A: TEXT INPUT MODE (With Voice) ---
  Widget _buildTextToSignMode() {
    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Column(
        children: [
          const SizedBox(height: 20),
          TextField(
            controller: _textController,
            maxLines: 4,
            decoration: InputDecoration(
              hintText: _isListening ? 'Listening...' : 'Type or hold mic to speak...',
              filled: true,
              fillColor: const Color(0xFFF9FAFB),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(16),
                borderSide: const BorderSide(color: Color(0xFFE5E7EB)),
              ),
            ),
          ),
          
          const SizedBox(height: 24),
          
          Row(
            children: [
              Expanded(
                child: GestureDetector(
                  onLongPressStart: (_) => _startListening(),
                  onLongPressEnd: (_) => _stopListening(),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    padding: const EdgeInsets.symmetric(vertical: 20),
                    decoration: BoxDecoration(
                      color: _isListening ? Colors.redAccent : Colors.white,
                      border: Border.all(
                        color: _isListening ? Colors.redAccent : Colors.grey,
                      ),
                      borderRadius: BorderRadius.circular(16),
                      boxShadow: _isListening
                          ? [BoxShadow(color: Colors.red.withOpacity(0.4), blurRadius: 10, spreadRadius: 2)]
                          : [],
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          _isListening ? Icons.mic : Icons.mic_none, 
                          color: _isListening ? Colors.white : Colors.black87
                        ),
                        const SizedBox(width: 8),
                        Text(
                          _isListening ? 'Listening...' : 'Hold to Speak',
                          style: TextStyle(
                            color: _isListening ? Colors.white : Colors.black,
                            fontWeight: FontWeight.bold
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              
              const SizedBox(width: 12),
              
              Expanded(
                child: ElevatedButton(
                  onPressed: _translateText,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF2563EB),
                    padding: const EdgeInsets.symmetric(vertical: 20),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                  ),
                  child: const Text('Translate', style: TextStyle(color: Colors.white)),
                ),
              ),
            ],
          ),
          
          const SizedBox(height: 24),
          
          if (_translatedText.isNotEmpty)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: const Color(0xFFEFF6FF),
                border: Border.all(color: const Color(0xFFBDDAFF)),
                borderRadius: BorderRadius.circular(14),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text("TRANSLATION:", style: TextStyle(fontSize: 12, color: Colors.grey, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 20),
                  Center(
                    child: Container(
                      height: 220,
                      width: double.infinity,
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: _buildDisplayImage()
                    ),
                  )
                ],
              ),
            ),
        ],
      ),
    );
  }

  // --- VIEW B: CAMERA MODE (Fixed: No Stretching, Correct Box Alignment) ---
  Widget _buildSignToTextMode() {
    if (_cameraController == null || !_cameraController!.value.isInitialized) {
      return const Center(child: CircularProgressIndicator());
    }

    return Column(
      children: [
        // Category Selector
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
                  selectedColor: const Color(0xFF00B8DA),
                  labelStyle: TextStyle(
                    color: isSelected ? Colors.white : Colors.black, 
                    fontWeight: FontWeight.bold
                  ),
                  onSelected: (bool selected) {
                    if (selected) _changeCategory(category);
                  },
                ),
              );
            }).toList(),
          ),
        ),

        // Camera Preview (Trimmed & Aspect Ratio Preserved)
        Expanded(
          child: Container(
            margin: const EdgeInsets.symmetric(horizontal: 16),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(20),
              child: Container(
                color: Colors.black,
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                      // 1. Camera Preview (FittedBox covers space without stretch)
                      FittedBox(
                        fit: BoxFit.cover,
                        child: SizedBox(
                          width: _cameraController!.value.previewSize!.height, // Swap for portrait
                          height: _cameraController!.value.previewSize!.width,
                          child: CameraPreview(_cameraController!),
                        ),
                      ),
                      
                      // 2. Bounding Boxes (Matched exactly to the FittedBox)
                      if (_detections.isNotEmpty && !_isSwitching)
                        FittedBox(
                          fit: BoxFit.cover,
                          child: SizedBox(
                            width: _cameraController!.value.previewSize!.height,
                            height: _cameraController!.value.previewSize!.width,
                            child: CustomPaint(
                              painter: BoundingBoxPainter(
                                detections: _detections,
                                previewSize: _cameraController!.value.previewSize!,
                              ),
                            ),
                          ),
                        ),

                      if (_isSwitching)
                        Container(
                          color: Colors.black54,
                          child: const Center(child: Text("Switching Model...", style: TextStyle(color: Colors.white))),
                        )
                  ],
                ),
              ),
            ),
          ),
        ),

        // Result Display
        Container(
          width: double.infinity,
          margin: const EdgeInsets.all(16),
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: const Color(0xFFEFF6FF),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: const Color(0xFFBDDAFF)),
          ),
          child: Column(
            children: [
              const Text("DETECTED SIGN:", style: TextStyle(color: Colors.grey, fontSize: 12)),
              const SizedBox(height: 5),
              Text(
                _currentDetectedSign,
                style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: Color(0xFF2563EB)),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

// Painter class 
class BoundingBoxPainter extends CustomPainter {
  final List<Map<String, dynamic>> detections;
  final Size previewSize;

  BoundingBoxPainter({required this.detections, required this.previewSize});

  @override
  void paint(Canvas canvas, Size size) {
    // Because we swapped width/height in the SizedBox for Portrait mode,
    // we use previewSize.height for width calculation and previewSize.width for height.
    final double scaleX = size.width / previewSize.height;
    final double scaleY = size.height / previewSize.width;

    final Paint paint = Paint()..style = PaintingStyle.stroke..strokeWidth = 3.0..color = Colors.green;

    for (var detection in detections) {
      final box = detection['box'];
      final rect = Rect.fromLTRB(
        box[0] * scaleX, box[1] * scaleY,
        box[2] * scaleX, box[3] * scaleY,
      );
      canvas.drawRect(rect, paint);
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}
