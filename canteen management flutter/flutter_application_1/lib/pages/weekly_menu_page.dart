import 'package:flutter/material.dart';
import 'dart:convert';
import 'api_service.dart'; // ✅ IMPORTANT

class WeeklyMenuPage extends StatefulWidget {
  const WeeklyMenuPage({super.key}); // ✅ TOKEN REMOVED

  @override
  State<WeeklyMenuPage> createState() => _WeeklyMenuPageState();
}

class _WeeklyMenuPageState extends State<WeeklyMenuPage> {
  late Future<List<dynamic>> weeklyMenuFuture;

  @override
  void initState() {
    super.initState();
    weeklyMenuFuture = fetchWeeklyMenu();
  }

  ////////////////////////////////////////////////////////////
  /// FETCH MENU (UPDATED)
  ////////////////////////////////////////////////////////////
  Future<List<dynamic>> fetchWeeklyMenu() async {
    try {
      final response = await ApiService.get("/weekly-menu/");

      final data = jsonDecode(response.body);
      return data['data'];
    } catch (e) {
      throw Exception("Failed to load menu");
    }
  }

  ////////////////////////////////////////////////////////////
  /// UI
  ////////////////////////////////////////////////////////////
  @override
Widget build(BuildContext context) {
  return Scaffold(
    appBar: AppBar(
      // Apply the style directly to the Text widget
      title: const Text(
        "Weekly Menu",
        style: TextStyle(color: Colors.white), 
      ),
      backgroundColor: const Color.fromARGB(255, 152, 29, 68),
    ),
    body: FutureBuilder<List<dynamic>>(
      future: weeklyMenuFuture,
      builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          if (snapshot.hasError) {
            return const Center(child: Text("Failed to load menu"));
          }

          final data = snapshot.data ?? [];

          if (data.isEmpty) {
            return const Center(child: Text("No menu available"));
          }

          return ListView.builder(
            padding: const EdgeInsets.all(12),
            itemCount: data.length,
            itemBuilder: (context, index) {
              final day = data[index];

              return Card(
                margin: const EdgeInsets.symmetric(vertical: 8),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                elevation: 4,
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      /// DAY TITLE
                      Text(
                        day["day"],
                        style: const TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                          color: Color.fromARGB(255, 152, 29, 68),
                        ),
                      ),
                      const Divider(),

                      /// SLOTS
                      ...day["slots"].map<Widget>((slot) {
                        return buildSlot(slot);
                      }).toList(),
                    ],
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }

  ////////////////////////////////////////////////////////////
  /// SLOT UI
  ////////////////////////////////////////////////////////////
  Widget buildSlot(dynamic slot) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          slot["slot"].toUpperCase(),
          style: const TextStyle(
            fontWeight: FontWeight.bold,
            fontSize: 16,
          ),
        ),
        const SizedBox(height: 6),

        /// COMBOS
        ...slot["combos"].map<Widget>((combo) {
          return buildCombo(combo);
        }).toList(),

        const SizedBox(height: 12),
      ],
    );
  }

  ////////////////////////////////////////////////////////////
  /// COMBO CARD
  ////////////////////////////////////////////////////////////
  Widget buildCombo(dynamic combo) {
    final isVeg = combo["category"] == "veg";

    return Card(
      margin: const EdgeInsets.symmetric(vertical: 4),
      elevation: 2,
      child: ListTile(
        leading: Container(
          width: 14,
          height: 14,
          decoration: BoxDecoration(
            color: isVeg ? Colors.green : Colors.red,
            borderRadius: BorderRadius.circular(3),
          ),
        ),
        title: Text(
          combo["name"],
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
        subtitle: Text(combo["items_text"]),
      ),
    );
  }
}