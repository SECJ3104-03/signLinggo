import 'package:cloud_firestore/cloud_firestore.dart';

class SignService {
  final CollectionReference signRef =
      FirebaseFirestore.instance.collection('sign');

  Future<void> addSign(Map<String, dynamic> data) async {
    await signRef.add(data);
  }
}
