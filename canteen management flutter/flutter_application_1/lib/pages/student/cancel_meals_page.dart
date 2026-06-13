import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_application_1/services/api_service.dart';

class CancelMealsPage extends StatefulWidget {
  const CancelMealsPage({super.key});

  @override
  State<CancelMealsPage> createState() => _CancelMealsPageState();
}

class _CancelMealsPageState extends State<CancelMealsPage> {
  List bookings = [];
  bool isLoading = true;
  String cancellationCutoffTime = "16:00";
  Set<int> cancellingMealIds = {};
  Set<int> cancellingItemIds = {};

  static const _primary = Color.fromARGB(255, 152, 29, 68);

  @override
  void initState() {
    super.initState();
    fetchBookings();
  }

  Future<void> fetchBookings() async {
    if (!mounted) return;
    setState(() => isLoading = true);
    try {
      final res = await ApiService.get("/my-booking/");
      if (res.statusCode == 200) {
        final data = jsonDecode(res.body);
        if (mounted) {
          setState(() {
            bookings = data["data"] ?? [];
            cancellationCutoffTime = data["cancellation_cutoff_time"] ?? "16:00";
            isLoading = false;
          });
        }
      } else {
        if (mounted) setState(() => isLoading = false);
      }
    } catch (e) {
      if (mounted) setState(() => isLoading = false);
    }
  }

  Future<void> cancelAction({int? mealId, int? itemId, required String name}) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text("Confirm Cancellation"),
        content: Text("Are you sure you want to cancel $name?"),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text("No")),
          TextButton(onPressed: () => Navigator.pop(context, true), child: const Text("Yes, Cancel")),
        ],
      ),
    );

    if (confirmed != true) return;

    setState(() {
      if (mealId != null) cancellingMealIds.add(mealId);
      if (itemId != null) cancellingItemIds.add(itemId);
    });

    try {
      final res = await ApiService.post("/cancel-meal/", {
        if (mealId != null) "meal_id": mealId,
        if (itemId != null) "item_id": itemId,
      });

      if (res.statusCode == 200) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Cancelled successfully")));
        fetchBookings();
      } else {
        final data = jsonDecode(res.body);
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(data["error"] ?? "Failed to cancel")));
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Error occurred")));
    } finally {
      if (mounted) {
        setState(() {
          if (mealId != null) cancellingMealIds.remove(mealId);
          if (itemId != null) cancellingItemIds.remove(itemId);
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Cancel Bookings"),
        backgroundColor: _primary,
        foregroundColor: Colors.white,
      ),
      body: isLoading
          ? const Center(child: CircularProgressIndicator())
          : bookings.isEmpty
              ? const Center(child: Text("No active bookings found"))
              : RefreshIndicator(
                  onRefresh: fetchBookings,
                  child: ListView.builder(
                    padding: const EdgeInsets.all(16),
                    itemCount: bookings.length,
                    itemBuilder: (context, index) => buildBookingCard(bookings[index]),
                  ),
                ),
    );
  }

  Widget buildBookingCard(Map booking) {
    final dateStr = booking["date"];
    final meals = (booking["meals"] as List? ?? []);
    final items = (booking["items"] as List? ?? []);

    // ── Cancellation Deadline Logic ──
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final bookingDate = DateTime.parse(dateStr);
    final diff = bookingDate.difference(today).inDays;

    bool canCancelDate = false;
    String statusNote = "";

    if (diff == 2) {
      final parts = cancellationCutoffTime.split(':');
      final hour = int.parse(parts[0]);
      final min = int.parse(parts[1]);
      final cutoff = DateTime(now.year, now.month, now.day, hour, min);
      if (now.isBefore(cutoff)) {
        canCancelDate = true;
      } else {
        statusNote = " (Window Closed at ${cancellationCutoffTime})";
      }
    } else if (diff > 2) {
      canCancelDate = true;
    } else {
      statusNote = " (Cannot cancel today/tomorrow)";
    }
    
    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      elevation: canCancelDate ? 2 : 0,
      color: canCancelDate ? Colors.white : Colors.grey.shade50,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: canCancelDate ? BorderSide.none : BorderSide(color: Colors.grey.shade300),
      ),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Text("Date: $dateStr", style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                if (statusNote.isNotEmpty)
                  Expanded(child: Text(statusNote, style: TextStyle(color: Colors.red.shade800, fontSize: 10, fontWeight: FontWeight.bold))),
              ],
            ),
            const Divider(),
            ...meals.map((m) => buildItemTile(m, isMeal: true, canCancel: canCancelDate)),
            ...items.map((i) => buildItemTile(i, isMeal: false, canCancel: canCancelDate)),
          ],
        ),
      ),
    );
  }

  Widget buildItemTile(Map data, {required bool isMeal, required bool canCancel}) {
    final id = data["id"];
    final name = data["name"];
    final slot = data["meal_slot"];
    final qty = data["quantity"];
    final status = data["status"];
    final bool isCancelled = status == "cancelled";
    final bool isConsumed = status == "consumed";
    final bool isProcessing = isMeal ? cancellingMealIds.contains(id) : cancellingItemIds.contains(id);

    return ListTile(
      contentPadding: EdgeInsets.zero,
      title: Text("$name (x$qty)"),
      subtitle: Text("$slot • $status"),
      trailing: (isCancelled || isConsumed || isProcessing)
          ? Text(status.toUpperCase(), style: TextStyle(color: isCancelled ? Colors.red : (isConsumed ? Colors.green : Colors.blue)))
          : (canCancel && status == "booked"
              ? ElevatedButton(
                  onPressed: () => cancelAction(
                    mealId: isMeal ? id : null,
                    itemId: isMeal ? null : id,
                    name: name,
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.red,
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 0),
                    minimumSize: const Size(60, 30),
                  ),
                  child: const Text("Cancel", style: TextStyle(color: Colors.white, fontSize: 12)),
                )
              : null),
    );
  }
}
