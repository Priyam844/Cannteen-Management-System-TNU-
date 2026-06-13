import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_application_1/services/api_service.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';

class AdminReportsPage extends StatefulWidget {
  const AdminReportsPage({super.key});

  @override
  State<AdminReportsPage> createState() => _AdminReportsPageState();
}

class _AdminReportsPageState extends State<AdminReportsPage> {
  bool isLoading = true;
  Map reportData = {};
  Map analyticsData = {};
  List feedbacks = [];
  String selectedPeriod = "weekly";
  final Color primaryMaroon = const Color.fromARGB(255, 152, 29, 68);

  DateTime? customStartDate;
  DateTime? customEndDate;

  @override
  void initState() {
    super.initState();
    _fetchData();
  }

  Future<void> _fetchData() async {
    setState(() => isLoading = true);
    try {
      String params = "period=$selectedPeriod";
      if (selectedPeriod == "custom" && customStartDate != null && customEndDate != null) {
        params += "&start_date=${DateFormat('yyyy-MM-dd').format(customStartDate!)}";
        params += "&end_date=${DateFormat('yyyy-MM-dd').format(customEndDate!)}";
      }

      final resReport = await ApiService.get("/admin-reports/?$params");
      final resAnal = await ApiService.get("/analytics/?$params");
      final resFeedback = await ApiService.get("/feedback-list/?$params");
      
      if (mounted) {
        setState(() {
          if (resReport.statusCode == 200) reportData = jsonDecode(resReport.body);
          if (resAnal.statusCode == 200) analyticsData = jsonDecode(resAnal.body);
          if (resFeedback.statusCode == 200) feedbacks = jsonDecode(resFeedback.body);
          isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Error: $e"), behavior: SnackBarBehavior.floating),
        );
        setState(() => isLoading = false);
      }
    }
  }

  Future<void> _selectCustomDate() async {
    final DateTimeRange? picked = await showDateRangePicker(
      context: context,
      firstDate: DateTime(2023),
      lastDate: DateTime.now(),
      initialDateRange: customStartDate != null && customEndDate != null
          ? DateTimeRange(start: customStartDate!, end: customEndDate!)
          : null,
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: ColorScheme.light(
              primary: primaryMaroon,
              onPrimary: Colors.white,
              onSurface: const Color(0xFF2D3142),
            ),
          ),
          child: child!,
        );
      },
    );

    if (picked != null) {
      setState(() {
        customStartDate = picked.start;
        customEndDate = picked.end;
        selectedPeriod = "custom";
      });
      _fetchData();
    }
  }

  Future<void> _downloadReport() async {
    try {
      String params = "period=$selectedPeriod";
      if (selectedPeriod == "custom" && customStartDate != null && customEndDate != null) {
        params += "&start_date=${DateFormat('yyyy-MM-dd').format(customStartDate!)}";
        params += "&end_date=${DateFormat('yyyy-MM-dd').format(customEndDate!)}";
      }

      final url = Uri.parse("${ApiService.baseUrl}/admin-download-report/?$params");
      
      if (!await launchUrl(url, mode: LaunchMode.externalApplication)) {
        throw Exception('Could not launch $url');
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Download failed: $e")),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    if (isLoading) {
      return Center(child: CircularProgressIndicator(color: primaryMaroon));
    }

    return RefreshIndicator(
      onRefresh: _fetchData,
      color: primaryMaroon,
      child: ListView(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
        children: [
          _buildPeriodSelector(),
          if (selectedPeriod == "custom" && customStartDate != null)
            Padding(
              padding: const EdgeInsets.only(top: 8, left: 4),
              child: Text(
                "Range: ${DateFormat('d MMM').format(customStartDate!)} - ${DateFormat('d MMM').format(customEndDate!)}",
                style: TextStyle(color: primaryMaroon, fontWeight: FontWeight.bold, fontSize: 12),
              ),
            ),
          const SizedBox(height: 16),
          _buildDownloadButton(),
          const SizedBox(height: 24),
          _buildOrderedDeliveredCard(),
          const SizedBox(height: 24),
          _buildSummaryCard(),
          const SizedBox(height: 32),
          _buildSectionHeader("Item-wise Demand Analysis"),
          const SizedBox(height: 16),
          _buildDemandChart(),
          const SizedBox(height: 32),
          _buildSectionHeader("Feedback Report"),
          const SizedBox(height: 16),
          _buildFeedbackReportList(),
          const SizedBox(height: 32),
          _buildSectionHeader("Hostel-wise Consumption"),
          const SizedBox(height: 16),
          ...((reportData["hostel_breakdown"] as List? ?? []).map((h) => _buildHostelReportTile(h))),
          const SizedBox(height: 24),
        ],
      ),
    );
  }

  Widget _buildFeedbackReportList() {
    if (feedbacks.isEmpty) {
      return Container(
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(20)),
        child: const Center(child: Text("No feedback found for this period.", style: TextStyle(color: Colors.grey))),
      );
    }

    return Column(
      children: feedbacks.map((fb) {
        int r = fb["rating"];
        return Card(
          margin: const EdgeInsets.only(bottom: 12),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          child: ListTile(
            leading: CircleAvatar(
              backgroundColor: _getRatingColor(r).withOpacity(0.1),
              child: Text(r.toString(), style: TextStyle(color: _getRatingColor(r), fontWeight: FontWeight.bold)),
            ),
            title: Text("${fb["hostel_name"]} • ${fb["meal_slot"]?.toString().toUpperCase()}", style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
            subtitle: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(fb["combo_name"] ?? "Standard Meal", style: const TextStyle(fontSize: 12, color: Colors.blueGrey)),
                const SizedBox(height: 4),
                Text(fb["comment"]?.isEmpty == true ? "No comment provided" : fb["comment"], style: TextStyle(fontSize: 12, color: Colors.black87, fontStyle: fb["comment"]?.isEmpty == true ? FontStyle.italic : FontStyle.normal)),
              ],
            ),
            trailing: Text(fb["created_at"].toString().substring(0, 10), style: const TextStyle(fontSize: 10, color: Colors.grey)),
          ),
        );
      }).toList(),
    );
  }

  Color _getRatingColor(int score) {
    if (score <= 2) return Colors.red;
    if (score == 3) return Colors.orange;
    return Colors.green;
  }

  Widget _buildDownloadButton() {
    return ElevatedButton.icon(
      onPressed: _downloadReport,
      icon: const Icon(Icons.download_rounded, color: Colors.white),
      label: const Text("Download Detailed CSV Report", style: TextStyle(fontWeight: FontWeight.bold)),
      style: ElevatedButton.styleFrom(
        backgroundColor: primaryMaroon,
        foregroundColor: Colors.white,
        padding: const EdgeInsets.symmetric(vertical: 16),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        elevation: 2,
      ),
    );
  }

  Widget _buildSectionHeader(String title) {
    return Row(
      children: [
        Container(width: 4, height: 24, decoration: BoxDecoration(color: primaryMaroon, borderRadius: BorderRadius.circular(2))),
        const SizedBox(width: 12),
        Text(title, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Color(0xFF2D3142))),
      ],
    );
  }

  Widget _buildPeriodSelector() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.03), blurRadius: 10, offset: const Offset(0, 4))],
      ),
      child: Row(
        children: [
          Icon(Icons.calendar_today_rounded, size: 18, color: primaryMaroon),
          const SizedBox(width: 12),
          const Text("Period:", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Color(0xFF2D3142))),
          const Spacer(),
          DropdownButton<String>(
            value: selectedPeriod,
            underline: const SizedBox(),
            icon: const Icon(Icons.keyboard_arrow_down_rounded),
            items: const [
              DropdownMenuItem(value: "today", child: Text("Today")),
              DropdownMenuItem(value: "weekly", child: Text("7 Days")),
              DropdownMenuItem(value: "15days", child: Text("15 Days")),
              DropdownMenuItem(value: "monthly", child: Text("30 Days")),
              DropdownMenuItem(value: "6months", child: Text("6 Months")),
              DropdownMenuItem(value: "custom", child: Text("Custom Range")),
            ],
            onChanged: (v) {
              if (v == "custom") {
                _selectCustomDate();
              } else if (v != null) {
                setState(() => selectedPeriod = v);
                _fetchData();
              }
            },
          ),
        ],
      ),
    );
  }

  Widget _buildOrderedDeliveredCard() {
    final overview = analyticsData["overview"] ?? {};
    final int ordered = overview["total_ordered"] ?? 0;
    final int delivered = overview["total_delivered"] ?? 0;
    final double deliveryRate = ordered > 0 ? (delivered / ordered) * 100 : 0;

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 10, offset: const Offset(0, 4))],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text("Operations Monitoring", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: Color(0xFF2D3142))),
          const SizedBox(height: 20),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _simpleStat("Plates Ordered", ordered.toString(), Colors.blue),
              Container(width: 1, height: 40, color: Colors.grey.shade200),
              _simpleStat("Plates Delivered", delivered.toString(), Colors.green),
            ],
          ),
          const SizedBox(height: 20),
          ClipRRect(
            borderRadius: BorderRadius.circular(10),
            child: LinearProgressIndicator(
              value: ordered > 0 ? (delivered / ordered) : 0,
              backgroundColor: Colors.grey.shade100,
              color: Colors.green,
              minHeight: 12,
            ),
          ),
          const SizedBox(height: 8),
          Center(
            child: Text(
              "Delivery Rate: ${deliveryRate.toStringAsFixed(1)}%",
              style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.grey.shade600),
            ),
          ),
        ],
      ),
    );
  }

  Widget _simpleStat(String label, String val, Color color) {
    return Column(
      children: [
        Text(val, style: TextStyle(fontSize: 24, fontWeight: FontWeight.w900, color: color)),
        Text(label, style: TextStyle(fontSize: 12, color: Colors.grey.shade600, fontWeight: FontWeight.w500)),
      ],
    );
  }

  Widget _buildSummaryCard() {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [primaryMaroon, primaryMaroon.withOpacity(0.8)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(24),
        boxShadow: [BoxShadow(color: primaryMaroon.withOpacity(0.3), blurRadius: 15, offset: const Offset(0, 8))],
      ),
      child: Column(
        children: [
          const Icon(Icons.restaurant_menu_rounded, color: Colors.white, size: 32),
          const SizedBox(height: 12),
          const Text(
            "Consumption Breakdown",
            style: TextStyle(color: Colors.white70, fontSize: 14, fontWeight: FontWeight.w500),
          ),
          const SizedBox(height: 4),
          Text(
            reportData["total_consumed"]?.toString() ?? "0",
            style: const TextStyle(color: Colors.white, fontSize: 40, fontWeight: FontWeight.w900, letterSpacing: -1),
          ),
          const Text("Total Meals", style: TextStyle(color: Colors.white54, fontSize: 12)),
          const SizedBox(height: 24),
          Container(
            padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 8),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.15),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                _summaryStat("Veg Items", reportData["veg_consumed"]?.toString() ?? "0", Icons.circle, Colors.greenAccent),
                Container(width: 1, height: 30, color: Colors.white24),
                _summaryStat("Non-Veg", reportData["nonveg_consumed"]?.toString() ?? "0", Icons.circle, Colors.redAccent),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _summaryStat(String label, String val, IconData icon, Color color) {
    return Column(
      children: [
        Row(
          children: [
            Icon(icon, size: 8, color: color),
            const SizedBox(width: 6),
            Text(val, style: const TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold)),
          ],
        ),
        Text(label, style: const TextStyle(color: Colors.white60, fontSize: 11)),
      ],
    );
  }

  Widget _buildDemandChart() {
    final List topItems = analyticsData["top_items_in_combos"] ?? [];
    if (topItems.isEmpty) {
      return const Center(child: Text("No item demand data available for this period."));
    }

    return Container(
      height: 300,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.02), blurRadius: 10, offset: const Offset(0, 4))],
      ),
      child: BarChart(
        BarChartData(
          alignment: BarChartAlignment.spaceAround,
          maxY: (topItems.first["count"] as num).toDouble() * 1.2,
          barTouchData: BarTouchData(
            enabled: true,
            touchTooltipData: BarTouchTooltipData(
              getTooltipColor: (group) => Colors.blueGrey,
              getTooltipItem: (group, groupIndex, rod, rodIndex) {
                return BarTooltipItem(
                  "${topItems[groupIndex]["item__name"]}\n",
                  const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                  children: [
                    TextSpan(
                      text: rod.toY.toInt().toString(),
                      style: const TextStyle(color: Colors.yellow, fontSize: 16, fontWeight: FontWeight.w500),
                    ),
                  ],
                );
              },
            ),
          ),
          titlesData: FlTitlesData(
            show: true,
            bottomTitles: AxisTitles(
              sideTitles: SideTitles(
                showTitles: true,
                reservedSize: 30,
                getTitlesWidget: (value, meta) {
                  if (value.toInt() >= topItems.length) return const SizedBox();
                  return Padding(
                    padding: const EdgeInsets.only(top: 8.0),
                    child: Text(
                      topItems[value.toInt()]["item__name"].toString().substring(0, 3),
                      style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Colors.grey),
                    ),
                  );
                },
              ),
            ),
            leftTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
            topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
            rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          ),
          gridData: const FlGridData(show: false),
          borderData: FlBorderData(show: false),
          barGroups: List.generate(topItems.length, (i) {
            return BarChartGroupData(
              x: i,
              barRods: [
                BarChartRodData(
                  toY: (topItems[i]["count"] as num).toDouble(),
                  color: primaryMaroon,
                  width: 16,
                  borderRadius: const BorderRadius.only(topLeft: Radius.circular(6), topRight: Radius.circular(6)),
                ),
              ],
            );
          }),
        ),
      ),
    );
  }

  Widget _buildHostelReportTile(Map h) {
    final int total = int.tryParse(reportData["total_consumed"].toString()) ?? 1;
    final int current = int.tryParse(h["total_consumed"].toString()) ?? 0;
    final double percentage = total > 0 ? (current / total) : 0;

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.grey.shade100),
      ),
      child: Column(
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(color: primaryMaroon.withOpacity(0.05), shape: BoxShape.circle),
                child: Icon(Icons.apartment_rounded, size: 18, color: primaryMaroon),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Text(
                  h["hostel"],
                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: Color(0xFF2D3142)),
                ),
              ),
              Text(
                current.toString(),
                style: TextStyle(fontWeight: FontWeight.w900, fontSize: 18, color: primaryMaroon),
              ),
              const SizedBox(width: 4),
              const Text("Meals", style: TextStyle(fontSize: 10, color: Colors.grey, fontWeight: FontWeight.bold)),
            ],
          ),
          const SizedBox(height: 12),
          ClipRRect(
            borderRadius: BorderRadius.circular(10),
            child: LinearProgressIndicator(
              value: percentage,
              backgroundColor: Colors.grey.shade100,
              color: primaryMaroon.withOpacity(0.6),
              minHeight: 6,
            ),
          ),
        ],
      ),
    );
  }
}
