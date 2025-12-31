import 'dart:io';
import 'dart:typed_data';
import 'dart:math';

import 'package:camera/camera.dart';
import 'package:flutter/foundation.dart';
import 'package:tflite_flutter/tflite_flutter.dart';

class ObjectDetector {
  Interpreter? _interpreter;
  bool _isBusy = false;
  int _framesProcessed = 0;
  List<int> _inputShape = [1, 640, 640, 3];
  List<int> _outputShape = [1, 54, 8400]; // 50 Classes + 4 Coordinates
  double _confidenceThreshold = 0.25;
  double _nmsThreshold = 0.45;
  
  // Performance tracking
  Stopwatch _inferenceTimer = Stopwatch();
  double _lastInferenceTime = 0.0;

  // EXACT LIST FROM YOUR SCREENSHOTS (50 Classes)
  final List<String> labels = [
    '1', '2', '3', '4', '5', '6', '7', '8', '9',
    'A', 'B', 'Bread', 'Brother', 'Bus', 'C', 'D', 'Drink',
    'E', 'Eat', 'Elder sister', 'F', 'Father', 'G', 'Help', 'Hotel',
    'How much', 'Hungry', 'I', 'J', 'L', 'Mother', 'N', 'No',
    'O', 'P', 'Q', 'R', 'S', 'Sorry', 'T', 'Thirsty', 'Toilet',
    'U', 'V', 'W', 'Water', 'X', 'Y', 'Yes', 'Z'
  ];

  Future<void> loadModel() async {
    try {
      print("🚀 Loading INT8 model...");
      
      final options = InterpreterOptions();
      
      // Optimize for Android GPU (if available)
      if (Platform.isAndroid) {
        try {
          // Try GPU Delegate
          final gpuDelegate = GpuDelegateV2();
          options.addDelegate(gpuDelegate);
          print("✅ Using GPU acceleration");
        } catch (e) {
          print("⚠️ GPU not available, using CPU with 4 threads");
          options.threads = 4; 
        }
      }
      
      // Load the renamed file
      _interpreter = await Interpreter.fromAsset(
        'assets/models/best_float32.tflite', 
        options: options,
      );
      
      // Get actual shapes from model to confirm
      _inputShape = _interpreter!.getInputTensor(0).shape;
      _outputShape = _interpreter!.getOutputTensor(0).shape;
      
      print("✅ Model Loaded!");
      print("📦 Input: $_inputShape");
      print("📤 Output: $_outputShape (Should be [1, 54, 8400])");
      print("🎯 Classes: ${labels.length}");
      
      // Warm up
      await _warmUpModel();
      
    } catch (e) {
      print("❌ Model Error: $e");
      print("👉 Did you rename 'best_dynamic_range_quant.tflite' to 'best_int8.tflite'?");
    }
  }

  Future<void> _warmUpModel() async {
    try {
      final inputSize = _inputShape.reduce((a, b) => a * b);
      final dummyInput = Float32List(inputSize);
      final outputSize = _outputShape.reduce((a, b) => a * b);
      final dummyOutput = Float32List(outputSize);
      
      _interpreter!.run([dummyInput.reshape(_inputShape)], dummyOutput);
      print("🔥 Model Warmed Up");
    } catch (e) {
      print("⚠️ Warm-up warning: $e");
    }
  }

  Future<String?> detectFromStream(CameraImage image) async {
    if (_interpreter == null || _isBusy) return null;
    
    _isBusy = true;
    _framesProcessed++;

    try {
      // 1. Process Image (YUV -> RGB) in background
      final inputTensor = await compute(_processCameraImage, {
        'image': image,
        'inputHeight': _inputShape[1], // 640
        'inputWidth': _inputShape[2],  // 640
      });
      
      if (inputTensor == null) {
        _isBusy = false;
        return null;
      }

      // 2. Run Inference
      _inferenceTimer.reset();
      _inferenceTimer.start();
      
      // Flatten output array size
      final outputSize = _outputShape.reduce((a, b) => a * b);
      final output = Float32List(outputSize);
      
      _interpreter!.run(inputTensor, output);
      
      _inferenceTimer.stop();
      _lastInferenceTime = _inferenceTimer.elapsedMilliseconds.toDouble();
      
      // 3. Parse Results
      final result = _parseYOLOv8Output(output);
      
      _isBusy = false;
      return result;
      
    } catch (e) {
      print("Error during detection: $e");
      _isBusy = false;
      return null;
    }
  }

