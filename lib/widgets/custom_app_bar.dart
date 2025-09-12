import 'package:easibite/screens/profile_page.dart';
import 'package:flutter/material.dart';
import 'dart:convert';

class CustomAppBar extends StatefulWidget implements PreferredSizeWidget {
  final dynamic user; // Replace with the actual user model
  final Map<String, dynamic>? userPreferences;
  final Function(int) setIndex;
  String ? groupName;

  CustomAppBar({Key? key, this.user, this.userPreferences, required this.setIndex, this.groupName}) : super(key: key);

  @override
  Size get preferredSize => Size.fromHeight(kToolbarHeight);

  @override
  _CustomAppBarState createState() => _CustomAppBarState();
}

class _CustomAppBarState extends State<CustomAppBar> {
  bool showAllPreferences = false;

  @override
  Widget build(BuildContext context) {
    print(widget.userPreferences);
    // Limiting to two types of preferences for preview in AppBar
    final List<String> dietaryPreferences =
    List<String>.from(widget.userPreferences?['dietary'] ?? []);
    final List<String> allergens =
    List<String>.from(widget.userPreferences?['allergens'] ?? []);

    final List<String> previewPreferences = [
      ...dietaryPreferences.take(1),
      ...allergens.take(1),
    ];

    return AppBar(
      elevation: 0,
      backgroundColor: Colors.white,
      foregroundColor: Colors.black,
      title: Row(
        children: [
          // User avatar
          if (widget.user != null)
            Padding(
              padding: const EdgeInsets.only(right: 10.0),
              child: CircleAvatar(
                radius: 23,
                backgroundImage: NetworkImage(
                  widget.user?.pictureUrl?.toString() ??
                      'https://www.example.com/default-avatar.png',
                ),
              ),
            ),
          Spacer(),
          if (widget.groupName != null)
            Text(widget.groupName!,style: TextStyle(fontSize: 30),),
            Spacer(),
          IconButton(
            onPressed: () {
              widget.setIndex(3);
            },
            icon: Icon(Icons.menu),
            iconSize: 30,
          ),
        ],
      ),
    );

  }
}
