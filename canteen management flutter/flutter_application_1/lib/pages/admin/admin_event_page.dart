import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_application_1/services/api_service.dart';
import 'package:intl/intl.dart';

class AdminEventPage extends StatefulWidget {
  const AdminEventPage({super.key});

  @override
  State<AdminEventPage> createState() => _AdminEventPageState();
}

class _AdminEventPageState extends State<AdminEventPage> {
  bool isLoading = true;
  List events = [];
  final Color primaryMaroon = const Color.fromARGB(255, 152, 29, 68);

  @override
  void initState() {
    super.initState();
    _fetchEvents();
  }

  Future<void> _fetchEvents() async {
    setState(() => isLoading = true);
    try {
      final res = await ApiService.get("/events/");
      if (res.statusCode == 200) {
        setState(() {
          events = jsonDecode(res.body);
        });
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Error: $e")));
    } finally {
      setState(() => isLoading = false);
    }
  }

  void _createEvent() {
    final nameCtrl = TextEditingController();
    final descCtrl = TextEditingController();
    DateTime start = DateTime.now();
    DateTime end = DateTime.now().add(const Duration(days: 1));

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: const Text("New Institutional Event"),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(controller: nameCtrl, decoration: const InputDecoration(labelText: "Event Name")),
                TextField(controller: descCtrl, decoration: const InputDecoration(labelText: "Description")),
                const SizedBox(height: 16),
                ListTile(
                  title: Text("Start: ${DateFormat('yyyy-MM-dd').format(start)}"),
                  trailing: const Icon(Icons.calendar_today),
                  onTap: () async {
                    final d = await showDatePicker(context: context, initialDate: start, firstDate: DateTime(2023), lastDate: DateTime(2030));
                    if (d != null) setDialogState(() => start = d);
                  },
                ),
                ListTile(
                  title: Text("End: ${DateFormat('yyyy-MM-dd').format(end)}"),
                  trailing: const Icon(Icons.calendar_today),
                  onTap: () async {
                    final d = await showDatePicker(context: context, initialDate: end, firstDate: DateTime(2023), lastDate: DateTime(2030));
                    if (d != null) setDialogState(() => end = d);
                  },
                ),
              ],
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(context), child: const Text("Cancel")),
            ElevatedButton(
              onPressed: () async {
                final res = await ApiService.post("/events/", {
                  "name": nameCtrl.text,
                  "description": descCtrl.text,
                  "start_date": DateFormat('yyyy-MM-dd').format(start),
                  "end_date": DateFormat('yyyy-MM-dd').format(end),
                });
                if (res.statusCode == 201) {
                  if (!mounted) return;
                  Navigator.pop(context);
                  _fetchEvents();
                } else {
                  if (!mounted) return;
                  ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Failed: ${res.body}")));
                }
              },
              child: const Text("Create"),
            )
          ],
        ),
      ),
    );
  }

  void _managePasses(Map event) {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => EventPassesPage(event: event)),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Institutional Events"),
        backgroundColor: primaryMaroon,
        foregroundColor: Colors.white,
      ),
      body: isLoading
          ? const Center(child: CircularProgressIndicator())
          : ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: events.length,
              itemBuilder: (context, index) {
                final e = events[index];
                return Card(
                  margin: const EdgeInsets.only(bottom: 12),
                  child: ListTile(
                    title: Text(e["name"], style: const TextStyle(fontWeight: FontWeight.bold)),
                    subtitle: Text("${e["start_date"]} to ${e["end_date"]}\n${e["description"]}"),
                    isThreeLine: true,
                    trailing: const Icon(Icons.chevron_right),
                    onTap: () => _managePasses(e),
                  ),
                );
              },
            ),
      floatingActionButton: FloatingActionButton(
        onPressed: _createEvent,
        backgroundColor: primaryMaroon,
        child: const Icon(Icons.add, color: Colors.white),
      ),
    );
  }
}

class EventPassesPage extends StatefulWidget {
  final Map event;
  const EventPassesPage({super.key, required this.event});

  @override
  State<EventPassesPage> createState() => _EventPassesPageState();
}

class _EventPassesPageState extends State<EventPassesPage> {
  bool isLoading = true;
  List passes = [];
  final Color primaryMaroon = const Color.fromARGB(255, 152, 29, 68);

  @override
  void initState() {
    super.initState();
    _fetchPasses();
  }

  Future<void> _fetchPasses() async {
    setState(() => isLoading = true);
    try {
      final res = await ApiService.get("/event-passes/?event_id=${widget.event["id"]}");
      if (res.statusCode == 200) {
        setState(() {
          passes = jsonDecode(res.body);
        });
      }
    } catch (e) {
      debugPrint("Error: $e");
    } finally {
      setState(() => isLoading = false);
    }
  }

