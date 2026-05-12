import 'dart:convert';
import 'package:flutter/material.dart';
import 'api_service.dart';

class ManagerAnnouncementsPage extends StatefulWidget {
  const ManagerAnnouncementsPage({super.key});

  @override
  State<ManagerAnnouncementsPage> createState() => _ManagerAnnouncementsPageState();
}

class _ManagerAnnouncementsPageState extends State<ManagerAnnouncementsPage> {
  bool isLoading = true;
  List announcements = [];

  final TextEditingController titleController = TextEditingController();
  final TextEditingController contentController = TextEditingController();

  @override
  void initState() {
    super.initState();
    fetchAnnouncements();
  }

  Future<void> fetchAnnouncements() async {
    setState(() => isLoading = true);
    try {
      final res = await ApiService.get("/announcements/");
      if (res.statusCode == 200) {
        setState(() {
          announcements = jsonDecode(res.body);
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

  Future<void> createAnnouncement() async {
    if (titleController.text.isEmpty || contentController.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Title and content required")));
      return;
    }

    try {
      final res = await ApiService.post("/announcements/", {
        "title": titleController.text.trim(),
        "content": contentController.text.trim(),
      });

      if (res.statusCode == 201) {
        titleController.clear();
        contentController.clear();
        Navigator.pop(context);
        fetchAnnouncements();
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Announcement posted")));
      } else {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Error: ${res.body}")));
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Error: $e")));
    }
  }

  Future<void> deleteAnnouncement(int id) async {
    try {
      final res = await ApiService.delete("/announcements/$id/");
      if (res.statusCode == 204) {
        fetchAnnouncements();
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Deleted")));
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Error: $e")));
    }
  }

  void openAddDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text("New Announcement"),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(controller: titleController, decoration: const InputDecoration(labelText: "Title")),
            TextField(controller: contentController, decoration: const InputDecoration(labelText: "Content"), maxLines: 3),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text("Cancel")),
          ElevatedButton(onPressed: createAnnouncement, child: const Text("Post")),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Manage Announcements"),
        backgroundColor: const Color.fromARGB(255, 152, 29, 68),
        foregroundColor: Colors.white,
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: openAddDialog,
        backgroundColor: const Color.fromARGB(255, 152, 29, 68),
        child: const Icon(Icons.add, color: Colors.white),
      ),
      body: isLoading
          ? const Center(child: CircularProgressIndicator())
          : announcements.isEmpty
              ? const Center(child: Text("No announcements yet"))
              : RefreshIndicator(
                  onRefresh: fetchAnnouncements,
                  child: ListView.builder(
                    padding: const EdgeInsets.all(16),
                    itemCount: announcements.length,
                    itemBuilder: (context, index) {
                      final a = announcements[index];
                      return Card(
                        child: ListTile(
                          title: Text(a["title"], style: const TextStyle(fontWeight: FontWeight.bold)),
                          subtitle: Text(a["content"]),
                          trailing: IconButton(
                            icon: const Icon(Icons.delete, color: Colors.red),
                            onPressed: () => deleteAnnouncement(a["id"]),
                          ),
                        ),
                      );
                    },
                  ),
                ),
    );
  }
}
