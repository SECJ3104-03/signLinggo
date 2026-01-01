import 'dart:ui';

import 'package:camera/camera.dart';
import 'package:flutter/services.dart';
import 'package:flutter_vision/flutter_vision.dart';

class ObjectDetector {
  late FlutterVision _vision;
  bool _isBusy = false;
  List<Map<String, dynamic>> _yoloResults = [];
  bool _isLoaded = false;

  // Getters
  bool get isLoaded => _isLoaded;
  bool get isBusy => _isBusy;
  List<Map<String, dynamic>> get results => _yoloResults;

  ObjectDetector() {
    _vision = FlutterVision();
  }

  Future<void> loadModel() async {
    try {
      await _vision.loadYoloModel(
        modelPath: 'assets/models/ahmed_best_int8.tflite',
        labels: 'assets/labels.txt',
        modelVersion: "yolov8",
        quantization: true, // Critical for Int8 models
        numThreads: 2,
        useGpu: true,
      );
      _isLoaded = true;
      print("✅ YOLOv8 Model Loaded Successfully");
    } catch (e) {
      print("❌ Error loading model: $e");
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
        iouThreshold: 0.4,
        confThreshold: 0.4,
        classThreshold: 0.4,
      );
      _yoloResults = result;
      _isBusy = false;
      return result;
    } catch (e) {
      print("Error running inference: $e");
      _isBusy = false;
      return [];
    }
  }

  void dispose() async {
    await _vision.closeYoloModel();
  }
}