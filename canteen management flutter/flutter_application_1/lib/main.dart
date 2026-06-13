import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter_application_1/pages/auth/login_page.dart';
import 'package:flutter_application_1/pages/student/student_home_page.dart';
import 'package:flutter_application_1/pages/manager/manager_home_page.dart';
import 'package:flutter_application_1/pages/admin/admin_home_page.dart';
import 'package:flutter_application_1/pages/faculty/faculty_home_page.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final prefs = await SharedPreferences.getInstance();
  final String? token = prefs.getString("access");
  final String? role = prefs.getString("role");

  runApp(MyApp(token: token, role: role));
}

class MyApp extends StatelessWidget {
  final String? token;
  final String? role;

  const MyApp({super.key, this.token, this.role});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Canteen App',
      theme: ThemeData(
        primarySwatch: Colors.teal,
        scaffoldBackgroundColor: const Color(0xFFF5F7FA),
        fontFamily: 'Roboto',
      ),
      home: _getHome(),
    );
  }

  Widget _getHome() {
    if (token == null || token!.isEmpty) {
      return const LoginPage();
    }
    
    if (role == "manager") {
      return const ManagerHomePage();
    } else if (role == "admin") {
      return const AdminHomePage();
    } else if (role == "faculty") {
      return const FacultyHomePage();
    } else {
      return const StudentHomePage();
    }
  }
}
