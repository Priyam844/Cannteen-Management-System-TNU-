import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_application_1/services/api_service.dart';
import 'package:flutter_application_1/pages/student/qr_page.dart';

class GuestBookingPage extends StatefulWidget {
  const GuestBookingPage({super.key});

  @override
  State<GuestBookingPage> createState() => _GuestBookingPageState();
}

class _GuestBookingPageState extends State<GuestBookingPage> {
  List<Map<String, dynamic>> menuByDate = [];
  Map<String, dynamic> hostelTimings = {};
  int lateBookingLeadTimeHours = 2;
  DateTime selectedDate = DateTime.now();
  List<Map<String, dynamic>> hostels = [];
  int? selectedHostelId;

  Map<String, Map<String, dynamic>> selectedMeals = {}; // slotComboKey -> {combo_id, meal_slot_id, quantity, price, combo_items}
  Map<String, Map<String, dynamic>> selectedItems = {}; // slotItemKey -> {item_id, meal_slot_id, quantity, price}

  bool isLoading = true;
  bool isBooking = false;
  String userRole = "student";
  double walletBalance = 0.0;

  @override
  void initState() {
    super.initState();
    fetchInitialData();
  }

  Future<void> fetchInitialData() async {
    setState(() => isLoading = true);
    await Future.wait([fetchProfile(), fetchHostels()]);
    await fetchMenu();
  }

  Future<void> fetchProfile() async {
    try {
      final res = await ApiService.get("/profile/");
      if (res.statusCode == 200) {
        final data = jsonDecode(res.body);
        if (mounted) {
          setState(() {
            userRole = data["role"] ?? "student";
            walletBalance = double.tryParse(data["wallet_balance"].toString()) ?? 0.0;
            if (selectedHostelId == null && data["hostel_id"] != null) {
              selectedHostelId = data["hostel_id"];
            }
          });
        }
      }
    } catch (e) {
      debugPrint("Profile Error: $e");
    }
  }

  Future<void> fetchHostels() async {
    try {
      final res = await ApiService.get("/hostels/");
      if (res.statusCode == 200) {
        if (mounted) {
          setState(() {
            hostels = List<Map<String, dynamic>>.from(jsonDecode(res.body));
          });
        }
      }
    } catch (e) {
      debugPrint("Hostels Error: $e");
    }
  }

  int _toInt(dynamic value) {
    if (value == null) return 0;
    if (value is int) return value;
    return int.tryParse(value.toString()) ?? 0;
  }

  Future<void> fetchMenu() async {
    if (mounted) setState(() => isLoading = true);

    try {
      String url = "/weekly-menu/";
      if (selectedHostelId != null) {
        url += "?hostel_id=$selectedHostelId";
      }

      final menuRes = await ApiService.get(url);

      if (menuRes.statusCode != 200) {
        showError("Failed to load menu");
        if (mounted) setState(() => isLoading = false);
        return;
      }

      selectedMeals.clear();
      selectedItems.clear();

      final menuData = jsonDecode(menuRes.body);
      if (mounted) {
        setState(() {
          menuByDate = List<Map<String, dynamic>>.from(menuData["data"]);
          hostelTimings = menuData["hostel_timings"] ?? {};
          lateBookingLeadTimeHours = menuData["late_booking_lead_time_hours"] ?? 2;
          isLoading = false;
        });
      }
    } catch (e) {
      debugPrint("Fetch Error: $e");
      if (mounted) setState(() => isLoading = false);
    }
  }

  double getPriceForRole(dynamic obj, {bool isGuest = true}) {
    return double.tryParse(obj["guest_price"]?.toString() ?? "0.0") ?? 0.0;
  }

  double calculateTotal() {
    double total = 0;
    selectedMeals.forEach((key, value) {
      final gp = value["price_guest"] ?? 0.0;
      final gq = _toInt(value["guest_quantity"]);
      total += (gp * gq);
    });
    selectedItems.forEach((key, value) {
      final gp = value["price_guest"] ?? 0.0;
      final gq = _toInt(value["guest_quantity"]);
      total += (gp * gq);
    });
    return total;
  }

