import 'dart:async';
import 'dart:io';
import 'package:speech_to_text/speech_to_text.dart' as stt;
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:camera/camera.dart';
import 'package:flutter/services.dart';

import '../../services/object_detector.dart'; // Ensure this path matches your project

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
  List<Map<String, dynamic>> _detections = [];
  String _currentDetectedSign = "Waiting for sign...";

  // Filtering Logic
  String _selectedCategory = 'Alphabets';
  final List<String> _numberLabels = ['1', '2', '3', '4', '5', '6', '7', '8', '9'];
  final List<String> _wordLabels = [
    'Bread', 'Brother', 'Bus', 'Drink', 'Eat', 'Elder sister',
    'Father', 'Help', 'Hotel', 'How much', 'Hungry', 'Mother',
    'No', 'Sorry', 'Thirsty', 'Toilet', 'Water', 'Yes'
  ];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _initializeModel();
    _initializeSpeech(); // Initialize Speech Engine
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _stopCamera(); 
    _detector.dispose();
    _textController.dispose();
    super.dispose();
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
          // Keep cursor at end
          _textController.selection = TextSelection.fromPosition(
            TextPosition(offset: _textController.text.length),
          );
        });
      },
    );
  }

  void _stopListening() async {
    if (_speech != null) {
      await _speech!.stop();
    }
    if (mounted) {
      setState(() => _isListening = false);
    }
  }

  // --- AI LOGIC ---
  Future<void> _initializeModel() async {
    await _detector.loadModel();
    if (mounted) setState(() => _modelLoaded = _detector.isLoaded);
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
      ResolutionPreset.high,
      enableAudio: false,
      imageFormatGroup: Platform.isAndroid ? ImageFormatGroup.yuv420 : ImageFormatGroup.bgra8888,
    );

    await _cameraController!.initialize();
    if (!mounted) return;

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
        _processCameraFrame(image);
      });
    } catch (e) {
      print("Stream Error: $e");
    }
  }

  void _processCameraFrame(CameraImage image) async {
    if (_detector.isBusy) return;

    final results = await _detector.yoloOnFrame(image);
    List<Map<String, dynamic>> filteredResults = [];

    // --- FILTERING LOGIC ---
    if (_selectedCategory == 'Alphabets') {
      filteredResults = results.where((result) {
        String tag = result['tag'].toString().trim();
        bool isNumber = _numberLabels.any((l) => l.toLowerCase() == tag.toLowerCase());
        bool isWord = _wordLabels.any((l) => l.toLowerCase() == tag.toLowerCase());
        return !isNumber && !isWord;
      }).toList();
    } else if (_selectedCategory == 'Numbers') {
      filteredResults = results.where((result) {
        String tag = result['tag'].toString().trim();
        return _numberLabels.any((l) => l.toLowerCase() == tag.toLowerCase());
      }).toList();
    } else if (_selectedCategory == 'Words') {
      filteredResults = results.where((result) {
        String tag = result['tag'].toString().trim();
        return _wordLabels.any((l) => l.toLowerCase() == tag.toLowerCase());
      }).toList();
    }

    if (mounted && isSignToText) {
      setState(() {
        _detections = filteredResults;
        if (filteredResults.isNotEmpty) {
           _currentDetectedSign = filteredResults.first['tag'];
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
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
          
          // --- CONTROLS ROW ---
          Row(
            children: [
              // HOLD TO SPEAK BUTTON
              Expanded(
                child: GestureDetector(
                  onLongPressStart: (_) => _startListening(),
                  onLongPressEnd: (_) => _stopListening(),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    padding: const EdgeInsets.symmetric(vertical: 20),
                    decoration: BoxDecoration(
                      // Red when listening, White (outlined) when idle
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
              
              // TRANSLATE BUTTON
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
          
          // TRANSLATION RESULT
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
                  const SizedBox(height: 8),
                  Text(_translatedText, style: const TextStyle(fontSize: 16, color: Color(0xFF101727))),
                  // Placeholder for Avatar
                  const SizedBox(height: 20),
                  Center(
                    child: Container(
                      height: 150,
                      width: 150,
                      color: Colors.grey[300],
                      child: const Center(child: Text("[Avatar Placeholder]")),
                    ),
                  )
                ],
              ),
            ),
        ],
      ),
    );
  }

  // --- VIEW B: CAMERA MODE ---
  Widget _buildSignToTextMode() {
    if (_cameraController == null || !_cameraController!.value.isInitialized) {
      return const Center(child: CircularProgressIndicator());
    }

    return Column(
      children: [
        // Category Selector (Alphabets/Numbers/Words)
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
                    if (selected) setState(() => _selectedCategory = category);
                  },
                  selectedColor: const Color(0xFF00B8DA),
                  labelStyle: TextStyle(color: isSelected ? Colors.white : Colors.black),
                ),
              );
            }).toList(),
          ),
        ),

        // Camera Preview
        Expanded(
          child: Container(
            margin: const EdgeInsets.symmetric(horizontal: 16),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: Colors.black12),
              boxShadow: const [BoxShadow(color: Colors.black26, blurRadius: 10)],
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(20),
              child: Stack(
                fit: StackFit.expand,
                children: [
                  CameraPreview(_cameraController!),
                  CustomPaint(
                    painter: BoundingBoxPainter(
                      detections: _detections,
                      previewSize: _cameraController!.value.previewSize!,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),

        // Detection Result Display
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

// Painter class remains the same
class BoundingBoxPainter extends CustomPainter {
  final List<Map<String, dynamic>> detections;
  final Size previewSize;

  BoundingBoxPainter({required this.detections, required this.previewSize});

  @override
  void paint(Canvas canvas, Size size) {
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