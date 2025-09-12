import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

class CustomUIContainer extends StatelessWidget {

  final Map<String, dynamic>? userPreferences;
  final Map<String, dynamic> editablePreferences;

  const CustomUIContainer({
    Key? key,
    this.userPreferences,
    required this.editablePreferences
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    void _launchDialer(String number) async {
      final Uri url = Uri(scheme: 'tel', path: number);
      if (await canLaunchUrl(url)) {
        await launchUrl(url);
      } else {
        throw 'Could not launch dialer for $number';
      }
    }
    void _showCallDialog(BuildContext context, List<dynamic> numbers) {
      showDialog(
        context: context,
        builder: (BuildContext context) {
          return AlertDialog(
            title: Text("Choose number to call"),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: numbers.map((number) {
                  return ListTile(
                    title: Text(number),
                    leading: Icon(Icons.phone),
                    onTap: () {
                      Navigator.of(context).pop(); // Close the dialog
                      _launchDialer(number);
                    },
                  );
                }).toList(),
              ),
            ),
          );
        },
      );
    }
    print(userPreferences);
    return Container(
      padding: const EdgeInsets.all(16.0),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12.0),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withOpacity(0.2),
            blurRadius: 6.0,
            spreadRadius: 2.0,
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Section(
            title: "Avoid Ingredients",
            items: userPreferences?["allergens"],
            color: Colors.red.shade100,
          ),
          SizedBox(height: 16),
          Text(
            "Medical Information",
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),
          SizedBox(height: 8),
          Container(
            padding: const EdgeInsets.all(12.0),
            decoration: BoxDecoration(
              color: Colors.red.shade50,
              borderRadius: BorderRadius.circular(8.0),
              border: Border.all(color: Colors.red),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Row(
                      children: [
                        Icon(Icons.warning, color: Colors.red),
                        SizedBox(width: 8),
                        Text(
                          "Emergency Contacts",
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: Colors.red,
                          ),
                        ),
                      ],
                    ),
                    IconButton(
                      icon: Icon(Icons.phone, color: Colors.red),
                      onPressed: () {
                        _showCallDialog(context, editablePreferences['emergency']);
                      },
                    ),
                  ],
                ),
                SizedBox(height: 8),
                Wrap(
                  spacing: 10,
                  runSpacing: 10,
                  children: (editablePreferences['emergency'] as List).map((contact) {
                    return Chip(
                      label: Text(contact),
                    );
                  }).toList(),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class Section extends StatelessWidget {
  final String title;
  final List<dynamic> items;
  final Color color;

  const Section({
    required this.title,
    required this.items,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
          ),
        ),
        SizedBox(height: 8),
        Wrap(
          spacing: 8.0,
          runSpacing: 8.0,
          children: items.map((item) {
            return Container(
              padding:
              const EdgeInsets.symmetric(horizontal: 12.0, vertical: 8.0),
              decoration: BoxDecoration(
                color: color,
                borderRadius: BorderRadius.circular(20.0),
              ),
              child: Text(
                item,
                style: TextStyle(fontSize: 14),
              ),
            );
          }).toList(),
        ),
      ],
    );
  }
}
