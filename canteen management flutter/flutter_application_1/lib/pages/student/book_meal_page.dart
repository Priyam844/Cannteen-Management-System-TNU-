import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_application_1/services/api_service.dart';
import 'package:flutter_application_1/pages/student/qr_page.dart';

class BookMealPage extends StatefulWidget {
  const BookMealPage({super.key});

  @override
  State<BookMealPage> createState() => _BookMealPageState();
}

class _BookMealPageState extends State<BookMealPage> {
  List<Map<String, dynamic>> menuByDate = [];
  Map<String, dynamic> hostelTimings = {};
  String bookingCutoffTime = "14:00";
  int lateBookingLeadTimeHours = 2;
  DateTime selectedDate = DateTime.now();
  List<Map<String, dynamic>> hostels = [];
  int? selectedHostelId;

  Map<String, Map<String, dynamic>> selectedMeals =
      {}; // slotComboKey -> {combo_id, meal_slot_id, quantity, price, combo_items}
  Map<String, Map<String, dynamic>> selectedItems =
      {}; // slotItemKey -> {item_id, meal_slot_id, quantity, price}

  Map<String, int> alreadyBookedCombos = {};
  Map<String, int> alreadyBookedItems = {};

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
            walletBalance =
                double.tryParse(data["wallet_balance"].toString()) ?? 0.0;
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
            // 🚀 Auto-select the first available canteen if none is selected
            if (hostels.isNotEmpty && selectedHostelId == null) {
              selectedHostelId = hostels.first["id"];
            }
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
      final bookingRes = await ApiService.get("/my-booking/");

      if (menuRes.statusCode != 200) {
        showError("Failed to load menu");
        if (mounted) setState(() => isLoading = false);
        return;
      }

      alreadyBookedCombos.clear();
      alreadyBookedItems.clear();
      selectedMeals.clear();
      selectedItems.clear();

      if (bookingRes.statusCode == 200) {
        final bookingResponse = jsonDecode(bookingRes.body);
        final bookingData = bookingResponse is Map ? bookingResponse["data"] : bookingResponse;
        
        if (bookingData is List) {
          final dateStr = selectedDate.toString().split(' ')[0];
          for (var booking in bookingData) {
            if (booking["date"] == dateStr) {
              final meals = booking["meals"] as List?;
              if (meals != null) {
                for (var m in meals) {
                  if (m["status"] == "booked") {
                    final mid = _toInt(m["meal_slot_id"]);
                    final cid = _toInt(m["combo_id"]);
                    if (mid != 0 && cid != 0) {
                      alreadyBookedCombos["${mid}_$cid"] = _toInt(
                        m["quantity"],
                      );
                    }
                  }
                }
              }
              final items = booking["items"] as List?;
              if (items != null) {
                for (var i in items) {
                  if (i["status"] == "booked") {
                    final mid = _toInt(i["meal_slot_id"]);
                    final iid = _toInt(i["item_id"]);
                    if (mid != 0 && iid != 0) {
                      final key = "${mid}_$iid";
                      alreadyBookedItems[key] =
                          (alreadyBookedItems[key] ?? 0) +
                          _toInt(i["quantity"]);
                    }
                  }
                }
              }
            }
          }
        }
      }

