import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:flutter/foundation.dart' show kIsWeb;

class FirebaseServices {
  final FirebaseAuth auth = FirebaseAuth.instance;
  final FirebaseFirestore firestore = FirebaseFirestore.instance;

  // GoogleSignIn instance for Web & Mobile
  final GoogleSignIn googleSignIn = GoogleSignIn(
    clientId: kIsWeb
        ? "724828186533-pd8s3b8kf9o3msjcova7n45eep61hha5.apps.googleusercontent.com"
        : null,
  );

  Future<bool> signInWithGoogle() async {
    try {
      // Trigger Google Sign-In
      final GoogleSignInAccount? googleUser = await googleSignIn.signIn();

      if (googleUser == null) {
        // User cancelled the sign-in
        return false;
      }

      // Get authentication tokens
      final GoogleSignInAuthentication googleAuth =
          await googleUser.authentication;

      // Create Firebase credential
      final credential = GoogleAuthProvider.credential(
        accessToken: googleAuth.accessToken,
        idToken: googleAuth.idToken,
      );

      // Sign in to Firebase
      final userCredential = await auth.signInWithCredential(credential);
      final user = userCredential.user;

      if (user != null) {
        // Check if user exists in Firestore
        final doc = await firestore.collection('users').doc(user.uid).get();
        if (!doc.exists) {
          // First-time Google sign-in: save basic info
          await firestore.collection('users').doc(user.uid).set({
            'name': user.displayName ?? "",
            'email': user.email ?? "",
            'createdAt': FieldValue.serverTimestamp(),
          });
        }
      }

      return true;
    } catch (e) {
      print("Google Sign-In error: $e");
      return false;
    }
  }

  Future<void> signOut() async {
    await googleSignIn.signOut();
    await auth.signOut();
  }
}
