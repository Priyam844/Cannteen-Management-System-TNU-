import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_application_1/services/api_service.dart';
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';

class ManagerNextDayBookingPage extends StatefulWidget {
  const ManagerNextDayBookingPage({super.key});

  @override
  State<ManagerNextDayBookingPage> createState() => _ManagerNextDayBookingPageState();
}

class _ManagerNextDayBookingPageState extends State<ManagerNextDayBookingPage> {
  bool isLoading = true;
  Map<String, dynamic>? data;
  int selectedDayOffset = 1; // 1 for tomorrow, 2 for day after
  final Color primaryMaroon = const Color.fromARGB(255, 152, 29, 68);
  
  String? userRole;
  List hostels = [];
  int? selectedHostelId; // null means 'All Hostels' for Admin

  @override
  void initState() {
    super.initState();
    _initUser();
  }

  Future<void> _initUser() async {
    final prefs = await SharedPreferences.getInstance();
    userRole = prefs.getString("role");
    
    if (userRole == 'admin') {
      await _fetchHostels();
    }
    await _fetchData();
  }

  Future<void> _fetchHostels() async {
    try {
      final res = await ApiService.get("/admin-management/");
      if (res.statusCode == 200) {
        final d = jsonDecode(res.body);
        setState(() {
          hostels = d["hostels"];
        });
      }
    } catch (e) {
      debugPrint("Error fetching hostels: $e");
    }
  }

