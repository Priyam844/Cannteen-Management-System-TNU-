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
  final int totalStudents;
  final int vegCount;
  final int nonVegCount;
  final int consumedCount;
  final int surplusCount;

  const MealSlotStat({
    required this.slotName,
    required this.icon,
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
class ManagerHomePage extends StatefulWidget {
  const ManagerHomePage({super.key});

  @override
  State<ManagerHomePage> createState() => _ManagerHomePageState();
}

class _ManagerHomePageState extends State<ManagerHomePage> {
  static const Color _primary = Color.fromARGB(255, 152, 29, 68);

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
          return MealSlotStat(
            slotName: slot["name"],
            icon: getIcon(slot["name"]),
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
      backgroundColor: Colors.grey[100],
      appBar: AppBar(
        backgroundColor: _primary,
        foregroundColor: Colors.white,
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text("Manager Dashboard", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            Text(hostelName, style: const TextStyle(fontSize: 13)),
          ],
        ),
        actions: [IconButton(icon: const Icon(Icons.refresh), onPressed: fetchDashboard)],
      ),
      drawer: const ManagerDrawer(),
      body: isLoading
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
                      childAspectRatio: 1.3,
                      children: [
                        _statCard('Total Students', totalStudents.toString(), Icons.people, Colors.blue),
                        _statCard('Overall Rating', '$overallRating / 5', Icons.star, Colors.purple),
                      ],
                    ),

                    const SizedBox(height: 20),
                    const Text("Today's Meal Bookings & Surplus", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                    const SizedBox(height: 12),
                    ...mealStats.map((slot) => Padding(
                      padding: const EdgeInsets.only(bottom: 14),
                      child: _MealSlotCard(stat: slot),
                    )),
                  ],
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
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            Row(
              children: [
                Icon(stat.icon),
                const SizedBox(width: 10),
                Text(stat.slotName, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                const Spacer(),
                Text("${stat.totalBooked} booked"),
              ],
            ),
            const SizedBox(height: 10),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text("Veg: ${stat.vegCount}"),
                    Text("Non-Veg: ${stat.nonVegCount}"),
                  ],
                ),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text("Consumed: ${stat.consumedCount}", style: const TextStyle(color: Colors.green, fontWeight: FontWeight.bold)),
                    Text("Surplus: ${stat.surplusCount}", style: const TextStyle(color: Colors.red, fontWeight: FontWeight.bold)),
                  ],
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
