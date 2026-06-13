import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_application_1/services/api_service.dart';

class AllowedUsersPage extends StatefulWidget {
  const AllowedUsersPage({super.key});

  @override
  State<AllowedUsersPage> createState() => _AllowedUsersPageState();
}

class _AllowedUsersPageState extends State<AllowedUsersPage> {
  bool isLoading = true;
  List allowedUsers = [];

  final TextEditingController emailController = TextEditingController();
  final TextEditingController phoneController = TextEditingController();

  @override
  void initState() {
    super.initState();
    fetchAllowedUsers();
  }

  Future<void> fetchAllowedUsers() async {
    setState(() => isLoading = true);
    try {
      final res = await ApiService.get("/allowed-users/");
      if (res.statusCode == 200) {
        setState(() {
          allowedUsers = jsonDecode(res.body);
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

  Future<void> addAllowedUser() async {
    if (emailController.text.isEmpty || phoneController.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("All fields required")));
      return;
    }

    try {
      final res = await ApiService.post("/allowed-users/", {
        "email": emailController.text.trim(),
        "phone": phoneController.text.trim(),
      });

      if (res.statusCode == 201) {
        emailController.clear();
        phoneController.clear();
        Navigator.pop(context);
        fetchAllowedUsers();
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("User authorized")));
      } else {
        final error = jsonDecode(res.body);
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(error.toString())));
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Error: $e")));
    }
  }

  void openAddDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text("Authorize New Student"),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(controller: emailController, decoration: const InputDecoration(labelText: "Email")),
            TextField(controller: phoneController, decoration: const InputDecoration(labelText: "Phone")),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text("Cancel")),
          ElevatedButton(onPressed: addAllowedUser, child: const Text("Add")),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Authorized Registrations"),
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
          : allowedUsers.isEmpty
              ? const Center(child: Text("No authorized users yet"))
              : RefreshIndicator(
                  onRefresh: fetchAllowedUsers,
                  child: ListView.builder(
                    padding: const EdgeInsets.all(16),
                    itemCount: allowedUsers.length,
                    itemBuilder: (context, index) {
                      final u = allowedUsers[index];
                      return Card(
                        child: ListTile(
                          leading: Icon(u["is_used"] ? Icons.check_circle : Icons.pending, color: u["is_used"] ? Colors.green : Colors.orange),
                          title: Text(u["email"]),
                          subtitle: Text("Phone: ${u["phone"]}\nStatus: ${u["is_used"] ? "Registered" : "Pending"}"),
                        ),
                      );
                    },
                  ),
                ),
    );
  }
}
