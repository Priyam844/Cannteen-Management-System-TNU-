import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_application_1/services/api_service.dart';
import 'package:image_picker/image_picker.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter_application_1/pages/student/wallet_history_page.dart';

class ProfilePage extends StatefulWidget {
  const ProfilePage({super.key});

  @override
  State<ProfilePage> createState() => _ProfilePageState();
}

class _ProfilePageState extends State<ProfilePage> {
  String firstName = "";
  String lastName = "";
  String email = "";
  String studentId = "";
  String hostel = "";
  String phone = "";
  String? profilePic;
  double walletBalance = 0.0;
  final Color primaryMaroon = const Color.fromARGB(255, 152, 29, 68);

  bool isLoading = true;
  bool isEditing = false;
  File? _imageFile;

  final TextEditingController firstNameController = TextEditingController();
  final TextEditingController lastNameController = TextEditingController();
  final TextEditingController phoneController = TextEditingController();

  Future<void> fetchProfile() async {
    try {
      final res = await ApiService.get("/profile/");
      final data = jsonDecode(res.body);

      setState(() {
        firstName = data["first_name"] ?? "";
        lastName = data["last_name"] ?? "";
        email = data["email"] ?? "";
        studentId = data["student_id"] ?? "";
        hostel = data["hostel"] ?? "";
        phone = data["phone"] ?? "";
        profilePic = data["profile_picture"];
        walletBalance = double.tryParse(data["wallet_balance"].toString()) ?? 0.0;

        firstNameController.text = firstName;
        lastNameController.text = lastName;
        phoneController.text = phone;

        isLoading = false;
      });

      // Save to shared prefs for drawers
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString("user_name", "$firstName $lastName");
      await prefs.setString("user_email", email);
      if (profilePic != null) await prefs.setString("user_pic", profilePic!);
      
    } catch (e) {
      setState(() => isLoading = false);
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Error: $e")));
    }
  }

  Future<void> pickImage() async {
    final picker = ImagePicker();
    final pickedFile = await picker.pickImage(source: ImageSource.gallery);

    if (pickedFile != null) {
      setState(() {
        _imageFile = File(pickedFile.path);
        isEditing = true; // Automatically enter edit mode if image picked
      });
    }
  }

  Future<void> updateProfile() async {
    setState(() => isLoading = true);
    try {
      final fields = {
        "first_name": firstNameController.text.trim(),
        "last_name": lastNameController.text.trim(),
        "phone": phoneController.text.trim(),
      };

      final responseStream = await ApiService.putMultipart(
        "/update-profile/",
        fields,
        "profile_picture",
        _imageFile?.path,
      );

      final responseBody = await responseStream.stream.bytesToString();

      if (responseStream.statusCode == 200) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Profile updated!")));
        setState(() {
          isEditing = false;
          _imageFile = null;
        });
        fetchProfile();
      } else {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Update failed: $responseBody")));
        setState(() => isLoading = false);
      }
    } catch (e) {
      setState(() => isLoading = false);
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Error: $e")));
    }
  }

  @override
  void initState() {
    super.initState();
    fetchProfile();
  }

  Widget buildInfoTile(String title, String value, {TextEditingController? controller, bool editable = false}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        children: [
          Expanded(
            flex: 3,
            child: Text(title, style: const TextStyle(fontWeight: FontWeight.w600, color: Colors.grey)),
          ),
          Expanded(
            flex: 5,
            child: isEditing && editable
                ? TextField(controller: controller, decoration: const InputDecoration(isDense: true))
                : Text(value.isEmpty ? "-" : value, style: const TextStyle(fontWeight: FontWeight.w500)),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Profile", style: TextStyle(color: Colors.white)),
        centerTitle: true,
        backgroundColor: const Color.fromARGB(255, 152, 29, 68),
        actions: [
          IconButton(
            icon: Icon(isEditing ? Icons.save : Icons.edit, color: Colors.white),
            onPressed: () {
              if (isEditing) {
                updateProfile();
              } else {
                setState(() => isEditing = true);
              }
            },
          ),
          if (isEditing)
            IconButton(
              icon: const Icon(Icons.cancel, color: Colors.white),
              onPressed: () => setState(() => isEditing = false),
            ),
        ],
      ),
      body: isLoading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Column(
                children: [
                  GestureDetector(
                    onTap: pickImage,
                    child: Stack(
                      children: [
                        CircleAvatar(
                          radius: 60,
                          backgroundColor: Colors.grey[300],
                          backgroundImage: _imageFile != null
                              ? FileImage(_imageFile!) as ImageProvider
                              : (profilePic != null ? NetworkImage(profilePic!) : null),
                          child: (profilePic == null && _imageFile == null)
                              ? const Icon(Icons.person, size: 80, color: Colors.white)
                              : null,
                        ),
                        if (isEditing)
                          Positioned(
                            bottom: 0,
                            right: 0,
                            child: CircleAvatar(
                              backgroundColor: const Color.fromARGB(255, 152, 29, 68),
                              radius: 18,
                              child: const Icon(Icons.camera_alt, size: 18, color: Colors.white),
                            ),
                          ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 20),
                  Card(
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    elevation: 4,
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        children: [
                          buildInfoTile("First Name", firstName, controller: firstNameController, editable: true),
                          buildInfoTile("Last Name", lastName, controller: lastNameController, editable: true),
                          buildInfoTile("Email", email),
                          buildInfoTile("Student ID", studentId),
                          buildInfoTile("Hostel", hostel),
                          buildInfoTile("Phone", phone, controller: phoneController, editable: true),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 20),
                  _buildWalletSection(),
                ],
              ),
            ),
    );
  }

  Widget _buildWalletSection() {
    return Card(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      elevation: 4,
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text("Available Balance", style: TextStyle(color: Colors.grey, fontSize: 13)),
                    Text("₹${walletBalance.toStringAsFixed(2)}", style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: primaryMaroon)),
                  ],
                ),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(color: primaryMaroon.withOpacity(0.1), shape: BoxShape.circle),
                  child: Icon(Icons.account_balance_wallet_rounded, color: primaryMaroon),
                ),
              ],
            ),
            const Divider(height: 32),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: () {
                  Navigator.push(context, MaterialPageRoute(builder: (_) => const WalletHistoryPage()));
                },
                icon: const Icon(Icons.history_rounded, size: 18),
                label: const Text("Transaction History"),
                style: ElevatedButton.styleFrom(
                  backgroundColor: primaryMaroon,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}