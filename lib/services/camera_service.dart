/// Camera Service
/// 
/// Handles camera initialization and availability checks.
/// Provides error handling for camera-related operations.
library;
import 'package:camera/camera.dart';
import 'package:flutter/foundation.dart';

/// Service class for managing camera operations
class CameraService {
  static List<CameraDescription> _cameras = [];
  static bool _initialized = false;
  static String? _errorMessage;

  /// Get available cameras
  static List<CameraDescription> get cameras => _cameras;

  /// Check if cameras are available
  static bool get hasCameras => _cameras.isNotEmpty;

  /// Check if camera service is initialized
  static bool get isInitialized => _initialized;

  /// Get error message if initialization failed
  static String? get errorMessage => _errorMessage;

  /// Initialize cameras with error handling
  /// 
  /// Returns true if cameras are successfully initialized, false otherwise
  static Future<bool> initializeCameras() async {
    try {
      _errorMessage = null;
      _cameras = await availableCameras();
      _initialized = true;
      
      if (_cameras.isEmpty) {
        _errorMessage = 'No cameras found on this device';
        debugPrint('CameraService: No cameras available');
        return false;
      }
      
      debugPrint('CameraService: Successfully initialized ${_cameras.length} camera(s)');
      return true;
    } on CameraException catch (e) {
      _errorMessage = _getCameraExceptionMessage(e);
      _initialized = false;
      debugPrint('CameraService: CameraException - ${e.code}: ${e.description}');
      return false;
    } catch (e) {
      _errorMessage = 'Failed to initialize camera: ${e.toString()}';
      _initialized = false;
      debugPrint('CameraService: Error - $e');
      return false;
    }
  }

  /// Get user-friendly error message from camera exception
  static String _getCameraExceptionMessage(CameraException e) {
    switch (e.code) {
      case 'cameraNotFound':
        return 'No camera found on this device. Please connect a camera or use a device with a camera.';
      case 'cameraAccessDenied':
        return 'Camera access denied. Please grant camera permissions in settings.';
      case 'cameraPermissionDenied':
        return 'Camera permission denied. Please enable camera access in app settings.';
      case 'cameraService':
        return 'Camera service error. Please try again later.';
      default:
        return 'Camera error: ${e.description ?? e.code}';
    }
  }

  /// Get first available camera
  /// 
  /// Returns null if no cameras are available
  static CameraDescription? getFirstCamera() {
    if (_cameras.isEmpty) return null;
    return _cameras.first;
  }

  /// Check if running on web platform
  static bool get isWeb => kIsWeb;

  /// Reset camera service (useful for testing or re-initialization)
  static void reset() {
    _cameras = [];
    _initialized = false;
    _errorMessage = null;
  }
}

