import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:async';
import 'package:flutter_application_1/services/api_service.dart';

class RegisterPage extends StatefulWidget {
  const RegisterPage({super.key});

  @override
  State<RegisterPage> createState() => _RegisterPageState();
}

class _RegisterPageState extends State<RegisterPage> {

  final emailController = TextEditingController();
  final otpController = TextEditingController();
  final firstNameController = TextEditingController();
  final lastNameController = TextEditingController();
  final studentIdController = TextEditingController();
  final passwordController = TextEditingController();
  final confirmPasswordController = TextEditingController();

  bool otpSent = false;
  bool otpVerified = false;
  bool isLoading = false;

  bool obscurePassword = true;
  bool obscureConfirmPassword = true;

  int resendSeconds = 0;
  Timer? timer;

  final String baseUrl = ApiService.baseUrl;

  void showSnack(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(msg)),
    );
  }

  void startTimer() {
    resendSeconds = 120;
    timer?.cancel();

    timer = Timer.periodic(const Duration(seconds: 1), (t) {
      if (resendSeconds == 0) {
        t.cancel();
      } else {
        setState(() => resendSeconds--);
      }
    });
  }

  // ================= SEND OTP =================
  Future<void> sendOTP() async {
    if (emailController.text.isEmpty) {
      showSnack("Enter email");
      return;
    }

    setState(() => isLoading = true);

    try {
      final res = await http.post(
        Uri.parse("${baseUrl}/send-otp/"),
        headers: {"Content-Type": "application/json"},
        body: jsonEncode({"email": emailController.text.trim()}),
      );

      final data = jsonDecode(res.body);
      setState(() => isLoading = false);

      if (res.statusCode == 200) {
        setState(() => otpSent = true);
        startTimer();
        showSnack("OTP Sent");
      } else {
        showSnack(data["error"]);
      }
    } catch (e) {
      setState(() => isLoading = false);
      showSnack("Connection error");
    }
  }

  // ================= VERIFY OTP =================
  Future<void> verifyOTP() async {
    if (otpController.text.isEmpty) {
      showSnack("Enter OTP");
      return;
    }

    setState(() => isLoading = true);

    try {
      final res = await http.post(
        Uri.parse("${baseUrl}/verify-otp/"),
        headers: {"Content-Type": "application/json"},
        body: jsonEncode({
          "email": emailController.text.trim(),
          "otp": otpController.text.trim(),
        }),
      );

      final data = jsonDecode(res.body);
      setState(() => isLoading = false);

      if (res.statusCode == 200) {
        setState(() => otpVerified = true);
        showSnack("OTP Verified");
      } else {
        showSnack(data["error"]);
      }
    } catch (e) {
      setState(() => isLoading = false);
      showSnack("Connection error");
    }
  }

  // ================= REGISTER =================
  Future<void> register() async {

    if (firstNameController.text.isEmpty ||
        studentIdController.text.isEmpty ||
        passwordController.text.isEmpty ||
        confirmPasswordController.text.isEmpty) {

      showSnack("Fill all required fields");
      return;
    }

    if (passwordController.text != confirmPasswordController.text) {
      showSnack("Passwords do not match");
      return;
    }

    if (passwordController.text.length < 8) {
      showSnack("Password must be at least 8 characters");
      return;
    }

    setState(() => isLoading = true);

    try {
      final res = await http.post(
        Uri.parse("${baseUrl}/register/"),
        headers: {"Content-Type": "application/json"},
        body: jsonEncode({
          "email": emailController.text.trim(),
          "otp": otpController.text.trim(),
          "password": passwordController.text.trim(),
          "confirm_password": confirmPasswordController.text.trim(),
          "first_name": firstNameController.text.trim(),
          "last_name": lastNameController.text.trim(),
          "student_id": studentIdController.text.trim(),
        }),
      );

      final data = jsonDecode(res.body);
      setState(() => isLoading = false);

      if (res.statusCode == 201 || res.statusCode == 200) {
        showSnack("Registration successful");
        Navigator.pop(context);
      } else {
        showSnack(data["error"] ?? "Registration failed");
      }

    } catch (e) {
      setState(() => isLoading = false);
      showSnack("Connection error");
    }
  }

  @override
  void dispose() {
    timer?.cancel();
    super.dispose();
  }

  // ================= UI =================
  @override
