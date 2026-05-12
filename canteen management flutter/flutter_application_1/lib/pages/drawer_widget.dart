import 'package:flutter/material.dart';

import 'weekly_menu_page.dart';
import 'feedback_page.dart';
import 'home_page.dart';
import 'login_page.dart';
import 'profile_page.dart';
import 'qr_page.dart';
import 'book_meals_page.dart';
import 'cancel_meals_page.dart';
import 'announcement_page.dart';

import 'package:shared_preferences/shared_preferences.dart';

class AppDrawer extends StatefulWidget {
  const AppDrawer({super.key});

  @override
  State<AppDrawer> createState() => _AppDrawerState();
}

class _AppDrawerState extends State<AppDrawer> {
  String name = "Student";
  String email = "student@gmail.com";
  String? profilePic;

  @override
  void initState() {
    super.initState();
    _loadUser();
  }

  Future<void> _loadUser() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      name = prefs.getString("user_name") ?? "Student";
      email = prefs.getString("user_email") ?? "student@gmail.com";
      profilePic = prefs.getString("user_pic");
    });
  }

  @override
  Widget build(BuildContext context) {
    const double globalIconSize = 30.0;
    const double globalFontSize = 18.0;

    return Drawer(
      child: ListView(
        padding: EdgeInsets.zero,
        children: [
          /// HEADER
          UserAccountsDrawerHeader(
            accountName: Text(
              name,
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            accountEmail: Text(
              email,
              style: const TextStyle(fontSize: 14),
            ),
            currentAccountPicture: CircleAvatar(
              backgroundColor: Colors.white,
              radius: 40,
              backgroundImage: profilePic != null ? NetworkImage(profilePic!) : null,
              child: profilePic == null ? const Icon(Icons.person, size: 40, color: Colors.grey) : null,
            ),
            decoration: const BoxDecoration(
              color: Color.fromARGB(255, 152, 29, 68),
            ),
          ),

          /// HOME
          ListTile(
            leading: const Icon(Icons.home, size: globalIconSize),
            title: const Text('Home', style: TextStyle(fontSize: globalFontSize)),
            onTap: () {
              Navigator.pop(context);
              Navigator.pushReplacement(
                context,
                MaterialPageRoute(
                  settings: const RouteSettings(name: '/home'),
                  builder: (_) => const HomePage(),
                ),
              );
            },
          ),

          /// PROFILE
          ListTile(
            leading: const Icon(Icons.person, size: globalIconSize),
            title: const Text('Profile', style: TextStyle(fontSize: globalFontSize)),
            onTap: () {
              Navigator.pop(context);
              Navigator.push(
                context,
                MaterialPageRoute(
                  settings: const RouteSettings(name: '/profile'),
                  builder: (_) => const ProfilePage(),
                ),
              );
            },
          ),

          /// BOOK MEALS
          ListTile(
            leading: const Icon(Icons.restaurant_menu),
            title: const Text('Book Meals'),
            onTap: () {
              Navigator.pop(context);
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => const BookMealsPage(),
                ),
              );
            },
          ),

          /// CANCEL MEALS
          ListTile(
            leading: const Icon(Icons.cancel),
            title: const Text('Cancel Meals'),
            onTap: () {
              Navigator.pop(context);
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => const CancelMealsPage(),
                ),
              );
            },
          ),

          /// QR PAGE
          ListTile(
            leading: const Icon(Icons.qr_code, size: globalIconSize),
            title: const Text('QR Code', style: TextStyle(fontSize: globalFontSize)),
            onTap: () {
              Navigator.pop(context);
              Navigator.push(
                context,
                MaterialPageRoute(
                  settings: const RouteSettings(name: '/qr'),
                  builder: (_) => QRPage(
                    // qrUuid: "temp-uuid-123",
                    // studentId: "TNU2023069100003",
                    // name: "USER",
                    // date: DateTime.now().toString().substring(0, 10),
                  ),
                ),
              );
            },
          ),

          /// FEEDBACK
          ListTile(
            leading: const Icon(Icons.feedback, size: globalIconSize),
            title: const Text('Feedback', style: TextStyle(fontSize: globalFontSize)),
            onTap: () {
              Navigator.pop(context);
              Navigator.push(
                context,
                MaterialPageRoute(
                  settings: const RouteSettings(name: '/feedback'),
                  builder: (_) => const FeedbackPage(),
                ),
              );
            },
          ),

          /// ANNOUNCEMENTS
          ListTile(
            leading: const Icon(Icons.campaign, size: globalIconSize),
            title: const Text('Announcements', style: TextStyle(fontSize: globalFontSize)),
            onTap: () {
              Navigator.pop(context);
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => const AnnouncementPage(),
                ),
              );
            },
          ),

          /// WEEKLY MENU
          ListTile(
            leading: const Icon(Icons.menu_book, size: globalIconSize),
            title: const Text('Weekly Menu', style: TextStyle(fontSize: globalFontSize)),
            onTap: () {
              Navigator.pop(context);
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => const WeeklyMenuPage(),
                ),
              );
            },
          ),

          const Divider(),

          /// LOGOUT
          ListTile(
            leading: const Icon(Icons.logout, size: globalIconSize, color: Colors.red),
            title: const Text(
              'Logout',
              style: TextStyle(fontSize: globalFontSize, color: Colors.red),
            ),
            onTap: () {
              Navigator.pop(context);
              Navigator.pushAndRemoveUntil(
                context,
                MaterialPageRoute(builder: (_) => const LoginPage()),
                (route) => false,
              );
            },
          ),
        ],
      ),
    );
  }
}