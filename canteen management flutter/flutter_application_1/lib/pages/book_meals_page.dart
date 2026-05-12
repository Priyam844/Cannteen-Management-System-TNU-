import 'dart:convert';
import 'package:flutter/material.dart';
import 'api_service.dart';
import 'qr_page.dart';

class BookMealsPage extends StatefulWidget {
  const BookMealsPage({super.key});

  @override
  State<BookMealsPage> createState() => _BookMealsPageState();
}

class _BookMealsPageState extends State<BookMealsPage> {
  List<Map<String, dynamic>> slots = [];
  Map<String, Map<String, dynamic>> selectedMeals = {};
  Set<int> bookedSlots = {};

  bool isLoading = true;
  bool isBooking = false;

  @override
  void initState() {
    super.initState();
    fetchMenu();
  }

  int _toInt(dynamic value) {
    if (value == null) return 0;
    if (value is int) return value;
    return int.tryParse(value.toString()) ?? 0;
  }

  Future<void> fetchMenu() async {
    setState(() => isLoading = true);

    try {
      final menuRes = await ApiService.get("/weekly-menu/");
      final bookingRes = await ApiService.get("/my-booking/");

      debugPrint("=== MENU STATUS: ${menuRes.statusCode}");
      debugPrint("=== BOOKING STATUS: ${bookingRes.statusCode}");

      if (menuRes.statusCode != 200) {
        final err = jsonDecode(menuRes.body);
        showError(err["error"]?.toString() ?? "Failed to load menu");
        setState(() => isLoading = false);
        return;
      }

      bookedSlots.clear();
      selectedMeals.clear();

      if (bookingRes.statusCode == 200) {
  final bookingData = jsonDecode(bookingRes.body);

  // 🔥 Now bookingData is a LIST
  if (bookingData is List) {
    for (var booking in bookingData) {
      final meals = booking["meals"];

      if (meals is List) {
        for (var m in meals) {
          if (m == null) continue;

          final status = m["status"]?.toString() ?? "";
          final id = _toInt(m["meal_slot_id"]);

          if (status == "booked" && id != 0) {
            bookedSlots.add(id);
          }
        }
      }
    }
  }
}

      final menuData = jsonDecode(menuRes.body);
      final tomorrow = DateTime.now().add(const Duration(days: 1));
      final dayName = getDayName(tomorrow.weekday);

      final rawData = menuData["data"];

      if (rawData is! List) {
        showError("Unexpected menu format");
        setState(() {
          slots = [];
          isLoading = false;
        });
        return;
      }

      final dataList = List<Map<String, dynamic>>.from(rawData);

      final dayMatches = dataList.where(
        (d) =>
            (d["day"]?.toString() ?? "").toLowerCase() ==
            dayName.toLowerCase(),
      );

      if (dayMatches.isEmpty) {
        setState(() {
          slots = [];
          isLoading = false;
        });
        return;
      }

      final rawSlots = dayMatches.first["slots"];

      setState(() {
        slots = rawSlots is List
            ? List<Map<String, dynamic>>.from(rawSlots)
            : [];
        isLoading = false;
      });
    } catch (e, stackTrace) {
      debugPrint("=== FETCH ERROR: $e");
      debugPrint("=== STACK: $stackTrace");
      if (mounted) setState(() => isLoading = false);
    }
  }

  String getDayName(int weekday) {
    const days = [
      "Monday", "Tuesday", "Wednesday", "Thursday",
      "Friday", "Saturday", "Sunday"
    ];
    return days[weekday - 1];
  }

