
import 'package:flutter/material.dart';
import 'home_page.dart';
// import 'package:http/http.dart' as http;
import 'dart:convert';
import 'signup_page.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'manager_home_page.dart';
import 'admin_home_page.dart';
import 'api_service.dart'; // 🔥 add this at topr

////////////////////////////////////////////////////////////
/// ROLE ENUM
////////////////////////////////////////////////////////////
enum UserRole { student, manager, admin }

class LoginPage extends StatefulWidget {
  const LoginPage({super.key});

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  final TextEditingController emailController = TextEditingController();
  final TextEditingController passwordController = TextEditingController();

  bool isLoading = false;
  UserRole selectedRole = UserRole.student;

  ////////////////////////////////////////////////////////////
  /// ROLE CONFIG
  ////////////////////////////////////////////////////////////
  static const _roleConfig = {
    UserRole.student: (
      label: 'Student',
      icon: Icons.school_rounded,
      color: Color.fromARGB(255, 152, 29, 68),
    ),
    UserRole.manager: (
      label: 'Manager',
      icon: Icons.manage_accounts_rounded,
      color: Color.fromARGB(255, 152, 29, 68),
    ),
    UserRole.admin: (
      label: 'Admin',
      icon: Icons.admin_panel_settings_rounded,
      color: Color.fromARGB(255, 152, 29, 68),
    ),
  };

  Color get _activeColor => _roleConfig[selectedRole]!.color;
  String get _roleLabel => _roleConfig[selectedRole]!.label;
  IconData get _roleIcon => _roleConfig[selectedRole]!.icon;

