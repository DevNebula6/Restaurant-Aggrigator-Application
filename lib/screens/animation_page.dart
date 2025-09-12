import 'dart:async';

import 'package:app_links/app_links.dart';
import 'package:easibite/screens/launch_page.dart';
import 'package:flutter/material.dart';
import 'dart:math';

import 'package:shared_preferences/shared_preferences.dart';

import 'package:flutter/material.dart';
import 'dart:async'; // For Timer if needed

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      home: const AnimationPage(),
      debugShowCheckedModeBanner: false,
    );
  }
}

class AnimationPage extends StatefulWidget {
  const AnimationPage({super.key});

  @override
  _AnimationPageState createState() => _AnimationPageState();
}

class _AnimationPageState extends State<AnimationPage> with SingleTickerProviderStateMixin {
  late AnimationController _controller;

  @override
  void initState() {
    super.initState();

    // Set up AnimationController for timing (2 seconds to match original)
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 3), // Adjust to your GIF's duration if different
    );

    // Navigate when the "animation" (GIF) completes
    _controller.addStatusListener((status) {
      if (status == AnimationStatus.completed) {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (context) => const LaunchPage()), // Replace with your target page
        );
      }
    });

    // Start the controller (simulates GIF playtime)
    _controller.forward();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white, // Match your original background
      body: Center(
        child: Image.asset(
          'assets/front-t.gif', // Your GIF
          width: 900, // Adjust size as needed
          height: 1200,
          fit: BoxFit.contain, // Ensure GIF fits nicely
        ),
      ),
    );
  }
}
