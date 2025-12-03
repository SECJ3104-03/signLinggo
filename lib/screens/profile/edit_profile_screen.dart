import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:image_picker/image_picker.dart';
import 'dart:io';

class EditProfileScreen extends StatefulWidget {
  const EditProfileScreen({super.key});

  @override
  State<EditProfileScreen> createState() => _EditProfileScreenState();
}

class _EditProfileScreenState extends State<EditProfileScreen> {
  final supabase = Supabase.instance.client;

  final TextEditingController fullNameCtrl = TextEditingController();
  final TextEditingController usernameCtrl = TextEditingController();
  final TextEditingController phoneCtrl = TextEditingController();
  final TextEditingController birthCtrl = TextEditingController();
  String gender = 'Male';
  File? profileImage;
  bool isLoading = false;

  Map<String, dynamic> initialData = {};
  bool hasChanges = false;

  @override
  void initState() {
    super.initState();
    _loadUserData();
    fullNameCtrl.addListener(_checkChanges);
    usernameCtrl.addListener(_checkChanges);
    phoneCtrl.addListener(_checkChanges);
    birthCtrl.addListener(_checkChanges);
  }

  void _checkChanges() {
    bool changed = fullNameCtrl.text != (initialData['fullName'] ?? '') ||
        usernameCtrl.text != (initialData['username'] ?? '') ||
        phoneCtrl.text != (initialData['phone'] ?? '') ||
        birthCtrl.text != (initialData['birth'] ?? '') ||
        gender != (initialData['gender'] ?? 'Male') ||
        profileImage != null;

    setState(() => hasChanges = changed);
  }

  Future<void> _loadUserData() async {
    final userId = supabase.auth.currentUser?.id;
    if (userId == null) return;

    final response =
        await supabase.from('profiles').select().eq('id', userId).single();
    if (response != null) {
      setState(() {
        fullNameCtrl.text = response['full_name'] ?? '';
        usernameCtrl.text = response['username'] ?? '';
        phoneCtrl.text = response['phone'] ?? '';
        birthCtrl.text = response['birth'] ?? '';
        gender = response['gender'] ?? 'Male';

        initialData = {
          'fullName': fullNameCtrl.text,
          'username': usernameCtrl.text,
          'phone': phoneCtrl.text,
          'birth': birthCtrl.text,
          'gender': gender,
        };
      });
    }
  }

  Future<String?> _uploadProfileImage() async {
    if (profileImage == null) return null;
    final userId = supabase.auth.currentUser?.id;
    if (userId == null) return null;

    final fileName = '$userId-${DateTime.now().millisecondsSinceEpoch}.jpg';
    final fileBytes = await profileImage!.readAsBytes();

    final response = await supabase.storage
        .from('avatars')
        .uploadBinary(fileName, fileBytes);

    final publicUrl = supabase.storage.from('avatars').getPublicUrl(fileName);
    return publicUrl;
  }

  Future<void> _saveProfile() async {
    setState(() => isLoading = true);
    final userId = supabase.auth.currentUser?.id;
    if (userId == null) return;

    try {
      final imageUrl = await _uploadProfileImage();

      await supabase.from('profiles').upsert({
        'id': userId,
        'full_name': fullNameCtrl.text,
        'username': usernameCtrl.text,
        'phone': phoneCtrl.text,
        'birth': birthCtrl.text,
        'gender': gender,
        'avatar_url': imageUrl ?? initialData['avatar_url'],
      });

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Profile updated successfully!')),
      );

      setState(() {
        hasChanges = false;
        profileImage = null;
      });
    } catch (e) {
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('Error: $e')));
    }

    setState(() => isLoading = false);
  }

  Future<void> _pickProfileImage() async {
    final picker = ImagePicker();
    final picked = await picker.pickImage(source: ImageSource.gallery);
    if (picked != null) {
      setState(() => profileImage = File(picked.path));
      _checkChanges();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Edit Profile')),
      body: isLoading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.all(20),
              child: Column(
                children: [
                  // Avatar
                  Center(
                    child: Stack(
                      children: [
                        CircleAvatar(
                          radius: 50,
                          backgroundImage: profileImage != null
                              ? FileImage(profileImage!)
                              : (initialData['avatar_url'] != null
                                  ? NetworkImage(initialData['avatar_url'])
                                  : const AssetImage('assets/profile.png')
                                      as ImageProvider),
                        ),
                        Positioned(
                          bottom: 0,
                          right: 0,
                          child: GestureDetector(
                            onTap: _pickProfileImage,
                            child: const CircleAvatar(
                              radius: 16,
                              backgroundColor: Color(0xFF11497C),
                              child: Icon(Icons.edit, color: Colors.white),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 20),
                  buildTextField('Full Name', fullNameCtrl),
                  buildTextField('Username', usernameCtrl),
                  buildTextField('Phone', phoneCtrl),
                  buildTextField('Birth', birthCtrl),
                  buildTextField('Gender', TextEditingController(text: gender),
                      enabled: false),
                  const SizedBox(height: 20),
                  ElevatedButton(
                    onPressed: hasChanges ? _saveProfile : null,
                    child: const Text('SAVE'),
                  ),
                ],
              ),
            ),
    );
  }

  Widget buildTextField(String label, TextEditingController ctrl,
      {bool enabled = true}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: TextField(
        controller: ctrl,
        enabled: enabled,
        decoration: InputDecoration(
          labelText: label,
          border: const OutlineInputBorder(),
        ),
      ),
    );
  }
}