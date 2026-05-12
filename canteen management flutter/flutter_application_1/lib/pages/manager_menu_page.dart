import 'dart:convert';
import 'package:flutter/material.dart';
import 'api_service.dart';

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
  /// 📅 WEEKLY MENU LOGIC
  ////////////////////////////////////////////////////////////
  void openEditSlotDialog(Map slot) {
    List<int> selectedComboIds = (slot["combos"] as List).map((c) => c["id"] as int).toList();

    showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              title: Text("Edit ${slot["slot"].toString().toUpperCase()}"),
              content: SizedBox(
                width: double.maxFinite,
                child: ListView.builder(
                  shrinkWrap: true,
                  itemCount: availableCombos.length,
                  itemBuilder: (context, index) {
                    final combo = availableCombos[index];
                    final bool isSelected = selectedComboIds.contains(combo["id"]);

                    // Filter combos by meal type matching the slot (optional but better UX)
                    // if (combo["meal_type"] != slot["slot"]) return const SizedBox.shrink();

                    return CheckboxListTile(
                      title: Text(combo["name"]),
                      subtitle: Text("${combo["meal_type"]} - ${combo["category"]}"),
                      value: isSelected,
                      onChanged: (val) {
                        setDialogState(() {
                          if (val == true) {
                            if (selectedComboIds.length < 2) {
                              selectedComboIds.add(combo["id"]);
                            } else {
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(content: Text("Max 2 combos allowed"))
                              );
                            }
                          } else {
                            selectedComboIds.remove(combo["id"]);
                          }
                        });
                      },
                    );
                  },
                ),
              ),
              actions: [
                TextButton(onPressed: () => Navigator.pop(context), child: const Text("Cancel")),
                ElevatedButton(
                  onPressed: () async {
                    final res = await ApiService.post("/update-meal-slot/", {
                      "slot_id": slot["id"],
                      "combo_ids": selectedComboIds
                    });
                    if (res.statusCode == 200) {
                      Navigator.pop(context);
                      fetchData();
                      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Menu updated")));
                    } else {
                      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Error: ${res.body}")));
                    }
                  },
                  child: const Text("Save"),
                )
              ],
            );
          },
        );
      },
    );
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
                TextField(controller: priceCtrl, decoration: const InputDecoration(labelText: "Price"), keyboardType: TextInputType.number),
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

  void deleteCombo(int id) async {
    final res = await ApiService.delete("/combos/?id=$id");
    if (res.statusCode == 200) {
      fetchData();
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Combo deactivated")));
    }
  }

  ////////////////////////////////////////////////////////////
  /// 🍎 ITEM LOGIC
  ////////////////////////////////////////////////////////////
  void openItemDialog({Map? item}) {
    final nameCtrl = TextEditingController(text: item?["name"] ?? "");
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

  void toggleItemStatus(Map item) async {
    final res = await ApiService.delete("/items/?id=${item["id"]}");
    if (res.statusCode == 200) {
      fetchData();
      final msg = jsonDecode(res.body)["message"];
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
    } else {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Error toggling status")));
    }
  }

  ////////////////////////////////////////////////////////////
  /// 🏗️ UI BUILD
  ////////////////////////////////////////////////////////////
  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 3,
      child: Scaffold(
        appBar: AppBar(
          title: const Text("Menu Management"),
          backgroundColor: const Color.fromARGB(255, 152, 29, 68),
          foregroundColor: Colors.white,
          bottom: const TabBar(
            labelColor: Colors.white,
            unselectedLabelColor: Colors.white70,
            indicatorColor: Colors.white,
            tabs: [
              Tab(text: "Weekly Menu", icon: Icon(Icons.calendar_month)),
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
                  dayData["day"],
                  style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Color.fromARGB(255, 152, 29, 68)),
                ),
              ),
              ... (dayData["slots"] as List).map((slot) => Card(
                margin: const EdgeInsets.only(bottom: 10),
                child: ListTile(
                  title: Text(slot["slot"].toString().toUpperCase(), style: const TextStyle(fontWeight: FontWeight.bold)),
                  subtitle: Text(
                    (slot["combos"] as List).isEmpty 
                      ? "No combos assigned" 
                      : (slot["combos"] as List).map((c) => c["name"]).join(", ")
                  ),
                  trailing: const Icon(Icons.edit, color: Colors.blue),
                  onTap: () => openEditSlotDialog(slot),
                ),
              )),
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
            subtitle: Text("${combo["meal_type"]} - ₹${combo["price"]}\nItems: ${(combo["items"] as List).map((i)=>i["name"]).join(", ")}"),
            isThreeLine: true,
            trailing: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                IconButton(icon: const Icon(Icons.edit, color: Colors.blue), onPressed: () => openComboDialog(combo: combo)),
                IconButton(icon: const Icon(Icons.delete, color: Colors.red), onPressed: () => deleteCombo(combo["id"])),
              ],
            ),
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
            subtitle: Text(item["description"] ?? ""),
            trailing: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                IconButton(icon: const Icon(Icons.edit, color: Colors.blue), onPressed: () => openItemDialog(item: item)),
                IconButton(
                  icon: Icon(isActive ? Icons.visibility : Icons.visibility_off, color: isActive ? Colors.green : Colors.orange), 
                  onPressed: () => toggleItemStatus(item)
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

