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
