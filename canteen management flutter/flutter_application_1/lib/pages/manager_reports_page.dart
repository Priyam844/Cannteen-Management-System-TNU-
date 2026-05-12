import 'dart:convert';
import 'package:flutter/material.dart';
import 'api_service.dart';

class ManagerReportsPage extends StatefulWidget {
  const ManagerReportsPage({super.key});

  @override
  State<ManagerReportsPage> createState() => _ManagerReportsPageState();
}

class _ManagerReportsPageState extends State<ManagerReportsPage> {
  bool isLoading = true;
  Map reportData = {};

  @override
  void initState() {
    super.initState();
    fetchReports();
  }

  Future<void> fetchReports() async {
    setState(() => isLoading = true);
    try {
      final res = await ApiService.get("/manager-reports/");
      if (res.statusCode == 200) {
        setState(() {
          reportData = jsonDecode(res.body);
          isLoading = false;
        });
      } else {
        setState(() => isLoading = false);
      }
    } catch (e) {
      setState(() => isLoading = false);
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Error: $e")));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Consumption Reports"),
        backgroundColor: const Color.fromARGB(255, 152, 29, 68),
        foregroundColor: Colors.white,
      ),
      body: isLoading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: fetchReports,
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      "Historical Data: ${reportData["period"]}",
                      style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 15),
                    
                    SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      child: DataTable(
                        columns: const [
                          DataColumn(label: Text("Date")),
                          DataColumn(label: Text("Total")),
                          DataColumn(label: Text("Consumed")),
                          DataColumn(label: Text("Veg")),
                          DataColumn(label: Text("Non-Veg")),
                        ],
                        rows: (reportData["report"] as List).map((day) {
                          return DataRow(cells: [
                            DataCell(Text(day["date"])),
                            DataCell(Text(day["total"].toString())),
                            DataCell(Text(day["consumed"].toString(), style: const TextStyle(color: Colors.green, fontWeight: FontWeight.bold))),
                            DataCell(Text(day["veg"].toString())),
                            DataCell(Text(day["non_veg"].toString())),
                          ]);
                        }).toList(),
                      ),
                    ),
                    
                    const SizedBox(height: 30),
                    const Text(
                      "Daily Consumption Trend",
                      style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 10),
                    ... (reportData["report"] as List).map((day) {
                      double percentage = day["total"] == 0 ? 0 : day["consumed"] / day["total"];
                      return Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text("${day["date"]}: ${day["consumed"]}/${day["total"]}"),
                          const SizedBox(height: 5),
                          LinearProgressIndicator(
                            value: percentage,
                            backgroundColor: Colors.grey[300],
                            color: percentage > 0.8 ? Colors.green : (percentage > 0.5 ? Colors.orange : Colors.red),
                            minHeight: 10,
                          ),
                          const SizedBox(height: 15),
                        ],
                      );
                    }).toList(),
                  ],
                ),
              ),
            ),
    );
  }
}
