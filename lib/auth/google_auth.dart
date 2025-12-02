import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:flutter/foundation.dart' show kIsWeb;

class FirebaseServices {
  final FirebaseAuth auth = FirebaseAuth.instance;

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
      await auth.signInWithCredential(credential);
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
