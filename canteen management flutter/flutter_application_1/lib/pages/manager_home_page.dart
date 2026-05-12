import 'package:flutter/material.dart';
import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import 'manager_drawer.dart';
import 'api_service.dart';

////////////////////////////////////////////////////////////
/// DATA MODEL
////////////////////////////////////////////////////////////
class MealSlotStat {
  final String slotName;
  final IconData icon;
  final String timeRange;
  final int totalStudents;
  final int vegCount;
  final int nonVegCount;
  final int consumedCount;
  final int surplusCount;

  const MealSlotStat({
    required this.slotName,
    required this.icon,
    required this.timeRange,
    required this.totalStudents,
    required this.vegCount,
    required this.nonVegCount,
    required this.consumedCount,
    required this.surplusCount,
  });

  int get totalBooked => vegCount + nonVegCount;
  int get notBooked => totalStudents - totalBooked;
}

////////////////////////////////////////////////////////////
/// MANAGER HOME PAGE
////////////////////////////////////////////////////////////
const Color _primaryColor = Color.fromARGB(255, 152, 29, 68);

class ManagerHomePage extends StatefulWidget {
  static final GlobalKey<ManagerHomePageState> refreshKey = GlobalKey<ManagerHomePageState>();
  const ManagerHomePage({super.key});

  @override
  State<ManagerHomePage> createState() => ManagerHomePageState();
}

class ManagerHomePageState extends State<ManagerHomePage> {
  bool isLoading = true;
  String hostelName = "";
  int totalStudents = 0;
  double overallRating = 0.0;

  List<MealSlotStat> mealStats = [];

  @override
  void initState() {
    super.initState();
    fetchDashboard();
  }

  IconData getIcon(String slot) {
    switch (slot.toLowerCase()) {
      case "breakfast": return Icons.wb_sunny_rounded;
      case "lunch": return Icons.lunch_dining_rounded;
      case "snacks": return Icons.coffee_rounded;
      case "dinner": return Icons.nights_stay_rounded;
      default: return Icons.restaurant;
    }
  }

  Future<void> fetchDashboard() async {
    setState(() => isLoading = true);
    try {
      final response = await ApiService.get("/manager-dashboard/");
      if (response.statusCode != 200) throw Exception("Server error");

      final data = jsonDecode(response.body);

      setState(() {
        hostelName = data["hostel_name"] ?? "Hostel";
        totalStudents = data["total_students"] ?? 0;
        overallRating = (data["overall_rating"] ?? 0.0).toDouble();

        mealStats = (data["slots"] as List).map((slot) {
          final timeList = slot["time"] as List? ?? ["N/A", "N/A"];
          return MealSlotStat(
            slotName: slot["name"],
            icon: getIcon(slot["name"]),
            timeRange: "${timeList[0]} - ${timeList[1]}",
            totalStudents: slot["total"],
            vegCount: slot["veg"],
            nonVegCount: slot["non_veg"],
            consumedCount: slot["consumed"],
            surplusCount: slot["surplus"] ?? 0,
          );
        }).toList();

        isLoading = false;
      });
    } catch (e) {
      setState(() => isLoading = false);
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Error: $e")));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      key: ManagerHomePage.refreshKey,
      backgroundColor: Colors.grey[100],
      appBar: AppBar(
        backgroundColor: _primaryColor,
        foregroundColor: Colors.white,
        centerTitle: true,
        title: Column(
          children: [
            const Text("Manager Dashboard", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            Text(hostelName, style: const TextStyle(fontSize: 13, color: Colors.white70)),
          ],
        ),
        actions: [IconButton(icon: const Icon(Icons.refresh), onPressed: fetchDashboard)],
      ),
      drawer: const ManagerDrawer(),
      body: SafeArea(
        child: isLoading
            ? const Center(child: CircularProgressIndicator())
            : RefreshIndicator(
                onRefresh: fetchDashboard,
                child: SingleChildScrollView(
                  physics: const AlwaysScrollableScrollPhysics(),
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _TotalStudentsBanner(hostelName: hostelName, totalStudents: totalStudents),
                      const SizedBox(height: 16),
                      
                      GridView.count(
                        crossAxisCount: 2,
                        crossAxisSpacing: 16,
                        mainAxisSpacing: 16,
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        childAspectRatio: 1.4,
                        children: [
                          _statCard('Total Students', totalStudents.toString(), Icons.people_outline, Colors.blue),
                          _statCard('Overall Rating', '$overallRating / 5', Icons.star_outline, Colors.amber),
                        ],
                      ),
  
                      const SizedBox(height: 25),
                      const Padding(
                        padding: EdgeInsets.only(left: 4, bottom: 12),
                        child: Text("Today's Meal Stats", style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
                      ),
                      ...mealStats.map((slot) => Padding(
                        padding: const EdgeInsets.only(bottom: 14),
                        child: _MealSlotCard(stat: slot),
                      )),
                      const SizedBox(height: 20),
                    ],
                  ),
                ),
              ),
      ),
    );
  }

  Widget _statCard(String title, String val, IconData icon, Color color) {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, color: color, size: 30),
            const SizedBox(height: 8),
            Text(val, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            Text(title, style: TextStyle(fontSize: 12, color: Colors.grey[600])),
          ],
        ),
      ),
    );
  }
}

class _TotalStudentsBanner extends StatelessWidget {
  final String hostelName;
  final int totalStudents;
  const _TotalStudentsBanner({required this.hostelName, required this.totalStudents});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        gradient: const LinearGradient(colors: [Color.fromARGB(255, 152, 29, 68), Color.fromARGB(255, 120, 20, 50)]),
        borderRadius: BorderRadius.circular(18),
      ),
      child: Row(
        children: [
          const Icon(Icons.apartment, color: Colors.white, size: 40),
          const SizedBox(width: 12),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(hostelName, style: const TextStyle(color: Colors.white70)),
              Text("$totalStudents Students", style: const TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.bold)),
            ],
          ),
        ],
      ),
    );
  }
}

class _MealSlotCard extends StatelessWidget {
  final MealSlotStat stat;
  const _MealSlotCard({required this.stat});

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 1,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: _primaryColor.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(stat.icon, color: _primaryColor, size: 24),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(stat.slotName, style: const TextStyle(fontSize: 17, fontWeight: FontWeight.bold)),
                      Text(stat.timeRange, style: TextStyle(fontSize: 12, color: Colors.grey[600], fontWeight: FontWeight.w500)),
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  decoration: BoxDecoration(
                    color: Colors.grey[100],
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    "${stat.totalBooked} booked", 
                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Colors.black87)
                  ),
                ),
              ],
            ),
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 14),
              child: Divider(height: 1),
            ),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                _miniStat("Veg", stat.vegCount.toString(), Colors.green),
                _miniStat("Non-Veg", stat.nonVegCount.toString(), Colors.orange),
                _miniStat("Consumed", stat.consumedCount.toString(), Colors.blue),
                _miniStat("Surplus", stat.surplusCount.toString(), Colors.red),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _miniStat(String label, String val, Color color) {
    return Column(
      children: [
        Text(val, style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: color)),
        const SizedBox(height: 2),
        Text(label, style: TextStyle(fontSize: 11, color: Colors.grey[600], fontWeight: FontWeight.w500)),
      ],
    );
  }
}