Widget build(BuildContext context) {
  return Scaffold(
    // body: Container(
    //   decoration: const BoxDecoration(
    //     gradient: LinearGradient(
    //       colors: [
    //         Color(0xFF981D44),
    //           Color(0xFF6A1B9A),
    //       ],
    //       begin: Alignment.topLeft,
    //       end: Alignment.bottomRight,
    //     ),
    //   ),
      body: Container(
      color: Colors.grey[100], // light white background
      child: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: Card(
            elevation: 10,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(20),
            ),
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [

                  const Icon(Icons.person_add, size: 60, color: Color(0xFF981D44)),

                  const SizedBox(height: 10),

                  const Text(
                    "Create Account",
                    style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
                  ),

                  const SizedBox(height: 25),

                  /// EMAIL
                  TextField(
                    controller: emailController,
                    enabled: !otpSent,
                    decoration: const InputDecoration(
                      labelText: "Email",
                      prefixIcon: Icon(Icons.email_outlined),
                      border: OutlineInputBorder(),
                    ),
                  ),

                  const SizedBox(height: 15),

                  /// OTP
                  if (otpSent)
                    TextField(
                      controller: otpController,
                      enabled: !otpVerified,
                      decoration: const InputDecoration(
                        labelText: "OTP",
                        prefixIcon: Icon(Icons.lock_clock),
                        border: OutlineInputBorder(),
                      ),
                    ),

                  if (otpSent && resendSeconds > 0)
                    Padding(
                      padding: const EdgeInsets.only(top: 8),
                      child: Text("Resend in $resendSeconds sec"),
                    ),

                  if (otpSent && resendSeconds == 0)
                    TextButton(
                      onPressed: sendOTP,
                      child: const Text("Resend OTP"),
                    ),

                  /// FULL FORM
                  if (otpVerified) ...[
                    const SizedBox(height: 20),

                    TextField(
                      controller: firstNameController,
                      decoration: const InputDecoration(
                        labelText: "First Name *",
                        prefixIcon: Icon(Icons.person_outline),
                        border: OutlineInputBorder(),
                      ),
                    ),

                    const SizedBox(height: 15),

                    TextField(
                      controller: lastNameController,
                      decoration: const InputDecoration(
                        labelText: "Last Name",
                        prefixIcon: Icon(Icons.person),
                        border: OutlineInputBorder(),
                      ),
                    ),

                    const SizedBox(height: 15),

                    TextField(
                      controller: studentIdController,
                      decoration: const InputDecoration(
                        labelText: "ID Number *",
                        prefixIcon: Icon(Icons.badge_outlined),
                        border: OutlineInputBorder(),
                      ),
                    ),

                    const SizedBox(height: 15),

                    TextField(
                      controller: passwordController,
                      obscureText: obscurePassword,
                      decoration: InputDecoration(
                        labelText: "Password *",
                        prefixIcon: const Icon(Icons.lock_outline),
                        border: const OutlineInputBorder(),
                        suffixIcon: IconButton(
                          icon: Icon(obscurePassword
                              ? Icons.visibility
                              : Icons.visibility_off),
                          onPressed: () {
                            setState(() {
                              obscurePassword = !obscurePassword;
                            });
                          },
                        ),
                      ),
                    ),

                    const SizedBox(height: 15),

                    TextField(
                      controller: confirmPasswordController,
                      obscureText: obscureConfirmPassword,
                      decoration: InputDecoration(
                        labelText: "Confirm Password *",
                        prefixIcon: const Icon(Icons.lock),
                        border: const OutlineInputBorder(),
                        suffixIcon: IconButton(
                          icon: Icon(obscureConfirmPassword
                              ? Icons.visibility
                              : Icons.visibility_off),
                          onPressed: () {
                            setState(() {
                              obscureConfirmPassword =
                                  !obscureConfirmPassword;
                            });
                          },
                        ),
                      ),
                    ),
                  ],

                  const SizedBox(height: 25),

                  /// BUTTON
                  isLoading
                      ? const CircularProgressIndicator()
                      : ElevatedButton(
                          onPressed: () {
                            if (!otpSent) {
                              sendOTP();
                            } else if (!otpVerified) {
                              verifyOTP();
                            } else {
                              register();
                            }
                          },
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF981D44),
                            minimumSize: const Size(double.infinity, 55),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                          child: Text(
                            !otpSent
                                ? "SEND OTP"
                                : !otpVerified
                                    ? "VERIFY OTP"
                                    : "REGISTER",
                            style: const TextStyle(
                                fontSize: 16, color: Colors.white),
                          ),
                        ),

                  const SizedBox(height: 10),

                  TextButton(
                    onPressed: () => Navigator.pop(context),
                    child: const Text("Already have an account? Login"),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    ),
  );
}
}