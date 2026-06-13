import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter_application_1/pages/manager/manager_home_page.dart';
import 'package:flutter_application_1/pages/auth/login_page.dart';
import 'package:flutter_application_1/pages/manager/manager_qr_scan_page.dart';
import 'package:flutter_application_1/pages/manager/manager_feedback_page.dart';
import 'package:flutter_application_1/pages/admin/student_list_page.dart';
import 'package:flutter_application_1/pages/manager/manager_menu_page.dart';
import 'package:flutter_application_1/pages/admin/allowed_users_page.dart';
import 'package:flutter_application_1/pages/manager/manager_reports_page.dart';
import 'package:flutter_application_1/pages/manager/manager_announcements_page.dart';
import 'package:flutter_application_1/pages/manager/manager_next_day_booking_page.dart';

// 💡 Import your other manager pages here as you create them:
// import 'manager_meals_page.dart';
// import 'manager_students_page.dart';
// import 'manager_reports_page.dart';
// import 'manager_announcements_page.dart';

class ManagerDrawer extends StatefulWidget {
  const ManagerDrawer({super.key});

  @override
  State<ManagerDrawer> createState() => _ManagerDrawerState();
}

class _ManagerDrawerState extends State<ManagerDrawer> {
  static const double _iconSize = 30.0;
  static const double _fontSize = 18.0;
  static const Color _primaryColor = Color.fromARGB(255, 152, 29, 68);

  String name = "Manager";
  String email = "manager@hostel.edu";
  String hostel = "";
  String? profilePic;

  @override
  void initState() {
    super.initState();
    _loadUser();
  }

  Future<void> _loadUser() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      name = prefs.getString("user_name") ?? "Manager";
      email = prefs.getString("user_email") ?? "manager@hostel.edu";
      hostel = prefs.getString("user_hostel") ?? "Hostel";
      profilePic = prefs.getString("user_pic");
    });
  }

  Future<void> _logout(BuildContext context) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.clear();
    if (!mounted) return;
    Navigator.pushAndRemoveUntil(
      context,
      MaterialPageRoute(builder: (_) => const LoginPage()),
      (route) => false,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Drawer(
      child: ListView(
        padding: EdgeInsets.zero,
        children: [
          UserAccountsDrawerHeader(
            accountName: Text(
              name,
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            accountEmail: Text(
              "$email\n$hostel",
              style: const TextStyle(fontSize: 14),
            ),
            currentAccountPicture: CircleAvatar(
              backgroundColor: Colors.white,
              radius: 40,
              backgroundImage: profilePic != null ? NetworkImage(profilePic!) : null,
              child: profilePic == null ? const Icon(Icons.person, size: 40, color: Colors.grey) : null,
            ),
            decoration: const BoxDecoration(color: _primaryColor),
          ),

          /// ── DASHBOARD ──
          ListTile(
            leading: const Icon(Icons.dashboard_rounded, size: _iconSize, color: _primaryColor),
            title: const Text('Dashboard', style: TextStyle(fontSize: _fontSize)),
            onTap: () {
              Navigator.pop(context);
              Navigator.pushReplacement(
                context,
                MaterialPageRoute(builder: (_) => const ManagerHomePage()),
              );
            },
          ),
          /// ── QR SCANNER ──
          ListTile(
            leading: const Icon(Icons.qr_code, size: _iconSize),
            title: const Text('Scan QR'),
            onTap: () async {
              Navigator.pop(context); // close drawer first

              await Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => const ManagerQRScanPage(),
                ),
              );
              
              // When returning from scanner, refresh the home page if it's currently active
              ManagerHomePage.refreshKey.currentState?.fetchDashboard();
            },
          ),
          
          /// ── FEEDBACK ──
          ListTile(
            leading: const Icon(Icons.feedback_rounded, size: _iconSize),
            title: const Text('Feedback', style: TextStyle(fontSize: _fontSize)),
            onTap: () {
              Navigator.pop(context);
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const ManagerFeedbackPage()),
              );
            },
          ),

          
          /// ── MEAL MANAGEMENT ──
          ListTile(
            leading: const Icon(Icons.restaurant_menu_rounded, size: _iconSize),
            title: const Text('Meal Management', style: TextStyle(fontSize: _fontSize)),
            onTap: () {
              Navigator.pop(context);
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const ManagerMenuPage()),
              );
            },
          ),

          /// ── STUDENT LIST ──
          ListTile(
            leading: const Icon(Icons.people_alt_rounded, size: _iconSize),
            title: const Text('Students', style: TextStyle(fontSize: _fontSize)),
            onTap: () {
              Navigator.pop(context);
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const StudentListPage()),
              );
            },
          ),

          /// ── AUTHORIZE REGISTRATIONS ──
          ListTile(
            leading: const Icon(Icons.person_add_alt_1_rounded, size: _iconSize),
            title: const Text('Authorize Registrations', style: TextStyle(fontSize: _fontSize)),
            onTap: () {
              Navigator.pop(context);
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const AllowedUsersPage()),
              );
            },
          ),

          /// ── REPORTS ──
          ListTile(
            leading: const Icon(Icons.bar_chart_rounded, size: _iconSize),
            title: const Text('Reports', style: TextStyle(fontSize: _fontSize)),
            onTap: () {
              Navigator.pop(context);
              Navigator.push(context, MaterialPageRoute(builder: (_) => const ManagerReportsPage()));
            },
          ),

          /// ── ANNOUNCEMENTS ──
          ListTile(
            leading: const Icon(Icons.campaign_rounded, size: _iconSize),
            title: const Text('Announcements', style: TextStyle(fontSize: _fontSize)),
            onTap: () {
              Navigator.pop(context);
              Navigator.push(context, MaterialPageRoute(builder: (_) => const ManagerAnnouncementsPage()));
            },
          ),

          /// ── NEXT DAY BOOKING ──
          ListTile(
            leading: const Icon(Icons.assignment_turned_in_outlined, size: _iconSize),
            title: const Text('Next Day Preparation', style: TextStyle(fontSize: _fontSize)),
            onTap: () {
              Navigator.pop(context);
              Navigator.push(context, MaterialPageRoute(builder: (_) => const ManagerNextDayBookingPage()));
            },
          ),

          const Divider(),

          /// ── LOGOUT ──
          ListTile(
            leading: const Icon(Icons.logout_rounded, size: _iconSize, color: Colors.red),
            title: const Text(
              'Logout',
              style: TextStyle(fontSize: _fontSize, color: Colors.red),
            ),
            onTap: () => _logout(context),
          ),
        ],
      ),
    );
  }
}