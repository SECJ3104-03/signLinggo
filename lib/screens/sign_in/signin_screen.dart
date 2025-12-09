// lib/screens/sign_in/signin_screen.dart

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:firebase_auth/firebase_auth.dart'; // Required for UID
import 'package:cloud_firestore/cloud_firestore.dart'; // Required for Database
import '../../providers/app_provider.dart';
import '../../auth/auth_service.dart';
import '../../auth/google_auth.dart';

class SignInScreen extends StatefulWidget {
  const SignInScreen({super.key});

  @override
  State<SignInScreen> createState() => _SignInScreenState();
}

class _SignInScreenState extends State<SignInScreen> {
  final TextEditingController emailController = TextEditingController();
  final TextEditingController passwordController = TextEditingController();

  final AuthService _authService = AuthService();
  final FirebaseServices _googleAuth = FirebaseServices();

  bool _loading = false;
  bool _obscurePassword = true; // Track password visibility

  @override
  void dispose() {
    emailController.dispose();
    passwordController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        width: double.infinity,
        height: double.infinity,
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              Color(0xFF50A2FF),
              Color(0xFFC17AFF),
              Color(0xFFFB63B6),
            ],
          ),
        ),
        child: SafeArea(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 40),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                // Logo
                Container(
                  width: 100,
                  height: 100,
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.2),
                    borderRadius: BorderRadius.circular(24),
                    border: Border.all(color: Colors.white.withOpacity(0.4)),
                  ),
                  child: const Icon(Icons.sign_language,
                      size: 50, color: Colors.white),
                ),
                const SizedBox(height: 20),
                const Text(
                  "Welcome Back to SignLingo",
                  style: TextStyle(color: Colors.white, fontSize: 18),
                ),
                const SizedBox(height: 4),
                const Text(
                  "Login to your account",
                  style: TextStyle(color: Colors.white70, fontSize: 16),
                ),
                const SizedBox(height: 40),

                // Toggle: Login/Register
                Container(
                  height: 40,
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.2),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        child: Container(
                          alignment: Alignment.center,
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(14),
                          ),
                          child: const Text(
                            "Login",
                            style: TextStyle(
                                color: Color(0xFF980FFA),
                                fontSize: 14,
                                fontWeight: FontWeight.bold),
                          ),
                        ),
                      ),
                      Expanded(
                        child: GestureDetector(
                          onTap: () => context.go('/register'),
                          child: const Center(
                            child: Text(
                              "Register",
                              style: TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.bold),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 40),

                // Email Field
                _buildInputField(
                    controller: emailController,
                    label: "Email",
                    icon: Icons.email),

                const SizedBox(height: 20),

                // Password Field with show/hide button
                _buildPasswordField(
                  controller: passwordController,
                  label: "Password",
                  icon: Icons.lock,
                ),

                const SizedBox(height: 40),

                // Email/Password Login Button
                GestureDetector(
                  onTap: _loading ? null : _emailPasswordLogin,
                  child: Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(16),
                      gradient: const LinearGradient(
                        colors: [Color(0xFFFDC700), Color(0xFFFF6800)],
                      ),
                    ),
                    alignment: Alignment.center,
                    child: _loading
                        ? const CircularProgressIndicator(color: Colors.white)
                        : const Text(
                            "Login",
                            style: TextStyle(color: Colors.white, fontSize: 16),
                          ),
                  ),
                ),

                const SizedBox(height: 20),

                // Google Sign-In Button
                GestureDetector(
                  onTap: _loading ? null : _googleLogin,
                  child: Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(16),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.08),
                          blurRadius: 10,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        SizedBox(
                          width: 26,
                          height: 26,
                          child: Image.asset(
                            'assets/assets/icons/google_logo.png',
                            fit: BoxFit.cover,
                          ),
                        ),
                        const SizedBox(width: 12),
                        const Text(
                          "Sign in with Google",
                          style: TextStyle(
                            color: Color(0xFF495565),
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),

                const SizedBox(height: 20),

                // Guest Mode
                TextButton(
                  onPressed: () {
                    final appProvider =
                        Provider.of<AppProvider>(context, listen: false);
                    appProvider.setGuestMode(true);
                    appProvider.setLoggedIn(false);
                    context.go('/profile');
                  },
                  child: const Text(
                    "Continue as Guest",
                    style: TextStyle(color: Colors.white),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // EMAIL/PASSWORD LOGIN (UPDATED with Self-Healing Logic)
  Future<void> _emailPasswordLogin() async {
    if (emailController.text.isEmpty || passwordController.text.isEmpty) {
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text("Fill all fields")));
      return;
    }

    setState(() => _loading = true);

    try {
      // Sign out any previous session
      await _authService.signOut();

      // Attempt login
      final user = await _authService.login(
        email: emailController.text.trim(),
        password: passwordController.text.trim(),
      );

      if (user != null) {
        
        // --- FAIL-SAFE FIX FOR CURRENT USERS ---
        // We check if this user has a profile in the database.
        // If they are an "Old User" and don't have one, we create it now.
        try {
          final userDoc = await FirebaseFirestore.instance.collection('users').doc(user.uid).get();
          if (!userDoc.exists) {
            // Auto-create the missing profile
            await FirebaseFirestore.instance.collection('users').doc(user.uid).set({
              'uid': user.uid,
              // We use the email prefix as a temporary name if they don't have one
              'name': user.displayName ?? emailController.text.split('@')[0], 
              'email': user.email ?? emailController.text,
              'createdAt': FieldValue.serverTimestamp(),
            });
            print("Auto-fixed missing profile for user: ${user.uid}");
          }
        } catch (dbError) {
          print("Safe-fail: Could not check/fix user profile: $dbError");
        }
        // ----------------------------------------

        final appProvider = Provider.of<AppProvider>(context, listen: false);
        appProvider.setLoggedIn(true);
        appProvider.setGuestMode(false);
        context.go('/profile');
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Login failed: Invalid email or password")),
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Login error: $e")),
      );
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  // GOOGLE LOGIN (UPDATED with Self-Healing Logic)
  Future<void> _googleLogin() async {
    setState(() => _loading = true);

    try {
      final success = await _googleAuth.signInWithGoogle();

      if (success) {
        
        // --- FAIL-SAFE FIX FOR GOOGLE USERS ---
        try {
          final user = FirebaseAuth.instance.currentUser;
          if (user != null) {
            final userDoc = await FirebaseFirestore.instance.collection('users').doc(user.uid).get();
            if (!userDoc.exists) {
              await FirebaseFirestore.instance.collection('users').doc(user.uid).set({
                'uid': user.uid,
                'name': user.displayName ?? 'No Name',
                'email': user.email ?? '',
                'createdAt': FieldValue.serverTimestamp(),
              });
              print("Auto-fixed missing Google profile for user: ${user.uid}");
            }
          }
        } catch (dbError) {
           print("Safe-fail: Could not check/fix Google user profile: $dbError");
        }
        // --------------------------------------

        final appProvider = Provider.of<AppProvider>(context, listen: false);
        appProvider.setLoggedIn(true);
        appProvider.setGuestMode(false);

        // Navigate to profile
        context.go('/profile');
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Google Sign-In cancelled")),
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Google Sign-In failed: $e")),
      );
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  // INPUT FIELD BUILDER
  Widget _buildInputField({
    required TextEditingController controller,
    required String label,
    required IconData icon,
  }) {
    return TextField(
      controller: controller,
      decoration: InputDecoration(
        prefixIcon: Icon(icon, color: const Color(0xFF495565)),
        filled: true,
        fillColor: Colors.white.withOpacity(0.9),
        hintText: label,
        hintStyle: const TextStyle(color: Color(0xFF495565)),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
        ),
      ),
    );
  }

  // PASSWORD FIELD BUILDER with show/hide toggle
  Widget _buildPasswordField({
    required TextEditingController controller,
    required String label,
    required IconData icon,
  }) {
    return TextField(
      controller: controller,
      obscureText: _obscurePassword,
      decoration: InputDecoration(
        prefixIcon: Icon(icon, color: const Color(0xFF495565)),
        suffixIcon: IconButton(
          icon: Icon(
            _obscurePassword ? Icons.visibility_off : Icons.visibility,
            color: const Color(0xFF495565),
          ),
          onPressed: () {
            setState(() {
              _obscurePassword = !_obscurePassword;
            });
          },
        ),
        filled: true,
        fillColor: Colors.white.withOpacity(0.9),
        hintText: label,
        hintStyle: const TextStyle(color: Color(0xFF495565)),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
        ),
      ),
    );
  }
}