  Future<void> bookGuestMeals() async {
    double total = calculateTotal();
    if (total == 0) {
      showError("Please select at least one guest meal");
      return;
    }

    if (total > walletBalance) {
      showError("Insufficient wallet balance");
      return;
    }

    setState(() => isBooking = true);

    try {
      final formattedMeals = selectedMeals.values.map((m) {
        final Map<String, int> itemMap = Map<String, int>.from(m["combo_items"] ?? {});
        final itemList = itemMap.entries.map((e) => {"id": int.parse(e.key), "qty": e.value}).toList();

        return {
          "combo_id": m["combo_id"],
          "meal_slot_id": m["meal_slot_id"],
          "quantity": 0,
          "guest_quantity": m["guest_quantity"],
          "combo_items": itemList,
        };
      }).toList();

      final formattedItems = selectedItems.values.map((i) {
        return {
          "item_id": i["item_id"],
          "meal_slot_id": i["meal_slot_id"],
          "quantity": 0,
          "guest_quantity": i["guest_quantity"],
        };
      }).toList();

      final res = await ApiService.post("/book-meals/", {
        "date": selectedDate.toString().split(' ')[0],
        "meals": formattedMeals,
        "items": formattedItems,
      });

      if (res.statusCode == 200) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Guest booking successful!")));
        Navigator.pushReplacement(context, MaterialPageRoute(builder: (_) => const QRPage()));
      } else {
        final data = jsonDecode(res.body);
        showError(data["error"]?.toString() ?? "Booking failed");
      }
    } catch (e) {
      showError("Something went wrong");
    } finally {
      if (mounted) setState(() => isBooking = false);
    }
  }

  void showError(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
  }

  @override
  Widget build(BuildContext context) {
    double currentTotal = calculateTotal();
    final dateStr = selectedDate.toString().split(' ')[0];
    final dayData = menuByDate.firstWhere(
      (d) => d["date"] == dateStr,
      orElse: () => {"slots": []},
    );
    final slots = dayData["slots"] as List;

    return Scaffold(
      appBar: AppBar(
        title: const Text("Guest Booking (Today)"),
        backgroundColor: Colors.blueGrey,
        foregroundColor: Colors.white,
      ),
      body: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            color: Colors.grey.shade100,
            child: DropdownButtonFormField<int>(
              value: selectedHostelId,
              decoration: const InputDecoration(
                labelText: "Select Hostel Canteen",
                isDense: true,
                border: OutlineInputBorder(),
                filled: true,
                fillColor: Colors.white,
              ),
              items: hostels.map((h) {
                return DropdownMenuItem<int>(
                  value: h["id"],
                  child: Text(h["name"] ?? "Unknown Canteen"),
                );
              }).toList(),
              onChanged: (val) {
                setState(() => selectedHostelId = val);
                fetchMenu();
              },
            ),
          ),
          Expanded(
            child: isLoading
                ? const Center(child: CircularProgressIndicator())
                : slots.isEmpty
                ? const Center(child: Text("No menu available for today"))
                : ListView.builder(
                    padding: const EdgeInsets.all(16),
                    itemCount: slots.length,
                    itemBuilder: (context, index) => buildSlotCard(slots[index]),
                  ),
          ),
        ],
      ),
      bottomNavigationBar: Container(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
        decoration: BoxDecoration(
          color: Colors.white,
          boxShadow: const [BoxShadow(color: Colors.black12, blurRadius: 10, offset: Offset(0, -2))],
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  "Total: ₹${currentTotal.toStringAsFixed(2)}",
                  style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.blueGrey),
                ),
                Text("Wallet: ₹${walletBalance.toStringAsFixed(2)}", style: TextStyle(fontSize: 12, color: currentTotal > walletBalance ? Colors.red : Colors.grey)),
              ],
            ),
            ElevatedButton(
              onPressed: (currentTotal == 0 || isBooking || currentTotal > walletBalance) ? null : bookGuestMeals,
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.blueGrey,
                padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 12),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              ),
              child: Text(isBooking ? "Processing..." : "Confirm Guest Booking", style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
            ),
          ],
        ),
      ),
    );
  }

  Widget buildSlotCard(Map<String, dynamic> slot) {
    final slotName = slot["slot"]?.toString() ?? "";
    final slotId = _toInt(slot["id"]);
    final combos = List<Map<String, dynamic>>.from(slot["combos"] ?? []);
    final items = List<Map<String, dynamic>>.from(slot["items"] ?? []);

    final now = DateTime.now();
    bool isClosed = false;
    String statusMsg = "";

    final timings = hostelTimings[slotName.toLowerCase()];
    if (timings != null && timings is List && timings.isNotEmpty) {
      final startStr = timings[0].toString();
      final startParts = startStr.split(':');
      final startHour = int.parse(startParts[0]);
      final startMin = int.parse(startParts[1]);
      final mealTime = DateTime(now.year, now.month, now.day, startHour, startMin);

      if (now.isAfter(mealTime.subtract(Duration(hours: lateBookingLeadTimeHours)))) {
        isClosed = true;
        statusMsg = "Too Late (Closed)";
      }
    }

    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      elevation: isClosed ? 0 : 2,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Opacity(
          opacity: isClosed ? 0.6 : 1.0,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(slotName.toUpperCase(), style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                  if (isClosed) Text(statusMsg, style: const TextStyle(color: Colors.red, fontSize: 10, fontWeight: FontWeight.bold)),
                ],
              ),
              const Divider(height: 24),
              ...combos.map((combo) {
                final comboId = _toInt(combo["id"]);
                final key = "${slotId}_$comboId";
                final isSelected = selectedMeals.containsKey(key);
                final comboItems = List<Map<String, dynamic>>.from(combo["items_list"] ?? []);

                return Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(combo["name"]?.toString() ?? "Combo"),
                            Text("Guest Price: ₹${getPriceForRole(combo)}", style: const TextStyle(fontSize: 11, color: Colors.grey)),
                          ],
                        ),
                      ),
                      if (!isClosed)
                        _buildCounter(
                          isSelected ? _toInt(selectedMeals[key]?["guest_quantity"]) : 0,
                          onAdd: () => setState(() {
                            if (!isSelected) {
                              selectedMeals[key] = {
                                "combo_id": comboId,
                                "meal_slot_id": slotId,
                                "guest_quantity": 1,
                                "price_guest": getPriceForRole(combo),
                                "combo_items": {for (var i in comboItems) _toInt(i["id"]).toString(): 1},
                              };
                            } else {
                              selectedMeals[key]?["guest_quantity"] = _toInt(selectedMeals[key]?["guest_quantity"]) + 1;
                            }
                          }),
                          onRemove: () => setState(() {
                            int gq = _toInt(selectedMeals[key]?["guest_quantity"]);
                            if (gq > 1) {
                              selectedMeals[key]?["guest_quantity"] = gq - 1;
                            } else {
                              selectedMeals.remove(key);
                            }
                          }),
                        ),
                    ],
                  ),
                );
              }),
              if (items.isNotEmpty) ...[
                const Padding(padding: EdgeInsets.symmetric(vertical: 8), child: Text("EXTRA ITEMS", style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.blueGrey))),
                ...items.map((item) {
                  final itemId = _toInt(item["id"]);
                  final key = "${slotId}_$itemId";
                  final isSelected = selectedItems.containsKey(key);

                  return Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: Row(
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(item["name"]?.toString() ?? "Item"),
                              Text("Guest Price: ₹${getPriceForRole(item)}", style: const TextStyle(fontSize: 11, color: Colors.grey)),
                            ],
                          ),
                        ),
                        if (!isClosed)
                          _buildCounter(
                            isSelected ? _toInt(selectedItems[key]?["guest_quantity"]) : 0,
                            onAdd: () => setState(() {
                              if (!isSelected) {
                                selectedItems[key] = {
                                  "item_id": itemId,
                                  "meal_slot_id": slotId,
                                  "guest_quantity": 1,
                                  "price_guest": getPriceForRole(item),
                                };
                              } else {
                                selectedItems[key]?["guest_quantity"] = _toInt(selectedItems[key]?["guest_quantity"]) + 1;
                              }
                            }),
                            onRemove: () => setState(() {
                              int gq = _toInt(selectedItems[key]?["guest_quantity"]);
                              if (gq > 1) {
                                selectedItems[key]?["guest_quantity"] = gq - 1;
                              } else {
                                selectedItems.remove(key);
                              }
                            }),
                          ),
                      ],
                    ),
                  );
                }),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildCounter(int count, {required VoidCallback onAdd, required VoidCallback onRemove}) {
    if (count == 0) {
      return ElevatedButton(onPressed: onAdd, style: ElevatedButton.styleFrom(minimumSize: const Size(60, 30), backgroundColor: Colors.blueGrey), child: const Text("Add", style: TextStyle(color: Colors.white, fontSize: 12)));
    }
    return Row(
      children: [
        IconButton(icon: const Icon(Icons.remove_circle_outline, color: Colors.blueGrey), onPressed: onRemove),
        Text("$count", style: const TextStyle(fontWeight: FontWeight.bold)),
        IconButton(icon: const Icon(Icons.add_circle_outline, color: Colors.blueGrey), onPressed: onAdd),
      ],
    );
  }
}
