import 'package:flutter/material.dart';

class MenuStats extends StatelessWidget {
  final int safeCount;
  final int cautionCount;
  final int avoidCount;

  const MenuStats({
    super.key,
    this.safeCount = 0,
    this.cautionCount = 0,
    this.avoidCount = 0,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        // Safe Card
        Card(
          color: Colors.green[100], // Light green background
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12.0), // Rounded corners
          ),
          child: Container(
            width: 90,
            height: 80,
            padding: const EdgeInsets.all(12.0),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,

              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      Icons.star,
                      color: Colors.green[700], // Green star
                      size: 24.0,
                    ),
                    const SizedBox(width: 4.0),
                    Text(
                      '$safeCount',
                      style: TextStyle(
                        fontSize: 18.0,
                        fontWeight: FontWeight.bold,
                        color: Colors.green[700],
                      ),
                    ),
                  ],
                ),
                Text(
                  'Safe',
                  style: TextStyle(
                    fontSize: 14.0,
                    color: Colors.green[700],
                    fontWeight: FontWeight.bold
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(width: 8.0), // Spacing between cards
        // Caution Card
        Card(
          color: Colors.yellow[100], // Light yellow background
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12.0),
          ),
          child: Container(
            width: 90,
            height: 80,
            padding: const EdgeInsets.all(12.0),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      Icons.star,
                      color: Colors.yellow[800], // Orange star
                      size: 24.0,
                    ),
                    const SizedBox(width: 4.0),
                    Text(
                      '$cautionCount',
                      style: TextStyle(
                        fontSize: 18.0,
                        fontWeight: FontWeight.bold,
                        color: Colors.yellow[800],
                      ),
                    ),
                  ],
                ),
                Text(
                  'Caution',
                  style: TextStyle(
                    fontSize: 14.0,
                    color: Colors.yellow[800],
                    fontWeight: FontWeight.bold
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(width: 8.0), // Spacing between cards
        // Avoid Card
        Card(
          color: Colors.red[100], // Light red background
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12.0),
          ),
          child: Container(
            width: 90,
            height: 80,
            padding: const EdgeInsets.all(12.0),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      Icons.star,
                      color: Colors.red[700], // Red star
                      size: 24.0,
                    ),
                    const SizedBox(width: 4.0),
                    Text(
                      '$avoidCount',
                      style: TextStyle(
                        fontSize: 18.0,
                        fontWeight: FontWeight.bold,
                        color: Colors.red[700],
                      ),
                    ),
                  ],
                ),
                Text(
                  'Avoid',
                  style: TextStyle(
                    fontSize: 12.0,
                    color: Colors.red[700],
                    fontWeight: FontWeight.bold
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}