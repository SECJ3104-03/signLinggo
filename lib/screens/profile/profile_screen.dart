// lib/screens/profile/profile_screen.dart

import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:cached_network_image/cached_network_image.dart';

import '../../auth/auth_service.dart';
import '../../providers/app_provider.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  User? user;
  Map<String, dynamic>? userData;
  bool isLoading = false;

  @override
  void initState() {
    super.initState();
    user = FirebaseAuth.instance.currentUser;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadUserData();
    });
  }

  Future<void> _loadUserData() async {
    if (user == null) return;

    if (mounted) setState(() => isLoading = true);

    try {
      final doc = await FirebaseFirestore.instance
          .collection("users")
          .doc(user!.uid)
          .get();

      if (doc.exists && mounted) {
        setState(() => userData = doc.data()!);
      }
    } catch (e) {
      print("Error loading user data: $e");
    } finally {
      if (mounted) setState(() => isLoading = false);
    }
  }

  void _openEditProfile() {
    // Use GoRouter to navigate to edit-profile route
    GoRouter.of(context).push('/edit-profile');
  }

  void _goBack() {
    // Simply go back using GoRouter
    if (GoRouter.of(context).canPop()) {
      GoRouter.of(context).pop();
    } else {
      GoRouter.of(context).go('/home');
    }
  }

  Future<void> _logout() async {
    try {
      final authService = AuthService();
      final appProvider = Provider.of<AppProvider>(context, listen: false);
      
      if (user != null) {
        await authService.signOut();
      }
      
      appProvider.setGuestMode(false);
      appProvider.setLoggedIn(false);

      // Clear any navigation history
      while (GoRouter.of(context).canPop()) {
        GoRouter.of(context).pop();
      }
      
      // Navigate to signin
      GoRouter.of(context).go('/signin');
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text("Logout failed: ${e.toString()}"),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final bool isGuest = user == null;

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.black),
          onPressed: _goBack,
        ),
        title: const Text(
          "My Profile",
          style: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.w600,
            color: Colors.black,
          ),
        ),
      ),
      body: _buildBody(isGuest),
    );
  }

  Widget _buildBody(bool isGuest) {
    if (isLoading) {
      return const Center(
        child: CircularProgressIndicator(),
      );
    }

    return SingleChildScrollView(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 20),
            
            // Profile Header
            _buildProfileHeader(isGuest),
            
            const SizedBox(height: 40),
            
            // Account Details
            if (!isGuest && userData != null && userData!.isNotEmpty)
              _buildFirestoreSection(),
            
            const SizedBox(height: 40),
            
            // Action Buttons
            _buildActionButtons(isGuest),
          ],
        ),
      ),
    );
  }

  Widget _buildProfileHeader(bool isGuest) {
    return Row(
      children: [
        // Profile Image
        GestureDetector(
          onTap: !isGuest ? _openEditProfile : null,
          child: Container(
            width: 100,
            height: 100,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: Colors.grey.shade200,
            ),
            child: _buildCachedProfileImage(),
          ),
        ),
        const SizedBox(width: 20),

        // User Info
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                _getDisplayName(),
                style: const TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.w700,
                ),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: 8),
              Text(
                _getUsername(),
                style: TextStyle(
                  fontSize: 16,
                  color: Colors.grey.shade700,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildActionButtons(bool isGuest) {
    return Column(
      children: [
        // Edit Profile Button
        _buildActionButton(
          icon: Icons.edit,
          label: "Edit Profile",
          color: Colors.blueGrey.shade800,
          onPressed: !isGuest ? _openEditProfile : null,
        ),
        
        const SizedBox(height: 16),
        
        // Offline Mode Button
        _buildActionButton(
          icon: Icons.wifi_off,
          label: "Offline Mode",
          color: Colors.teal.shade600,
          onPressed: () => GoRouter.of(context).go('/offline'),
        ),
        
        const SizedBox(height: 40),
        
        // Log Out Button
        if (!isGuest)
          _buildActionButton(
            icon: Icons.logout,
            label: "Log Out",
            color: Colors.red.shade600,
            onPressed: _logout,
          ),
        
        // Guest Message
        if (isGuest)
          Container(
            margin: const EdgeInsets.only(top: 40),
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.grey.shade100,
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Column(
              children: [
                Icon(Icons.info_outline, color: Colors.blue, size: 40),
                SizedBox(height: 12),
                Text(
                  "Guest Mode",
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                SizedBox(height: 8),
                Text(
                  "Sign in to access all features",
                  textAlign: TextAlign.center,
                  style: TextStyle(color: Colors.grey),
                ),
              ],
            ),
          ),
      ],
    );
  }

  Widget _buildActionButton({
    required IconData icon,
    required String label,
    required Color color,
    VoidCallback? onPressed,
  }) {
    return SizedBox(
      width: double.infinity,
      child: ElevatedButton(
        onPressed: onPressed,
        style: ElevatedButton.styleFrom(
          backgroundColor: color,
          foregroundColor: Colors.white,
          minimumSize: const Size(double.infinity, 56),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          padding: const EdgeInsets.symmetric(vertical: 16),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 20),
            const SizedBox(width: 10),
            Text(
              label,
              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
            ),
          ],
        ),
      ),
    );
  }

  // Helper methods
  String _getDisplayName() {
    return userData?['fullName']?.toString().trim() ??
        user?.displayName?.trim() ??
        user?.email?.split('@')[0]?.trim() ??
        "Guest User";
  }

  String _getUsername() {
    final username = userData?['username']?.toString().trim();
    if (username != null && username.isNotEmpty) {
      return "@$username";
    }
    final emailPrefix = user?.email?.split('@')[0]?.trim();
    if (emailPrefix != null && emailPrefix.isNotEmpty) {
      return "@$emailPrefix";
    }
    return "@guest";
  }

  Widget _buildCachedProfileImage() {
    final supabaseUrl = userData?['profileUrl']?.toString();
    final firebaseUrl = user?.photoURL;
    final url = supabaseUrl ?? firebaseUrl;

    if (url == null || url.isEmpty) {
      return const Center(
        child: Icon(
          Icons.person,
          size: 50,
          color: Colors.grey,
        ),
      );
    }

    return ClipOval(
      child: CachedNetworkImage(
        imageUrl: url,
        fit: BoxFit.cover,
        placeholder: (context, url) => Center(
          child: CircularProgressIndicator(
            strokeWidth: 2,
            color: Colors.blueGrey.shade300,
          ),
        ),
        errorWidget: (context, url, error) => const Center(
          child: Icon(
            Icons.person,
            size: 50,
            color: Colors.grey,
          ),
        ),
      ),
    );
  }

  Widget _buildFirestoreSection() {
    final details = _buildDetailItems();
    if (details.isEmpty) return const SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          "Account Details",
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
            color: Colors.black87,
          ),
        ),
        const SizedBox(height: 12),
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.grey.shade50,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Colors.grey.shade200),
          ),
          child: Column(children: details),
        ),
      ],
    );
  }

  List<Widget> _buildDetailItems() {
    final items = <Widget>[];

    if (userData?['email'] != null) {
      items.add(_buildDetailItem("Email", userData!['email'].toString()));
    }
    if (userData?['phone'] != null && userData!['phone'].toString().isNotEmpty) {
      items.add(_buildDetailItem("Phone", userData!['phone'].toString()));
    }
    if (userData?['gender'] != null && userData!['gender'].toString().isNotEmpty) {
      items.add(_buildDetailItem("Gender", userData!['gender'].toString()));
    }
    if (userData?['birthday'] != null && userData!['birthday'] is Timestamp) {
      final birthday = (userData!['birthday'] as Timestamp).toDate();
      items.add(_buildDetailItem(
        "Birthday",
        "${birthday.day}/${birthday.month}/${birthday.year}",
      ));
    }

    return items;
  }

  Widget _buildDetailItem(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 100,
            child: Text(
              "$label:",
              style: const TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w500,
                color: Colors.grey,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(
                fontSize: 15,
                color: Colors.black87,
              ),
            ),
          ),
        ],
      ),
    );
  }
}