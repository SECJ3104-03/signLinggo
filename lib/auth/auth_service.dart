import 'package:firebase_auth/firebase_auth.dart';

class AuthService {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  // Expose the Auth State Stream
  Stream<User?> get authStateChanges => _auth.authStateChanges();

  // Register new user
  Future<String?> register({
    required String name,
    required String email,
    required String password,
  }) async {
    try {
      UserCredential result = await _auth.createUserWithEmailAndPassword(
        email: email,
        password: password,
      );

      await result.user!.updateDisplayName(name);
      return null; // success
    } on FirebaseAuthException catch (e) {
      return e.message; // error message
    }
  }

  // Login existing user
  Future<User?> login({
    required String email,
    required String password,
  }) async {
    try {
      UserCredential result = await _auth.signInWithEmailAndPassword(
        email: email,
        password: password,
      );
      return result.user; // return user only if login succeeds
    } on FirebaseAuthException catch (e) {
      print("Login failed: ${e.code}");
      return null; // login failed
    }
  }

  // Sign out user
  Future<void> signOut() async {
    await _auth.signOut();
  }
}
