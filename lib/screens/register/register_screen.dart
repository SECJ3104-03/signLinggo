library;

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import '../../providers/app_provider.dart';
import '../../auth/auth_service.dart';   // <-- make sure this file exists

class RegisterScreen extends StatefulWidget {
  const RegisterScreen({super.key});

  @override
  State<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends State<RegisterScreen> {
  // controllers
  final _fullName = TextEditingController();
  final _email = TextEditingController();
  final _password = TextEditingController();

  final _auth = AuthService(); // Firebase Auth service

  bool _loading = false;

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

                // Toggle
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
                          onTap: () => context.go('/signin'),
                          child: const Center(
                            child: Text(
                              "Login",
                              style: TextStyle(
                                  color: Colors.white,
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
                                fontWeight: FontWeight.bold),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 40),

                // Inputs
                _buildInputField(_fullName, "Full Name", Icons.person),
                const SizedBox(height: 20),

                _buildInputField(_email, "Email", Icons.email),
                const SizedBox(height: 20),

                _buildInputField(_password, "Password", Icons.lock,
                    obscureText: true),
                const SizedBox(height: 40),

                // Create Account
                GestureDetector(
                  onTap: _loading ? null : _signup,
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
                            "Create Account",
                            style: TextStyle(color: Colors.white, fontSize: 16),
                          ),
                  ),
                ),

                const SizedBox(height: 20),

                // Guest mode
                TextButton(
                  onPressed: () {
                    final appProvider =
                        Provider.of<AppProvider>(context, listen: false);
                    appProvider.setGuestMode(true);
                    appProvider.setLoggedIn(false);
                    context.go('/home');
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

  /// Build text input field
  Widget _buildInputField(
    TextEditingController controller,
    String label,
    IconData icon, {
    bool obscureText = false,
  }) {
    return TextField(
      controller: controller,
      obscureText: obscureText,
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

  /// Firebase Sign Up
  Future<void> _signup() async {
    if (_email.text.isEmpty || _password.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Please fill all fields")),
      );
      return;
    }

    setState(() => _loading = true);

    final result = await _auth.register(
      name: _fullName.text.trim(),
      email: _email.text.trim(),
      password: _password.text.trim(),
    );

    setState(() => _loading = false);

    if (result == null) {
      // success
      final appProvider = Provider.of<AppProvider>(context, listen: false);
      appProvider.setLoggedIn(true);
      appProvider.setGuestMode(false);

      context.go('/home');

    } else {
      // error
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(result)),
      );
    }
  }
}
