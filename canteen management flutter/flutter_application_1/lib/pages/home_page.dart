import 'dart:convert';
import 'package:flutter/material.dart';
import 'drawer_widget.dart';
import 'api_service.dart';

// 🔥 Import pages (IMPORTANT)
import 'book_meals_page.dart';
import 'qr_page.dart';
import 'cancel_meals_page.dart';

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  List bookings = [];
  List weeklyMenu = [];
  bool isLoading = true;

  ////////////////////////////////////////////////////////////
  /// FETCH DATA
  ////////////////////////////////////////////////////////////

  Future<void> fetchAllData() async {
    setState(() => isLoading = true);
    await Future.wait([
      fetchBookings(),
      fetchWeeklyMenu(),
    ]);
    setState(() => isLoading = false);
  }

  Future<void> fetchBookings() async {
    try {
      final res = await ApiService.get("/my-booking/");
      if (res.statusCode == 200) {
        bookings = jsonDecode(res.body);
      }
    } catch (e) {
      print("Error fetching bookings: $e");
    }
  }

  Future<void> fetchWeeklyMenu() async {
    try {
      final res = await ApiService.get("/weekly-menu/");
      print("Weekly Menu Response: ${res.statusCode} - ${res.body}");
      if (res.statusCode == 200) {
        final data = jsonDecode(res.body);
        weeklyMenu = data["data"] ?? [];
        print("Weekly Menu loaded: ${weeklyMenu.length} days");
      }
    } catch (e) {
      print("Error fetching menu: $e");
    }
  }

  @override
  void initState() {
    super.initState();
    fetchAllData();
  }

  ////////////////////////////////////////////////////////////
  /// POPUP MENU
  ////////////////////////////////////////////////////////////

  void _showMenuPopup(DateTime date) {
    const daysFull = ["Monday", "Tuesday", "Wednesday", "Thursday", "Friday", "Saturday", "Sunday"];
    String dayName = daysFull[date.weekday - 1];

    // Find data for selected day
    final dayData = weeklyMenu.firstWhere(
      (d) => d["day"].toString().toLowerCase() == dayName.toLowerCase(),
      orElse: () => null,
    );

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        titlePadding: EdgeInsets.zero,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Container(
          padding: const EdgeInsets.all(20),
          decoration: const BoxDecoration(
            color: Color.fromARGB(255, 152, 29, 68),
            borderRadius: BorderRadius.only(topLeft: Radius.circular(16), topRight: Radius.circular(16)),
          ),
          child: Column(
            children: [
              Text(dayName, style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.white, fontSize: 22)),
              Text("${date.day}/${date.month}/${date.year}", style: const TextStyle(fontSize: 14, color: Colors.white70)),
            ],
          ),
        ),
        content: SizedBox(
          width: double.maxFinite,
          child: dayData == null || (dayData["slots"] as List).isEmpty
            ? Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const SizedBox(height: 20),
                  const Icon(Icons.restaurant_menu, size: 60, color: Colors.grey),
                  const SizedBox(height: 16),
                  Text("No menu available for $dayName.", textAlign: TextAlign.center, style: const TextStyle(fontSize: 16, color: Colors.grey)),
                  const SizedBox(height: 20),
                ],
              )
            : ListView.builder(
                shrinkWrap: true,
                padding: const EdgeInsets.only(top: 10),
                itemCount: (dayData["slots"] as List).length,
                itemBuilder: (context, i) {
                  final slot = dayData["slots"][i];
                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Padding(
                        padding: const EdgeInsets.symmetric(vertical: 8),
                        child: Text(
                          slot["slot"].toString().toUpperCase(),
                          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: Colors.black87),
                        ),
                      ),
                      ... (slot["combos"] as List).map<Widget>((combo) {
                        final isVeg = combo["category"] == "veg";
                        return Card(
                          margin: const EdgeInsets.symmetric(vertical: 4),
                          elevation: 2,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                          child: ListTile(
                            contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                            leading: Container(
                              width: 12,
                              height: 12,
                              decoration: BoxDecoration(
                                color: isVeg ? Colors.green : Colors.red,
                                borderRadius: BorderRadius.circular(2),
                              ),
                            ),
                            title: Text(combo["name"], style: const TextStyle(fontWeight: FontWeight.bold)),
                            subtitle: Text(combo["items_text"] ?? "", maxLines: 2, overflow: TextOverflow.ellipsis),
                          ),
                        );
                      }).toList(),
                      const SizedBox(height: 10),
                    ],
                  );
                },
              ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text("CLOSE", style: TextStyle(fontWeight: FontWeight.bold, color: Color.fromARGB(255, 152, 29, 68))),
          ),
        ],
      ),
    );
  }

  ////////////////////////////////////////////////////////////
  /// DATE SELECTOR
  ////////////////////////////////////////////////////////////

  Widget buildDateSelector() {
    final today = DateTime.now();
    final tomorrow = today.add(const Duration(days: 1));

    return SizedBox(
      height: 100,
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        itemCount: 7,
        itemBuilder: (context, index) {
          final date = today.add(Duration(days: index));
          final isToday = index == 0;
          final isTomorrow = index == 1;

          Color bgColor = Colors.white;
          Color textColor = Colors.black;
          Color subTextColor = Colors.grey;

          if (isToday) {
            bgColor = const Color.fromARGB(255, 152, 29, 68);
            textColor = Colors.white;
            subTextColor = Colors.white70;
          } else if (isTomorrow) {
            bgColor = Colors.green.shade600;
            textColor = Colors.white;
            subTextColor = Colors.white70;
          }

          return GestureDetector(
            onTap: () => _showMenuPopup(date),
            child: Container(
              margin: const EdgeInsets.symmetric(horizontal: 6),
              padding: const EdgeInsets.all(10),
              width: 75,
              decoration: BoxDecoration(
                color: bgColor,
                borderRadius: BorderRadius.circular(16),
                boxShadow: [
                  BoxShadow(color: Colors.black12, blurRadius: 4, offset: Offset(0, 2)),
                ],
                border: Border.all(color: (isToday || isTomorrow) ? Colors.transparent : Colors.grey.shade300),
              ),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(getDayName(date.weekday),
                      style: TextStyle(color: subTextColor, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 5),
                  Text(
                    date.day.toString(),
                    style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        color: textColor),
                  ),
                  if (isToday)
                    const Text("Today",
                        style: TextStyle(fontSize: 10, color: Colors.white, fontWeight: FontWeight.bold)),
                  if (isTomorrow)
                    const Text("Booking",
                        style: TextStyle(fontSize: 10, color: Colors.white, fontWeight: FontWeight.bold)),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  String getDayName(int weekday) {
    const days = ["Mon", "Tue", "Wed", "Thu", "Fri", "Sat", "Sun"];
    return days[weekday - 1];
  }

  ////////////////////////////////////////////////////////////
  /// FILTER MEALS
  ////////////////////////////////////////////////////////////

  List getTodayBookings() {
    final today = DateTime.now();

    return bookings.where((b) {
      final date = DateTime.tryParse(b["date"] ?? "");
      return date != null &&
          date.year == today.year &&
          date.month == today.month &&
          date.day == today.day;
    }).toList();
  }

  List getTomorrowBookings() {
    final tomorrow = DateTime.now().add(const Duration(days: 1));

    return bookings.where((b) {
      final date = DateTime.tryParse(b["date"] ?? "");
      return date != null &&
          date.year == tomorrow.year &&
          date.month == tomorrow.month &&
          date.day == tomorrow.day;
    }).toList();
  }

  ////////////////////////////////////////////////////////////
  /// SLOT ICON
  ////////////////////////////////////////////////////////////

  IconData _slotIcon(String slot) {
    switch (slot.toLowerCase()) {
      case 'breakfast':
        return Icons.free_breakfast;
      case 'lunch':
        return Icons.lunch_dining;
      case 'snacks':
        return Icons.cookie;
      case 'dinner':
        return Icons.dinner_dining;
      default:
        return Icons.restaurant;
    }
  }

  ////////////////////////////////////////////////////////////
  /// UI
  ////////////////////////////////////////////////////////////

  @override
  Widget build(BuildContext context) {
    final todayBookings = getTodayBookings();
    final tomorrowBookings = getTomorrowBookings();

    return Scaffold(
      drawer: const AppDrawer(),

      appBar: AppBar(
        title: const Text("Dashboard"),
        centerTitle: true,
        backgroundColor: Colors.white,
        elevation: 0,
      ),

      body: isLoading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: fetchBookings,
              child: SingleChildScrollView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [

                    /// DATE SELECTOR
                    const Padding(
                      padding: EdgeInsets.only(left: 4, bottom: 8),
                      child: Text("Select Date",
                          style: TextStyle(
                              fontSize: 18, fontWeight: FontWeight.bold)),
                    ),

                    buildDateSelector(),

                    const SizedBox(height: 25),

                    /// TODAY MEALS
                    const Padding(
                      padding: EdgeInsets.only(left: 4, bottom: 8),
                      child: Text("Today's Meals",
                          style: TextStyle(
                              fontSize: 18, fontWeight: FontWeight.bold)),
                    ),

                    if (todayBookings.isEmpty)
                      const Center(
                        child: Padding(
                          padding: EdgeInsets.symmetric(vertical: 20),
                          child: Text("No meals booked for today", style: TextStyle(color: Colors.grey)),
                        ),
                      ),

                    ...todayBookings.map((b) {
                      final meals = (b["meals"] as List);

                      if (meals.isEmpty) return const SizedBox();

                      return Container(
                        margin: const EdgeInsets.only(bottom: 15),
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            colors: [
                              Colors.orange.shade400,
                              Colors.orange.shade700
                            ],
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                          ),
                          borderRadius: BorderRadius.circular(16),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.orange.withOpacity(0.3),
                              blurRadius: 8,
                              offset: const Offset(0, 4),
                            ),
                          ],
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                const Icon(Icons.calendar_today,
                                    color: Colors.white, size: 18),
                                const SizedBox(width: 8),
                                Text(
                                  "Today • ${b["date"]}",
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ],
                            ),

                            const SizedBox(height: 12),

                            ...meals.map((m) {
                              bool isConsumed = m["status"] == "consumed";
                              bool isCancelled = m["status"] == "cancelled";

                              return Container(
                                margin: const EdgeInsets.only(bottom: 8),
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 12, vertical: 10),
                                decoration: BoxDecoration(
                                  color: Colors.white,
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: Row(
                                  children: [
                                    Icon(
                                      _slotIcon(m["meal_slot"]),
                                      size: 20,
                                      color: isCancelled ? Colors.grey : (isConsumed ? Colors.green : Colors.orange),
                                    ),
                                    const SizedBox(width: 12),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            m["meal_slot"].toUpperCase(),
                                            style: TextStyle(
                                                fontWeight: FontWeight.bold,
                                                fontSize: 14,
                                                decoration: isCancelled ? TextDecoration.lineThrough : null,
                                                color: isCancelled ? Colors.grey : Colors.black87),
                                          ),
                                          if (m["meal_time"] != null)
                                            Text(
                                              m["meal_time"],
                                              style: TextStyle(fontSize: 11, color: isCancelled ? Colors.grey : Colors.grey.shade600),
                                            ),
                                        ],
                                      ),
                                    ),
                                    Text(
                                      isCancelled ? "Cancelled" : (isConsumed ? "Consumed" : m["combo"]),
                                      style: TextStyle(
                                          fontSize: 14,
                                          color: isCancelled ? Colors.red : (isConsumed ? Colors.green : Colors.grey.shade700),
                                          fontWeight: isConsumed || isCancelled ? FontWeight.bold : FontWeight.w500),
                                    ),
                                  ],
                                ),
                              );
                            }),
                          ],
                        ),
                      );
                    }).toList(),

                    const SizedBox(height: 25),

                    /// TOMORROW MEALS
                    const Padding(
                      padding: EdgeInsets.only(left: 4, bottom: 8),
                      child: Text("Tomorrow's Meals",
                          style: TextStyle(
                              fontSize: 18, fontWeight: FontWeight.bold)),
                    ),

                    if (tomorrowBookings.isEmpty)
                      const Center(
                        child: Padding(
                          padding: EdgeInsets.symmetric(vertical: 20),
                          child: Text("No meals booked for tomorrow", style: TextStyle(color: Colors.grey)),
                        ),
                      ),

                    ...tomorrowBookings.map((b) {
                      final meals = (b["meals"] as List)
                          .where((m) => m["status"] == "booked")
                          .toList();

                      if (meals.isEmpty) return const SizedBox();

                      return Container(
                        margin: const EdgeInsets.only(bottom: 15),
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(
                          gradient: const LinearGradient(
                            colors: [
                              Color.fromARGB(255, 193, 87, 122),
                              Color.fromARGB(255, 197, 110, 151)
                            ],
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                          ),
                          borderRadius: BorderRadius.circular(16),
                          boxShadow: [
                            BoxShadow(
                              color: const Color.fromARGB(255, 193, 87, 122).withOpacity(0.3),
                              blurRadius: 8,
                              offset: const Offset(0, 4),
                            ),
                          ],
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                const Icon(Icons.calendar_today,
                                    color: Colors.white, size: 18),
                                const SizedBox(width: 8),
                                Text(
                                  "Tomorrow • ${b["date"]}",
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ],
                            ),

                            const SizedBox(height: 12),

                            ...meals.map((m) {
                              return Container(
                                margin: const EdgeInsets.only(bottom: 8),
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 12, vertical: 10),
                                decoration: BoxDecoration(
                                  color: Colors.white,
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: Row(
                                  children: [
                                    Icon(
                                      _slotIcon(m["meal_slot"]),
                                      size: 20,
                                      color: const Color.fromARGB(255, 121, 2, 48),
                                    ),
                                    const SizedBox(width: 12),
                                    Expanded(
                                      child: Text(
                                        m["meal_slot"].toUpperCase(),
                                        style: const TextStyle(
                                            fontWeight: FontWeight.bold,
                                            fontSize: 14,
                                            color: Colors.black87),
                                      ),
                                    ),
                                    Text(
                                      m["combo"],
                                      style:
                                          TextStyle(color: Colors.grey.shade700, fontSize: 14, fontWeight: FontWeight.w500),
                                    ),
                                  ],
                                ),
                              );
                            }),
                          ],
                        ),
                      );
                    }).toList(),

                    const SizedBox(height: 25),

                    /// ACTION BUTTONS
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                      children: [
                        _actionButton("Book", Icons.add_circle_outline, () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                                builder: (_) => const BookMealsPage()),
                          );
                        }),
                        _actionButton("Cancel", Icons.cancel_outlined, () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                                builder: (_) => const CancelMealsPage(),),
                          );
                        }),
                        _actionButton("QR", Icons.qr_code_scanner, () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                                builder: (_) => const QRPage()),
                          );
                        }),
                      ],
                    ),
                    const SizedBox(height: 20),
                  ],
                ),
              ),
            ),
    );
  }

  ////////////////////////////////////////////////////////////
  /// BUTTON
  ////////////////////////////////////////////////////////////

  Widget _actionButton(String label, IconData icon, VoidCallback onTap) {
    return Expanded(
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          margin: const EdgeInsets.symmetric(horizontal: 6),
          padding: const EdgeInsets.symmetric(vertical: 16),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(14),
            boxShadow: [
              BoxShadow(
                color: Colors.black12,
                blurRadius: 6,
                offset: const Offset(0, 3),
              ),
            ],
          ),
          child: Column(
            children: [
              Icon(icon, color: const Color.fromARGB(255, 163, 7, 38)),
              const SizedBox(height: 6),
              Text(label),
            ],
          ),
        ),
      ),
    );
  }
}