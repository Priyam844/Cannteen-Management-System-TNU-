import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_application_1/services/api_service.dart';

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
        elevation: 0,
      ),
      body: isLoading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: fetchData,
              child: SingleChildScrollView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Card(
                      elevation: 4,
                      shadowColor: Colors.black12,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                      child: Padding(
                        padding: const EdgeInsets.all(20),
                        child: Column(
                          children: [
                            const Text(
                              "Submit New Review",
                              style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                            ),
                            const SizedBox(height: 20),

                            /// Meal Dropdown
                            DropdownButtonFormField<int>(
                              value: selectedBookingMealId,
                              hint: const Text("Select a consumed meal"),
                              isExpanded: true,
                              decoration: InputDecoration(
                                labelText: "Consumed Meals",
                                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                                prefixIcon: const Icon(Icons.restaurant_menu),
                              ),
                              items: consumedMeals.map((m) {
                                return DropdownMenuItem<int>(
                                  value: m["id"],
                                  child: Text(m["label"], overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 14)),
                                );
                              }).toList(),
                              onChanged: (value) => setState(() => selectedBookingMealId = value),
                            ),

                            const SizedBox(height: 25),

                            /// Rating Section
                            const Text(
                              "How was the food?",
                              style: TextStyle(fontWeight: FontWeight.w600, fontSize: 16),
                            ),
                            const SizedBox(height: 8),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: List.generate(5, (index) => buildStar(index + 1)),
                            ),

                            if (rating > 0)
                              Padding(
                                padding: const EdgeInsets.only(top: 8.0),
                                child: Text(
                                  getRatingLabel(rating).toUpperCase(),
                                  style: TextStyle(
                                    fontSize: 16, 
                                    fontWeight: FontWeight.bold,
                                    color: getRatingColor(rating),
                                    letterSpacing: 1.2,
                                  ),
                                ),
                              ),

                            const SizedBox(height: 25),

                            /// Review Text
                            TextField(
                              controller: reviewController,
                              maxLines: 3,
                              decoration: InputDecoration(
                                labelText: "Review (Optional)",
                                hintText: "Share your experience...",
                                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                                alignLabelWithHint: true,
                              ),
                            ),

                            const SizedBox(height: 25),

                            /// Submit Button
                            ElevatedButton(
                              onPressed: isSubmitting ? null : submitReview,
                              style: ElevatedButton.styleFrom(
                                backgroundColor: const Color.fromARGB(255, 152, 29, 68),
                                foregroundColor: Colors.white,
                                minimumSize: const Size(double.infinity, 55),
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                                elevation: 2,
                              ),
                              child: isSubmitting 
                                ? const SizedBox(height: 24, width: 24, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 3))
                                : const Text("SUBMIT FEEDBACK", style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, letterSpacing: 1.1)),
                            ),
                          ],
                        ),
                      ),
                    ),

                    const SizedBox(height: 35),

                    const Padding(
                      padding: EdgeInsets.only(left: 4, bottom: 12),
                      child: Text(
                        "Hostel Reviews",
                        style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                      ),
                    ),

                    myFeedbacks.isEmpty
                        ? const Center(
                            child: Padding(
                              padding: EdgeInsets.only(top: 40),
                              child: Column(
                                children: [
                                  Icon(Icons.feedback_outlined, size: 60, color: Colors.grey),
                                  SizedBox(height: 16),
                                  Text("No feedback received yet", style: TextStyle(color: Colors.grey, fontSize: 16)),
                                ],
                              ),
                            ),
                          )
                        : ListView.builder(
                            shrinkWrap: true,
                            physics: const NeverScrollableScrollPhysics(),
                            itemCount: myFeedbacks.length,
                            itemBuilder: (context, index) {
                              var fb = myFeedbacks[index];
                              int r = fb["rating"];
                              return Card(
                                margin: const EdgeInsets.only(bottom: 12),
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                                child: ListTile(
                                  contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                                  leading: CircleAvatar(
                                    backgroundColor: getRatingColor(r).withOpacity(0.1),
                                    child: Text(r.toString(), style: TextStyle(color: getRatingColor(r), fontWeight: FontWeight.bold)),
                                  ),
                                  title: Text(
                                    "${fb["meal_slot"]?.toString().toUpperCase()} - ${fb["combo_name"]}",
                                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                                  ),
                                  subtitle: Padding(
                                    padding: const EdgeInsets.only(top: 4),
                                    child: Text(
                                      fb["comment"]?.isEmpty == true ? "No written review" : fb["comment"],
                                      style: TextStyle(color: fb["comment"]?.isEmpty == true ? Colors.grey : Colors.black87),
                                    ),
                                  ),
                                  trailing: Text(
                                    fb["created_at"].toString().substring(0, 10),
                                    style: const TextStyle(fontSize: 12, color: Colors.grey),
                                  ),
                                ),
                              );
                            },
                          ),
                    const SizedBox(height: 20),
                  ],
                ),
              ),
            ),
    );
  }
}