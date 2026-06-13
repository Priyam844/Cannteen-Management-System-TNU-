import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_application_1/services/api_service.dart';
import 'package:intl/intl.dart';

class WalletHistoryPage extends StatefulWidget {
  const WalletHistoryPage({super.key});

  @override
  State<WalletHistoryPage> createState() => _WalletHistoryPageState();
}

class _WalletHistoryPageState extends State<WalletHistoryPage> {
  bool isLoading = true;
  List transactions = [];
  double currentBalance = 0.0;
  final Color primaryMaroon = const Color.fromARGB(255, 152, 29, 68);

  @override
  void initState() {
    super.initState();
    _fetchData();
  }

  Future<void> _fetchData() async {
    setState(() => isLoading = true);
    try {
      final res = await ApiService.get("/profile/");
      // Assuming we'll add a transactions endpoint or just fetch it here
      // For now, let's implement the backend view for /transactions/ if it doesn't exist
      final transRes = await ApiService.get("/transactions/");
      
      if (mounted) {
        setState(() {
          if (res.statusCode == 200) {
             currentBalance = double.tryParse(jsonDecode(res.body)["wallet_balance"].toString()) ?? 0.0;
          }
          if (transRes.statusCode == 200) {
             transactions = jsonDecode(transRes.body);
          }
          isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) setState(() => isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Wallet & Transactions"),
        backgroundColor: primaryMaroon,
        foregroundColor: Colors.white,
        elevation: 0,
      ),
      body: isLoading
          ? const Center(child: CircularProgressIndicator())
          : Column(
              children: [
                _buildBalanceHeader(),
                Expanded(
                  child: transactions.isEmpty
                      ? _buildEmptyState()
                      : ListView.builder(
                          padding: const EdgeInsets.all(16),
                          itemCount: transactions.length,
                          itemBuilder: (context, index) => _buildTransactionTile(transactions[index]),
                        ),
                ),
              ],
            ),
    );
  }

  Widget _buildBalanceHeader() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(32),
      decoration: BoxDecoration(
        color: primaryMaroon,
        borderRadius: const BorderRadius.only(bottomLeft: Radius.circular(32), bottomRight: Radius.circular(32)),
      ),
      child: Column(
        children: [
          const Text("Available Balance", style: TextStyle(color: Colors.white70, fontSize: 14)),
          const SizedBox(height: 8),
          Text("₹${currentBalance.toStringAsFixed(2)}", style: const TextStyle(color: Colors.white, fontSize: 36, fontWeight: FontWeight.bold)),
        ],
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.history_rounded, size: 64, color: Colors.grey.shade300),
          const SizedBox(height: 16),
          Text("No transactions yet", style: TextStyle(color: Colors.grey.shade500)),
        ],
      ),
    );
  }

  Widget _buildTransactionTile(Map tx) {
    bool isDebit = tx["transaction_type"] == 'debit';
    bool isRefund = tx["transaction_type"] == 'refund';
    
    Color amountColor = isDebit ? Colors.red : Colors.green;
    String prefix = isDebit ? "-" : "+";
    IconData icon = isDebit ? Icons.shopping_bag_rounded : (isRefund ? Icons.replay_circle_filled_rounded : Icons.add_circle_rounded);

    DateTime dt = DateTime.parse(tx["created_at"]);
    String dateStr = DateFormat('MMM d, yyyy • hh:mm a').format(dt);

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: amountColor.withOpacity(0.1),
          child: Icon(icon, color: amountColor, size: 20),
        ),
        title: Text(tx["description"] ?? "Transaction", style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
        subtitle: Text(dateStr, style: TextStyle(fontSize: 11, color: Colors.grey.shade600)),
        trailing: Text(
          "$prefix ₹${double.parse(tx["amount"].toString()).toStringAsFixed(2)}",
          style: TextStyle(color: amountColor, fontWeight: FontWeight.bold, fontSize: 16),
        ),
      ),
    );
  }
}
