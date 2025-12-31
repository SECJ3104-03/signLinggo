import 'dart:io';
import 'dart:typed_data';
import 'dart:isolate';
import 'dart:math';

import 'package:camera/camera.dart';
import 'package:flutter/foundation.dart';
import 'package:tflite_flutter/tflite_flutter.dart';

class ObjectDetector {
  Interpreter? _interpreter;
  bool _isBusy = false;
  int _framesProcessed = 0;
  List<int> _inputShape = [1, 640, 640, 3];
  List<int> _outputShape = [1, 54, 8400]; // CORRECTED: [1, 4+50, 8400] from your export
  double _confidenceThreshold = 0.5;
  double _nmsThreshold = 0.45;
  
  // Performance tracking
  Stopwatch _inferenceTimer = Stopwatch();
  double _lastInferenceTime = 0.0;

  // CORRECTED: 50 classes to match the model output
  // Based on your training output, the model expects 50 classes
  // If you only have 18 sign classes, the model was trained with extra classes
  // You need to check your actual dataset classes
  final List<String> labels = [
    // Your original 18 classes
    "bread", "Brother", "Bus", "drink", "eat", "Elder sister", "Father",
    "Help", "Hotel", "How much", "hungry", "Mother", "no", "sorry",
    "thirsty", "Toilet", "water", "yes",
    
    // Add 32 more classes - CHECK YOUR DATASET FOR ACTUAL NAMES
    // These are placeholders - replace with your actual class names
    "class_19", "class_20", "class_21", "class_22", "class_23", "class_24",
    "class_25", "class_26", "class_27", "class_28", "class_29", "class_30",
    "class_31", "class_32", "class_33", "class_34", "class_35", "class_36",
    "class_37", "class_38", "class_39", "class_40", "class_41", "class_42",
    "class_43", "class_44", "class_45", "class_46", "class_47", "class_48",
    "class_49", "class_50"
  ];

  Future<void> loadModel() async {
    try {
      print("🚀 Loading INT8 model...");
      
      final options = InterpreterOptions();
      
      // Optimize for Vivo X200 GPU
      if (Platform.isAndroid) {
        try {
          final gpuDelegate = GpuDelegateV2();
          options.addDelegate(gpuDelegate);
          print("✅ Using GPU acceleration");
        } catch (e) {
          print("⚠️ GPU not available, using CPU");
          options.threads = 8; // Use all cores
        }
      }
      
      // IMPORTANT: Load the INT8 model that was exported
      _interpreter = await Interpreter.fromAsset(
        'assets/models/best_int8.tflite', // CHANGED to match your export
        options: options,
      );
      
      // Get actual model shapes
      _inputShape = _interpreter!.getInputTensor(0).shape;
      _outputShape = _interpreter!.getOutputTensor(0).shape;
      
      print("✅ INT8 Model loaded successfully!");
      print("📦 Input shape: $_inputShape");
      print("📤 Output shape: $_outputShape");
      print("🎯 ${labels.length} classes loaded (model expects 50)");
      
      // Verify label count matches model
      if (labels.length != 50) {
        print("⚠️ WARNING: Labels list has ${labels.length} items, but model expects 50 classes!");
        print("   This may cause index out of bounds errors.");
      }
      
      // Warm up the model
      await _warmUpModel();
      
    } catch (e) {
      print("❌ FATAL: Model loading failed: $e");
      print("   Check: assets/models/best_int8.tflite exists");
      print("   Check: Model is exported with simplify=True");
      
      // Fallback to float32 model if INT8 fails
      print("🔄 Trying float32 model fallback...");
      try {
        _interpreter = await Interpreter.fromAsset(
          'assets/models/best_float32.tflite',
          options: InterpreterOptions()..threads = 8,
        );
        print("✅ Float32 model loaded as fallback");
      } catch (e2) {
        print("❌ Both model formats failed");
        rethrow;
      }
    }
  }

  Future<void> _warmUpModel() async {
    try {
      print("🔥 Warming up model...");
      
      // Create dummy input
      final inputSize = _inputShape.reduce((a, b) => a * b);
      final dummyInput = Float32List(inputSize);
      for (int i = 0; i < dummyInput.length; i++) {
        dummyInput[i] = 0.5;
      }
      
      // Prepare output
      final outputSize = _outputShape.reduce((a, b) => a * b);
      final dummyOutput = Float32List(outputSize);
      
      // Run warm-up inference
      _inferenceTimer.start();
      _interpreter!.run([dummyInput.reshape(_inputShape)], dummyOutput);
      _inferenceTimer.stop();
      
      print("✅ Model warmed up - Ready for production!");
      print("   First inference: ${_inferenceTimer.elapsedMilliseconds}ms");
      
    } catch (e) {
      print("⚠️ Warm-up failed: $e");
    }
  }

