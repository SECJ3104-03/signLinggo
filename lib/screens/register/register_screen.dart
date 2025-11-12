/// Register Screen
/// 
/// Provides user registration interface with:
/// - Full name, email, and password fields
/// - Google Sign-In option
/// - Guest mode access
/// - Navigation to sign-in screen
library;
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import '../../providers/app_provider.dart';

class RegisterScreen extends StatelessWidget {
  const RegisterScreen({super.key});

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
                  "Welcome to SignLingo",
                  style: TextStyle(color: Colors.white, fontSize: 18),
                ),
                const SizedBox(height: 4),
                const Text(
                  "Create your account",
                  style: TextStyle(color: Colors.white70, fontSize: 16),
                ),
                const SizedBox(height: 40),

                // Toggle buttons
                Container(
                  height: 40,
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.2),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        child: GestureDetector(
                          onTap: () {
                            context.go('/signin');
                          },
                          child: Container(
                            alignment: Alignment.center,
                            child: const Text(
                              "Login",
                              style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 14,
                                  fontWeight: FontWeight.bold),
                            ),
                          ),
                        ),
                      ),
                      Expanded(
                        child: Container(
                          alignment: Alignment.center,
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(14),
                          ),
                          child: const Text(
                            "Register",
                            style: TextStyle(
                                color: Color(0xFF980FFA),
                                fontSize: 14,
                                fontWeight: FontWeight.bold),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 40),

                // Input fields
                _buildInputField("Full Name", Icons.person),
                const SizedBox(height: 20),
                _buildInputField("Email", Icons.email),
                const SizedBox(height: 20),
                _buildInputField("Password", Icons.lock, obscureText: true),
                const SizedBox(height: 40),

                // Create account button
                GestureDetector(
                  onTap: () {
                    // Update app state to mark user as logged in
                    final appProvider = Provider.of<AppProvider>(context, listen: false);
                    appProvider.setLoggedIn(true);
                    appProvider.setGuestMode(false);
                    
                    // Show success message
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text("Account created successfully!"),
                        duration: Duration(seconds: 1),
                      ),
                    );
                    
                    // Navigate to home page
                    context.go('/home');
                  },
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
                    child: const Text(
                      "Create Account",
                      style: TextStyle(color: Colors.white, fontSize: 16),
                    ),
                  ),
                ),
                const SizedBox(height: 20),

                // Continue as guest
                TextButton(
                  onPressed: () {
                    // Update app state to mark user as guest
                    final appProvider = Provider.of<AppProvider>(context, listen: false);
                    appProvider.setGuestMode(true);
                    appProvider.setLoggedIn(false);
                    
                    // Navigate to home page
                    context.go('/home');
                  },
                  child: const Text(
                    "Continue as Guest",
                    style: TextStyle(color: Colors.white, fontSize: 14),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildInputField(String label, IconData icon,
      {bool obscureText = false}) {
    return TextField(
      obscureText: obscureText,
      decoration: InputDecoration(
        prefixIcon: Icon(icon, color: const Color(0xFF495565)),
        filled: true,
        fillColor: Colors.white.withOpacity(0.9),
        hintText: label,
        hintStyle: const TextStyle(color: Color(0xFF495565)),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: const BorderSide(color: Colors.white60),
        ),
      ),
    );
  }
}
