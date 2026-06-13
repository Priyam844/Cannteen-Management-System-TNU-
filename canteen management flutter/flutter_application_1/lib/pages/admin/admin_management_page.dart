import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_application_1/services/api_service.dart';
import 'package:file_picker/file_picker.dart';

class AdminManagementPage extends StatefulWidget {
  const AdminManagementPage({super.key});

  @override
  State<AdminManagementPage> createState() => _AdminManagementPageState();
}

class _AdminManagementPageState extends State<AdminManagementPage> {
  bool isLoading = true;
  List managers = [];
  List hostels = [];
  final Color primaryMaroon = const Color.fromARGB(255, 152, 29, 68);

  @override
  void initState() {
    super.initState();
    _fetchData();
  }

  Future<void> _fetchData() async {
    setState(() => isLoading = true);
    try {
      final res = await ApiService.get("/admin-management/");
      if (res.statusCode == 200) {
        final data = jsonDecode(res.body);
        setState(() {
          managers = data["managers"];
          hostels = data["hostels"];
        });
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Error: $e"), behavior: SnackBarBehavior.floating),
        );
      }
    } finally {
      if (mounted) setState(() => isLoading = false);
    }
  }

  void _addUser() {
    final emailCtrl = TextEditingController();
    final passCtrl = TextEditingController();
    final firstCtrl = TextEditingController();
    final lastCtrl = TextEditingController();
    final phoneCtrl = TextEditingController();
    final studentIdCtrl = TextEditingController();
    String selectedRole = "student";
    int? selectedHostel;

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
          title: Text("Add New User",
              style: TextStyle(
                  color: primaryMaroon, fontWeight: FontWeight.bold)),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                DropdownButtonFormField<String>(
                  value: selectedRole,
                  decoration: InputDecoration(
                    labelText: "Role",
                    prefixIcon: Icon(Icons.badge_outlined, color: primaryMaroon),
                    border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12)),
                  ),
                  items: ["student", "faculty", "staff", "manager"]
                      .map((r) => DropdownMenuItem(
                          value: r, child: Text(r.toUpperCase())))
                      .toList(),
                  onChanged: (v) => setDialogState(() => selectedRole = v!),
                ),
                const SizedBox(height: 12),
                _buildTextField(firstCtrl, "First Name", Icons.person_outline),
                _buildTextField(lastCtrl, "Last Name", Icons.person_outline),
                _buildTextField(emailCtrl, "Email Address", Icons.email_outlined),
                if (selectedRole == 'manager')
                  _buildTextField(passCtrl, "Initial Password", Icons.lock_outline,
                      isPassword: true)
                else
                  _buildTextField(phoneCtrl, "Phone Number", Icons.phone_outlined),
                
                if (selectedRole == 'student')
                  _buildTextField(studentIdCtrl, "Student ID", Icons.assignment_ind_outlined),

                const SizedBox(height: 12),
                DropdownButtonFormField<int>(
                  value: selectedHostel,
                  decoration: InputDecoration(
                    labelText: "Assign Hostel",
                    prefixIcon:
                        Icon(Icons.business_rounded, color: primaryMaroon),
                    border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12)),
                  ),
                  items: hostels
                      .map<DropdownMenuItem<int>>((h) => DropdownMenuItem(
                          value: h["id"], child: Text(h["name"])))
                      .toList(),
                  onChanged: (v) => setDialogState(() => selectedHostel = v),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text("Cancel")),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: primaryMaroon,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12)),
                padding:
                    const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
              ),
              onPressed: () async {
                final res = await ApiService.post("/admin-add-user/", {
                  "email": emailCtrl.text,
                  "password": selectedRole == 'manager' ? passCtrl.text : null,
                  "first_name": firstCtrl.text,
                  "last_name": lastCtrl.text,
                  "role": selectedRole,
                  "hostel_id": selectedHostel,
                  "phone": phoneCtrl.text,
                  "student_id": studentIdCtrl.text,
                });

                if (!mounted) return;
                if (res.statusCode == 201) {
                  Navigator.pop(context);
                  _fetchData();
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text("User added successfully!")),
                  );
                } else {
                  final msg = jsonDecode(res.body)["error"] ?? "Failed to add user";
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text(msg), backgroundColor: Colors.red),
                  );
                }
              },
              child: const Text("Add User"),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTextField(TextEditingController ctrl, String label, IconData icon, {bool isPassword = false}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: TextField(
        controller: ctrl,
        obscureText: isPassword,
        decoration: InputDecoration(
          labelText: label,
          prefixIcon: Icon(icon, color: primaryMaroon),
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide(color: primaryMaroon, width: 2),
          ),
        ),
      ),
    );
  }

  void _deleteManager(int id) async {
    final bool? confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text("Confirm Delete"),
        content: const Text("Are you sure you want to remove this manager?"),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text("Cancel")),
          TextButton(
            onPressed: () => Navigator.pop(context, true), 
            child: const Text("Delete", style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );

    if (confirm == true) {
      final res = await ApiService.delete("/admin-management/?id=$id");
      if (res.statusCode == 200) _fetchData();
    }
  }

  void _editHostelSettings(Map hostel) {
    final bookingParts = (hostel["cutoff_time"] ?? "14:00").split(":");
    final cancelParts = (hostel["cancellation_cutoff_time"] ?? "16:00").split(":");
    
    TimeOfDay bookingTime = TimeOfDay(hour: int.parse(bookingParts[0]), minute: int.parse(bookingParts[1]));
    TimeOfDay cancelTime = TimeOfDay(hour: int.parse(cancelParts[0]), minute: int.parse(cancelParts[1]));
    final leadTimeCtrl = TextEditingController(text: hostel["late_booking_lead_time"]?.toString() ?? "2");
    bool excludedForFaculty = hostel["excluded_for_faculty"] ?? false;

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
          title: Text("Operational Rules: ${hostel["name"]}", style: TextStyle(color: primaryMaroon, fontSize: 18, fontWeight: FontWeight.bold)),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildRulePicker(
                  "Booking Cutoff", 
                  "Time limit to book meals 2 days prior",
                  bookingTime.format(context),
                  () async {
                    final time = await showTimePicker(context: context, initialTime: bookingTime);
                    if (time != null) setDialogState(() => bookingTime = time);
                  },
                  Icons.access_time_rounded
                ),
                const SizedBox(height: 20),
                _buildRulePicker(
                  "Cancellation Cutoff", 
                  "Time limit to cancel 2 days prior",
                  cancelTime.format(context),
                  () async {
                    final time = await showTimePicker(context: context, initialTime: cancelTime);
                    if (time != null) setDialogState(() => cancelTime = time);
                  },
                  Icons.cancel_schedule_send_rounded
                ),
                const SizedBox(height: 24),
                const Text("Today's Late Booking Lead Time", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Color(0xFF2D3142))),
                const SizedBox(height: 8),
                TextField(
                  controller: leadTimeCtrl,
                  keyboardType: TextInputType.number,
                  decoration: InputDecoration(
                    labelText: "Lead Time (Hours)",
                    hintText: "e.g. 2, 3, or 4",
                    prefixIcon: Icon(Icons.bolt_rounded, color: primaryMaroon),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                    helperText: "Hours before meal start to stop bookings",
                  ),
                ),
                const SizedBox(height: 24),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: excludedForFaculty ? Colors.orange.shade50 : Colors.green.shade50,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: excludedForFaculty ? Colors.orange.shade200 : Colors.green.shade200),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        excludedForFaculty ? Icons.block_flipped : Icons.check_circle_outline,
                        color: excludedForFaculty ? Colors.orange.shade800 : Colors.green.shade800,
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text("Faculty Access", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                            Text(
                              excludedForFaculty ? "Faculty restricted from this hostel" : "Faculty allowed to book here",
                              style: TextStyle(fontSize: 11, color: Colors.grey.shade700),
                            ),
                          ],
                        ),
                      ),
                      Switch(
                        value: !excludedForFaculty,
                        activeColor: Colors.green,
                        onChanged: (val) => setDialogState(() => excludedForFaculty = !val),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(context), child: const Text("Cancel")),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: primaryMaroon, 
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
              onPressed: () async {
                final res = await ApiService.put("/admin-management/", {
                  "hostel_id": hostel["id"],
                  "cutoff_time": "${bookingTime.hour.toString().padLeft(2, '0')}:${bookingTime.minute.toString().padLeft(2, '0')}",
                  "cancellation_cutoff_time": "${cancelTime.hour.toString().padLeft(2, '0')}:${cancelTime.minute.toString().padLeft(2, '0')}",
                  "late_booking_lead_time": leadTimeCtrl.text,
                  "excluded_for_faculty": excludedForFaculty,
                });
                if (res.statusCode == 200) {
                  Navigator.pop(context);
                  _fetchData();
                  ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Settings updated"), behavior: SnackBarBehavior.floating));
                } else {
                  ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(res.body)));
                }
              },
              child: const Text("Save Rules"),
            )
          ],
        ),
      ),
    );
  }

  Widget _buildRulePicker(String title, String subtitle, String value, VoidCallback onTap, IconData icon) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(title, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Color(0xFF2D3142))),
        Text(subtitle, style: TextStyle(fontSize: 11, color: Colors.grey.shade600)),
        const SizedBox(height: 8),
        InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(12),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              border: Border.all(color: Colors.grey.shade300),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              children: [
                Icon(icon, color: primaryMaroon, size: 20),
                const SizedBox(width: 12),
                Text(value, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
                const Spacer(),
                const Icon(Icons.edit_rounded, size: 16, color: Colors.grey),
              ],
            ),
          ),
        ),
      ],
    );
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
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
          title: Text("Meal Service Times", style: TextStyle(color: primaryMaroon, fontWeight: FontWeight.bold)),
          content: SizedBox(
            width: double.maxFinite,
            child: ListView(
              shrinkWrap: true,
              children: slots.map((slot) {
                final range = timings[slot] as List;
                return Container(
                  margin: const EdgeInsets.only(bottom: 16),
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.grey.shade50,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: Colors.grey.shade200),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(slot.toUpperCase(), style: TextStyle(fontWeight: FontWeight.w900, color: primaryMaroon, fontSize: 12, letterSpacing: 1)),
                      const SizedBox(height: 10),
                      Row(
                        children: [
                          _timeAdjuster("Start", range[0], () async {
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
                          }),
                          const Padding(
                            padding: EdgeInsets.symmetric(horizontal: 8),
                            child: Icon(Icons.arrow_forward_rounded, size: 16, color: Colors.grey),
                          ),
                          _timeAdjuster("End", range[1], () async {
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
                          }),
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
              style: ElevatedButton.styleFrom(
                backgroundColor: primaryMaroon, 
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
              onPressed: () async {
                final res = await ApiService.put("/admin-management/", {
                  "hostel_id": hostel["id"],
                  "slot_timings": timings
                });
                if (res.statusCode == 200) {
                  Navigator.pop(context);
                  _fetchData();
                  ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Meal times updated"), behavior: SnackBarBehavior.floating));
                } else {
                  ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(res.body)));
                }
              },
              child: const Text("Save Times"),
            )
          ],
        ),
      ),
    );
  }

  Widget _timeAdjuster(String label, String time, VoidCallback onTap) {
    return Expanded(
      child: InkWell(
        onTap: onTap,
        child: Column(
          children: [
            Text(label, style: TextStyle(fontSize: 10, color: Colors.grey.shade500)),
            Text(time, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
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
        if (filePath == null) return;

        int? selectedHostel;

        showDialog(
          context: context,
          builder: (context) => StatefulBuilder(
            builder: (context, setDialogState) => AlertDialog(
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
              title: const Text("Bulk Student Auth", style: TextStyle(fontWeight: FontWeight.bold)),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text("Select the destination hostel for these students.", style: TextStyle(fontSize: 13)),
                  const SizedBox(height: 20),
                  DropdownButtonFormField<int>(
                    isExpanded: true,
                    decoration: InputDecoration(
                      labelText: "Select Hostel",
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                    items: hostels.map<DropdownMenuItem<int>>((h) => DropdownMenuItem(value: h["id"], child: Text(h["name"]))).toList(),
                    onChanged: (v) => setDialogState(() => selectedHostel = v),
                  ),
                  const SizedBox(height: 20),
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(color: Colors.blue.shade50, borderRadius: BorderRadius.circular(12)),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text("File requirements:", style: TextStyle(fontWeight: FontWeight.bold, color: Colors.blue, fontSize: 12)),
                        const SizedBox(height: 4),
                        Text("• CSV or Excel format\n• Column 1: email\n• Column 2: phone", style: TextStyle(fontSize: 11, color: Colors.blue.shade800)),
                      ],
                    ),
                  ),
                ],
              ),
              actions: [
                TextButton(onPressed: () => Navigator.pop(context), child: const Text("Cancel")),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(backgroundColor: primaryMaroon, foregroundColor: Colors.white, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
                  onPressed: () async {
                    if (selectedHostel == null) {
                      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Select a hostel")));
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
                        _showSuccessDialog("Upload Complete", data["message"] ?? "Operation successful");
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
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Error: $e")));
    }
  }

  void _showSuccessDialog(String title, String content) {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        title: Row(
          children: [
            const Icon(Icons.check_circle, color: Colors.green),
            const SizedBox(width: 10),
            Text(title),
          ],
        ),
        content: Text(content),
        actions: [TextButton(onPressed: () => Navigator.pop(context), child: const Text("Done"))],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (isLoading) {
      return Center(child: CircularProgressIndicator(color: primaryMaroon));
    }

    return Scaffold(
      backgroundColor: const Color(0xFFF5F7FA),
      body: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildSectionHeader("Hostels & Operational Rules"),
            const SizedBox(height: 16),
            ...hostels.map((h) => _buildHostelCard(h)),
            const SizedBox(height: 32),
            _buildSectionHeader("Tools"),
            const SizedBox(height: 16),
            _buildBulkUploadTile(),
            const SizedBox(height: 32),
            _buildSectionHeader("Management Users"),
            const SizedBox(height: 16),
            ...managers.map((m) => _buildManagerCard(m)),
            const SizedBox(height: 80),
          ],
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _addUser,
        backgroundColor: primaryMaroon,
        icon: const Icon(Icons.person_add_alt_1_rounded, color: Colors.white),
        label: const Text("New User", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
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

  Widget _buildHostelCard(Map h) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.03), blurRadius: 10, offset: const Offset(0, 4))],
      ),
      child: ExpansionTile(
        shape: const RoundedRectangleBorder(side: BorderSide.none),
        leading: Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(color: primaryMaroon.withOpacity(0.1), borderRadius: BorderRadius.circular(10)),
          child: Icon(Icons.business_rounded, color: primaryMaroon, size: 20),
        ),
        title: Text(h["name"], style: const TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF2D3142))),
        subtitle: Text("Cutoff: ${h["cutoff_time"]} | ${h["cancellation_cutoff_time"]}", style: TextStyle(fontSize: 12, color: Colors.grey.shade600)),
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Divider(),
                const SizedBox(height: 8),
                _hostelDetailRow(Icons.timer_outlined, "Booking Rules", "Cutoff at ${h["cutoff_time"]} (2 days prior)"),
                _hostelDetailRow(Icons.cancel_outlined, "Cancellation", "Cutoff at ${h["cancellation_cutoff_time"]} (2 days prior)"),
                _hostelDetailRow(Icons.bolt_rounded, "Late Booking", "Lead time: ${h["late_booking_lead_time"]} hours"),
                const SizedBox(height: 16),
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    _hostelActionButton("Edit Rules", Icons.settings_rounded, () => _editHostelSettings(h)),
                    const SizedBox(width: 10),
                    _hostelActionButton("Meal Times", Icons.access_time_filled_rounded, () => _editMealTimes(h)),
                  ],
                )
              ],
            ),
          )
        ],
      ),
    );
  }

  Widget _hostelDetailRow(IconData icon, String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(
        children: [
          Icon(icon, size: 14, color: Colors.grey.shade500),
          const SizedBox(width: 8),
          Text("$label: ", style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.grey.shade700)),
          Text(value, style: TextStyle(fontSize: 12, color: Colors.grey.shade600)),
        ],
      ),
    );
  }

  Widget _hostelActionButton(String label, IconData icon, VoidCallback onTap) {
    return OutlinedButton.icon(
      onPressed: onTap,
      icon: Icon(icon, size: 16),
      label: Text(label, style: const TextStyle(fontSize: 12)),
      style: OutlinedButton.styleFrom(
        foregroundColor: primaryMaroon,
        side: BorderSide(color: primaryMaroon.withOpacity(0.5)),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      ),
    );
  }

  Widget _buildBulkUploadTile() {
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(colors: [primaryMaroon, primaryMaroon.withOpacity(0.8)]),
        borderRadius: BorderRadius.circular(20),
        boxShadow: [BoxShadow(color: primaryMaroon.withOpacity(0.3), blurRadius: 10, offset: const Offset(0, 4))],
      ),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
        leading: Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(color: Colors.white.withOpacity(0.2), shape: BoxShape.circle),
          child: const Icon(Icons.upload_file_rounded, color: Colors.white),
        ),
        title: const Text("Bulk Student Authorization", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
        subtitle: const Text("Upload CSV or Excel file to authorize users", style: TextStyle(color: Colors.white70, fontSize: 12)),
        trailing: const Icon(Icons.chevron_right_rounded, color: Colors.white),
        onTap: _bulkUploadStudents,
      ),
    );
  }

  Widget _buildManagerCard(Map m) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.grey.shade100),
      ),
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: primaryMaroon.withOpacity(0.1),
          child: Text(m["first_name"][0], style: TextStyle(color: primaryMaroon, fontWeight: FontWeight.bold)),
        ),
        title: Text("${m["first_name"]} ${m["last_name"]}", style: const TextStyle(fontWeight: FontWeight.bold)),
        subtitle: Text("${m["email"]}\nHostel: ${m["hostel"]}", style: TextStyle(fontSize: 12, color: Colors.grey.shade600)),
        isThreeLine: true,
        trailing: IconButton(
          icon: const Icon(Icons.delete_outline_rounded, color: Colors.redAccent),
          onPressed: () => _deleteManager(m["id"]),
        ),
      ),
    );
  }
}

