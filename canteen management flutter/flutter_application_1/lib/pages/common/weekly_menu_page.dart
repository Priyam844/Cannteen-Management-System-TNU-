import 'package:flutter/material.dart';
import 'dart:convert';
import 'package:flutter_application_1/services/api_service.dart'; // ✅ IMPORTANT

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
                        day["day"]?.toString() ?? "Day",
                        style: const TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                          color: Color.fromARGB(255, 152, 29, 68),
                        ),
                      ),
                      const Divider(),

                      /// SLOTS
                      ...((day["slots"] as List?) ?? []).map<Widget>((slot) {
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
                              (slot["slot"]?.toString() ?? "SLOT").toUpperCase(),
                              style: const TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 16,
                                color: Colors.blueGrey,
                              ),
                            ),
                            const SizedBox(height: 8),

                            /// COMBOS
                            ...((slot["combos"] as List?) ?? []).map<Widget>((combo) {
                              return buildCombo(combo);
                            }).toList(),

                            /// INDIVIDUAL ITEMS
                            if ((slot["items"] as List?)?.isNotEmpty ?? false) ...[
                              const Padding(
                                padding: EdgeInsets.only(top: 8, bottom: 4),
                                child: Text("EXTRA ITEMS", style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Colors.grey)),
                              ),
                              ...((slot["items"] as List?) ?? []).map<Widget>((item) {
                                return buildItemRow(item);
                              }).toList(),
                            ],

                            const SizedBox(height: 16),
                          ],
                        );
                      }

                      Widget buildItemRow(dynamic item) {
                        final isVeg = item["is_veg"] == true || item["is_veg"] == 1;
                        return Padding(
                          padding: const EdgeInsets.symmetric(vertical: 2, horizontal: 8),
                          child: Row(
                            children: [
                              Container(
                                width: 8, height: 8,
                                decoration: BoxDecoration(shape: BoxShape.circle, color: isVeg ? Colors.green : Colors.red),
                              ),
                              const SizedBox(width: 10),
                              Text(item["name"]?.toString() ?? "", style: const TextStyle(fontSize: 14)),
                            ],
                          ),
                        );
                      }

                      Widget buildCombo(dynamic combo) {
                        final comboItems = (combo["items_list"] as List?) ?? [];
                        
                        return Card(
                          margin: const EdgeInsets.symmetric(vertical: 6),
                          elevation: 1,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                          child: Padding(
                            padding: const EdgeInsets.all(12),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  combo["name"]?.toString() ?? "Combo",
                                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                                ),
                                const SizedBox(height: 8),
                                ...comboItems.map((ci) {
                                  final isVeg = ci["is_veg"] == true || ci["is_veg"] == 1;
                                  return Padding(
                                    padding: const EdgeInsets.only(bottom: 4, left: 4),
                                    child: Row(
                                      children: [
                                        Container(
                                          width: 7, height: 7,
                                          decoration: BoxDecoration(shape: BoxShape.circle, color: isVeg ? Colors.green : Colors.red),
                                        ),
                                        const SizedBox(width: 10),
                                        Text(ci["name"]?.toString() ?? "", style: const TextStyle(fontSize: 13, color: Colors.black87)),
                                      ],
                                    ),
                                  );
                                }).toList(),
                              ],
                            ),
                          ),
                        );
                      }
                      }