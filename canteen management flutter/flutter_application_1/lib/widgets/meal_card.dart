import 'package:flutter/material.dart';

class MealCard extends StatelessWidget {
  final String mealName;
  final IconData icon;
  final String? selectedType;
  final VoidCallback onTap;
  final Color iconColor;

  const MealCard({
  super.key,
  required this.mealName,
  required this.icon,
  required this.onTap,
  required this.iconColor,
  this.selectedType,
});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Card(
        margin: const EdgeInsets.symmetric(horizontal: 10),
        child: Stack(
          children: [
            Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(icon, size: 50, color: const Color.fromARGB(255, 157, 12, 44)),
                  const SizedBox(height: 10),
                  Text(mealName, style: const TextStyle(fontSize: 18)),
                ],
              ),
            ),

            if (selectedType != null)
              Positioned(
                top: 10,
                right: 10,
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                  decoration: BoxDecoration(
                    color: Colors.green,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    selectedType!,
                    style: const TextStyle(
                        color: Colors.white, fontSize: 12),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}