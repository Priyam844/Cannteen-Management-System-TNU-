import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_application_1/pages/common/drawer_widget.dart';
import 'package:flutter_application_1/services/api_service.dart';

// 🔥 Import pages (IMPORTANT)
import 'package:flutter_application_1/pages/student/book_meal_page.dart';
import 'package:flutter_application_1/pages/student/guest_booking_page.dart';
import 'package:flutter_application_1/pages/student/qr_page.dart';
import 'package:flutter_application_1/pages/student/cancel_meals_page.dart';

class StudentHomePage extends StatefulWidget {
  const StudentHomePage({super.key});

  @override
  State<StudentHomePage> createState() => _StudentHomePageState();
}

class _StudentHomePageState extends State<StudentHomePage> {
  List bookings = [];
  List weeklyMenu = [];
  double walletBalance = 0.0;
  bool isLoading = true;

  ////////////////////////////////////////////////////////////
  /// FETCH DATA
  ////////////////////////////////////////////////////////////

  Future<void> fetchAllData({bool showLoading = true}) async {
    if (showLoading) setState(() => isLoading = true);
    
    await Future.wait([
      fetchBookings(),
      fetchWeeklyMenu(),
      fetchProfile(),
    ]);

    if (mounted) {
      setState(() => isLoading = false);
    }
  }

  Future<void> fetchBookings() async {
    try {
      final res = await ApiService.get("/my-booking/");
      if (res.statusCode == 200) {
        final data = jsonDecode(res.body);
        bookings = data is Map ? data["data"] : data;
      }
    } catch (e) {
      print("Error fetching bookings: $e");
    }
  }

