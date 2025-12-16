import 'package:cloud_firestore/cloud_firestore.dart';

class Category {
  String id;
  String name;
  String iconUrl;
  int order;

  Category({
    required this.id,
    required this.name,
    required this.iconUrl,
    required this.order,
  });

  // Factory constructor to create Category from Firestore document
  factory Category.fromFirestore(DocumentSnapshot doc) {
    Map<String, dynamic> data = doc.data() as Map<String, dynamic>;
    
    return Category(
      id: doc.id,
      name: data['name'] ?? '',
      iconUrl: data['icon_url'] ?? '',
      order: int.tryParse(data['order']?.toString() ?? '0') ?? 0,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'name': name,
      'icon_url': iconUrl,
      'order': order,
    };
  }
}
