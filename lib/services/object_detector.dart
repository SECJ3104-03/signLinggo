import 'dart:ui';

import 'package:camera/camera.dart';
import 'package:flutter_vision/flutter_vision.dart';

class ObjectDetector {
  late FlutterVision _vision;
  bool _isBusy = false;
  bool _isLoaded = false;

  ObjectDetector() {
    _vision = FlutterVision();
  }

  // Getters
  bool get isLoaded => _isLoaded;
  bool get isBusy => _isBusy;

  Future<void> loadModel({
    String? modelPath,
    String? labelsPath,
    int? numThreads,
    bool? useGpu,
  }) async {
    try {
      await _vision.loadYoloModel(
        modelPath: modelPath ?? 'assets/models/ahmed_best_int8.tflite',
        labels: labelsPath ?? 'assets/models/labels.txt',
        modelVersion: "yolov8",
        numThreads: numThreads ?? 1,
        useGpu: useGpu ?? false,
        quantization: false, // Set to true if using int8 quantized model and it requires this flag
      );
      _isLoaded = true;
      print("Model loaded successfully: ${modelPath ?? 'default'}");
    } catch (e) {
      print("Error loading model: $e");
      _isLoaded = false;
      rethrow; // Allow caller to handle the error
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
        iouThreshold: 0.4, // Adjusted threshold
        confThreshold: 0.4, // Adjusted threshold
        classThreshold: 0.4, // Adjusted threshold
      );
      _isBusy = false;
      return result;
    } catch (e) {
      print("Error running inference: $e");
      _isBusy = false;
      return [];
    }
  }

  Future<void> dispose() async {
    try {
      await _vision.closeYoloModel();
      _isLoaded = false;
    } catch (e) {
      print("Error disposing model: $e");
    }
  }
}