  Future<String?> detectFromStream(CameraImage image) async {
    if (_interpreter == null || _isBusy) return null;
    
    _isBusy = true;
    _framesProcessed++;

    try {
      // Process image in background isolate
      final inputTensor = await compute(_processCameraImage, {
        'image': image,
        'inputHeight': _inputShape[1],
        'inputWidth': _inputShape[2],
      });
      
      if (inputTensor == null) {
        _isBusy = false;
        return null;
      }

      // Run inference with timing
      _inferenceTimer.reset();
      _inferenceTimer.start();
      
      final outputSize = _outputShape.reduce((a, b) => a * b);
      final output = Float32List(outputSize);
      
      _interpreter!.run(inputTensor, output);
      
      _inferenceTimer.stop();
      _lastInferenceTime = _inferenceTimer.elapsedMilliseconds.toDouble();
      
      // Parse YOLOv8 output
      final result = _parseYOLOv8Output(output);
      
      _isBusy = false;
      return result;
      
    } catch (e) {
      print("⚠️ Detection error: $e");
      print("   Stack trace: ${e.toString()}");
      _isBusy = false;
      return null;
    }
  }

  /// Process camera image to model input (runs in isolate)
  static dynamic _processCameraImage(Map<String, dynamic> params) {
    try {
      final CameraImage image = params['image'];
      final int inputHeight = params['inputHeight'];
      final int inputWidth = params['inputWidth'];
      
      // Handle different image formats
      if (image.planes.length < 3) {
        print("⚠️ Unexpected image format: ${image.planes.length} planes");
        return null;
      }
      
      final yBuffer = image.planes[0].bytes;
      final uBuffer = image.planes[1].bytes;
      final vBuffer = image.planes[2].bytes;
      
      final yRowStride = image.planes[0].bytesPerRow;
      final uvRowStride = image.planes[1].bytesPerRow;
      final uvPixelStride = image.planes[1].bytesPerPixel ?? 1;
      
      // Create input tensor
      final input = Float32List(1 * inputHeight * inputWidth * 3);
      int index = 0;
      
      final scaleX = image.width / inputWidth;
      final scaleY = image.height / inputHeight;
      
      // Process each pixel with optimized YUV→RGB
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
          
          // Fast YUV to RGB (integer optimized)
          int r = (yValue + ((vValue - 128) * 1436 ~/ 1024)).clamp(0, 255);
          int g = (yValue - ((uValue - 128) * 46549 ~/ 131072) - ((vValue - 128) * 93604 ~/ 131072)).clamp(0, 255);
          int b = (yValue + ((uValue - 128) * 1814 ~/ 1024)).clamp(0, 255);
          
          // Normalize to [0, 1]
          input[index++] = r / 255.0;
          input[index++] = g / 255.0;
          input[index++] = b / 255.0;
        }
      }
      
