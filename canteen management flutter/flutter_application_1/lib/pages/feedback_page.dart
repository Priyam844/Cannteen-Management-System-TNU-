import 'dart:convert';
import 'package:flutter/material.dart';
import 'api_service.dart';

class FeedbackPage extends StatefulWidget {
  const FeedbackPage({super.key});

  @override
  State<FeedbackPage> createState() => _FeedbackPageState();
}

class _FeedbackPageState extends State<FeedbackPage> {
  /// Selected values
  int? selectedBookingMealId;
  int rating = 0;
  bool isLoading = true;
  bool isSubmitting = false;

  final TextEditingController reviewController = TextEditingController();

  List<Map<String, dynamic>> consumedMeals = [];
  List<Map<String, dynamic>> myFeedbacks = [];

  @override
  void initState() {
    super.initState();
    fetchData();
  }

  Future<void> fetchData() async {
    setState(() => isLoading = true);
    await Future.wait([
      fetchConsumedMeals(),
      fetchMyFeedbacks(),
    ]);
    setState(() => isLoading = false);
  }

  Future<void> fetchConsumedMeals() async {
    try {
      final res = await ApiService.get("/my-booking/");
      if (res.statusCode == 200) {
        final List bookings = jsonDecode(res.body);
        List<Map<String, dynamic>> extracted = [];

        for (var b in bookings) {
          final date = b["date"];
          for (var m in b["meals"]) {
            if (m["status"] == "consumed") {
              extracted.add({
                "id": m["id"],
                "label": "${m["meal_slot"].toString().toUpperCase()} ($date) - ${m["combo"]}",
              });
            }
          }
        }
        setState(() {
          consumedMeals = extracted;
        });
      }
    } catch (e) {
      print("Error fetching consumed meals: $e");
    }
  }

  Future<void> fetchMyFeedbacks() async {
    try {
      final res = await ApiService.get("/my-feedback/");
      if (res.statusCode == 200) {
        final List data = jsonDecode(res.body);
        setState(() {
          myFeedbacks = data.cast<Map<String, dynamic>>();
        });
      }
    } catch (e) {
      print("Error fetching feedbacks: $e");
    }
  }

  ////////////////////////////////////////////////////////////
  /// HELPERS
  ////////////////////////////////////////////////////////////

  String getRatingLabel(int score) {
    switch (score) {
      case 1: return "Worst";
      case 2: return "Bad";
      case 3: return "OK";
      case 4: return "Good";
      case 5: return "Excellent";
      default: return "";
    }
  }

  Color getRatingColor(int score) {
    if (score <= 2) return Colors.red;
    if (score == 3) return Colors.orange;
    return Colors.green;
  }

  ////////////////////////////////////////////////////////////
  /// SUBMIT FEEDBACK
  ////////////////////////////////////////////////////////////

  Future<void> submitReview() async {
    if (selectedBookingMealId == null) {
      showSnack("Please select a meal");
      return;
    }

    if (rating == 0) {
      showSnack("Please provide a rating");
      return;
    }

    setState(() => isSubmitting = true);

    try {
      final response = await ApiService.post("/feedback/", {
        "booking_meal": selectedBookingMealId,
        "rating": rating,
        "comment": reviewController.text.trim(),
      });

      if (response.statusCode == 201) {
        showSnack("Review submitted successfully");
        setState(() {
          selectedBookingMealId = null;
          rating = 0;
          reviewController.clear();
        });
        fetchData(); // Refresh lists
      } else {
        final error = jsonDecode(response.body);
        showSnack(error.toString());
      }
    } catch (e) {
      showSnack("Error: $e");
    } finally {
      setState(() => isSubmitting = false);
    }
  }

  void showSnack(String msg) {
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(msg)));
  }

  Widget buildStar(int index) {
    return IconButton(
      onPressed: () {
        setState(() {
          rating = index;
        });
      },
      icon: Icon(
        index <= rating ? Icons.star : Icons.star_border,
        color: Colors.amber,
        size: 35,
      ),
    );
  }

  @override
  void dispose() {
    reviewController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Meal Feedback"),
        centerTitle: true,
      ),
      body: isLoading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: fetchData,
              child: SingleChildScrollView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.all(16),
                child: Column(
                  children: [
                    Card(
                      elevation: 4,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          children: [
                            const Text(
                              "Submit Feedback",
                              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                            ),
                            const SizedBox(height: 20),

                            /// Meal Dropdown
                            DropdownButtonFormField<int>(
                              value: selectedBookingMealId,
                              hint: const Text("Select Consumed Meal"),
                              decoration: const InputDecoration(border: OutlineInputBorder()),
                              items: consumedMeals.map((m) {
                                return DropdownMenuItem<int>(
                                  value: m["id"],
                                  child: Text(m["label"], overflow: TextOverflow.ellipsis),
                                );
                              }).toList(),
                              onChanged: (value) => setState(() => selectedBookingMealId = value),
                            ),

                            const SizedBox(height: 25),

                            /// Rating Section
                            const Text(
                              "Rate your meal",
                              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                            ),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: List.generate(5, (index) => buildStar(index + 1)),
                            ),

                            if (rating > 0)
                              Padding(
                                padding: const EdgeInsets.only(top: 8.0),
                                child: Text(
                                  "$rating - ${getRatingLabel(rating)}",
                                  style: TextStyle(
                                    fontSize: 18, 
                                    fontWeight: FontWeight.bold,
                                    color: getRatingColor(rating),
                                  ),
                                ),
                              ),

                            const SizedBox(height: 20),

                            /// Review Text
                            TextField(
                              controller: reviewController,
                              maxLines: 3,
                              decoration: const InputDecoration(
                                hintText: "Write your review (optional)",
                                border: OutlineInputBorder(),
                              ),
                            ),

                            const SizedBox(height: 20),

                            /// Submit Button
                            ElevatedButton(
                              onPressed: isSubmitting ? null : submitReview,
                              style: ElevatedButton.styleFrom(
                                backgroundColor: const Color.fromARGB(255, 140, 9, 48),
                                foregroundColor: Colors.white,
                                minimumSize: const Size(double.infinity, 50),
                              ),
                              child: isSubmitting 
                                ? const CircularProgressIndicator(color: Colors.white)
                                : const Text("Submit Review", style: TextStyle(fontSize: 16)),
                            ),
                          ],
                        ),
                      ),
                    ),

                    const SizedBox(height: 30),

                    const Align(
                      alignment: Alignment.centerLeft,
                      child: Text(
                        "My Past Feedback",
                        style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                      ),
                    ),

                    const SizedBox(height: 10),

                    myFeedbacks.isEmpty
                        ? const Padding(
                            padding: EdgeInsets.only(top: 20),
                            child: Text("No feedback yet", style: TextStyle(color: Colors.grey)),
                          )
                        : ListView.builder(
                            shrinkWrap: true,
                            physics: const NeverScrollableScrollPhysics(),
                            itemCount: myFeedbacks.length,
                            itemBuilder: (context, index) {
                              var fb = myFeedbacks[index];
                              int r = fb["rating"];
                              return Card(
                                child: ListTile(
                                  leading: CircleAvatar(
                                    backgroundColor: getRatingColor(r),
                                    child: Text(r.toString(), style: const TextStyle(color: Colors.white)),
                                  ),
                                  title: Text("Rating: ${getRatingLabel(r)}"),
                                  subtitle: Text(fb["comment"] ?? "No written review"),
                                  trailing: Text(fb["created_at"].toString().substring(0, 10)),
                                ),
                              );
                            },
                          ),
                  ],
                ),
              ),
            ),
    );
  }
}