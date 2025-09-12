import 'package:flutter/material.dart';

class MenuStats2 extends StatelessWidget {
  final int safeCount;
  final int cautionCount;
  final int avoidCount;

  const MenuStats2({
    super.key,
    this.safeCount = 0,
    this.cautionCount = 0,
    this.avoidCount = 0,
  });

  Widget buildStatCard(String label, int count, Color bgColor, Color textColor) {
    return Container(
      width: 90,
      height: 80,
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(
            '$count',
            style: TextStyle(
              fontSize: 19,
              fontWeight: FontWeight.bold,
              color: textColor,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            label,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.normal,
              color: textColor,
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        buildStatCard("Safe for All", safeCount, Colors.green[100]!, Colors.black87),
        const SizedBox(width: 12),
        buildStatCard("Some Can Eat", cautionCount, Colors.yellow[100]!, Colors.black87),
        const SizedBox(width: 12),
        buildStatCard("None Can Eat", avoidCount, Colors.red[100]!, Colors.black87),
      ],
    );
  }
}
