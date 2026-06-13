import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_application_1/services/api_service.dart';

class ManagerFeedbackPage extends StatefulWidget {
  const ManagerFeedbackPage({super.key});

  @override
  State<ManagerFeedbackPage> createState() => _ManagerFeedbackPageState();
}

class _ManagerFeedbackPageState extends State<ManagerFeedbackPage> {
  bool isLoading = true;
  List feedbacks = [];

  @override
  void initState() {
    super.initState();
    fetchFeedback();
  }

  Future<void> fetchFeedback() async {
    setState(() => isLoading = true);
    try {
      final res = await ApiService.get("/my-feedback/");
      if (res.statusCode == 200) {
        setState(() {
          feedbacks = jsonDecode(res.body);
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
        title: const Text("Student Feedback"),
        backgroundColor: const Color.fromARGB(255, 152, 29, 68),
        foregroundColor: Colors.white,
      ),
      body: isLoading
          ? const Center(child: CircularProgressIndicator())
          : feedbacks.isEmpty
              ? const Center(child: Text("No feedback received yet"))
              : RefreshIndicator(
                  onRefresh: fetchFeedback,
                  child: ListView.builder(
                    padding: const EdgeInsets.all(16),
                    itemCount: feedbacks.length,
                    itemBuilder: (context, index) {
                      final fb = feedbacks[index];
                      final rating = fb["rating"];
                      return Card(
                        child: ListTile(
                          leading: CircleAvatar(
                            backgroundColor: rating >= 4 ? Colors.green : (rating >= 3 ? Colors.orange : Colors.red),
                            child: Text(rating.toString(), style: const TextStyle(color: Colors.white)),
                          ),
                          title: Text("${fb["meal_slot"]?.toString().toUpperCase()} - ${fb["combo_name"]}"),
                          subtitle: Text(fb["comment"]?.isEmpty == true ? "No written review" : fb["comment"]),
                          trailing: Text(fb["created_at"].toString().substring(0, 10)),
                        ),
                      );
                    },
                  ),
                ),
    );
  }
}
