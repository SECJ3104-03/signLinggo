library;

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
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

                // Password Field
                _buildInputField(
                  controller: passwordController,
                  label: "Password",
                  icon: Icons.lock,
                  obscureText: true,
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
                      color: Colors.white.withOpacity(0.9),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: Colors.white70),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Image.asset('assets/icons/google_logo.png', height: 24),
                        const SizedBox(width: 10),
                        const Text(
                          "Sign in with Google",
                          style: TextStyle(
                              color: Color(0xFF495565),
                              fontSize: 15,
                              fontWeight: FontWeight.w600),
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

  // EMAIL/PASSWORD LOGIN
  Future<void> _emailPasswordLogin() async {
    if (emailController.text.isEmpty || passwordController.text.isEmpty) {
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text("Fill all fields")));
      return;
    }

    setState(() => _loading = true);

    // Sign out any previous session
    await _authService.signOut();

    final user = await _authService.login(
      email: emailController.text.trim(),
      password: passwordController.text.trim(),
    );

    setState(() => _loading = false);

    if (user != null) {
      final appProvider = Provider.of<AppProvider>(context, listen: false);
      appProvider.setLoggedIn(true);
      appProvider.setGuestMode(false);
      context.go('/home');
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Login failed: Invalid email or password")),
      );
    }
  }

  // GOOGLE LOGIN
  Future<void> _googleLogin() async {
    setState(() => _loading = true);

    try {
      final success = await _googleAuth.signInWithGoogle();

      if (success) {
        final appProvider = Provider.of<AppProvider>(context, listen: false);
        appProvider.setLoggedIn(true);
        appProvider.setGuestMode(false);
        context.go('/home');
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
      if (mounted) setState(() => _loading = false); // Always reset loading
    }
  }

  // INPUT FIELD BUILDER
  Widget _buildInputField({
    required TextEditingController controller,
    required String label,
    required IconData icon,
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
}