  // Isolate function to convert camera YUV to RGB
  static dynamic _processCameraImage(Map<String, dynamic> params) {
    try {
      final CameraImage image = params['image'];
      final int inputHeight = params['inputHeight'];
      final int inputWidth = params['inputWidth'];
      
      if (image.planes.length < 3) return null;
      
      final yBuffer = image.planes[0].bytes;
      final uBuffer = image.planes[1].bytes;
      final vBuffer = image.planes[2].bytes;
      
      final yRowStride = image.planes[0].bytesPerRow;
      final uvRowStride = image.planes[1].bytesPerRow;
      final uvPixelStride = image.planes[1].bytesPerPixel ?? 1;
      
      final input = Float32List(1 * inputHeight * inputWidth * 3);
      int index = 0;
      
      // Scale logic to fit camera image into 640x640
      final scaleX = image.width / inputWidth;
      final scaleY = image.height / inputHeight;
      
      for (int y = 0; y < inputHeight; y++) {
        final srcY = (y * scaleY).toInt();
        if (srcY >= image.height) continue;
        
        for (int x = 0; x < inputWidth; x++) {
          final srcX = (x * scaleX).toInt();
          if (srcX >= image.width) continue;
          
          final yIndex = srcY * yRowStride + srcX;
          final uvIndex = (srcY ~/ 2) * uvRowStride + (srcX ~/ 2) * uvPixelStride;
          
          final yValue = yBuffer[yIndex] & 0xFF;
          final uValue = uBuffer[uvIndex] & 0xFF;
          final vValue = vBuffer[uvIndex] & 0xFF;
          
          // YUV to RGB conversion
          int r = (yValue + ((vValue - 128) * 1436 ~/ 1024)).clamp(0, 255);
          int g = (yValue - ((uValue - 128) * 46549 ~/ 131072) - ((vValue - 128) * 93604 ~/ 131072)).clamp(0, 255);
          int b = (yValue + ((uValue - 128) * 1814 ~/ 1024)).clamp(0, 255);
          
          // Normalize (0.0 to 1.0)
          input[index++] = r / 255.0;
          input[index++] = g / 255.0;
          input[index++] = b / 255.0;
        }
      }
      return [input.reshape([1, inputHeight, inputWidth, 3])];
    } catch (e) {
      return null;
    }
  }

  String? _parseYOLOv8Output(Float32List output) {
    try {
      // output shape is [1, 54, 8400]
      final int numClasses = 50; 
      final int features = numClasses + 4; // 54
      final int numBoxes = 8400; 
      
      List<Detection> detections = [];
      
      for (int box = 0; box < numBoxes; box++) {
        final boxOffset = box * features;
        
        // Find the class with the highest score
        double maxScore = 0.0;
        int bestClass = -1;
        
        // Check ALL 50 classes (starts at index 4)
        for (int c = 0; c < numClasses; c++) {
          final score = output[boxOffset + 4 + c];
          if (score > maxScore) {
            maxScore = score;
            bestClass = c;
          }
        }
        
        if (maxScore > _confidenceThreshold && bestClass != -1) {
          detections.add(Detection(
            classIndex: bestClass,
            confidence: maxScore,
            xCenter: output[boxOffset],
            yCenter: output[boxOffset + 1],
            width: output[boxOffset + 2],
            height: output[boxOffset + 3],
          ));
        }
      }
      
      // Apply NMS (Remove duplicate boxes)
      detections = _applyNMS(detections);
      
      if (detections.isNotEmpty) {
        final top = detections.first;
        if (top.classIndex < labels.length) {
          final label = labels[top.classIndex];
          // Print result every few frames to debug
          if (_framesProcessed % 10 == 0) {
             print("Found: $label (${(top.confidence*100).toInt()}%)");
          }
          return label;
        }
      }
      return null;
      
    } catch (e) {
      print("Parsing Error: $e");
      return null;
    }
  }

  List<Detection> _applyNMS(List<Detection> detections) {
    if (detections.isEmpty) return [];
    
    // Sort by confidence
    detections.sort((a, b) => b.confidence.compareTo(a.confidence));
    
    List<Detection> filtered = [];
    while (detections.isNotEmpty) {
      final best = detections.removeAt(0);
      filtered.add(best);
      
      detections.removeWhere((other) {
        // Calculate Intersection over Union (IoU)
        final x1 = max(best.xCenter - best.width/2, other.xCenter - other.width/2);
        final y1 = max(best.yCenter - best.height/2, other.yCenter - other.height/2);
        final x2 = min(best.xCenter + best.width/2, other.xCenter + other.width/2);
        final y2 = min(best.yCenter + best.height/2, other.yCenter + other.height/2);
        
        final interArea = max(0, x2 - x1) * max(0, y2 - y1);
        final unionArea = (best.width * best.height) + (other.width * other.height) - interArea;
        final iou = interArea / unionArea;
        
        return iou > _nmsThreshold; // Remove if too similar
      });
    }
    return filtered;
  }
  
  // Helpers for UI
  Map<String, dynamic> getPerformanceMetrics() {
    return {
      'fps': _lastInferenceTime > 0 ? (1000 / _lastInferenceTime).toStringAsFixed(1) : "0",
      'inferenceTime': _lastInferenceTime.toStringAsFixed(1),
      'framesProcessed': _framesProcessed,
      'modelType': 'INT8',
    };
  }

  Map<String, dynamic> getModelInfo() {
    return {
      'inputShape': _inputShape,
      'outputShape': _outputShape,
      'totalClasses': labels.length,
      'signClasses': labels.length,
      'modelSize': 'Quantized (INT8)',
    };
  }
  
  void setConfidenceThreshold(double value) => _confidenceThreshold = value;
  void dispose() => _interpreter?.close();
}

class Detection {
  final int classIndex;
  final double confidence;
  final double xCenter, yCenter, width, height;
  Detection({required this.classIndex, required this.confidence, required this.xCenter, required this.yCenter, required this.width, required this.height});
}