// lib/screens/profile/edit_profile_screen.dart

import 'dart:io';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:signlinggo/services/supabase_storage_service.dart';

class EditProfilePage extends StatefulWidget {
  const EditProfilePage({super.key});

  @override
  State<EditProfilePage> createState() => _EditProfilePageState();
}

class _EditProfilePageState extends State<EditProfilePage> {
  final User user = FirebaseAuth.instance.currentUser!;
  final ImagePicker picker = ImagePicker();
  final SupabaseStorageService supabaseService = SupabaseStorageService();
  final FirebaseFirestore firestore = FirebaseFirestore.instance;

  final TextEditingController nameC = TextEditingController();
  final TextEditingController usernameC = TextEditingController();
  final TextEditingController emailC = TextEditingController();
  final TextEditingController phoneC = TextEditingController();

  String? gender;
  DateTime? birthday;
  String? profileUrl;
  File? imageFile;
  bool isSaving = false;
  bool hasNewImage = false;
  bool isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadUserData();
  }

  Future<void> _loadUserData() async {
    try {
      final DocumentSnapshot doc = await firestore
          .collection("users")
          .doc(user.uid)
          .get();

      if (doc.exists) {
        final data = doc.data() as Map<String, dynamic>;
        
        nameC.text = data["fullName"]?.toString() ?? "";
        usernameC.text = data["username"]?.toString() ?? "";
        emailC.text = data["email"]?.toString() ?? user.email ?? "";
        phoneC.text = data["phone"]?.toString() ?? "";
        gender = data["gender"]?.toString();
        profileUrl = data["profileUrl"]?.toString();
        
        if (data["birthday"] != null) {
          birthday = (data["birthday"] as Timestamp).toDate();
        }
      } else {
        // Initialize with Firebase auth data if no Firestore document exists
        nameC.text = user.displayName ?? "";
        emailC.text = user.email ?? "";
        profileUrl = user.photoURL;
      }
    } catch (e) {
      print("❌ Error loading user data: $e");
    } finally {
      setState(() => isLoading = false);
    }
  }

  Future<void> _pickImage() async {
    try {
      final XFile? image = await picker.pickImage(
        source: ImageSource.gallery,
        imageQuality: 85,
        maxWidth: 800,
      );
      
      if (image != null) {
        setState(() {
          imageFile = File(image.path);
          hasNewImage = true;
        });
      }
    } catch (e) {
      print("❌ Image picker error: $e");
      _showErrorSnackbar("Failed to pick image");
    }
  }

  Future<void> _saveProfile() async {
    if (isSaving) return;
    
    // Validate required fields
    if (nameC.text.trim().isEmpty) {
      _showErrorSnackbar("Full name is required");
      return;
    }

    if (usernameC.text.trim().isEmpty) {
      _showErrorSnackbar("Username is required");
      return;
    }

    setState(() => isSaving = true);

    try {
      String? imageUrl = profileUrl;

      // If new image picked → upload to Supabase
      if (hasNewImage && imageFile != null) {
        print("📤 Uploading new profile image...");
        
        final uploadedUrl = await supabaseService.uploadProfileImage(imageFile!);

        if (uploadedUrl != null) {
          imageUrl = uploadedUrl;
          print("✅ Image uploaded successfully: $imageUrl");

          // Update Firebase Auth Photo URL (optional but good for consistency)
          try {
            await user.updateProfile(photoURL: imageUrl);
            await user.reload();
          } catch (e) {
            print("⚠️ Firebase Auth update failed: $e");
            // Continue anyway - Firestore is our primary storage
          }
        } else {
          throw Exception("Failed to upload profile picture to Supabase");
        }
      }

      // Prepare update data
      final Map<String, dynamic> updateData = {
        "fullName": nameC.text.trim(),
        "username": usernameC.text.trim(),
        "email": emailC.text.trim(),
        "phone": phoneC.text.trim(),
        "gender": gender,
        "profileUrl": imageUrl,
        "updatedAt": FieldValue.serverTimestamp(),
      };

      // Add birthday if selected
      if (birthday != null) {
        updateData["birthday"] = Timestamp.fromDate(birthday!);
      }

      // Update Firestore - using set with merge to create if doesn't exist
      await firestore
          .collection("users")
          .doc(user.uid)
          .set(updateData, SetOptions(merge: true));

      print("✅ Profile saved successfully!");

      if (mounted) {
        // Use GoRouter to pop with true value
        GoRouter.of(context).pop(true);
      }
    } catch (e) {
      print("❌ Error saving profile: $e");
      if (mounted) {
        _showErrorSnackbar("Error saving profile: ${e.toString()}");
      }
    } finally {
      if (mounted) {
        setState(() => isSaving = false);
      }
    }
  }

  void _showErrorSnackbar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.red,
        duration: const Duration(seconds: 3),
      ),
    );
  }

  Future<void> _showBirthdayPicker() async {
    final DateTime? pickedDate = await showDatePicker(
      context: context,
      initialDate: birthday ?? DateTime.now().subtract(const Duration(days: 365 * 18)),
      firstDate: DateTime(1900),
      lastDate: DateTime.now(),
      initialEntryMode: DatePickerEntryMode.calendarOnly,
    );
    
    if (pickedDate != null && pickedDate != birthday) {
      setState(() => birthday = pickedDate);
    }
  }

  String _formatBirthday(DateTime? date) {
    if (date == null) return "Select your birthday";
    return "${date.day.toString().padLeft(2, '0')}/${date.month.toString().padLeft(2, '0')}/${date.year}";
  }

  @override
  Widget build(BuildContext context) {
    if (isLoading) {
      return const Scaffold(
        body: Center(
          child: CircularProgressIndicator(),
        ),
      );
    }

    return Scaffold(
      backgroundColor: Colors.grey.shade200,
      body: SafeArea(
        child: Stack(
          children: [
            ListView(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 40),
              children: [
                // Profile Image Section
                Center(
                  child: Stack(
                    children: [
                      GestureDetector(
                        onTap: _pickImage,
                        child: CircleAvatar(
                          radius: 60,
                          backgroundColor: Colors.grey.shade300,
                          backgroundImage: _getProfileImage(),
                        ),
                      ),
                      Positioned(
                        bottom: 0,
                        right: 0,
                        child: GestureDetector(
                          onTap: _pickImage,
                          child: Container(
                            padding: const EdgeInsets.all(6),
                            decoration: BoxDecoration(
                              color: Colors.blue.shade700,
                              shape: BoxShape.circle,
                              border: Border.all(color: Colors.white, width: 3),
                            ),
                            child: const Icon(
                              Icons.edit,
                              color: Colors.white,
                              size: 18,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 20),
                
                // Edit Form Card
                Card(
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(20),
                  ),
                  elevation: 4,
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 25),
                    child: Column(
                      children: [
                        // Header with Save Button
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            const Text(
                              "Edit Profile",
                              style: TextStyle(
                                fontSize: 22,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            isSaving
                                ? const CircularProgressIndicator()
                                : ElevatedButton(
                                    onPressed: _saveProfile,
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: Colors.green.shade600,
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 24,
                                        vertical: 12,
                                      ),
                                      shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(15),
                                      ),
                                    ),
                                    child: const Text(
                                      "SAVE",
                                      style: TextStyle(
                                        fontWeight: FontWeight.bold,
                                        color: Colors.white,
                                      ),
                                    ),
                                  ),
                          ],
                        ),
                        const SizedBox(height: 20),
                        
                        // Form Fields
                        _buildTextField("Full Name", nameC, TextInputType.name),
                        const SizedBox(height: 12),
                        _buildTextField("Username", usernameC, TextInputType.text),
                        const SizedBox(height: 12),
                        _buildTextField("Email", emailC, TextInputType.emailAddress),
                        const SizedBox(height: 12),
                        _buildTextField("Phone Number", phoneC, TextInputType.phone),
                        const SizedBox(height: 12),
                        _buildGenderDropdown(),
                        const SizedBox(height: 12),
                        _buildBirthdayPicker(),
                        const SizedBox(height: 25),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 30),
              ],
            ),
            
            // Back Button
            Positioned(
              left: 20,
              top: 40,
              child: CircleAvatar(
                backgroundColor: Colors.white,
                radius: 20,
                child: IconButton(
                  icon: const Icon(Icons.arrow_back, size: 20, color: Colors.black),
                  // onPressed: () => Navigator.of(context).pop(false),
                  onPressed: () => GoRouter.of(context).pop(false),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  ImageProvider? _getProfileImage() {
    if (imageFile != null) {
      return FileImage(imageFile!);
    } else if (profileUrl != null && profileUrl!.isNotEmpty) {
      return NetworkImage(profileUrl!);
    }
    return null;
  }

  Widget _buildTextField(String label, TextEditingController controller, TextInputType keyboardType) {
    return TextField(
      controller: controller,
      keyboardType: keyboardType,
      decoration: InputDecoration(
        labelText: label,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
        ),
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      ),
    );
  }

  Widget _buildGenderDropdown() {
    return DropdownButtonFormField<String>(
      value: gender,
      decoration: InputDecoration(
        labelText: "Gender",
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
        ),
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      ),
      items: const [
        DropdownMenuItem(value: "Male", child: Text("Male")),
        DropdownMenuItem(value: "Female", child: Text("Female")),
        DropdownMenuItem(value: "Other", child: Text("Other")),
        DropdownMenuItem(value: "Prefer not to say", child: Text("Prefer not to say")),
      ],
      onChanged: (value) => setState(() => gender = value),
    );
  }

  Widget _buildBirthdayPicker() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          "Birthday",
          style: TextStyle(
            fontSize: 16,
            color: Colors.black87,
            fontWeight: FontWeight.w500,
          ),
        ),
        const SizedBox(height: 8),
        GestureDetector(
          onTap: _showBirthdayPicker,
          child: Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            decoration: BoxDecoration(
              border: Border.all(color: Colors.grey.shade400),
              borderRadius: BorderRadius.circular(12),
              color: Colors.white,
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  _formatBirthday(birthday),
                  style: TextStyle(
                    fontSize: 16,
                    color: birthday == null ? Colors.grey.shade500 : Colors.black87,
                  ),
                ),
                Icon(
                  Icons.calendar_today,
                  color: Colors.grey.shade600,
                  size: 20,
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  @override
  void dispose() {
    nameC.dispose();
    usernameC.dispose();
    emailC.dispose();
    phoneC.dispose();
    super.dispose();
  }
}