      return [input.reshape([1, inputHeight, inputWidth, 3])];
      
    } catch (e) {
      print("❌ Image processing error: $e");
      return null;
    }
  }

  /// Parse YOLOv8 output format
  String? _parseYOLOv8Output(Float32List output) {
    try {
      // YOLOv8 output: [1, 54, 8400] where 54 = 4(bbox) + 50(classes)
      final int numClasses = 50; // FIXED: Your model has 50 classes
      final int numBoxes = _outputShape[2]; // 8400
      final int features = _outputShape[1]; // 54
      
      List<Detection> detections = [];
      
      // Parse all boxes
      for (int box = 0; box < numBoxes; box++) {
        final boxOffset = box * features;
        
        // Get class probabilities (skip first 4 bbox values)
        double maxScore = 0.0;
        int bestClass = -1;
        
        // Only check first 18 classes if that's all you care about
        for (int c = 0; c < 18; c++) { // CHANGED: Only check your 18 sign classes
          final score = output[boxOffset + 4 + c];
          if (score > maxScore) {
            maxScore = score;
            bestClass = c;
          }
        }
        
        // Apply confidence threshold
        if (maxScore > _confidenceThreshold && bestClass != -1) {
          // Get bounding box (x_center, y_center, width, height)
          final xCenter = output[boxOffset];
          final yCenter = output[boxOffset + 1];
          final width = output[boxOffset + 2];
          final height = output[boxOffset + 3];
          
          // Calculate box area for NMS
          final area = width * height;
          
          detections.add(Detection(
            classIndex: bestClass,
            confidence: maxScore,
            xCenter: xCenter,
            yCenter: yCenter,
            width: width,
            height: height,
            area: area,
          ));
        }
      }
      
      // Apply Non-Maximum Suppression (NMS)
      detections = _applyNMS(detections);
      
      // Return top detection
      if (detections.isNotEmpty) {
        final topDetection = detections.first;
        
        // Safety check for array bounds
        if (topDetection.classIndex >= 0 && topDetection.classIndex < labels.length) {
          final label = labels[topDetection.classIndex];
          
          // Log detection (throttled)
          if (_framesProcessed % 30 == 0) {
            print("🎯 Detected: $label (${topDetection.confidence.toStringAsFixed(3)}) "
                  "in ${_lastInferenceTime.toStringAsFixed(1)}ms");
          }
          
          return label;
        } else {
          print("⚠️ Invalid class index: ${topDetection.classIndex}");
          return null;
        }
      }
      
      return null;
      
    } catch (e) {
      print("❌ Output parsing error: $e");
      print("   Stack trace: ${e.toString()}");
      return null;
    }
  }

  /// Apply Non-Maximum Suppression
  List<Detection> _applyNMS(List<Detection> detections) {
    if (detections.isEmpty) return [];
    
    // Sort by confidence (highest first)
    detections.sort((a, b) => b.confidence.compareTo(a.confidence));
    
    List<Detection> filtered = [];
    
    while (detections.isNotEmpty) {
      // Take the best detection
      final best = detections.removeAt(0);
      filtered.add(best);
      
      // Remove overlapping detections
      detections.removeWhere((detection) {
        final iou = _calculateIoU(best, detection);
        return iou > _nmsThreshold;
      });
    }
    
    return filtered;
  }

  /// Calculate Intersection over Union
  double _calculateIoU(Detection a, Detection b) {
    final x1 = max(a.xCenter - a.width / 2, b.xCenter - b.width / 2);
    final y1 = max(a.yCenter - a.height / 2, b.yCenter - b.height / 2);
    final x2 = min(a.xCenter + a.width / 2, b.xCenter + b.width / 2);
    final y2 = min(a.yCenter + a.height / 2, b.yCenter + b.height / 2);
    
    final intersection = max(0, x2 - x1) * max(0, y2 - y1);
    final union = a.area + b.area - intersection;
    
    return intersection / union;
  }

  /// Get performance metrics
  Map<String, dynamic> getPerformanceMetrics() {
    final fps = _lastInferenceTime > 0 ? (1000 / _lastInferenceTime) : 0;
    
    return {
      'fps': fps.toStringAsFixed(1),
      'inferenceTime': _lastInferenceTime.toStringAsFixed(1),
      'confidenceThreshold': _confidenceThreshold,
      'framesProcessed': _framesProcessed,
      'modelType': 'INT8',
      'inputShape': _inputShape.toString(),
      'outputShape': _outputShape.toString(),
    };
  }

  /// Adjust confidence threshold
  void setConfidenceThreshold(double threshold) {
    _confidenceThreshold = threshold.clamp(0.1, 0.9);
    print("🎚️ Confidence threshold set to $_confidenceThreshold");
  }

  /// Get model info
  Map<String, dynamic> getModelInfo() {
    return {
      'inputShape': _inputShape,
      'outputShape': _outputShape,
      'totalClasses': 50,
      'signClasses': 18,
      'modelSize': '3.2 MB (INT8)',
    };
  }

  void dispose() {
    _interpreter?.close();
    print("🛑 Object detector disposed");
  }
}

/// Helper class for detection data
class Detection {
  final int classIndex;
  final double confidence;
  final double xCenter;
  final double yCenter;
  final double width;
  final double height;
  final double area;
  
  Detection({
    required this.classIndex,
    required this.confidence,
    required this.xCenter,
    required this.yCenter,
    required this.width,
    required this.height,
    required this.area,
  });
}