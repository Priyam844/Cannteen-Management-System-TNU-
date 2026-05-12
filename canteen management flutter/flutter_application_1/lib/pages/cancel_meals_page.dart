import 'dart:convert';
import 'package:flutter/material.dart';
import 'api_service.dart';

class CancelMealsPage extends StatefulWidget {
  const CancelMealsPage({super.key});

  @override
  State<CancelMealsPage> createState() => _CancelMealsPageState();
}

class _CancelMealsPageState extends State<CancelMealsPage> {
  List meals = [];
  bool isLoading = true;
  Set<int> cancellingSlots = {};

  static const _primary = Color.fromARGB(255, 152, 29, 68);

  @override
  void initState() {
    super.initState();
    fetchBooking();
  }

  ////////////////////////////////////////////////////////////
  /// FETCH BOOKINGS
  ////////////////////////////////////////////////////////////
  Future<void> fetchBooking() async {
    setState(() => isLoading = true);
    try {
      final res = await ApiService.get("/my-booking/");

      if (res.statusCode == 200) {
        final List data = jsonDecode(res.body);
        final tomorrow = DateTime.now().add(const Duration(days: 1));
        final String tomorrowStr = tomorrow.toString().substring(0, 10);

        List tomorrowMeals = [];
        for (var booking in data) {
          if (booking["date"] == tomorrowStr) {
            tomorrowMeals = booking["meals"];
            break;
          }
        }

        setState(() {
          meals = tomorrowMeals;
          isLoading = false;
        });
      } else {
        setState(() {
          meals = [];
          isLoading = false;
        });
      }
    } catch (e) {
      setState(() {
        meals = [];
        isLoading = false;
      });
    }
  }

