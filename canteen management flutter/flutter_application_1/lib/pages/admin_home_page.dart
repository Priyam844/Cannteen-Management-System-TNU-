import 'dart:convert';
import 'package:flutter/material.dart';
import 'api_service.dart';
import 'login_page.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:file_picker/file_picker.dart';

class AdminHomePage extends StatefulWidget {
  const AdminHomePage({super.key});

  @override
  State<AdminHomePage> createState() => _AdminHomePageState();
}

class _AdminHomePageState extends State<AdminHomePage> {
  int _currentIndex = 0;
  bool isLoading = true;

  Map dashboardData = {};
  List managers = [];
  List hostels = [];
  Map reportData = {};
  String selectedPeriod = "weekly";

  @override
  void initState() {
    super.initState();
    _fetchData();
  }

  Future<void> _fetchData() async {
    setState(() => isLoading = true);
    try {
      if (_currentIndex == 0) {
        final res = await ApiService.get("/admin-dashboard/");
        if (res.statusCode == 200) dashboardData = jsonDecode(res.body);
      } else if (_currentIndex == 1) {
        final res = await ApiService.get("/admin-management/");
        if (res.statusCode == 200) {
          final data = jsonDecode(res.body);
          managers = data["managers"];
          hostels = data["hostels"];
        }
      } else if (_currentIndex == 2) {
        final res = await ApiService.get("/admin-reports/?period=$selectedPeriod");
        if (res.statusCode == 200) reportData = jsonDecode(res.body);
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Error: $e")));
    } finally {
      setState(() => isLoading = false);
    }
  }

  void _addManager() {
    final emailCtrl = TextEditingController();
    final passCtrl = TextEditingController();
    final firstCtrl = TextEditingController();
    final lastCtrl = TextEditingController();
    int? selectedHostel;

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: const Text("Add Manager"),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(controller: firstCtrl, decoration: const InputDecoration(labelText: "First Name")),
                TextField(controller: lastCtrl, decoration: const InputDecoration(labelText: "Last Name")),
                TextField(controller: emailCtrl, decoration: const InputDecoration(labelText: "Email")),
                TextField(controller: passCtrl, decoration: const InputDecoration(labelText: "Password"), obscureText: true),
                const SizedBox(height: 10),
                DropdownButtonFormField<int>(
                  decoration: const InputDecoration(labelText: "Assign Hostel"),
                  items: hostels.map<DropdownMenuItem<int>>((h) => DropdownMenuItem(value: h["id"], child: Text(h["name"]))).toList(),
                  onChanged: (v) => setDialogState(() => selectedHostel = v),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(context), child: const Text("Cancel")),
            ElevatedButton(
              onPressed: () async {
                final res = await ApiService.post("/admin-management/", {
                  "email": emailCtrl.text,
                  "password": passCtrl.text,
                  "first_name": firstCtrl.text,
                  "last_name": lastCtrl.text,
                  "hostel_id": selectedHostel
                });
                if (res.statusCode == 201) {
                  Navigator.pop(context);
                  _fetchData();
                } else {
                  ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(res.body)));
                }
              },
              child: const Text("Create"),
            )
          ],
        ),
      ),
    );
  }

  void _deleteManager(int id) async {
    final res = await ApiService.delete("/admin-management/?id=$id");
    if (res.statusCode == 200) _fetchData();
  }

  void _editCutoffTime(Map hostel) async {
    final timeStr = hostel["cutoff_time"] ?? "17:00";
    final parts = timeStr.split(":");
    final initialTime = TimeOfDay(hour: int.parse(parts[0]), minute: int.parse(parts[1]));

    final pickedTime = await showTimePicker(
      context: context,
      initialTime: initialTime,
    );

    if (pickedTime != null) {
      final formattedTime = "${pickedTime.hour.toString().padLeft(2, '0')}:${pickedTime.minute.toString().padLeft(2, '0')}";
      final res = await ApiService.put("/admin-management/", {
        "hostel_id": hostel["id"],
        "cutoff_time": formattedTime
      });

      if (res.statusCode == 200) {
        _fetchData();
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Cutoff time updated")));
      } else {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Error: ${res.body}")));
      }
    }
  }

  void _editMealTimes(Map hostel) {
    Map<String, dynamic> timings = Map<String, dynamic>.from(hostel["slot_timings"] ?? {});
    final slots = ["breakfast", "lunch", "snacks", "dinner"];

    for (var slot in slots) {
      if (!timings.containsKey(slot) || timings[slot] == null || (timings[slot] as List).length != 2) {
        if (slot == "breakfast") timings[slot] = ["08:00", "10:00"];
        else if (slot == "lunch") timings[slot] = ["12:00", "14:00"];
        else if (slot == "snacks") timings[slot] = ["16:00", "17:00"];
        else if (slot == "dinner") timings[slot] = ["19:00", "21:00"];
      }
    }

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: Text("Meal Times: ${hostel["name"]}"),
          content: SizedBox(
            width: double.maxFinite,
            child: ListView(
              shrinkWrap: true,
              children: slots.map((slot) {
                final range = timings[slot] as List;
                return Padding(
                  padding: const EdgeInsets.symmetric(vertical: 8.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(slot.toUpperCase(), style: const TextStyle(fontWeight: FontWeight.bold, color: Color.fromARGB(255, 152, 29, 68))),
                      const SizedBox(height: 5),
                      Row(
                        children: [
                          Expanded(
                            child: OutlinedButton(
                              onPressed: () async {
                                final parts = range[0].split(":");
                                final time = await showTimePicker(
                                  context: context,
                                  initialTime: TimeOfDay(hour: int.parse(parts[0]), minute: int.parse(parts[1])),
                                );
                                if (time != null) {
                                  setDialogState(() {
                                    timings[slot][0] = "${time.hour.toString().padLeft(2, '0')}:${time.minute.toString().padLeft(2, '0')}";
                                  });
                                }
                              },
                              child: Text("Start: ${range[0]}"),
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: OutlinedButton(
                              onPressed: () async {
                                final parts = range[1].split(":");
                                final time = await showTimePicker(
                                  context: context,
                                  initialTime: TimeOfDay(hour: int.parse(parts[0]), minute: int.parse(parts[1])),
                                );
                                if (time != null) {
                                  setDialogState(() {
                                    timings[slot][1] = "${time.hour.toString().padLeft(2, '0')}:${time.minute.toString().padLeft(2, '0')}";
                                  });
                                }
                              },
                              child: Text("End: ${range[1]}"),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                );
              }).toList(),
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(context), child: const Text("Cancel")),
            ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: const Color.fromARGB(255, 152, 29, 68), foregroundColor: Colors.white),
              onPressed: () async {
                final res = await ApiService.put("/admin-management/", {
                  "hostel_id": hostel["id"],
                  "slot_timings": timings
                });
                if (res.statusCode == 200) {
                  Navigator.pop(context);
                  _fetchData();
                  ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Meal times updated")));
                } else {
                  ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(res.body)));
                }
              },
              child: const Text("Save Changes"),
            )
          ],
        ),
      ),
    );
  }

  void _bulkUploadStudents() async {
    try {
      FilePickerResult? result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['csv', 'xlsx'],
      );

      if (result != null) {
        String? filePath = result.files.single.path;
        if (filePath == null) {
          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Could not retrieve file path")));
          return;
        }

        int? selectedHostel;

        showDialog(
          context: context,
          builder: (context) => StatefulBuilder(
            builder: (context, setDialogState) => AlertDialog(
              title: const Text("Select Hostel for Students"),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text("Select which hostel these students belong to."),
                  const SizedBox(height: 15),
                  DropdownButtonFormField<int>(
                    isExpanded: true,
                    decoration: const InputDecoration(labelText: "Hostel"),
                    items: hostels.map<DropdownMenuItem<int>>((h) => DropdownMenuItem(value: h["id"], child: Text(h["name"]))).toList(),
                    onChanged: (v) => setDialogState(() => selectedHostel = v),
                  ),
                  const SizedBox(height: 15),
                  const Text("File requirements:", style: TextStyle(fontWeight: FontWeight.bold)),
                  const Text("• CSV or Excel (.xlsx)"),
                  const Text("• Column 1: email"),
                  const Text("• Column 2: phone"),
                ],
              ),
              actions: [
                TextButton(onPressed: () => Navigator.pop(context), child: const Text("Cancel")),
                ElevatedButton(
                  onPressed: () async {
                    if (selectedHostel == null) {
                      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Please select a hostel")));
                      return;
                    }

                    Navigator.pop(context);
                    setState(() => isLoading = true);

                    try {
                      final responseStream = await ApiService.putMultipart(
                        "/bulk-authorize/",
                        {"hostel_id": selectedHostel.toString()},
                        "file",
                        filePath,
                      );

                      final responseBody = await responseStream.stream.bytesToString();
                      final data = jsonDecode(responseBody);

                      if (responseStream.statusCode == 200) {
                        showDialog(
                          context: context,
                          builder: (_) => AlertDialog(
                            title: const Text("Upload Complete"),
                            content: Text(data["message"] ?? "Operation successful"),
                            actions: [TextButton(onPressed: () => Navigator.pop(context), child: const Text("OK"))],
                          ),
                        );
                      } else {
                        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Error: $responseBody")));
                      }
                    } catch (e) {
                      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Upload failed: $e")));
                    } finally {
                      setState(() => isLoading = false);
                      _fetchData();
                    }
                  },
                  child: const Text("Upload Now"),
                )
              ],
            ),
          ),
        );
      }
    } catch (e) {
      debugPrint("File picker error: $e");
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Error opening file picker: $e")));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Admin Panel"),
        backgroundColor: const Color.fromARGB(255, 152, 29, 68),
        foregroundColor: Colors.white,
        actions: [
          IconButton(icon: const Icon(Icons.logout), onPressed: () async {
            final prefs = await SharedPreferences.getInstance();
            await prefs.clear();
            Navigator.pushAndRemoveUntil(context, MaterialPageRoute(builder: (_) => const LoginPage()), (r) => false);
          }),
        ],
      ),
      body: isLoading
          ? const Center(child: CircularProgressIndicator())
          : _buildBody(),
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _currentIndex,
        selectedItemColor: const Color.fromARGB(255, 152, 29, 68),
        onTap: (idx) {
          setState(() => _currentIndex = idx);
          _fetchData();
        },
        items: const [
          BottomNavigationBarItem(icon: Icon(Icons.dashboard), label: "Dashboard"),
          BottomNavigationBarItem(icon: Icon(Icons.people), label: "Managers"),
          BottomNavigationBarItem(icon: Icon(Icons.bar_chart), label: "Reports"),
        ],
      ),
      floatingActionButton: _currentIndex == 1
          ? FloatingActionButton(
              onPressed: _addManager,
              backgroundColor: const Color.fromARGB(255, 152, 29, 68),
              child: const Icon(Icons.add, color: Colors.white),
            )
          : null,
    );
  }

  Widget _buildBody() {
    if (_currentIndex == 0) return _buildDashboard();
    if (_currentIndex == 1) return _buildManagers();
    return _buildReports();
  }

  Widget _buildDashboard() {
    return RefreshIndicator(
      onRefresh: _fetchData,
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          GridView.count(
            crossAxisCount: 2,
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            mainAxisSpacing: 10,
            crossAxisSpacing: 10,
            childAspectRatio: 1.5,
            children: [
              _statCard("Students", dashboardData["total_students"]?.toString() ?? "0", Icons.school, Colors.blue),
              _statCard("Overall Rating", "${dashboardData["overall_rating"] ?? 0} / 5", Icons.star, Colors.purple),
              _statCard("Today's Bookings", dashboardData["today_bookings"]?.toString() ?? "0", Icons.book, Colors.green),
              _statCard("Total Feedback", dashboardData["total_feedback"]?.toString() ?? "0", Icons.feedback, Colors.orange),
            ],
          ),
          const SizedBox(height: 20),
          const Text("Hostel Breakdown (Today)", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
          const SizedBox(height: 10),
          ...(dashboardData["hostels"] as List? ?? []).map((h) => Card(
            child: ListTile(
              title: Text(h["name"], style: const TextStyle(fontWeight: FontWeight.bold)),
              subtitle: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text("${h["students"]} Students | Rating: ${h["avg_rating"]}/5"),
                  Text("Booked: ${h["bookings_today"]} | Consumed: ${h["consumed_today"]}"),
                ],
              ),
              trailing: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Text("Surplus", style: TextStyle(fontSize: 10, color: Colors.grey)),
                  Text(h["surplus_today"].toString(), style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18, color: Colors.red)),
                ],
              ),
              isThreeLine: true,
            ),
          )),
          const SizedBox(height: 20),
          const Text("Recent Feedback", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
          ...(dashboardData["recent_feedback"] as List? ?? []).map((fb) => ListTile(
            leading: CircleAvatar(child: Text(fb["rating"].toString())),
            title: Text(fb["user"]),
            subtitle: Text("${fb["comment"]}\n(${fb["hostel"]})"),
          )),
        ],
      ),
    );
  }

  Widget _statCard(String title, String val, IconData icon, Color color) {
    return Card(
      color: color.withOpacity(0.1),
      elevation: 0,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12), side: BorderSide(color: color)),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, color: color),
            const SizedBox(height: 5),
            Text(val, style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: color)),
            Text(title, style: TextStyle(fontSize: 12, color: color.withOpacity(0.8))),
          ],
        ),
      ),
    );
  }

  Widget _buildManagers() {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        const Text("Hostels & Cutoff Times", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
        const SizedBox(height: 10),
        ...hostels.map((h) => Card(
          child: ListTile(
            leading: const Icon(Icons.business, color: Color.fromARGB(255, 152, 29, 68)),
            title: Text(h["name"], style: const TextStyle(fontWeight: FontWeight.bold)),
            subtitle: Text("Cutoff Time: ${h["cutoff_time"]}"),
            trailing: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                IconButton(
                  tooltip: "Edit Cutoff",
                  icon: const Icon(Icons.edit_calendar, color: Colors.blue),
                  onPressed: () => _editCutoffTime(h),
                ),
                IconButton(
                  tooltip: "Edit Meal Times",
                  icon: const Icon(Icons.access_time, color: Colors.green),
                  onPressed: () => _editMealTimes(h),
                ),
              ],
            ),
          ),
        )),
        const SizedBox(height: 25),
        const Text("Bulk Student Authorization", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
        const SizedBox(height: 10),
        Card(
          elevation: 0,
          color: const Color.fromARGB(255, 152, 29, 68).withOpacity(0.05),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12), side: const BorderSide(color: Color.fromARGB(255, 152, 29, 68))),
          child: ListTile(
            leading: const Icon(Icons.upload_file, color: Color.fromARGB(255, 152, 29, 68)),
            title: const Text("Upload CSV/Excel", style: TextStyle(fontWeight: FontWeight.bold)),
            subtitle: const Text("Bulk authorize students for registration"),
            onTap: _bulkUploadStudents,
          ),
        ),
        const SizedBox(height: 25),
        const Text("Management Users", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
        const SizedBox(height: 10),
        ...managers.map((m) => Card(
          child: ListTile(
            leading: const CircleAvatar(child: Icon(Icons.person)),
            title: Text("${m["first_name"]} ${m["last_name"]}"),
            subtitle: Text("${m["email"]}\nHostel: ${m["hostel"]}"),
            trailing: IconButton(
              icon: const Icon(Icons.delete, color: Colors.red),
              onPressed: () => _deleteManager(m["id"]),
            ),
          ),
        )),
      ],
    );
  }

  Widget _buildReports() {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Row(
          children: [
            const Text("Period: ", style: TextStyle(fontWeight: FontWeight.bold)),
            const SizedBox(width: 10),
            Expanded(
              child: DropdownButton<String>(
                value: selectedPeriod,
                isExpanded: true,
                items: const [
                  DropdownMenuItem(value: "weekly", child: Text("Weekly")),
                  DropdownMenuItem(value: "monthly", child: Text("Monthly")),
                  DropdownMenuItem(value: "6months", child: Text("6 Months")),
                ],
                onChanged: (v) {
                  setState(() => selectedPeriod = v!);
                  _fetchData();
                },
              ),
            ),
          ],
        ),
        const SizedBox(height: 20),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              children: [
                const Text("Total Meals Consumed", style: TextStyle(fontSize: 16)),
                Text(reportData["total_consumed"]?.toString() ?? "0", style: const TextStyle(fontSize: 40, fontWeight: FontWeight.bold, color: Colors.indigo)),
                const Divider(),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceAround,
                  children: [
                    _reportStat("Veg", reportData["veg_consumed"]?.toString() ?? "0", Colors.green),
                    _reportStat("Non-Veg", reportData["nonveg_consumed"]?.toString() ?? "0", Colors.red),
                  ],
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 20),
        const Text("Hostel-wise Breakdown", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
        ...(reportData["hostel_breakdown"] as List? ?? []).map((h) => ListTile(
          title: Text(h["hostel"]),
          trailing: Text(h["total_consumed"].toString(), style: const TextStyle(fontWeight: FontWeight.bold)),
        )),
      ],
    );
  }

  Widget _reportStat(String label, String val, Color color) {
    return Column(
      children: [
        Text(val, style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: color)),
        Text(label, style: TextStyle(color: color)),
      ],
    );
  }
}
