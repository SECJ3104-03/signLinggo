import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:flutter/foundation.dart' show kIsWeb;

class FirebaseServices {
  final FirebaseAuth auth = FirebaseAuth.instance;
  final FirebaseFirestore firestore = FirebaseFirestore.instance;

  final GoogleSignIn googleSignIn = GoogleSignIn(
    clientId: kIsWeb
        ? "724828186533-pd8s3b8kf9o3msjcova7n45eep61hha5.apps.googleusercontent.com"
        : null,
  );

  Future<bool> signInWithGoogle() async {
    try {
      // ✅ FORCE account chooser (IMPORTANT)
      if (!kIsWeb) {
        await googleSignIn.signOut();      // clears cached account
        // await googleSignIn.disconnect(); // optional: stronger reset
      }

      final GoogleSignInAccount? googleUser =
          await googleSignIn.signIn();

      if (googleUser == null) {
        return false; // user cancelled
      }

      final GoogleSignInAuthentication googleAuth =
          await googleUser.authentication;

      final credential = GoogleAuthProvider.credential(
        accessToken: googleAuth.accessToken,
        idToken: googleAuth.idToken,
      );

      final userCredential =
          await auth.signInWithCredential(credential);

      final user = userCredential.user;

      if (user != null) {
        final doc =
            await firestore.collection('users').doc(user.uid).get();

        if (!doc.exists) {
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