  ////////////////////////////////////////////////////////////
  /// LOGIN FUNCTION
  ////////////////////////////////////////////////////////////
void login() async {
  String email = emailController.text.trim();
  String password = passwordController.text.trim();

  if (email.isEmpty || password.isEmpty) {
    showSnack("Please fill all fields");
    return;
  }

  setState(() => isLoading = true);

  try {
    final response = await ApiService.publicPost(
      "/login/",
      {
        "email": email,
        "password": password,
        "role": _roleLabel.toLowerCase(),
      },
    );

    setState(() => isLoading = false);

    final data = jsonDecode(response.body);

    if (response.statusCode == 200) {
      String accessToken = data["access"];
      String refreshToken = data["refresh"];
      String role = data["user"]["role"];

      final prefs = await SharedPreferences.getInstance();
      await prefs.setString("access", accessToken);
      await prefs.setString("refresh", refreshToken);
      await prefs.setString("role", role);
      await prefs.setString("user_name", data["user"]["name"] ?? "User");
      await prefs.setString("user_email", data["user"]["email"] ?? "");
      await prefs.setString("user_hostel", data["user"]["hostel"] ?? "Hostel");

      if (!mounted) return;

      if (role == "manager") {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (_) => const ManagerHomePage()),
        );
      } else if (role == "admin") {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (_) => const AdminHomePage()),
        );
      } else {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (_) => const HomePage()),
        );
      }
    } else {
      showSnack(data["error"] ?? "Login failed");
    }
  } catch (e) {
    setState(() => isLoading = false);
    print("ERROR: $e");
    showSnack("Connection error");
  }
}

  ////////////////////////////////////////////////////////////
  /// SNACKBAR
  ////////////////////////////////////////////////////////////
  void showSnack(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(msg),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  ////////////////////////////////////////////////////////////
  /// DISPOSE
  ////////////////////////////////////////////////////////////
  @override
  void dispose() {
    emailController.dispose();
    passwordController.dispose();
    super.dispose();
  }

  ////////////////////////////////////////////////////////////
  /// UI
  ////////////////////////////////////////////////////////////
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[100],
      body: GestureDetector(
        onTap: () => FocusScope.of(context).unfocus(),
        child: Center(
          child: SingleChildScrollView(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [

                  /// 🔷 LOGO
                  Column(
                    children: [
                      SizedBox(
                        height: 70,
                        child: Image.asset(
                          'assets/images/tnu1.png',
                          fit: BoxFit.contain,
                        ),
                      ),
                      const SizedBox(height: 10),
                      const Text(
                        "Canteen Management",
                        style: TextStyle(
                          fontSize: 24,
                          fontWeight: FontWeight.bold,
                          color: Color.fromARGB(255, 152, 29, 68),
                          letterSpacing: 1.1,
                        ),
                      ),
                    ],
                  ),

                  const SizedBox(height: 20),

                  /// 🔷 ROLE TOGGLE
                  Container(
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(14),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black12,
                          blurRadius: 6,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                    padding: const EdgeInsets.all(5),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: UserRole.values.map((role) {
                        final cfg = _roleConfig[role]!;
                        final isSelected = selectedRole == role;
                        return GestureDetector(
                          onTap: () => setState(() => selectedRole = role),
                          child: AnimatedContainer(
                            duration: const Duration(milliseconds: 220),
                            curve: Curves.easeInOut,
                            padding: const EdgeInsets.symmetric(
                                horizontal: 16, vertical: 10),
                            decoration: BoxDecoration(
                              color: isSelected ? cfg.color : Colors.transparent,
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: Row(
                              children: [
                                Icon(
                                  cfg.icon,
                                  size: 16,
                                  color: isSelected ? Colors.white : Colors.grey[600],
                                ),
                                const SizedBox(width: 5),
                                Text(
                                  cfg.label,
                                  style: TextStyle(
                                    fontSize: 13,
                                    fontWeight: FontWeight.w600,
                                    color: isSelected
                                        ? Colors.white
                                        : Colors.grey[700],
                                  ),
                                ),
                              ],
                            ),
                          ),
                        );
                      }).toList(),
                    ),
                  ),

                  const SizedBox(height: 20),

                  /// 🔷 CARD
                  AnimatedContainer(
                    duration: const Duration(milliseconds: 300),
                    curve: Curves.easeInOut,
                    child: Card(
                      elevation: 8,
                      shadowColor: Colors.black26,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(20),
                        side: BorderSide(
                          color: _activeColor.withOpacity(0.2),
                          width: 1.5,
                        ),
                      ),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [

                            /// Animated icon + title
                            AnimatedSwitcher(
                              duration: const Duration(milliseconds: 300),
                              child: Container(
                                key: ValueKey(selectedRole),
                                padding: const EdgeInsets.all(16),
                                decoration: BoxDecoration(
                                  color: _activeColor.withOpacity(0.1),
                                  shape: BoxShape.circle,
                                ),
                                child: Icon(
                                  _roleIcon,
                                  size: 45,
                                  color: _activeColor,
                                ),
                              ),
                            ),

                            const SizedBox(height: 16),

                            AnimatedSwitcher(
                              duration: const Duration(milliseconds: 200),
                              child: Text(
                                "$_roleLabel Login",
                                key: ValueKey(selectedRole),
                                style: const TextStyle(
                                  fontSize: 22,
                                  fontWeight: FontWeight.bold,
                                  letterSpacing: 1.1,
                                ),
                              ),
                            ),

                            const SizedBox(height: 32),

                            /// 🔷 EMAIL
                            TextField(
                              controller: emailController,
                              keyboardType: TextInputType.emailAddress,
                              decoration: InputDecoration(
                                labelText: "Email",
                                prefixIcon: Icon(Icons.email_outlined, color: _activeColor.withOpacity(0.7)),
                                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                                focusedBorder: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(12),
                                  borderSide: BorderSide(color: _activeColor, width: 2),
                                ),
                                labelStyle: TextStyle(color: Colors.grey[600]),
                                floatingLabelStyle: TextStyle(color: _activeColor, fontWeight: FontWeight.bold),
                              ),
                            ),

                            const SizedBox(height: 20),

                            /// 🔷 PASSWORD
                            TextField(
                              controller: passwordController,
                              obscureText: true,
                              decoration: InputDecoration(
                                labelText: "Password",
                                prefixIcon: Icon(Icons.lock_outline, color: _activeColor.withOpacity(0.7)),
                                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                                focusedBorder: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(12),
                                  borderSide: BorderSide(color: _activeColor, width: 2),
                                ),
                                labelStyle: TextStyle(color: Colors.grey[600]),
                                floatingLabelStyle: TextStyle(color: _activeColor, fontWeight: FontWeight.bold),
                              ),
                            ),

                            const SizedBox(height: 30),

                            /// 🔷 LOGIN BUTTON
                            isLoading
                                ? CircularProgressIndicator(color: _activeColor)
                                : ElevatedButton(
                                    onPressed: login,
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: _activeColor,
                                      foregroundColor: Colors.white,
                                      minimumSize: const Size(double.infinity, 55),
                                      elevation: 4,
                                      shadowColor: _activeColor.withOpacity(0.4),
                                      shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(12),
                                      ),
                                    ),
                                    child: const Text(
                                      "LOGIN",
                                      style: TextStyle(
                                        fontSize: 16,
                                        fontWeight: FontWeight.bold,
                                        letterSpacing: 1.2,
                                      ),
                                    ),
                                  ),

                            const SizedBox(height: 16),

                            /// 🔷 SIGNUP (student only)
                            if (selectedRole == UserRole.student)
                              TextButton(
                                onPressed: () {
                                  Navigator.push(
                                    context,
                                    MaterialPageRoute(
                                        builder: (_) => const RegisterPage()),
                                  );
                                },
                                child: Text(
                                  "Don't have an account? Sign Up",
                                  style: TextStyle(
                                    fontSize: 14,
                                    color: Colors.blue.shade800,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}