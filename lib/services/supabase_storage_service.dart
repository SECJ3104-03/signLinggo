// lib/services/supabase_storage_service.dart

import 'dart:io';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class SupabaseStorageService {
  // Access the client instance
  final SupabaseClient _supabase = Supabase.instance.client;

  // Function to upload file and return the Public URL
  Future<String?> uploadFile(File file, String folderName) async {
    try {
      // 1. Create a unique file name (e.g., vid_123456789.mp4)
      final String fileExtension = file.path.split('.').last;
      final String fileName = '${folderName}_${DateTime.now().millisecondsSinceEpoch}.$fileExtension';
      
      // 2. Upload to the 'community_media' bucket
      // Note: Make sure you created this bucket in your Supabase Dashboard!
      final String path = 'uploads/$fileName';
      
      await _supabase.storage.from('community_media').upload(
        path,
        file,
        fileOptions: const FileOptions(cacheControl: '3600', upsert: false),
      );

      // 3. Get the Public URL so we can save it to Firebase
      final String publicUrl = _supabase.storage
          .from('community_media')
          .getPublicUrl(path);

      return publicUrl;
    } catch (e) {
      print("Error uploading to Supabase: $e");
      return null;
    }
  }

  // Upload profile picture
  Future<String?> uploadProfileImage(File file) async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) return null;

      final userId = user.uid;
      final timestamp = DateTime.now().millisecondsSinceEpoch;
      final fileName = "profile_$timestamp.jpg";
      final path = "users/$userId/$fileName";

      print("📤 Starting upload to: $path");

      // Simple upload approach
      await _supabase.storage
          .from('community_media')
          .upload(path, file);

      // If no exception was thrown, upload was successful
      final publicUrl = _supabase.storage
          .from('community_media')
          .getPublicUrl(path);

      print("✅ Upload completed! URL: $publicUrl");
      return publicUrl;

    } catch (e) {
      print("❌ Upload failed: $e");
      return null;
    }
  }
}