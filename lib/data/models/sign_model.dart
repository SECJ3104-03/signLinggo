import 'package:cloud_firestore/cloud_firestore.dart';

class Sign {
  String id;
  String title;
  String meaning;
  String categoryId;
  String videoUrl;
  String thumbnailUrl;
  String difficultyLevel;
  String description;
  DateTime createdAt;
  DateTime updatedAt;
  String createdBy;

  Sign({
    required this.id,
    required this.title,
    required this.meaning,
    required this.categoryId,
    required this.videoUrl,
    required this.thumbnailUrl,
    required this.difficultyLevel,
    required this.description,
    required this.createdAt,
    required this.updatedAt,
    required this.createdBy,
  });

  // Factory constructor to create Sign from Firestore document
  factory Sign.fromFirestore(DocumentSnapshot doc) {
    Map<String, dynamic> data = doc.data() as Map<String, dynamic>;
    
    return Sign(
      id: doc.id,
      title: data['title'] ?? '',
      meaning: data['meaning'] ?? '',
      categoryId: data['categoryId'] ?? '',
      videoUrl: data['videoUrl'] ?? '',
      thumbnailUrl: data['thumbnailUrl'] ?? '',
      difficultyLevel: data['difficultyLevel'] ?? 'Easy',
      description: data['description'] ?? '',
      createdAt: _parseDate(data['createdAt']),
      updatedAt: _parseDate(data['updatedAt']),
      createdBy: data['createdBy'] ?? '',
    );
  }

  // Helper method to parse date from multiple formats (Timestamp or String)
  static DateTime _parseDate(dynamic value) {
    if (value == null) return DateTime.now();
    
    // Handle Firestore Timestamp
    if (value is Timestamp) {
      return value.toDate();
    }
    
    // Handle ISO String format
    if (value is String) {
      try {
        return DateTime.parse(value);
      } catch (e) {
        print('⚠️ Error parsing date string: $value - $e');
        return DateTime.now();
      }
    }
    
    // Fallback for unknown types
    return DateTime.now();
  }

  Map<String, dynamic> toMap() {
    return {
      'title': title,
      'meaning': meaning,
      'categoryId': categoryId,
      'videoUrl': videoUrl,
      'thumbnailUrl': thumbnailUrl,
      'difficultyLevel': difficultyLevel,
      'description': description,
      'createdAt': createdAt,
      'updatedAt': updatedAt,
      'createdBy': createdBy,
    };
  }
}
