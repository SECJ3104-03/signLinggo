import 'dart:io';
import 'package:flutter/foundation.dart'; // Needed for 'compute'
import 'package:image/image.dart' as img;
import 'package:tflite_flutter/tflite_flutter.dart';

class ObjectDetector {
  Interpreter? _interpreter;

  // Your classes
  final List<String> labels = [
    "bread", "Brother", "Bus", "drink", "eat", "Elder sister",
    "Father", "Help", "Hotel", "How much", "hungry", "Mother",
    "no", "sorry", "thirsty", "Toilet", "water", "yes"
  ];

  Future<void> loadModel() async {
    try {
      final options = InterpreterOptions();
      if (Platform.isAndroid) options.addDelegate(XNNPackDelegate());
      
      _interpreter = await Interpreter.fromAsset(
        'assets/models/best_float32.tflite',
        options: options
      );
      print("✅ Model loaded successfully");
    } catch (e) {
      print("❌ Error loading model: $e");
    }
  }

  Future<String?> detect(String imagePath) async {
    if (_interpreter == null) return null;

    try {
      // 1. Run HEAVY processing in a Background Thread (Isolate)
      // This prevents the "smooth... lag... smooth" cycle on the UI
      final input = await compute(_preprocessImageInIsolate, imagePath);

      // 2. Run Inference (Fast on NPU/CPU)
      // Output shape: [1, 22, 8400]
      var output = List.filled(1 * 22 * 8400, 0.0).reshape([1, 22, 8400]);
      _interpreter!.run(input, output);

      // 3. Parse Results
      return _parseOutput(output);
    } catch (e) {
      print("Error during detection: $e");
      return null;
    }
  }

  String? _parseOutput(var output) {
    double maxScore = 0.0;
    int bestClassIndex = -1;

    for (var i = 0; i < 8400; i++) {
      for (var c = 4; c < 22; c++) {
        double score = output[0][c][i];
        if (score > maxScore) {
          maxScore = score;
          bestClassIndex = c - 4;
        }
      }
    }

    if (maxScore > 0.50) {
      return labels[bestClassIndex];
    }
    return null;
  }
}

// --- BACKGROUND TASK (Must be outside the class) ---
// This function runs on a separate thread. It decodes, resizes, and normalizes.
List<List<List<List<double>>>> _preprocessImageInIsolate(String imagePath) {
  // 1. Read File
  final imageData = File(imagePath).readAsBytesSync();
  
  // 2. Decode Image
  final decodedImage = img.decodeImage(imageData);
  if (decodedImage == null) {
    throw Exception("Failed to decode image");
  }

  // 3. Resize to 640x640
  final resizedImage = img.copyResize(decodedImage, width: 640, height: 640);

  // 4. Convert to Matrix & Normalize (0.0 - 1.0)
  // Generating this massive list is what usually causes the lag.
  // Now it happens in the background!
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

  return input;
}