  void _addGuest() {
    final nameCtrl = TextEditingController();
    final emailCtrl = TextEditingController();
    List<String> selectedSlots = [];
    final slots = ["breakfast", "lunch", "snacks", "dinner"];

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          title: const Text("Generate Guest Pass",
              style: TextStyle(fontWeight: FontWeight.bold)),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                    controller: nameCtrl,
                    decoration: const InputDecoration(
                        labelText: "Guest Name",
                        prefixIcon: Icon(Icons.person_outline))),
                TextField(
                    controller: emailCtrl,
                    decoration: const InputDecoration(
                        labelText: "Guest Email (Optional)",
                        hintText: "Sends QR via email",
                        prefixIcon: Icon(Icons.email_outlined))),
                const SizedBox(height: 20),
                const Align(
                    alignment: Alignment.centerLeft,
                    child: Text("Select Allowed Meal Slots:",
                        style: TextStyle(
                            fontSize: 13, fontWeight: FontWeight.bold))),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  children: slots
                      .map((s) => FilterChip(
                            label: Text(s.toUpperCase(),
                                style: const TextStyle(fontSize: 10)),
                            selected: selectedSlots.contains(s),
                            selectedColor: primaryMaroon.withOpacity(0.2),
                            checkmarkColor: primaryMaroon,
                            onSelected: (v) {
                              setDialogState(() {
                                if (v) {
                                  selectedSlots.add(s);
                                } else {
                                  selectedSlots.remove(s);
                                }
                              });
                            },
                          ))
                      .toList(),
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
                      borderRadius: BorderRadius.circular(10))),
              onPressed: () async {
                if (nameCtrl.text.isEmpty) return;

                final res = await ApiService.post("/event-passes/", {
                  "event_id": widget.event["id"],
                  "guests": [
                    {
                      "name": nameCtrl.text,
                      "email": emailCtrl.text.trim().isNotEmpty
                          ? emailCtrl.text.trim()
                          : null,
                      "meal_slots": selectedSlots,
                    }
                  ],
                });

                if (res.statusCode == 201) {
                  if (!mounted) return;
                  Navigator.pop(context);
                  _fetchPasses();
                  ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text("Pass generated!")));
                } else {
                  if (!mounted) return;
                  ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text("Failed: ${res.body}")));
                }
              },
              child: const Text("Generate"),
            )
          ],
        ),
      ),
    );
  }

  void _deletePass(int id) async {
    final bool? confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text("Cancel Guest Pass"),
        content: const Text("Are you sure you want to delete this pass?"),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text("No")),
          TextButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text("Delete", style: TextStyle(color: Colors.red))),
        ],
      ),
    );

    if (confirm == true) {
      final res = await ApiService.delete("/event-passes/?id=$id");
      if (res.statusCode == 200) {
        _fetchPasses();
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text("Passes: ${widget.event["name"]}"),
        backgroundColor: primaryMaroon,
        foregroundColor: Colors.white,
      ),
      body: isLoading
          ? const Center(child: CircularProgressIndicator())
          : ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: passes.length,
              itemBuilder: (context, index) {
                final p = passes[index];
                final allowedMeals =
                    (p["meal_slots"] as List?)?.join(", ") ?? "All Meals";
                return Card(
                  margin: const EdgeInsets.only(bottom: 8),
                  child: ListTile(
                    leading: Icon(
                        p["is_used"] ? Icons.check_circle : Icons.qr_code,
                        color: p["is_used"] ? Colors.green : Colors.grey),
                    title: Text(p["guest_name"],
                        style: const TextStyle(fontWeight: FontWeight.bold)),
                    subtitle: Text(
                      "${p["email"] ?? "No email"}\nAllowed: ${allowedMeals.toUpperCase()}\n${p["is_used"] ? "Consumed: ${p["consumed_at"].toString().substring(0, 16)}" : "Not used"}",
                      style: const TextStyle(fontSize: 11),
                    ),
                    isThreeLine: true,
                    trailing: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        IconButton(
                          icon: const Icon(Icons.qr_code_scanner, size: 20),
                          onPressed: () => _showQR(p),
                        ),
                        IconButton(
                          icon: const Icon(Icons.delete_outline,
                              color: Colors.red, size: 20),
                          onPressed: () => _deletePass(p["id"]),
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _addGuest,
        label: const Text("New Guest Pass", style: TextStyle(color: Colors.white)),
        icon: const Icon(Icons.person_add_alt_1, color: Colors.white),
        backgroundColor: primaryMaroon,
      ),
    );
  }

  void _showQR(Map p) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text("Pass: ${p["guest_name"]}"),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 200, height: 200,
              color: Colors.grey.shade200,
              child: const Center(child: Text("QR CODE HERE\n(UUID in real app)")),
              // Use a real QR widget here if needed
            ),
            const SizedBox(height: 16),
            Text("UUID: ${p["qr_uuid"]}", style: const TextStyle(fontSize: 10, color: Colors.grey)),
          ],
        ),
        actions: [TextButton(onPressed: () => Navigator.pop(context), child: const Text("Close"))],
      ),
    );
  }
}
