import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:signlinggo/data/models/sign_model.dart';
import 'package:signlinggo/data/models/category_model.dart';

class SignService {
  final CollectionReference signRef =
      FirebaseFirestore.instance.collection('signs');
  final CollectionReference categoryRef =
      FirebaseFirestore.instance.collection('category');

  // Get all categories ordered by 'order' field
  Stream<List<Category>> getCategories() {
    return categoryRef.orderBy('order').snapshots().map((snapshot) {
      return snapshot.docs.map((doc) => Category.fromFirestore(doc)).toList();
    });
  }

  // Get all signs as a stream
  Stream<List<Sign>> getAllSigns() {
    return signRef.snapshots().map((snapshot) {
      return snapshot.docs.map((doc) => Sign.fromFirestore(doc)).toList();
    });
  }

  // Get signs filtered by category
  Stream<List<Sign>> getSignsByCategory(String categoryId) {
    return signRef
        .where('categoryId', isEqualTo: categoryId)
        .snapshots()
        .map((snapshot) {
      return snapshot.docs.map((doc) => Sign.fromFirestore(doc)).toList();
    });
  }

  // Search signs by title
  Stream<List<Sign>> searchSigns(String query) {
    return signRef.snapshots().map((snapshot) {
      final allSigns = snapshot.docs.map((doc) => Sign.fromFirestore(doc)).toList();
      if (query.isEmpty) return allSigns;
      
      return allSigns.where((sign) {
        return sign.title.toLowerCase().contains(query.toLowerCase());
      }).toList();
    });
  }

  // Get signs by category with search filter
  Stream<List<Sign>> getFilteredSigns(String? categoryId, String searchQuery) {
    Query query = signRef;
    
    // Apply category filter if provided
    if (categoryId != null && categoryId.isNotEmpty) {
      query = query.where('categoryId', isEqualTo: categoryId);
    }
    
    return query.snapshots().map((snapshot) {
      final signs = snapshot.docs.map((doc) => Sign.fromFirestore(doc)).toList();
      
      // Apply search filter
      if (searchQuery.isEmpty) return signs;
      
      return signs.where((sign) {
        return sign.title.toLowerCase().contains(searchQuery.toLowerCase());
      }).toList();
    });
  }

  Future<void> addSign(Map<String, dynamic> data) async {
    await signRef.add(data);
  }
}