  ////////////////////////////////////////////////////////////
  /// CONFIRM CANCEL
  ////////////////////////////////////////////////////////////
  void confirmCancel(int mealSlotId, String slotName) {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Row(
          children: [
            const Icon(Icons.warning_amber_rounded, color: Colors.red),
            const SizedBox(width: 8),
            const Text("Cancel Meal"),
          ],
        ),
        content: Text(
          "Are you sure you want to cancel your ${slotName.toUpperCase()} meal?",
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text("Keep it"),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              cancelMeal(mealSlotId);
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
            child: const Text(
              "Yes, Cancel",
              style: TextStyle(color: Colors.white),
            ),
          ),
        ],
      ),
    );
  }

  ////////////////////////////////////////////////////////////
  /// CANCEL MEAL
  ////////////////////////////////////////////////////////////
  Future<void> cancelMeal(int mealSlotId) async {
    setState(() => cancellingSlots.add(mealSlotId));

    try {
      final res = await ApiService.post("/cancel-meal/", {
        "meal_slot_id": mealSlotId,
      });

      final data = jsonDecode(res.body);

      if (!mounted) return;

      if (res.statusCode == 200) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Row(
              children: [
                Icon(Icons.check_circle, color: Colors.white),
                SizedBox(width: 8),
                Text("Meal cancelled successfully"),
              ],
            ),
            backgroundColor: Colors.green.shade700,
            behavior: SnackBarBehavior.floating,
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          ),
        );
        fetchBooking();
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(data["error"] ?? "Error cancelling meal"),
            backgroundColor: Colors.red.shade700,
            behavior: SnackBarBehavior.floating,
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          ),
        );
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text("Something went wrong"),
          backgroundColor: Colors.red.shade700,
          behavior: SnackBarBehavior.floating,
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        ),
      );
    }

    setState(() => cancellingSlots.remove(mealSlotId));
  }

  ////////////////////////////////////////////////////////////
  /// SLOT ICON  (mirrors BookMealsPage)
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
  /// MEAL CARD
  ////////////////////////////////////////////////////////////
  Widget _buildMealCard(Map meal) {
    final int slotId = meal["meal_slot_id"] as int;
    final String slotName = meal["meal_slot"]?.toString() ?? "";
    final String day = meal["day"]?.toString() ?? "";
    final String combo = meal["combo"]?.toString() ?? "";
    final String status = meal["status"]?.toString() ?? "";

    final bool isCancelled = status == "cancelled";
    final bool isCancelling = cancellingSlots.contains(slotId);

    return Card(
      elevation: 3,
      margin: const EdgeInsets.only(bottom: 16),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(14),
      ),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ── Slot header ──────────────────────────────
            Row(
              children: [
                Icon(
                  _slotIcon(slotName),
                  size: 18,
                  color: _primary,
                ),
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
                // Status badge
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: isCancelled
                        ? Colors.red.shade50
                        : Colors.green.shade100,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    isCancelled ? "CANCELLED" : "BOOKED",
                    style: TextStyle(
                      color:
                          isCancelled ? Colors.red : Colors.green.shade700,
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

            // ── Combo detail card ─────────────────────────
            AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: isCancelled
                    ? Colors.grey.shade100
                    : Colors.green.shade50,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: isCancelled
                      ? Colors.grey.shade300
                      : Colors.green.shade300,
                  width: 1,
                ),
              ),
              child: Row(
                children: [
                  // ── Left: day + combo info ──
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Icon(Icons.calendar_today,
                                size: 13, color: Colors.grey.shade600),
                            const SizedBox(width: 4),
                            Text(
                              day,
                              style: TextStyle(
                                fontSize: 12,
                                color: Colors.grey.shade600,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 6),
                        Text(
                          combo,
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 14,
                          ),
                        ),
                      ],
                    ),
                  ),

                  // ── Right: action ──
                  if (isCancelled)
                    Icon(Icons.cancel, color: Colors.red.shade300, size: 24)
                  else if (isCancelling)
                    const SizedBox(
                      height: 22,
                      width: 22,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  else
                    GestureDetector(
                      onTap: () => confirmCancel(slotId, slotName),
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 12, vertical: 7),
                        decoration: BoxDecoration(
                          color: Colors.red.shade50,
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: Colors.red.shade200),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.cancel_outlined,
                                size: 15, color: Colors.red.shade700),
                            const SizedBox(width: 4),
                            Text(
                              "Cancel",
                              style: TextStyle(
                                color: Colors.red.shade700,
                                fontWeight: FontWeight.bold,
                                fontSize: 12,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  ////////////////////////////////////////////////////////////
  /// BUILD
  ////////////////////////////////////////////////////////////
  @override
  Widget build(BuildContext context) {
    final int activeCount =
        meals.where((m) => m["status"] != "cancelled").length;

    return Scaffold(
      appBar: AppBar(
        title: const Text("My Bookings"),
        backgroundColor: _primary,
        foregroundColor: Colors.white,
      ),
      body: isLoading
          ? const Center(child: CircularProgressIndicator())
          : meals.isEmpty
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(Icons.no_meals, size: 48, color: Colors.grey),
                      const SizedBox(height: 12),
                      const Text(
                        "No bookings found",
                        style: TextStyle(color: Colors.grey),
                      ),
                      const SizedBox(height: 16),
                      TextButton(
                        onPressed: fetchBooking,
                        child: const Text("Retry"),
                      ),
                    ],
                  ),
                )
              : RefreshIndicator(
                  onRefresh: fetchBooking,
                  child: ListView(
                    padding: const EdgeInsets.all(16),
                    children: [
                      ...meals.map((m) => _buildMealCard(m)),
                    ],
                  ),
                ),

      // ── Summary bar at the bottom ──────────────────────────
      bottomNavigationBar: meals.isEmpty
          ? null
          : Container(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
              child: ElevatedButton.icon(
                onPressed: activeCount == 0 ? null : null, // informational
                icon: Icon(
                  activeCount == 0
                      ? Icons.check_circle_outline
                      : Icons.restaurant_menu,
                  color: Colors.white,
                ),
                label: Text(
                  activeCount == 0
                      ? "All meals cancelled"
                      : "$activeCount meal${activeCount > 1 ? 's' : ''} active · tap to cancel",
                  style: const TextStyle(fontSize: 15, color: Colors.white),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor:
                      activeCount == 0 ? Colors.grey.shade400 : _primary,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              ),
            ),
    );
  }
}