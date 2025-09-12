import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;

import '../widgets/FoodCard.dart';

class MenuPage extends StatefulWidget {
  final int index;

  const MenuPage({Key? key, required this.index}) : super(key: key);

  @override
  _MenuPageState createState() => _MenuPageState();
}

class _MenuPageState extends State<MenuPage> {
  late Map<String, dynamic> restaurantMenu;
  bool isLoading = true;
  bool menuNotFound = false;

  @override
  void initState() {
    super.initState();
    fetchMenu(widget.index);
  }

  Future<void> fetchMenu(int index) async {
    try {
      final response = await http.get(Uri.parse('http://13.57.29.10:7000/menu/$index'));
      if (response.statusCode == 200) {
        setState(() {
          restaurantMenu = json.decode(response.body);
          isLoading = false;
          menuNotFound = false;
        });
      } else {
        throw Exception('Failed to load menu');
      }
    } catch (e) {
      setState(() {
        isLoading = false;
        menuNotFound = true;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('Menu')),
      body: Expanded(
        child: isLoading
            ? Center(child: CircularProgressIndicator()) // Show loading spinner
            : menuNotFound
            ? Center(
          child: Text(
            'Menu not found in the database',
            style: TextStyle(fontSize: 18, color: Colors.red),
            textAlign: TextAlign.center,
          ),
        )
            : ListView.builder(
          padding: const EdgeInsets.symmetric(horizontal: 16.0),
          itemCount: restaurantMenu['menu'].length,
          itemBuilder: (context, categoryIndex) {
            var category = restaurantMenu['menu'][categoryIndex];
            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Show category heading
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 8.0),
                  child: Text(
                    category['category'], // Category name
                    style: TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                // Loop over items in the category and show each item
                ...category['items'].map<Widget>((item) {
                  return FoodCard(
                    name: item['name'], // Item name
                    price: "\$${item['price']}", // Item price
                    tags: ["Vegetarian", "Contains Dairy"], // Add tags if necessary
                    allergenStatus: "Safe for most allergies", // Customize allergen status
                    allergenDetails: "Contains: Gluten, Dairy", // Add allergen details
                    modificationOptions:
                    "Request gluten-free crust  {+\$3} \n Ask for dairy-free cheese substitute", description: '',
                    link: '', // Add modification options
                  );
                }).toList(),
              ],
            );
          },
        ),
      ),
    );
  }
}