  Future<void> _fetchData() async {
    setState(() => isLoading = true);
    try {
      final targetDate = DateTime.now().add(Duration(days: selectedDayOffset));
      final dateStr = DateFormat('yyyy-MM-dd').format(targetDate);
      
      String url = "/next-day-bookings/?date=$dateStr";
      if (userRole == 'admin' && selectedHostelId != null) {
        url += "&hostel_id=$selectedHostelId";
      }
      
      final res = await ApiService.get(url);
      if (!mounted) return;
      
      if (res.statusCode == 200) {
        setState(() {
          data = jsonDecode(res.body);
        });
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Error: ${res.body}"), behavior: SnackBarBehavior.floating),
        );
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Failed to load: $e"), behavior: SnackBarBehavior.floating),
      );
    } finally {
      setState(() => isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F7FA),
      appBar: AppBar(
        title: const Text("Meal Preparation", style: TextStyle(fontWeight: FontWeight.bold)),
        backgroundColor: primaryMaroon,
        foregroundColor: Colors.white,
        centerTitle: true,
        elevation: 0,
      ),
      body: Column(
        children: [
          _buildDateSelector(),
          if (userRole == 'admin') _buildHostelSelector(),
          Expanded(
            child: isLoading
                ? Center(child: CircularProgressIndicator(color: primaryMaroon))
                : RefreshIndicator(
                    onRefresh: _fetchData,
                    color: primaryMaroon,
                    child: ListView(
                      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
                      children: [
                        _buildHeader(),
                        const SizedBox(height: 24),
                        if (data?["stats"] == null || (data!["stats"] as List).isEmpty)
                          _buildEmptyState()
                        else
                          ... (data!["stats"] as List).map((slot) => _buildSlotCard(slot)),
                        const SizedBox(height: 30),
                      ],
                    ),
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildHostelSelector() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 16),
      color: primaryMaroon,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16),
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.15),
          borderRadius: BorderRadius.circular(12),
        ),
        child: DropdownButtonHideUnderline(
          child: DropdownButton<int?>(
            value: selectedHostelId,
            dropdownColor: primaryMaroon,
            icon: const Icon(Icons.keyboard_arrow_down_rounded, color: Colors.white),
            isExpanded: true,
            hint: const Text("Select Hostel", style: TextStyle(color: Colors.white)),
            items: [
              const DropdownMenuItem<int?>(
                value: null,
                child: Text("All Hostels Summary", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
              ),
              ...hostels.map((h) => DropdownMenuItem<int?>(
                value: h["id"],
                child: Text(h["name"], style: const TextStyle(color: Colors.white)),
              )),
            ],
            onChanged: (v) {
              setState(() => selectedHostelId = v);
              _fetchData();
            },
          ),
        ),
      ),
    );
  }

  Widget _buildDateSelector() {
    return Container(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 8),
      color: primaryMaroon,
      child: Row(
        children: [
          _dateTab("Tomorrow", 1),
          const SizedBox(width: 12),
          _dateTab("Day After", 2),
        ],
      ),
    );
  }

  Widget _dateTab(String label, int offset) {
    bool isSelected = selectedDayOffset == offset;
    return Expanded(
      child: GestureDetector(
        onTap: () {
          if (!isSelected) {
            setState(() => selectedDayOffset = offset);
            _fetchData();
          }
        },
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 12),
          decoration: BoxDecoration(
            color: isSelected ? Colors.white : Colors.white.withOpacity(0.15),
            borderRadius: BorderRadius.circular(16),
          ),
          alignment: Alignment.center,
          child: Text(
            label,
            style: TextStyle(
              color: isSelected ? primaryMaroon : Colors.white,
              fontWeight: FontWeight.bold,
              fontSize: 14,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.only(top: 60),
        child: Column(
          children: [
            Icon(Icons.event_busy_rounded, size: 64, color: Colors.grey.shade300),
            const SizedBox(height: 16),
            Text(
              "No bookings for this date yet.",
              style: TextStyle(color: Colors.grey.shade500, fontWeight: FontWeight.w500),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader() {
    bool isPast = data?["is_past_cutoff"] ?? false;
    String dateStr = data?["date"] ?? "";
    DateTime? dt = DateTime.tryParse(dateStr);
    String formattedDate = dt != null ? DateFormat('EEEE, d MMM').format(dt) : dateStr;

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.03), blurRadius: 10, offset: const Offset(0, 4))],
      ),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text("Target Date", style: TextStyle(color: Colors.grey, fontSize: 13, fontWeight: FontWeight.w500)),
              Text(formattedDate, style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 17, color: Color(0xFF2D3142))),
            ],
          ),
          const Padding(padding: EdgeInsets.symmetric(vertical: 4), child: Divider()),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text("Hostel", style: TextStyle(color: Colors.grey, fontSize: 13, fontWeight: FontWeight.w500)),
              Text(data?["hostel"] ?? "N/A", style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: Color(0xFF2D3142))),
            ],
          ),
          const Padding(padding: EdgeInsets.symmetric(vertical: 8), child: Divider()),
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: (isPast ? Colors.green : Colors.orange).withOpacity(0.1),
                  shape: BoxShape.circle,
                ),
                child: Icon(isPast ? Icons.lock_rounded : Icons.lock_open_rounded, color: isPast ? Colors.green : Colors.orange, size: 18),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      isPast ? "Booking Finalized" : "Booking Still Open",
                      style: TextStyle(color: isPast ? Colors.green.shade700 : Colors.orange.shade700, fontWeight: FontWeight.bold, fontSize: 14),
                    ),
                    Text(
                      isPast ? "Cutoff time (${data?["cutoff_time"]}) passed" : "Final counts at ${data?["cutoff_time"]}",
                      style: TextStyle(color: Colors.grey.shade500, fontSize: 11),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildSlotCard(dynamic slot) {
    return Container(
      margin: const EdgeInsets.only(bottom: 20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 20, offset: const Offset(0, 10))],
      ),
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
            decoration: BoxDecoration(
              color: primaryMaroon.withOpacity(0.05),
              borderRadius: const BorderRadius.only(topLeft: Radius.circular(24), topRight: Radius.circular(24)),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    Icon(_getIcon(slot["slot"]), color: primaryMaroon, size: 20),
                    const SizedBox(width: 12),
                    Text(
                      slot["slot"].toString().toUpperCase(), 
                      style: TextStyle(color: primaryMaroon, fontWeight: FontWeight.w900, fontSize: 16, letterSpacing: 0.5)
                    ),
                  ],
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                  decoration: BoxDecoration(color: primaryMaroon, borderRadius: BorderRadius.circular(12)),
                  child: Text(
                    "TOTAL: ${slot["total"]}", 
                    style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13)
                  ),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildSubSectionHeader("Combo Distribution", Icons.pie_chart_outline_rounded),
                const SizedBox(height: 12),
                ... (slot["combos"] as Map<String, dynamic>).entries.map((entry) => _buildListRow(entry.key, entry.value.toString(), false)),
                const SizedBox(height: 24),
                _buildSubSectionHeader("Item Preparation List", Icons.inventory_2_outlined),
                const SizedBox(height: 12),
                ... (slot["items"] as Map<String, dynamic>).entries.map((entry) => _buildListRow(entry.key, "x ${entry.value}", true)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSubSectionHeader(String title, IconData icon) {
    return Row(
      children: [
        Icon(icon, size: 14, color: Colors.grey.shade400),
        const SizedBox(width: 8),
        Text(
          title, 
          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: Colors.grey.shade500, letterSpacing: 0.5)
        ),
      ],
    );
  }

  Widget _buildListRow(String label, String value, bool isHighlighted) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: isHighlighted ? primaryMaroon.withOpacity(0.03) : Colors.grey.shade50,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: isHighlighted ? primaryMaroon.withOpacity(0.1) : Colors.grey.shade100),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Expanded(child: Text(label, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: Color(0xFF2D3142)))),
          Text(
            value, 
            style: TextStyle(
              fontWeight: FontWeight.w900, 
              fontSize: 16, 
              color: isHighlighted ? primaryMaroon : const Color(0xFF2D3142)
            )
          ),
        ],
      ),
    );
  }

  IconData _getIcon(String slot) {
    switch (slot.toLowerCase()) {
      case "breakfast": return Icons.wb_sunny_rounded;
      case "lunch": return Icons.lunch_dining_rounded;
      case "snacks": return Icons.coffee_rounded;
      case "dinner": return Icons.nights_stay_rounded;
      default: return Icons.restaurant;
    }
  }
}


