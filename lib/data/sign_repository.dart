import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

// lib/data/sign_repository.dart
class Sign {
  final String id;
  final String category;
  final int difficulty; // 1-5
  final String videoUrl;
  final String thumbnailUrl;
  final String description;
  final Map<String, String> translations;

  Sign({
    required this.id,
    required this.category,
    required this.difficulty,
    required this.videoUrl,
    required this.thumbnailUrl,
    required this.description,
    required this.translations,
  });

  factory Sign.fromFirestore(Map<String, dynamic> data, String id) {
    return Sign(
      id: id,
      category: data['category'] ?? 'General',
      difficulty: data['difficulty'] ?? 1,
      videoUrl: data['videoUrl'] ?? '',
      thumbnailUrl: data['thumbnailUrl'] ?? '',
      description: data['description'] ?? '',
      translations: Map<String, String>.from(data['translations'] ?? {}),
    );
  }

  Map<String, dynamic> toFirestore() {
    return {
      'category': category,
      'difficulty': difficulty,
      'videoUrl': videoUrl,
      'thumbnailUrl': thumbnailUrl,
      'description': description,
      'translations': translations,
    };
  }
}

class SignRepository {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  // Fetch all signs
  Future<List<Sign>> getAllSigns() async {
    try {
      final snapshot = await _firestore.collection('signs').get();
      return snapshot.docs.map((doc) => Sign.fromFirestore(doc.data(), doc.id)).toList();
    } catch (e) {
      print('Error fetching signs: $e');
      return [];
    }
  }

  // Fetch signs by category
  Future<List<Sign>> getSignsByCategory(String category) async {
    try {
      final snapshot = await _firestore
          .collection('signs')
          .where('category', isEqualTo: category)
          .get();
      return snapshot.docs.map((doc) => Sign.fromFirestore(doc.data(), doc.id)).toList();
    } catch (e) {
      print('Error fetching signs by category: $e');
      return [];
    }
  }

  // Get sign by ID
  Future<Sign?> getSignById(String signId) async {
    try {
      final doc = await _firestore.collection('signs').doc(signId).get();
      if (doc.exists) {
        return Sign.fromFirestore(doc.data()!, doc.id);
      }
      return null;
    } catch (e) {
      print('Error fetching sign by ID: $e');
      return null;
    }
  }
}