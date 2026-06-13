import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_application_1/services/api_service.dart';

class ManagerMenuPage extends StatefulWidget {
  const ManagerMenuPage({super.key});

  @override
  State<ManagerMenuPage> createState() => _ManagerMenuPageState();
}

class _ManagerMenuPageState extends State<ManagerMenuPage> {
  bool isLoading = true;
  List weeklyMenu = [];
  List availableCombos = [];
  List allItems = [];

  @override
  void initState() {
    super.initState();
    fetchData();
  }

  Future<void> fetchData() async {
    setState(() => isLoading = true);
    try {
      final menuRes = await ApiService.get("/weekly-menu/");
      final comboRes = await ApiService.get("/combos/");
      final itemRes = await ApiService.get("/items/");

      if (menuRes.statusCode == 200 && comboRes.statusCode == 200 && itemRes.statusCode == 200) {
        setState(() {
          weeklyMenu = jsonDecode(menuRes.body)["data"];
          availableCombos = jsonDecode(comboRes.body);
          allItems = jsonDecode(itemRes.body);
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

  ////////////////////////////////////////////////////////////
  /// 🍱 COMBO LOGIC
  ////////////////////////////////////////////////////////////
  void openComboDialog({Map? combo}) {
    final nameCtrl = TextEditingController(text: combo?["name"] ?? "");
    final priceCtrl = TextEditingController(text: combo?["price"]?.toString() ?? "");
    final descCtrl = TextEditingController(text: combo?["description"] ?? "");
    
    String mealType = combo?["meal_type"] ?? "breakfast";
    String category = combo?["category"] ?? "veg";
    List<int> selectedItemIds = combo != null 
      ? (combo["items"] as List).map((i) => i["id"] as int).toList()
      : [];

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: Text(combo == null ? "Create New Combo" : "Edit Combo"),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(controller: nameCtrl, decoration: const InputDecoration(labelText: "Combo Name")),
                TextField(controller: priceCtrl, decoration: const InputDecoration(labelText: "Price (₹)"), keyboardType: TextInputType.number),
                TextField(controller: descCtrl, decoration: const InputDecoration(labelText: "Description")),
                
                const SizedBox(height: 10),
                const Text("Meal Type", style: TextStyle(fontWeight: FontWeight.bold)),
                DropdownButton<String>(
                  value: mealType,
                  isExpanded: true,
                  items: ["breakfast", "lunch", "snacks", "dinner"].map((s) => DropdownMenuItem(value: s, child: Text(s.toUpperCase()))).toList(),
                  onChanged: (val) => setDialogState(() => mealType = val!),
                ),
                
                const SizedBox(height: 10),
                const Text("Category", style: TextStyle(fontWeight: FontWeight.bold)),
                Row(
                  children: [
                    Radio(value: "veg", groupValue: category, onChanged: (v) => setDialogState(() => category = v as String)),
                    const Text("Veg"),
                    Radio(value: "nonveg", groupValue: category, onChanged: (v) => setDialogState(() => category = v as String)),
                    const Text("Non-Veg"),
                  ],
                ),

                const Divider(),
                const Text("Select Items", style: TextStyle(fontWeight: FontWeight.bold)),
                ...allItems.where((i) => i["is_active"] == true || selectedItemIds.contains(i["id"])).map((item) => CheckboxListTile(
                  title: Text(item["name"]),
                  value: selectedItemIds.contains(item["id"]),
                  onChanged: (v) {
                    setDialogState(() {
                      if (v!) selectedItemIds.add(item["id"]);
                      else selectedItemIds.remove(item["id"]);
                    });
                  },
                )).toList(),
              ],
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(context), child: const Text("Cancel")),
            ElevatedButton(
              onPressed: () async {
                final data = {
                  if (combo != null) "id": combo["id"],
                  "name": nameCtrl.text,
                  "price": double.tryParse(priceCtrl.text) ?? 0.0,
                  "description": descCtrl.text,
                  "meal_type": mealType,
                  "category": category,
                  "item_ids": selectedItemIds
                };

                final res = combo == null 
                  ? await ApiService.post("/combos/", data)
                  : await ApiService.put("/combos/", data);

                if (res.statusCode == 200 || res.statusCode == 201) {
                  Navigator.pop(context);
                  fetchData();
                } else {
                  ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Error: ${res.body}")));
                }
              },
              child: const Text("Save"),
            )
          ],
        ),
      ),
    );
  }

  ////////////////////////////////////////////////////////////
  /// 🍎 ITEM LOGIC
  ////////////////////////////////////////////////////////////
  void openItemDialog({Map? item}) {
    final nameCtrl = TextEditingController(text: item?["name"] ?? "");
    final priceCtrl = TextEditingController(text: item?["price"]?.toString() ?? "");
    final descCtrl = TextEditingController(text: item?["description"] ?? "");
    bool isVeg = item?["is_veg"] ?? true;
    bool isActive = item?["is_active"] ?? true;

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: Text(item == null ? "Add New Item" : "Edit Item"),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(controller: nameCtrl, decoration: const InputDecoration(labelText: "Item Name")),
              TextField(controller: priceCtrl, decoration: const InputDecoration(labelText: "Price (₹)"), keyboardType: TextInputType.number),
              TextField(controller: descCtrl, decoration: const InputDecoration(labelText: "Description")),
              SwitchListTile(
                title: const Text("Veg?"),
                value: isVeg,
                onChanged: (v) => setDialogState(() => isVeg = v),
              ),
              if (item != null)
                SwitchListTile(
                  title: const Text("Active?"),
                  value: isActive,
                  onChanged: (v) => setDialogState(() => isActive = v),
                ),
            ],
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(context), child: const Text("Cancel")),
            ElevatedButton(
              onPressed: () async {
                final data = {
                  if (item != null) "id": item["id"],
                  "name": nameCtrl.text,
                  "price": double.tryParse(priceCtrl.text) ?? 0.0,
                  "description": descCtrl.text,
                  "is_veg": isVeg,
                  "is_active": isActive,
                };

                final res = item == null 
                  ? await ApiService.post("/items/", data)
                  : await ApiService.put("/items/", data);

                if (res.statusCode == 200 || res.statusCode == 201) {
                  Navigator.pop(context);
                  fetchData();
                } else {
                  ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Error: ${res.body}")));
                }
              },
              child: const Text("Save"),
            )
          ],
        ),
      ),
    );
  }

  ////////////////////////////////////////////////////////////
  /// 📅 DAILY MENU OVERRIDE LOGIC
  ////////////////////////////////////////////////////////////
  void openDailyMenuDialog() {
    DateTime selectedDate = DateTime.now().add(const Duration(days: 1));
    String selectedSlot = "breakfast";
    List<int> selectedComboIds = [];
    List<int> selectedItemIds = [];

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: const Text("Set Daily Menu Override"),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                ListTile(
                  title: Text("Date: ${selectedDate.toString().split(' ')[0]}"),
                  trailing: const Icon(Icons.calendar_today),
                  onTap: () async {
                    final picked = await showDatePicker(
                      context: context,
                      initialDate: selectedDate,
                      firstDate: DateTime.now(),
                      lastDate: DateTime.now().add(const Duration(days: 30)),
                    );
                    if (picked != null) setDialogState(() => selectedDate = picked);
                  },
                ),
                DropdownButton<String>(
                  value: selectedSlot,
                  isExpanded: true,
                  items: ["breakfast", "lunch", "snacks", "dinner"].map((s) => DropdownMenuItem(value: s, child: Text(s.toUpperCase()))).toList(),
                  onChanged: (val) => setDialogState(() => selectedSlot = val!),
                ),
                const Divider(),
                const Text("Select Combos", style: TextStyle(fontWeight: FontWeight.bold)),
                ...availableCombos.map((combo) => CheckboxListTile(
                  title: Text(combo["name"]),
                  value: selectedComboIds.contains(combo["id"]),
                  onChanged: (v) {
                    setDialogState(() {
                      if (v!) selectedComboIds.add(combo["id"]);
                      else selectedComboIds.remove(combo["id"]);
                    });
                  },
                )).toList(),
                const Divider(),
                const Text("Select Standalone Items", style: TextStyle(fontWeight: FontWeight.bold)),
                ...allItems.map((item) => CheckboxListTile(
                  title: Text(item["name"]),
                  value: selectedItemIds.contains(item["id"]),
                  onChanged: (v) {
                    setDialogState(() {
                      if (v!) selectedItemIds.add(item["id"]);
                      else selectedItemIds.remove(item["id"]);
                    });
                  },
                )).toList(),
              ],
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(context), child: const Text("Cancel")),
            ElevatedButton(
              onPressed: () async {
                final res = await ApiService.post("/daily-menu/", {
                  "date": selectedDate.toString().split(' ')[0],
                  "slot": selectedSlot,
                  "combo_ids": selectedComboIds,
                  "item_ids": selectedItemIds,
                });
                if (res.statusCode == 200) {
                  Navigator.pop(context);
                  ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Daily override set!")));
                } else {
                   ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Error: ${res.body}")));
                }
              },
              child: const Text("Save Override"),
            )
          ],
        ),
      ),
    );
  }

  ////////////////////////////////////////////////////////////
  /// ⏰ MEAL SLOT EDIT LOGIC
  ////////////////////////////////////////////////////////////
  void openEditSlotDialog(Map slot) {
    List<int> selectedComboIds = (slot["combos"] as List).map((c) => c["id"] as int).toList();
    List<int> selectedItemIds = (slot["items"] as List).map((i) => i["id"] as int).toList();
    final String slotName = slot["slot"].toString();

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: Text("Edit ${slotName.toUpperCase()}"),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text("Assign Combos", style: TextStyle(fontWeight: FontWeight.bold)),
                ...availableCombos.where((c) => c["meal_type"] == slotName.toLowerCase()).map((combo) => CheckboxListTile(
                  title: Text(combo["name"]),
                  subtitle: Text("₹${combo["price"]}"),
                  value: selectedComboIds.contains(combo["id"]),
                  onChanged: (v) {
                    setDialogState(() {
                      if (v!) {
                        if (selectedComboIds.length < 2) selectedComboIds.add(combo["id"]);
                        else ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Max 2 combos allowed")));
                      } else {
                        selectedComboIds.remove(combo["id"]);
                      }
                    });
                  },
                )).toList(),
                const Divider(),
                const Text("Assign Standalone Items", style: TextStyle(fontWeight: FontWeight.bold)),
                ...allItems.where((i) => i["is_active"] == true).map((item) => CheckboxListTile(
                  title: Text(item["name"]),
                  subtitle: Text("₹${item["price"]}"),
                  value: selectedItemIds.contains(item["id"]),
                  onChanged: (v) {
                    setDialogState(() {
                      if (v!) selectedItemIds.add(item["id"]);
                      else selectedItemIds.remove(item["id"]);
                    });
                  },
                )).toList(),
              ],
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(context), child: const Text("Cancel")),
            ElevatedButton(
              onPressed: () async {
                final res = await ApiService.post("/update-meal-slot/", {
                   "slot_id": slot["id"],
                   "combo_ids": selectedComboIds,
                   "item_ids": selectedItemIds,
                });

                if (res.statusCode == 200) {
                  Navigator.pop(context);
                  fetchData();
                  ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Template updated successfully")));
                } else {
                  ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Error: ${res.body}")));
                }
              },
              child: const Text("Update Template"),
            )
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 3,
      child: Scaffold(
        appBar: AppBar(
          title: const Text("Menu Management"),
          backgroundColor: const Color.fromARGB(255, 152, 29, 68),
          foregroundColor: Colors.white,
          actions: [
            IconButton(
              icon: const Icon(Icons.today, color: Colors.white),
              onPressed: openDailyMenuDialog,
              tooltip: "Daily Override",
            )
          ],
          bottom: const TabBar(
            labelColor: Colors.white,
            unselectedLabelColor: Colors.white70,
            indicatorColor: Colors.white,
            tabs: [
              Tab(text: "Weekly", icon: Icon(Icons.calendar_month)),
              Tab(text: "Combos", icon: Icon(Icons.fastfood)),
              Tab(text: "Items", icon: Icon(Icons.restaurant)),
            ],
          ),
        ),
        body: isLoading
            ? const Center(child: CircularProgressIndicator())
            : TabBarView(
                children: [
                  _buildWeeklyMenuTab(),
                  _buildCombosTab(),
                  _buildItemsTab(),
                ],
              ),
        floatingActionButton: Builder(
          builder: (context) {
            return FloatingActionButton(
              onPressed: () {
                final tabIdx = DefaultTabController.of(context).index;
                if (tabIdx == 1) openComboDialog();
                if (tabIdx == 2) openItemDialog();
              },
              backgroundColor: const Color.fromARGB(255, 152, 29, 68),
              child: const Icon(Icons.add, color: Colors.white),
            );
          }
        ),
      ),
    );
  }

  Widget _buildWeeklyMenuTab() {
    return RefreshIndicator(
      onRefresh: fetchData,
      child: ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: weeklyMenu.length,
        itemBuilder: (context, index) {
          final dayData = weeklyMenu[index];
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 8.0),
                child: Text(
                  dayData["day"]?.toString() ?? "",
                  style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Color.fromARGB(255, 152, 29, 68)),
                ),
              ),
              ... (dayData["slots"] as List).map((slot) {
                final combos = slot["combos"] as List? ?? [];
                final items = slot["items"] as List? ?? [];
                
                return Card(
                  margin: const EdgeInsets.only(bottom: 10),
                  child: ListTile(
                    title: Text(slot["slot"].toString().toUpperCase(), style: const TextStyle(fontWeight: FontWeight.bold)),
                    subtitle: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text("Combos: ${combos.isEmpty ? 'None' : combos.map((c) => c['name']).join(', ')}"),
                        Text("Items: ${items.isEmpty ? 'None' : items.map((i) => i['name']).join(', ')}"),
                      ],
                    ),
                    isThreeLine: true,
                    trailing: IconButton(
                      icon: const Icon(Icons.edit_note, color: Colors.blue),
                      onPressed: () => openEditSlotDialog(slot),
                    ),
                  ),
                );
              }),
              const Divider(),
            ],
          );
        },
      ),
    );
  }

  Widget _buildCombosTab() {
    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: availableCombos.length,
      itemBuilder: (context, index) {
        final combo = availableCombos[index];
        return Card(
          child: ListTile(
            title: Text(combo["name"], style: const TextStyle(fontWeight: FontWeight.bold)),
            subtitle: Text("₹${combo["price"]} • ${combo["meal_type"]}\nItems: ${(combo["items"] as List).map((i)=>i["name"]).join(", ")}"),
            isThreeLine: true,
            trailing: IconButton(icon: const Icon(Icons.edit, color: Colors.blue), onPressed: () => openComboDialog(combo: combo)),
          ),
        );
      },
    );
  }

  Widget _buildItemsTab() {
    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: allItems.length,
      itemBuilder: (context, index) {
        final item = allItems[index];
        final bool isActive = item["is_active"] ?? true;
        return Card(
          color: isActive ? Colors.white : Colors.grey[200],
          child: ListTile(
            leading: Icon(Icons.circle, color: item["is_veg"] ? Colors.green : Colors.red, size: 12),
            title: Text(
              item["name"],
              style: TextStyle(
                decoration: isActive ? null : TextDecoration.lineThrough,
                color: isActive ? Colors.black : Colors.grey,
              ),
            ),
            subtitle: Text("₹${item["price"]} • ${item["description"] ?? ""}"),
            trailing: IconButton(icon: const Icon(Icons.edit, color: Colors.blue), onPressed: () => openItemDialog(item: item)),
          ),
        );
      },
    );
  }
}
