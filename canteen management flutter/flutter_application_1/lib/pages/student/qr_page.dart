import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:flutter_application_1/services/api_service.dart';

class QRPage extends StatefulWidget {
  const QRPage({super.key});

  @override
  State<QRPage> createState() => _QRPageState();
}

class _QRPageState extends State<QRPage> {
  bool isLoading = true;
  List bookings = [];

  static const _primary = Color.fromARGB(255, 152, 29, 68);

  @override
  void initState() {
    super.initState();
    fetchBooking();
  }

  Future<void> fetchBooking() async {
    setState(() => isLoading = true);

    try {
      final res = await ApiService.get("/my-booking/");

      if (res.statusCode == 200) {
        final data = jsonDecode(res.body);

        setState(() {
          bookings = data is Map ? data["data"] : data;
          isLoading = false;
        });
      } else {
        setState(() {
          bookings = [];
          isLoading = false;
        });
      }
    } catch (e) {
      setState(() {
        bookings = [];
        isLoading = false;
      });
    }
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

  int _toInt(dynamic value) {
    if (value == null) return 0;
    if (value is int) return value;
    return int.tryParse(value.toString()) ?? 0;
  }

  @override
  Widget build(BuildContext context) {
    if (isLoading) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    if (bookings.isEmpty) {
      return Scaffold(
        appBar: AppBar(title: const Text("Meal QR Code")),
        body: const Center(child: Text("No bookings found")),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text("Meal QR Codes"),
        backgroundColor: _primary,
        foregroundColor: Colors.white,
      ),
      body: RefreshIndicator(
        onRefresh: fetchBooking,
        child: ListView.builder(
          padding: const EdgeInsets.all(16),
          itemCount: bookings.length,
          itemBuilder: (context, index) {
            final booking = bookings[index];

            final qrData = booking["qr_uuid"].toString();

            final meals = (booking["meals"] as List)
                .where((m) => m["status"] != "cancelled")
                .toList();

            if (meals.isEmpty) return const SizedBox();

            return Card(
              margin: const EdgeInsets.only(bottom: 20),
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  children: [
                    Text(
                      "Valid for: ${booking["date"]}",
                      style: const TextStyle(fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 10),

                    QrImageView(
                      data: qrData,
                      size: 200,
                    ),

                    const SizedBox(height: 10),

                    ...meals.map((m) {
                      final selectedItems = (m["selected_items"] as List? ?? []);
                      return Column(
                        children: [
                          const Divider(),
                          Text(
                            "${m["meal_slot"].toUpperCase()} - ${m["name"]}",
                            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                          ),
                          if (selectedItems.isNotEmpty)
                             Padding(
                               padding: const EdgeInsets.symmetric(vertical: 4),
                               child: Text(
                                 "Items: ${selectedItems.where((si) => _toInt(si["quantity"]) > 0).map((si) => "${si["name"]} (x${si["quantity"]})").join(", ")}",
                                 textAlign: TextAlign.center,
                                 style: const TextStyle(fontSize: 12, color: Colors.blueGrey),
                               ),
                             ),
                        ],
                      );
                    }),
                    
                    // Also show standalone items
                    ...((booking["items"] as List? ?? [])
                        .where((i) => i["status"] != "cancelled")
                        .map((i) {
                      return Column(
                        children: [
                          const Divider(),
                          Text(
                            "${i["meal_slot"].toUpperCase()} - ${i["name"]} (x${i["quantity"]})",
                            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                          ),
                        ],
                      );
                    })),
                  ],
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}