  Future<void> fetchProfile() async {
    try {
      final res = await ApiService.get("/profile/");
      if (res.statusCode == 200) {
        final data = jsonDecode(res.body);
        if (mounted) {
          setState(() {
            walletBalance = double.tryParse(data["wallet_balance"].toString()) ?? 0.0;
          });
        }
      }
    } catch (e) {
      print("Error fetching profile: $e");
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

  void _showMenuPopup(Map<String, dynamic> dayData) {
    String dayName = dayData["day"];
    String dateStr = dayData["date"];

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
              Text(dateStr, style: const TextStyle(fontSize: 14, color: Colors.white70)),
            ],
          ),
        ),
        content: SizedBox(
          width: double.maxFinite,
          child: (dayData["slots"] as List).isEmpty
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
                  final combos = (slot["combos"] as List?) ?? [];
                  final items = (slot["items"] as List?) ?? [];

                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Padding(
                        padding: const EdgeInsets.symmetric(vertical: 8),
                        child: Text(
                          (slot["slot"]?.toString() ?? "SLOT").toUpperCase(),
                          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: Colors.blueGrey),
                        ),
                      ),
                      ... combos.map<Widget>((combo) {
                        final comboItems = (combo["items_list"] as List?) ?? [];
                        return Card(
                          margin: const EdgeInsets.symmetric(vertical: 4),
                          elevation: 1,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                          child: Padding(
                            padding: const EdgeInsets.all(12),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(combo["name"]?.toString() ?? "Combo", style: const TextStyle(fontWeight: FontWeight.bold)),
                                const SizedBox(height: 6),
                                ...comboItems.map((ci) {
                                  final isVeg = ci["is_veg"] == true || ci["is_veg"] == 1;
                                  return Padding(
                                    padding: const EdgeInsets.only(bottom: 4),
                                    child: Row(
                                      children: [
                                        Container(
                                          width: 7, height: 7,
                                          decoration: BoxDecoration(shape: BoxShape.circle, color: isVeg ? Colors.green : Colors.red),
                                        ),
                                        const SizedBox(width: 8),
                                        Text(ci["name"]?.toString() ?? "", style: const TextStyle(fontSize: 12, color: Colors.black87)),
                                      ],
                                    ),
                                  );
                                }).toList(),
                              ],
                            ),
                          ),
                        );
                      }).toList(),

                      if (items.isNotEmpty) ...[
                        const Padding(
                          padding: EdgeInsets.only(top: 4, bottom: 2),
                          child: Text("EXTRA ITEMS", style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Colors.grey)),
                        ),
                        ... items.map<Widget>((item) {
                          final isVeg = item["is_veg"] == true || item["is_veg"] == 1;
                          return Padding(
                            padding: const EdgeInsets.symmetric(vertical: 2, horizontal: 4),
                            child: Row(
                              children: [
                                Container(
                                  width: 7, height: 7,
                                  decoration: BoxDecoration(shape: BoxShape.circle, color: isVeg ? Colors.green : Colors.red),
                                ),
                                const SizedBox(width: 8),
                                Text(item["name"]?.toString() ?? "", style: const TextStyle(fontSize: 13)),
                              ],
                            ),
                          );
                        }).toList(),
                      ],
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
    return SizedBox(
      height: 100,
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        itemCount: weeklyMenu.length,
        itemBuilder: (context, index) {
          final dayData = weeklyMenu[index];
          final date = DateTime.parse(dayData["date"]);
          final now = DateTime.now();
          final today = DateTime(now.year, now.month, now.day);
          final chipDate = DateTime(date.year, date.month, date.day);
          final diff = chipDate.difference(today).inDays;
          
          final isToday = diff == 0;
          final bool isBookable = diff >= 0 && diff <= 2;
          
          Color bgColor = Colors.white;
          Color textColor = Colors.black;
          Color subTextColor = Colors.grey;

          if (isToday) {
            bgColor = const Color.fromARGB(255, 152, 29, 68);
            textColor = Colors.white;
            subTextColor = Colors.white70;
          } else if (isBookable) {
            bgColor = Colors.white;
            textColor = const Color.fromARGB(255, 152, 29, 68);
            subTextColor = const Color.fromARGB(255, 152, 29, 68).withOpacity(0.7);
          }

          return GestureDetector(
            onTap: () => _showMenuPopup(dayData),
            child: Container(
              margin: const EdgeInsets.symmetric(horizontal: 6),
              padding: const EdgeInsets.all(10),
              width: 75,
              decoration: BoxDecoration(
                color: bgColor,
                borderRadius: BorderRadius.circular(16),
                boxShadow: const [
                  BoxShadow(color: Colors.black12, blurRadius: 4, offset: Offset(0, 2)),
                ],
                border: Border.all(
                  color: (isToday || isBookable) ? const Color.fromARGB(255, 152, 29, 68) : Colors.grey.shade300,
                  width: (isToday || isBookable) ? 1.5 : 1,
                ),
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

  List getDayAfterTomorrowBookings() {
    final dayAfter = DateTime.now().add(const Duration(days: 2));

    return bookings.where((b) {
      final date = DateTime.tryParse(b["date"] ?? "");
      return date != null &&
          date.year == dayAfter.year &&
          date.month == dayAfter.month &&
          date.day == dayAfter.day;
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
    final dayAfterTomorrowBookings = getDayAfterTomorrowBookings();

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
              onRefresh: () => fetchAllData(showLoading: false),
              child: SingleChildScrollView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [

                    /// DATE SELECTOR
                    buildWalletCard(),

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
                              final List selectedItems = m["selected_items"] as List? ?? [];

                              return Container(
                                margin: const EdgeInsets.only(bottom: 8),
                                decoration: BoxDecoration(
                                  color: Colors.white,
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: Theme(
                                  data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
                                  child: ExpansionTile(
                                    dense: true,
                                    visualDensity: VisualDensity.compact,
                                    leading: Icon(
                                      _slotIcon(m["meal_slot"]?.toString() ?? ""),
                                      size: 20,
                                      color: isCancelled ? Colors.grey : (isConsumed ? Colors.green : Colors.orange),
                                    ),
                                    title: Text(
                                      (m["meal_slot"]?.toString() ?? "SLOT").toUpperCase(),
                                      style: TextStyle(
                                          fontWeight: FontWeight.bold,
                                          fontSize: 14,
                                          decoration: isCancelled ? TextDecoration.lineThrough : null,
                                          color: isCancelled ? Colors.grey : Colors.black87),
                                    ),
                                    subtitle: Text(
                                      isCancelled ? "Cancelled" : (isConsumed ? "Consumed" : (m["name"]?.toString() ?? "Meal")),
                                      style: TextStyle(
                                          fontSize: 12,
                                          color: isCancelled ? Colors.red : (isConsumed ? Colors.green : Colors.grey.shade700)),
                                    ),
                                    children: [
                                      Padding(
                                        padding: const EdgeInsets.fromLTRB(48, 0, 16, 12),
                                        child: Column(
                                          crossAxisAlignment: CrossAxisAlignment.start,
                                          children: [
                                            if (m["meal_time"] != null)
                                              Padding(
                                                padding: const EdgeInsets.only(bottom: 8),
                                                child: Text("Time: ${m["meal_time"]}", style: TextStyle(fontSize: 11, color: Colors.grey.shade600)),
                                              ),
                                            if (selectedItems.isNotEmpty) ...[
                                              const Text("Items:", style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.blueGrey)),
                                              const SizedBox(height: 4),
                                              ...selectedItems.map<Widget>((si) {
                                                return Padding(
                                                  padding: const EdgeInsets.only(bottom: 4),
                                                  child: Row(
                                                    children: [
                                                      Text("• ", style: TextStyle(color: Colors.grey.shade400)),
                                                      Expanded(child: Text(si["name"]?.toString() ?? "", style: const TextStyle(fontSize: 12, color: Colors.black54))),
                                                      Text("x${si["quantity"]}", style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.blueGrey)),
                                                    ],
                                                  ),
                                                );
                                              }).toList(),
                                            ],
                                          ],
                                        ),
                                      ),
                                    ],
                                  ),
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
                                  "Tomorrow • ${b["date"] ?? ""}",
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ],
                            ),

                            const SizedBox(height: 12),

                            ...meals.map((m) {
                              final List selectedItems = m["selected_items"] as List? ?? [];

                              return Container(
                                margin: const EdgeInsets.only(bottom: 8),
                                decoration: BoxDecoration(
                                  color: Colors.white,
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: Theme(
                                  data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
                                  child: ExpansionTile(
                                    dense: true,
                                    visualDensity: VisualDensity.compact,
                                    leading: Icon(
                                      _slotIcon(m["meal_slot"]?.toString() ?? ""),
                                      size: 20,
                                      color: const Color.fromARGB(255, 121, 2, 48),
                                    ),
                                    title: Text(
                                      (m["meal_slot"]?.toString() ?? "SLOT").toUpperCase(),
                                      style: const TextStyle(
                                          fontWeight: FontWeight.bold,
                                          fontSize: 14,
                                          color: Colors.black87),
                                    ),
                                    subtitle: Text(
                                      m["name"]?.toString() ?? "Meal",
                                      style: TextStyle(color: Colors.grey.shade700, fontSize: 12),
                                    ),
                                    children: [
                                      if (selectedItems.isNotEmpty)
                                        Padding(
                                          padding: const EdgeInsets.fromLTRB(48, 0, 16, 12),
                                          child: Column(
                                            crossAxisAlignment: CrossAxisAlignment.start,
                                            children: [
                                              const Text("Items:", style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.blueGrey)),
                                              const SizedBox(height: 4),
                                              ...selectedItems.map<Widget>((si) {
                                                return Padding(
                                                  padding: const EdgeInsets.only(bottom: 4),
                                                  child: Row(
                                                    children: [
                                                      Text("• ", style: TextStyle(color: Colors.grey.shade400)),
                                                      Expanded(child: Text(si["name"]?.toString() ?? "", style: const TextStyle(fontSize: 12, color: Colors.black54))),
                                                      Text("x${si["quantity"]}", style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.blueGrey)),
                                                    ],
                                                  ),
                                                );
                                              }).toList(),
                                            ],
                                          ),
                                        ),
                                    ],
                                  ),
                                ),
                              );
                            }),
                          ],
                        ),
                      );
                    }).toList(),

                    const SizedBox(height: 25),

                    /// DAY AFTER TOMORROW MEALS
                    const Padding(
                      padding: EdgeInsets.only(left: 4, bottom: 8),
                      child: Text("Upcoming Bookings",
                          style: TextStyle(
                              fontSize: 18, fontWeight: FontWeight.bold)),
                    ),

                    if (dayAfterTomorrowBookings.isEmpty)
                      const Center(
                        child: Padding(
                          padding: EdgeInsets.symmetric(vertical: 20),
                          child: Text("No upcoming meals booked", style: TextStyle(color: Colors.grey)),
                        ),
                      ),

                    ...dayAfterTomorrowBookings.map((b) {
                      final meals = (b["meals"] as List)
                          .where((m) => m["status"] == "booked")
                          .toList();

                      if (meals.isEmpty) return const SizedBox();

                      return Container(
                        margin: const EdgeInsets.only(bottom: 15),
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            colors: [
                              Colors.teal.shade400,
                              Colors.teal.shade700
                            ],
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                          ),
                          borderRadius: BorderRadius.circular(16),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.teal.withOpacity(0.3),
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
                                  "Booked • ${b["date"] ?? ""}",
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ],
                            ),

                            const SizedBox(height: 12),

                            ...meals.map((m) {
                              final List selectedItems = m["selected_items"] as List? ?? [];

                              return Container(
                                margin: const EdgeInsets.only(bottom: 8),
                                decoration: BoxDecoration(
                                  color: Colors.white,
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: Theme(
                                  data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
                                  child: ExpansionTile(
                                    dense: true,
                                    visualDensity: VisualDensity.compact,
                                    leading: Icon(
                                      _slotIcon(m["meal_slot"]?.toString() ?? ""),
                                      size: 20,
                                      color: Colors.teal,
                                    ),
                                    title: Text(
                                      (m["meal_slot"]?.toString() ?? "SLOT").toUpperCase(),
                                      style: const TextStyle(
                                          fontWeight: FontWeight.bold,
                                          fontSize: 14,
                                          color: Colors.black87),
                                    ),
                                    subtitle: Text(
                                      m["name"]?.toString() ?? "Meal",
                                      style: TextStyle(color: Colors.grey.shade700, fontSize: 12),
                                    ),
                                    children: [
                                      if (selectedItems.isNotEmpty)
                                        Padding(
                                          padding: const EdgeInsets.fromLTRB(48, 0, 16, 12),
                                          child: Column(
                                            crossAxisAlignment: CrossAxisAlignment.start,
                                            children: [
                                              const Text("Items:", style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.blueGrey)),
                                              const SizedBox(height: 4),
                                              ...selectedItems.map<Widget>((si) {
                                                return Padding(
                                                  padding: const EdgeInsets.only(bottom: 4),
                                                  child: Row(
                                                    children: [
                                                      Text("• ", style: TextStyle(color: Colors.grey.shade400)),
                                                      Expanded(child: Text(si["name"]?.toString() ?? "", style: const TextStyle(fontSize: 12, color: Colors.black54))),
                                                      Text("x${si["quantity"]}", style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.blueGrey)),
                                                    ],
                                                  ),
                                                );
                                              }).toList(),
                                            ],
                                          ),
                                        ),
                                    ],
                                  ),
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
                        _actionButton("Book", Icons.add_circle_outline, () async {
                          await Navigator.push(
                            context,
                            MaterialPageRoute(
                                builder: (_) => const BookMealPage()),
                          );
                          fetchAllData(showLoading: false);
                        }),
                        _actionButton("Guest", Icons.group_add_outlined, () async {
                          await Navigator.push(
                            context,
                            MaterialPageRoute(
                                builder: (_) => const GuestBookingPage()),
                          );
                          fetchAllData(showLoading: false);
                        }),
                        _actionButton("Cancel", Icons.cancel_outlined, () async {
                          await Navigator.push(
                            context,
                            MaterialPageRoute(
                                builder: (_) => const CancelMealsPage()),
                          );
                          fetchAllData(showLoading: false);
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

  Widget buildWalletCard() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      margin: const EdgeInsets.only(bottom: 25),
      decoration: BoxDecoration(
        color: const Color.fromARGB(255, 152, 29, 68),
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: const Color.fromARGB(255, 152, 29, 68).withOpacity(0.3),
            blurRadius: 10,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            "Prepaid Wallet Balance",
            style: TextStyle(color: Colors.white70, fontSize: 14),
          ),
          const SizedBox(height: 8),
          Text(
            "₹${walletBalance.toStringAsFixed(2)}",
            style: const TextStyle(
              color: Colors.white,
              fontSize: 32,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 12),
          const Text(
            "Total Semester Meal Balance",
            style: TextStyle(color: Colors.white54, fontSize: 12),
          ),
        ],
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