import 'package:camera/camera.dart';
import 'package:flutter_vision/flutter_vision.dart';

class ObjectDetector {
  late FlutterVision _vision;
  bool _isBusy = false;
  bool _isLoaded = false;
  String? _currentModelPath;

  ObjectDetector() {
    _vision = FlutterVision();
  }

  bool get isLoaded => _isLoaded;
  bool get isBusy => _isBusy;

  Future<void> loadModel({
    String? modelPath,
    String? labelsPath,
    bool isQuantized = false, // <--- NEW PARAMETER (Default to false for Float32)
  }) async {
    final path = modelPath ?? 'assets/models/ahmed_best_int8.tflite';
    
    // 1. If the SAME model is already loaded, do nothing
    if (_isLoaded && _currentModelPath == path) return;

    // 2. If a DIFFERENT model is loaded, close it first
    if (_isLoaded) {
      await dispose();
    }

    try {
      await _vision.loadYoloModel(
        modelPath: path,
        labels: labelsPath ?? 'assets/models/labels.txt',
        modelVersion: "yolov8",
        quantization: isQuantized, // <--- USES THE PARAMETER NOW
        numThreads: 4,
        useGpu: true,
      );

      _isLoaded = true;
      _currentModelPath = path;
      print("✅ Loaded Model: $path | Quantized: $isQuantized");
    } catch (e) {
      print("❌ Error loading model: $e");
      _isLoaded = false;
    }
  }

  Future<List<Map<String, dynamic>>> yoloOnFrame(CameraImage cameraImage) async {
    if (!_isLoaded || _isBusy) return [];

    _isBusy = true;
    try {
      final result = await _vision.yoloOnFrame(
        bytesList: cameraImage.planes.map((plane) => plane.bytes).toList(),
        imageHeight: cameraImage.height,
        imageWidth: cameraImage.width,
        iouThreshold: 0.1, // Reset to standard (0.25) now that you have Float32
        confThreshold: 0.1,
        classThreshold: 0.1,
      );
      _isBusy = false;
      return result;
    } catch (e) {
      _isBusy = false;
      return [];
    }
  }

  Future<void> dispose() async {
    try {
      await _vision.closeYoloModel();
      _isLoaded = false;
      _currentModelPath = null;
      print("Model closed");
    } catch (e) {
      print("Error disposing model: $e");
    }
  }
}