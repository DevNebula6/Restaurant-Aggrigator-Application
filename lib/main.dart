import 'package:easibite/firebase_options.dart';
import 'package:easibite/screens/animation_page.dart';
import 'package:flutter/material.dart';
import 'package:get/get_navigation/src/root/get_material_app.dart';

import 'package:firebase_core/firebase_core.dart';

final RouteObserver<PageRoute> routeObserver = RouteObserver<PageRoute>();

void main() async  {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  runApp(const Easibite());
}

class Easibite extends StatelessWidget {
  const Easibite({super.key});

  @override
  Widget build(BuildContext context) {
    // final prefs = await SharedPreferences.getInstance();
    // await prefs.remove('userProfile');
    // await prefs.setBool('isLoggedIn', false);
    // await prefs.clear();
    // await prefs.setBool('isOnboarded', false);

    return GetMaterialApp(
      title: 'Easibite',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        primarySwatch: Colors.blue,
      ),
      home: AnimationPage(),
      navigatorObservers: [routeObserver], // ✅ Add RouteObserver
    );
  }
}
