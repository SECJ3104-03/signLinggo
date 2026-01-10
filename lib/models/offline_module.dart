import 'package:flutter/material.dart';

class OfflineModule {
  final String id;
  final String title;
  final String description;
  final String zipFileName; // Exact filename in Supabase Storage
  final String folderName;  // Folder name inside the Zip
  final IconData icon;      // Icon to display
  final List<String> includedVideos;

  OfflineModule({
    required this.id,
    required this.title,
    required this.description,
    required this.zipFileName,
    required this.folderName,
    required this.icon,
    this.includedVideos = const [],
  });
}