  Future<void> bookMeals() async {
    if (selectedMeals.isEmpty) {
      showError("Please select at least one meal");
      return;
    }

    setState(() => isBooking = true);

    try {
      final res = await ApiService.post("/book-meals/", {
        "meals": selectedMeals.values.toList(),
      });

      final data = jsonDecode(res.body);

      if (res.statusCode == 200) {
        if (!mounted) return;
        // ✅ QRPage fetches its own data — no args needed
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (_) => const QRPage()),
        );
      } else {
        showError(data["error"]?.toString() ?? "Booking failed");
      }
    } catch (e) {
      debugPrint("=== BOOK ERROR: $e");
      showError("Something went wrong");
    } finally {
      if (mounted) setState(() => isBooking = false);
    }
  }

  void showError(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(msg)),
    );
  }

  @override
  Widget build(BuildContext context) {
    final hasNewSelections = selectedMeals.isNotEmpty;

    return Scaffold(
      appBar: AppBar(
        title: const Text("Book Meals"),
        backgroundColor: const Color.fromARGB(255, 152, 29, 68),
        foregroundColor: Colors.white,
      ),
      body: isLoading
          ? const Center(child: CircularProgressIndicator())
          : slots.isEmpty
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(Icons.no_meals, size: 48, color: Colors.grey),
                      const SizedBox(height: 12),
                      const Text(
                        "No menu available for tomorrow",
                        style: TextStyle(color: Colors.grey),
                      ),
                      const SizedBox(height: 16),
                      TextButton(
                        onPressed: fetchMenu,
                        child: const Text("Retry"),
                      ),
                    ],
                  ),
                )
              : RefreshIndicator(
                  onRefresh: fetchMenu,
                  child: ListView(
                    padding: const EdgeInsets.all(16),
                    children: slots.map(buildSlotCard).toList(),
                  ),
                ),
      bottomNavigationBar: Container(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
        child: ElevatedButton(
          onPressed: (!hasNewSelections || isBooking) ? null : bookMeals,
          style: ElevatedButton.styleFrom(
            backgroundColor: const Color.fromARGB(255, 152, 29, 68),
            disabledBackgroundColor: Colors.grey.shade300,
            padding: const EdgeInsets.symmetric(vertical: 16),
          ),
          child: Text(
            isBooking
                ? "Booking..."
                : !hasNewSelections
                    ? bookedSlots.isNotEmpty
                        ? "All meals booked"
                        : "Select meals to book"
                    : "Confirm Booking (${selectedMeals.length})",
            style: const TextStyle(fontSize: 16, color: Colors.white),
          ),
        ),
      ),
    );
  }

  Widget buildSlotCard(Map<String, dynamic> slot) {
    final slotName = slot["slot"]?.toString() ?? "";
    final slotIdInt = _toInt(slot["id"]);

    if (slotIdInt == 0) return const SizedBox.shrink();

    final rawCombos = slot["combos"];
    final combos = rawCombos is List
        ? List<Map<String, dynamic>>.from(rawCombos)
        : <Map<String, dynamic>>[];

    final isBooked = bookedSlots.contains(slotIdInt);
    final slotKey = slotIdInt.toString();

    return Card(
      elevation: 3,
      margin: const EdgeInsets.only(bottom: 16),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ── slot header ──
            Row(
              children: [
                Icon(_slotIcon(slotName),
                    size: 18,
                    color: const Color.fromARGB(255, 152, 29, 68)),
                const SizedBox(width: 8),
                Text(
                  slotName.toUpperCase(),
                  style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 0.5,
                  ),
                ),
                const SizedBox(width: 8),
                if (isBooked)
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: Colors.green.shade100,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Text(
                      "BOOKED",
                      style: TextStyle(
                        color: Colors.green,
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
              ],
            ),

            const SizedBox(height: 10),
            const Divider(height: 1),
            const SizedBox(height: 10),

            // ── combos ──
            if (combos.isEmpty)
              const Text("No combos available",
                  style: TextStyle(color: Colors.grey, fontSize: 13))
            else
              ...combos.map((combo) {
                final comboId = _toInt(combo["id"]);
                final comboName = combo["name"]?.toString() ?? "";
                final category = combo["category"]?.toString() ?? "veg";
                final itemsText = combo["items_text"]?.toString() ?? "";
                final isSelected =
                    _toInt(selectedMeals[slotKey]?["combo_id"]) == comboId &&
                        comboId != 0;

                return GestureDetector(
                  onTap: () {
                    if (isBooked || comboId == 0) return;
                    setState(() {
                      if (isSelected) {
                        selectedMeals.remove(slotKey);
                      } else {
                        selectedMeals[slotKey] = {
                          "meal_slot_id": slotIdInt,
                          "combo_id": comboId,
                        };
                      }
                    });
                  },
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    margin: const EdgeInsets.symmetric(vertical: 6),
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: isBooked
                          ? Colors.grey.shade200
                          : isSelected
                              ? Colors.green.shade50
                              : Colors.grey.shade50,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        width: isSelected ? 1.5 : 1,
                        color: isBooked
                            ? Colors.grey.shade400
                            : isSelected
                                ? Colors.green
                                : Colors.grey.shade300,
                      ),
                    ),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Padding(
                          padding: const EdgeInsets.only(top: 3),
                          child: Container(
                            width: 14,
                            height: 14,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: category == "veg"
                                  ? Colors.green
                                  : Colors.red,
                            ),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                comboName,
                                style: const TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 14,
                                ),
                              ),
                              if (itemsText.isNotEmpty) ...[
                                const SizedBox(height: 4),
                                Text(
                                  itemsText,
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: Colors.grey.shade600,
                                  ),
                                ),
                              ],
                            ],
                          ),
                        ),
                        if (isSelected)
                          const Icon(Icons.check_circle,
                              color: Colors.green, size: 22)
                        else if (!isBooked)
                          Icon(Icons.radio_button_unchecked,
                              color: Colors.grey.shade400, size: 22),
                      ],
                    ),
                  ),
                );
              }),
          ],
        ),
      ),
    );
  }

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
}