      final menuData = jsonDecode(menuRes.body);
      if (mounted) {
        setState(() {
          menuByDate = List<Map<String, dynamic>>.from(menuData["data"]);
          hostelTimings = menuData["hostel_timings"] ?? {};
          bookingCutoffTime = menuData["booking_cutoff_time"] ?? "14:00";
          lateBookingLeadTimeHours =
              menuData["late_booking_lead_time_hours"] ?? 2;
          isLoading = false;
        });
      }
    } catch (e) {
      debugPrint("Fetch Error: $e");
      if (mounted) setState(() => isLoading = false);
    }
  }

  double getPriceForRole(dynamic obj, {bool isGuest = false}) {
    if (isGuest)
      return double.tryParse(obj["guest_price"]?.toString() ?? "0.0") ?? 0.0;
    if (userRole == "faculty")
      return double.tryParse(obj["faculty_price"]?.toString() ?? "0.0") ?? 0.0;
    if (userRole == "staff")
      return double.tryParse(obj["staff_price"]?.toString() ?? "0.0") ?? 0.0;
    return double.tryParse(obj["price"]?.toString() ?? "0.0") ?? 0.0;
  }

  double _getInitialComboPrice(dynamic combo, {bool isGuest = false}) {
    final itemsList = List<Map<String, dynamic>>.from(
      combo["items_list"] ?? [],
    );
    double total = 0;
    for (var item in itemsList) {
      total += getPriceForRole(item, isGuest: isGuest);
    }
    return total;
  }

  double _calculateComboPrice(
    dynamic combo,
    Map<String, int> comboItems, {
    bool isGuest = false,
  }) {
    double total = 0;
    final itemsList = List<Map<String, dynamic>>.from(
      combo["items_list"] ?? [],
    );
    comboItems.forEach((itemIdStr, qty) {
      final item = itemsList.firstWhere(
        (it) => it["id"].toString() == itemIdStr,
        orElse: () => {},
      );
      if (item.isNotEmpty) {
        total += getPriceForRole(item, isGuest: isGuest) * qty;
      }
    });
    return total;
  }

  double calculateTotal() {
    double total = 0;
    selectedMeals.forEach((key, value) {
      final p = value["price_self"] ?? 0.0;
      final gp = value["price_guest"] ?? 0.0;
      final q = _toInt(value["quantity"]);
      final gq = _toInt(value["guest_quantity"]);
      total += (p * q) + (gp * gq);
    });
    selectedItems.forEach((key, value) {
      final p = value["price_self"] ?? 0.0;
      final gp = value["price_guest"] ?? 0.0;
      final q = _toInt(value["quantity"]);
      final gq = _toInt(value["guest_quantity"]);
      total += (p * q) + (gp * gq);
    });
    return total;
  }

  Future<void> bookMeals() async {
    double total = calculateTotal();
    if (total == 0) {
      showError("Please select at least one item");
      return;
    }

    if (total > walletBalance) {
      showError("Insufficient wallet balance");
      return;
    }

    setState(() => isBooking = true);

    try {
      final formattedMeals = selectedMeals.values.map((m) {
        final Map<String, int> itemMap = Map<String, int>.from(
          m["combo_items"] ?? {},
        );
        final itemList = itemMap.entries
            .map((e) => {"id": int.parse(e.key), "qty": e.value})
            .toList();

        return {
          "combo_id": m["combo_id"],
          "meal_slot_id": m["meal_slot_id"],
          "quantity": m["quantity"],
          "guest_quantity": m["guest_quantity"],
          "combo_items": itemList,
        };
      }).toList();

      final formattedItems = selectedItems.values.map((i) {
        return {
          "item_id": i["item_id"],
          "meal_slot_id": i["meal_slot_id"],
          "quantity": i["quantity"],
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
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text("Booking successful!")));
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (_) => const QRPage()),
        );
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
        title: const Text("Book Meals"),
        backgroundColor: const Color.fromARGB(255, 152, 29, 68),
        foregroundColor: Colors.white,
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 16),
            child: Center(
              child: Text(
                "Total: ₹${currentTotal.toStringAsFixed(0)}",
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                ),
              ),
            ),
          ),
        ],
      ),
      body: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            color: Colors.grey.shade100,
            child: Column(
              children: [
                DropdownButtonFormField<int>(
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
                const SizedBox(height: 12),
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    children: menuByDate
                        .take(3)
                        .where((day) {
                          final d = DateTime.parse(day["date"]);
                          final now = DateTime.now();
                          final today = DateTime(now.year, now.month, now.day);
                          final chipDate = DateTime(d.year, d.month, d.day);
                          final diff = chipDate.difference(today).inDays;
                          return diff != 1; // 🚫 Exclude Tomorrow
                        })
                        .map((day) {
                          final d = DateTime.parse(day["date"]);
                          String label = day["day"];
                          final now = DateTime.now();
                          if (d.year == now.year &&
                              d.month == now.month &&
                              d.day == now.day)
                            label = "Today";

                          return Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 4),
                            child: _dateChip(label, d),
                          );
                        })
                        .toList(),
                  ),
                ),
              ],
            ),
          ),

          Expanded(
            child: isLoading
                ? const Center(child: CircularProgressIndicator())
                : slots.isEmpty
                ? const Center(child: Text("No menu available for this date"))
                : ListView.builder(
                    padding: const EdgeInsets.all(16),
                    itemCount: slots.length,
                    itemBuilder: (context, index) =>
                        buildSlotCard(slots[index]),
                  ),
          ),
        ],
      ),
      bottomNavigationBar: Container(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
        decoration: BoxDecoration(
          color: Colors.white,
          boxShadow: const [
            BoxShadow(
              color: Colors.black12,
              blurRadius: 10,
              offset: Offset(0, -2),
            ),
          ],
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                AnimatedSwitcher(
                  duration: const Duration(milliseconds: 300),
                  transitionBuilder: (child, animation) =>
                      ScaleTransition(scale: animation, child: child),
                  child: Text(
                    "Total: ₹${currentTotal.toStringAsFixed(2)}",
                    key: ValueKey(currentTotal),
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: Color.fromARGB(255, 152, 29, 68),
                    ),
                  ),
                ),
                Text(
                  "Wallet: ₹${walletBalance.toStringAsFixed(2)}",
                  style: TextStyle(
                    fontSize: 12,
                    color: currentTotal > walletBalance
                        ? Colors.red
                        : Colors.grey,
                  ),
                ),
              ],
            ),
            ElevatedButton(
              onPressed:
                  (currentTotal == 0 ||
                      isBooking ||
                      currentTotal > walletBalance)
                  ? null
                  : bookMeals,
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color.fromARGB(255, 152, 29, 68),
                padding: const EdgeInsets.symmetric(
                  horizontal: 32,
                  vertical: 12,
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
              child: Text(
                isBooking ? "Processing..." : "Confirm Book",
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _dateChip(String label, DateTime date) {
    final isSelected =
        selectedDate.day == date.day && selectedDate.month == date.month;

    return GestureDetector(
      onTap: () {
        setState(() => selectedDate = date);
        fetchMenu();
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          color: isSelected
              ? const Color.fromARGB(255, 152, 29, 68)
              : Colors.white,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: const Color.fromARGB(255, 152, 29, 68),
            width: isSelected ? 0 : 1,
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: isSelected
                ? Colors.white
                : const Color.fromARGB(255, 152, 29, 68),
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
    );
  }

  Widget buildSlotCard(Map<String, dynamic> slot) {
    final slotName = slot["slot"]?.toString() ?? "";
    final slotId = _toInt(slot["id"]);
    final combos = List<Map<String, dynamic>>.from(slot["combos"] ?? []);
    final items = List<Map<String, dynamic>>.from(slot["items"] ?? []);

    // ── Deadline Logic ──
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final dateDiff = selectedDate.difference(today).inDays;

    bool isClosed = false;
    String statusMsg = "";

    if (dateDiff == 2) {
      final cutoffParts = bookingCutoffTime.split(':');
      final cutoffHour = int.parse(cutoffParts[0]);
      final cutoffMin = int.parse(cutoffParts[1]);
      if (now.hour > cutoffHour ||
          (now.hour == cutoffHour && now.minute >= cutoffMin)) {
        statusMsg = "Late Booking";
      }
    } else if (dateDiff == 1) {
      statusMsg = "Late Booking";
    }

    if (dateDiff <= 1 || statusMsg == "Late Booking") {
      final timings = hostelTimings[slotName.toLowerCase()];
      if (timings != null && timings is List && timings.isNotEmpty) {
        final startStr = timings[0].toString();
        final startParts = startStr.split(':');
        final startHour = int.parse(startParts[0]);
        final startMin = int.parse(startParts[1]);
        
        final mealTime = DateTime(
          selectedDate.year,
          selectedDate.month,
          selectedDate.day,
          startHour,
          startMin,
        );

        if (now.isAfter(mealTime.subtract(Duration(hours: lateBookingLeadTimeHours)))) {
          isClosed = true;
          statusMsg = "Too Late (Closed)";
        } else if (dateDiff < 2 || (dateDiff == 2 && statusMsg == "Late Booking")) {
          statusMsg = "Late Booking";
        }
      }
    }

    final bool isSlotOccupiedInDb = combos.any(
      (c) => (alreadyBookedCombos["${slotId}_${_toInt(c['id'])}"] ?? 0) > 0,
    );

    // ── Calculate Slot Total ──
    double slotTotal = 0;
    for (var c in combos) {
      final key = "${slotId}_${_toInt(c['id'])}";
      if (selectedMeals.containsKey(key)) {
        final val = selectedMeals[key]!;
        slotTotal += (val["price_self"] ?? 0) * _toInt(val["quantity"]);
      }
    }
    for (var i in items) {
      final key = "${slotId}_${_toInt(i['id'])}";
      if (selectedItems.containsKey(key)) {
        final val = selectedItems[key]!;
        slotTotal += (val["price_self"] ?? 0) * _toInt(val["quantity"]);
      }
    }

    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      elevation: isClosed ? 0 : 2,
      color: isClosed ? Colors.grey.shade50 : Colors.white,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(15),
        side: isClosed
            ? BorderSide(color: Colors.grey.shade300)
            : BorderSide.none,
      ),
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
                  Row(
                    children: [
                      Icon(
                        _slotIcon(slotName),
                        color: isClosed
                            ? Colors.grey
                            : const Color.fromARGB(255, 152, 29, 68),
                      ),
                      const SizedBox(width: 10),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            slotName.toUpperCase(),
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                              letterSpacing: 1,
                              color: isClosed ? Colors.grey : Colors.black,
                            ),
                          ),
                          if (slotTotal > 0)
                            Text(
                              "Slot Total: ₹${slotTotal.toStringAsFixed(1)}",
                              style: const TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.bold,
                                color: Color.fromARGB(255, 152, 29, 68),
                              ),
                            ),
                        ],
                      ),
                    ],
                  ),
                  if (isClosed)
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.red.shade50,
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        statusMsg,
                        style: TextStyle(
                          color: Colors.red.shade800,
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    )
                  else if (isSlotOccupiedInDb)
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.green.shade50,
                        borderRadius: BorderRadius.circular(6),
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
              const Divider(height: 24),

              ...combos.map((combo) {
                final comboId = _toInt(combo["id"]);
                final key = "${slotId}_$comboId";
                final isThisComboBookedInDb =
                    (alreadyBookedCombos[key] ?? 0) > 0;
                final isSelected = selectedMeals.containsKey(key);
                final comboItems = List<Map<String, dynamic>>.from(
                  combo["items_list"] ?? [],
                );

                return Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  combo["name"]?.toString() ?? "Unnamed Combo",
                                  style: const TextStyle(
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                Text(
                                  "₹${_getInitialComboPrice(combo).toStringAsFixed(1)}",
                                  style: const TextStyle(
                                    fontSize: 11,
                                    color: Colors.grey,
                                  ),
                                ),
                                if (isThisComboBookedInDb)
                                  const Text(
                                    "Currently Booked",
                                    style: TextStyle(
                                      fontSize: 11,
                                      color: Colors.green,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                              ],
                            ),
                          ),
                          if (!isClosed && !isSlotOccupiedInDb)
                            ElevatedButton(
                              onPressed: () => setState(() {
                                if (isSelected) {
                                  selectedMeals.remove(key);
                                } else {
                                  // Remove any other combo selected in THIS slot first
                                  selectedMeals.removeWhere((k, v) => k.startsWith("${slotId}_"));
                                  
                                  selectedMeals[key] = {
                                    "combo_id": comboId,
                                    "meal_slot_id": slotId,
                                    "quantity": 1,
                                    "guest_quantity": 0,
                                    "price_self": _calculateComboPrice(
                                      combo,
                                      {for (var i in comboItems) _toInt(i["id"]).toString(): 1},
                                    ),
                                    "price_guest": _calculateComboPrice(
                                      combo,
                                      {for (var i in comboItems) _toInt(i["id"]).toString(): 1},
                                      isGuest: true,
                                    ),
                                    "combo_items": {
                                      for (var i in comboItems)
                                        _toInt(i["id"]).toString(): 1,
                                    },
                                  };
                                }
                              }),
                              style: ElevatedButton.styleFrom(
                                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 0),
                                minimumSize: const Size(80, 30),
                                backgroundColor: isSelected 
                                    ? Colors.green 
                                    : const Color.fromARGB(255, 152, 29, 68),
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                              ),
                              child: Text(
                                isSelected ? "Selected" : "Add",
                                style: const TextStyle(color: Colors.white, fontSize: 12),
                              ),
                            ),
                        ],
                      ),
                      if (isSelected)
                        Padding(
                          padding: const EdgeInsets.only(left: 22, top: 4),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                "Subtotal: ₹${((selectedMeals[key]?["price_self"] ?? 0) * _toInt(selectedMeals[key]?["quantity"])).toStringAsFixed(1)}",
                                style: const TextStyle(
                                  fontSize: 10,
                                  color: Color.fromARGB(255, 152, 29, 68),
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              const SizedBox(height: 4),
                              const Text(
                                "Customize Items:",
                                style: TextStyle(
                                  fontSize: 10,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.blueGrey,
                                ),
                              ),
                              ...comboItems.map((ci) {
                                final int itemId = _toInt(ci["id"]);
                                Map<String, int> currentComboItems =
                                    Map<String, int>.from(
                                      selectedMeals[key]?["combo_items"] ?? {},
                                    );
                                final int itemQty =
                                    currentComboItems[itemId.toString()] ?? 0;

                                return Padding(
                                  padding: const EdgeInsets.symmetric(
                                    vertical: 4,
                                  ),
                                  child: Row(
                                    children: [
                                      Container(
                                        width: 7,
                                        height: 7,
                                        decoration: BoxDecoration(
                                          shape: BoxShape.circle,
                                          color:
                                              (ci["is_veg"] == true ||
                                                  ci["is_veg"] == 1)
                                              ? Colors.green
                                              : Colors.red,
                                        ),
                                      ),
                                      const SizedBox(width: 8),
                                      Expanded(
                                        child: Column(
                                          crossAxisAlignment:
                                              CrossAxisAlignment.start,
                                          children: [
                                            Text(
                                              ci["name"]?.toString() ?? "",
                                              style: const TextStyle(
                                                fontSize: 12,
                                              ),
                                            ),
                                            Text(
                                              "₹${ci["price"] ?? 0}",
                                              style: const TextStyle(
                                                fontSize: 10,
                                                color: Colors.grey,
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                      if (!isClosed)
                                        _buildCounter(
                                          itemQty,
                                          onAdd: () => setState(() {
                                            currentComboItems[itemId
                                                    .toString()] =
                                                itemQty + 1;
                                            
                                            final currentMeal = Map<String, dynamic>.from(selectedMeals[key]!);
                                            currentMeal["combo_items"] = currentComboItems;
                                            currentMeal["price_self"] = _calculateComboPrice(combo, currentComboItems);
                                            currentMeal["price_guest"] = _calculateComboPrice(combo, currentComboItems, isGuest: true);
                                            
                                            selectedMeals[key] = currentMeal;
                                          }),
                                          onRemove: () => setState(() {
                                            if (itemQty > 0) {
                                              if (itemQty == 1) {
                                                currentComboItems.remove(
                                                  itemId.toString(),
                                                );
                                              } else {
                                                currentComboItems[itemId
                                                        .toString()] =
                                                    itemQty - 1;
                                              }
                                              
                                              final currentMeal = Map<String, dynamic>.from(selectedMeals[key]!);
                                              currentMeal["combo_items"] = currentComboItems;
                                              currentMeal["price_self"] = _calculateComboPrice(combo, currentComboItems);
                                              currentMeal["price_guest"] = _calculateComboPrice(combo, currentComboItems, isGuest: true);
                                              
                                              selectedMeals[key] = currentMeal;
                                            }
                                          }),
                                        ),
                                    ],
                                  ),
                                );
                              }),
                            ],
                          ),
                        ),
                    ],
                  ),
                );
              }),

              if (items.isNotEmpty) ...[
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 8),
                  child: Text(
                    "ADDITIONAL ITEMS",
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                      color: Colors.blueGrey,
                      letterSpacing: 0.5,
                    ),
                  ),
                ),
                ...items.map((item) {
                  final itemId = _toInt(item["id"]);
                  final key = "${slotId}_$itemId";
                  final alreadyQty = alreadyBookedItems[key] ?? 0;
                  final isSelected = selectedItems.containsKey(key);

                  return Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: Row(
                      children: [
                        Container(
                          width: 8,
                          height: 8,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color:
                                (item["is_veg"] == true || item["is_veg"] == 1)
                                ? Colors.green
                                : Colors.red,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                item["name"]?.toString() ?? "Unnamed Item",
                                style: const TextStyle(fontSize: 13),
                              ),
                              Text(
                                "₹${getPriceForRole(item)}",
                                style: const TextStyle(
                                  fontSize: 11,
                                  color: Colors.grey,
                                ),
                              ),
                              if (isSelected)
                                Text(
                                  "Subtotal: ₹${((selectedItems[key]?["price_self"] ?? 0) * _toInt(selectedItems[key]?["quantity"]) + (selectedItems[key]?["price_guest"] ?? 0) * _toInt(selectedItems[key]?["guest_quantity"])).toStringAsFixed(1)}",
                                  style: const TextStyle(
                                    fontSize: 10,
                                    color: Color.fromARGB(255, 152, 29, 68),
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              if (alreadyQty > 0)
                                Text(
                                  "Booked: $alreadyQty",
                                  style: const TextStyle(
                                    fontSize: 10,
                                    color: Colors.green,
                                  ),
                                ),
                            ],
                          ),
                        ),
                        if (!isClosed)
                          _buildCounter(
                            isSelected
                                ? _toInt(selectedItems[key]?["quantity"])
                                : 0,
                            onAdd: () => setState(() {
                              if (!isSelected) {
                                selectedItems[key] = {
                                  "item_id": itemId,
                                  "meal_slot_id": slotId,
                                  "quantity": 1,
                                  "guest_quantity": 0,
                                  "price_self": getPriceForRole(item),
                                  "price_guest": getPriceForRole(
                                    item,
                                    isGuest: true,
                                  ),
                                };
                              } else {
                                final currentItem = Map<String, dynamic>.from(selectedItems[key]!);
                                currentItem["quantity"] = _toInt(currentItem["quantity"]) + 1;
                                selectedItems[key] = currentItem;
                              }
                            }),
                            onRemove: () => setState(() {
                              int q = _toInt(selectedItems[key]?["quantity"]);
                              if (q > 1) {
                                final currentItem = Map<String, dynamic>.from(selectedItems[key]!);
                                currentItem["quantity"] = q - 1;
                                selectedItems[key] = currentItem;
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

  Widget _buildCounter(
    int count, {
    required VoidCallback onAdd,
    required VoidCallback onRemove,
  }) {
    if (count == 0) {
      return ElevatedButton(
        onPressed: onAdd,
        style: ElevatedButton.styleFrom(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 0),
          minimumSize: const Size(60, 30),
          backgroundColor: const Color.fromARGB(255, 152, 29, 68),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        ),
        child: const Text(
          "Add",
          style: TextStyle(color: Colors.white, fontSize: 12),
        ),
      );
    }
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        IconButton(
          iconSize: 20,
          padding: EdgeInsets.zero,
          constraints: const BoxConstraints(),
          icon: const Icon(
            Icons.remove_circle_outline,
            color: Color.fromARGB(255, 152, 29, 68),
          ),
          onPressed: onRemove,
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8),
          child: Text(
            "$count",
            style: const TextStyle(fontWeight: FontWeight.bold),
          ),
        ),
        IconButton(
          iconSize: 20,
          padding: EdgeInsets.zero,
          constraints: const BoxConstraints(),
          icon: const Icon(
            Icons.add_circle_outline,
            color: Color.fromARGB(255, 152, 29, 68),
          ),
          onPressed: onAdd,
        ),
      ],
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
