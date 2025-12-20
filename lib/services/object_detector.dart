import 'dart:io';
import 'package:flutter/services.dart';
import 'package:image/image.dart' as img;
import 'package:tflite_flutter/tflite_flutter.dart';

class ObjectDetector {
  Interpreter? _interpreter;

  // TODO: Replace these with your actual class names from Roboflow (DONE)
  // You have 18 classes (based on your logs). Example:
  final List<String> labels = [
    "bread",
    "Brother",
    "Bus",
    "drink",
    "eat",
    "Elder sister",
    "Father",
    "Help",
    "Hotel",
    "How much",
    "hungry",
    "Mother",
    "no",
    "sorry",
    "thirsty",
    "Toilet",
    "water",
    "yes"
  ];

  Future<void> loadModel() async {
    try {
      final options = InterpreterOptions();
      // Use XNNPACK for faster inference on Android
      if (Platform.isAndroid) options.addDelegate(XNNPackDelegate());
      
      // Load the model from assets
      _interpreter = await Interpreter.fromAsset(
        'assets/models/best_float32.tflite',
        options: options
      );
      print("✅ Model loaded successfully");
    } catch (e) {
      print("❌ Error loading model: $e");
    }
  }

  Future<List<Map<String, dynamic>>> runInference(String imagePath) async {
    if (_interpreter == null) {
      print("⚠️ Interpreter not initialized");
      return [];
    }

    // 1. Read and Resize Image (640x640)
    final imageData = File(imagePath).readAsBytesSync();
    final decodedImage = img.decodeImage(imageData);
    final resizedImage = img.copyResize(decodedImage!, width: 640, height: 640);

    // 2. Convert to Matrix (Normalization 0.0 - 1.0)
    var input = List.generate(1, (i) => 
      List.generate(640, (j) => 
        List.generate(640, (k) => List.filled(3, 0.0))
      )
    );

    for (var y = 0; y < 640; y++) {
      for (var x = 0; x < 640; x++) {
        var pixel = resizedImage.getPixel(x, y);
        input[0][y][x][0] = pixel.r / 255.0;
        input[0][y][x][1] = pixel.g / 255.0;
        input[0][y][x][2] = pixel.b / 255.0;
      }
    }

    // 3. Run Inference
    // Output shape: [1, 22, 8400] (based on your logs)
    var output = List.filled(1 * 22 * 8400, 0.0).reshape([1, 22, 8400]);
    _interpreter!.run(input, output);

    // 4. Parse Results
    return _parseOutput(output);
  }

  List<Map<String, dynamic>> _parseOutput(var output) {
    List<Map<String, dynamic>> detections = [];
    
    // 8400 is the number of grid cells YOLO checks
    for (var i = 0; i < 8400; i++) {
      double maxScore = 0.0;
      int bestClassIndex = -1;

      // Find the class with the highest score (indices 4 to 21)
      for (var c = 4; c < 22; c++) {
        double score = output[0][c][i];
        if (score > maxScore) {
          maxScore = score;
          bestClassIndex = c - 4;
        }
      }

      // Threshold: Only accept if confidence > 50%
      if (maxScore > 0.50) {
        // Get label name safely
        String label = (bestClassIndex >= 0 && bestClassIndex < labels.length) 
            ? labels[bestClassIndex] 
            : "Unknown";

        detections.add({
          "label": label,
          "score": (maxScore * 100).toStringAsFixed(1) + "%",
        });
      }
    }
    
    // Sort by confidence (highest first) and take the top 1
    detections.sort((a, b) => b['score'].compareTo(a['score']));
    return detections.take(1).toList();
  }
}