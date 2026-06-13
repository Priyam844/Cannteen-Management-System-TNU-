import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_application_1/services/api_service.dart';
import 'package:flutter_application_1/pages/manager/manager_next_day_booking_page.dart';
import 'package:flutter_application_1/pages/admin/admin_event_page.dart';

class AdminDashboardPage extends StatefulWidget {
  const AdminDashboardPage({super.key});

  @override
  State<AdminDashboardPage> createState() => _AdminDashboardPageState();
}

class _AdminDashboardPageState extends State<AdminDashboardPage> {
  bool isLoading = true;
  Map dashboardData = {};
  Map analyticsData = {};
  final Color primaryMaroon = const Color.fromARGB(255, 152, 29, 68);

  @override
  void initState() {
    super.initState();
    _fetchData();
  }

  Future<void> _fetchData() async {
    setState(() => isLoading = true);
    try {
      final dashRes = await ApiService.get("/admin-dashboard/");
      final analRes = await ApiService.get("/analytics/");
      
      if (mounted) {
        setState(() {
          if (dashRes.statusCode == 200) dashboardData = jsonDecode(dashRes.body);
          if (analRes.statusCode == 200) analyticsData = jsonDecode(analRes.body);
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

  @override
  Widget build(BuildContext context) {
    if (isLoading) {
      return Center(child: CircularProgressIndicator(color: primaryMaroon));
    }

    final overview = analyticsData["overview"] ?? {};

    return RefreshIndicator(
      onRefresh: _fetchData,
      color: primaryMaroon,
      child: ListView(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
        children: [
          _buildSectionHeader("Institution Overview"),
          const SizedBox(height: 16),
          _buildStatGrid(overview),
          const SizedBox(height: 32),
          
          _buildSectionHeader("Popular Demand"),
          const SizedBox(height: 16),
          _buildDemandList("Top Items in Combos", analyticsData["top_items_in_combos"], Icons.fastfood_outlined),
          const SizedBox(height: 16),
          _buildDemandList("Top Individual Items", analyticsData["top_individual_items"], Icons.restaurant_menu),
          const SizedBox(height: 32),

          _buildSectionHeader("Planning & Future Prep"),
          const SizedBox(height: 16),
          _buildPlanningCard(),
          const SizedBox(height: 16),
          _buildEventCard(),
          const SizedBox(height: 32),
          
          _buildSectionHeader("Hostel Breakdown (Today)"),
          const SizedBox(height: 16),
          ...((dashboardData["hostels"] as List? ?? []).map((h) => _buildHostelCard(h))),
          const SizedBox(height: 32),
          
          _buildSectionHeader("Recent Feedback"),
          const SizedBox(height: 16),
          _buildFeedbackList(),
          const SizedBox(height: 24),
        ],
      ),
    );
  }

  Widget _buildPlanningCard() {
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [primaryMaroon.withOpacity(0.8), primaryMaroon],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: primaryMaroon.withOpacity(0.3),
            blurRadius: 15,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () {
            Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const ManagerNextDayBookingPage()),
            );
          },
          borderRadius: BorderRadius.circular(24),
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.2),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.event_note_rounded, color: Colors.white, size: 28),
                ),
                const SizedBox(width: 20),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        "Meal Preparation Insights",
                        style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        "View booking counts for tomorrow and day after.",
                        style: TextStyle(color: Colors.white.withOpacity(0.8), fontSize: 12),
                      ),
                    ],
                  ),
                ),
                const Icon(Icons.arrow_forward_ios_rounded, color: Colors.white, size: 18),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildEventCard() {
    return Container(
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF6A1B9A), Color(0xFF4527A0)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: Colors.purple.withOpacity(0.3),
            blurRadius: 15,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () {
            Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const AdminEventPage()),
            );
          },
          borderRadius: BorderRadius.circular(24),
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.2),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.stars_rounded, color: Colors.white, size: 28),
                ),
                const SizedBox(width: 20),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        "Institutional Event Guests",
                        style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        "Manage temporary passes for conferences & visits.",
                        style: TextStyle(color: Colors.white.withOpacity(0.8), fontSize: 12),
                      ),
                    ],
                  ),
                ),
                const Icon(Icons.arrow_forward_ios_rounded, color: Colors.white, size: 18),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildSectionHeader(String title) {
    return Row(
      children: [
        Container(
          width: 4,
          height: 24,
          decoration: BoxDecoration(
            color: primaryMaroon,
            borderRadius: BorderRadius.circular(2),
          ),
        ),
        const SizedBox(width: 12),
        Text(
          title,
          style: const TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.bold,
            color: Color(0xFF2D3142),
            letterSpacing: -0.5,
          ),
        ),
      ],
    );
  }

  Widget _buildStatGrid(Map overview) {
    return GridView.count(
      crossAxisCount: 2,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      mainAxisSpacing: 16,
      crossAxisSpacing: 16,
      childAspectRatio: 1.5,
      children: [
        _modernStatCard(
          "Ordered", 
          overview["total_ordered"]?.toString() ?? "0", 
          Icons.shopping_bag_rounded, 
          Colors.blue.shade600,
        ),
        _modernStatCard(
          "Delivered", 
          overview["total_delivered"]?.toString() ?? "0", 
          Icons.check_circle_rounded, 
          Colors.green.shade600,
        ),
        _modernStatCard(
          "Students", 
          dashboardData["total_students"]?.toString() ?? "0", 
          Icons.people_alt_rounded, 
          Colors.orange.shade700,
        ),
        _modernStatCard(
          "Rating", 
          "${dashboardData["overall_rating"] ?? 0}/5", 
          Icons.stars_rounded, 
          Colors.amber.shade700,
        ),
      ],
    );
  }

  Widget _modernStatCard(String title, String val, IconData icon, Color color) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: color.withOpacity(0.1),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: color.withOpacity(0.1),
                  shape: BoxShape.circle,
                ),
                child: Icon(icon, color: color, size: 20),
              ),
              Text(
                val,
                style: TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                  color: color,
                ),
              ),
            ],
          ),
          const Spacer(),
          Text(
            title,
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: Colors.grey.shade600,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDemandList(String title, dynamic data, IconData icon) {
    if (data == null || (data as List).isEmpty) return const SizedBox();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(left: 4, bottom: 8),
          child: Text(
            title,
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.bold,
              color: Colors.grey.shade500,
              letterSpacing: 0.5,
            ),
          ),
        ),
        SizedBox(
          height: 110,
          child: ListView.builder(
            scrollDirection: Axis.horizontal,
            physics: const BouncingScrollPhysics(),
            itemCount: (data as List).length,
            itemBuilder: (context, index) {
              final item = data[index];
              final name = item["combo__items__name"] ?? item["item__name"] ?? "Unknown";
              final count = item["count"] ?? 0;
              
              return Container(
                width: 140,
                margin: const EdgeInsets.only(right: 12, bottom: 4, top: 4),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: Colors.grey.shade100),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.02),
                      blurRadius: 5,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                padding: const EdgeInsets.all(12),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(icon, size: 18, color: primaryMaroon.withOpacity(0.6)),
                    const SizedBox(height: 6),
                    Text(
                      name,
                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                      textAlign: TextAlign.center,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 2),
                    Text(
                      count.toString(),
                      style: TextStyle(
                        fontSize: 18,
                        color: primaryMaroon,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                  ],
                ),
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _buildHostelCard(Map h) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 20,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(24),
        child: Column(
          children: [
            Container(
              padding: const EdgeInsets.all(16),
              color: primaryMaroon.withOpacity(0.03),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: primaryMaroon.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: Icon(Icons.apartment_rounded, color: primaryMaroon, size: 24),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          h["name"],
                          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 17, color: Color(0xFF2D3142)),
                        ),
                        Text(
                          "${h["students"]} Students • ${h["avg_rating"]}/5 Rating",
                          style: TextStyle(color: Colors.grey.shade600, fontSize: 13, fontWeight: FontWeight.w500),
                        ),
                      ],
                    ),
                  ),
                  _buildSurplusBadge(h["surplus_today"]),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 20),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceAround,
                children: [
                  _breakdownItem("Booked", h["bookings_today"].toString(), Colors.blue.shade700, Icons.event_note_rounded),
                  Container(width: 1, height: 40, color: Colors.grey.shade200),
                  _breakdownItem("Consumed", h["consumed_today"].toString(), Colors.green.shade700, Icons.restaurant_rounded),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSurplusBadge(dynamic surplus) {
    final int s = int.tryParse(surplus.toString()) ?? 0;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: s > 0 ? Colors.red.shade50 : Colors.green.shade50,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: s > 0 ? Colors.red.shade100 : Colors.green.shade100),
      ),
      child: Column(
        children: [
          Text(
            "SURPLUS",
            style: TextStyle(fontSize: 9, fontWeight: FontWeight.w900, color: s > 0 ? Colors.red.shade700 : Colors.green.shade700),
          ),
          Text(
            s.toString(),
            style: TextStyle(fontWeight: FontWeight.w900, fontSize: 18, color: s > 0 ? Colors.red.shade700 : Colors.green.shade700),
          ),
        ],
      ),
    );
  }

  Widget _breakdownItem(String label, String val, Color color, IconData icon) {
    return Row(
      children: [
        Icon(icon, size: 18, color: color.withOpacity(0.5)),
        const SizedBox(width: 10),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              val,
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: color, height: 1.1),
            ),
            Text(
              label,
              style: TextStyle(fontSize: 12, color: Colors.grey.shade600, fontWeight: FontWeight.w600),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildFeedbackList() {
    final feedbacks = dashboardData["recent_feedback"] as List? ?? [];
    if (feedbacks.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Text("No feedback received yet", style: TextStyle(color: Colors.grey.shade500)),
        ),
      );
    }

    return Column(
      children: feedbacks.map((fb) {
        final double rating = double.tryParse(fb["rating"].toString()) ?? 0;
        final Color ratingColor = rating >= 4 ? Colors.green : rating >= 3 ? Colors.orange : Colors.red;
        
        return Container(
          margin: const EdgeInsets.only(bottom: 12),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: Colors.grey.shade100),
          ),
          child: ListTile(
            contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            leading: Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                color: ratingColor.withOpacity(0.1),
                shape: BoxShape.circle,
              ),
              child: Center(
                child: Text(
                  rating.toStringAsFixed(1),
                  style: TextStyle(color: ratingColor, fontWeight: FontWeight.bold, fontSize: 16),
                ),
              ),
            ),
            title: Text(
              "${fb["meal_slot"]?.toString().toUpperCase()} - ${fb["combo_name"]}",
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: Color(0xFF2D3142)),
            ),
            subtitle: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SizedBox(height: 4),
                Text(
                  fb["comment"] ?? "No comment",
                  style: TextStyle(fontSize: 13, color: Colors.grey.shade700, fontStyle: FontStyle.italic),
                ),
                const SizedBox(height: 6),
                Row(
                  children: [
                    Icon(Icons.location_on_outlined, size: 12, color: Colors.grey.shade500),
                    const SizedBox(width: 4),
                    Text(
                      "${fb["hostel"]} • ${fb["meal_time"]}",
                      style: TextStyle(fontSize: 11, color: Colors.grey.shade500, fontWeight: FontWeight.w500),
                    ),
                  ],
                ),
              ],
            ),
          ),
        );
      }).toList(),
    );
  }
}
