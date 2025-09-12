import 'package:auth0_flutter/auth0_flutter.dart';
import 'package:easibite/screens/MyProfilePage.dart';
import 'package:easibite/screens/group_invites.dart';
import 'package:easibite/screens/menuDatabase.dart';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'home_login.dart';

class ProfilePage extends StatefulWidget {
  final dynamic user; // Replace with the actual user model
  final Map<String, dynamic>? userPreferences;
  final Function(int) setIndex;
  final Future<void> Function() getUserPreferences;

  ProfilePage({Key? key, this.user, this.userPreferences, required this.setIndex, required this.getUserPreferences}) : super(key: key);

  @override
  _ProfilePageState createState() => _ProfilePageState();
}

class _ProfilePageState extends State<ProfilePage> {
  late Auth0 auth0;
  Map<String, dynamic> userPreferences2 = {};
  List<String> dietaryPreferences = [];
  List<String> allergens = [];

  @override
  void initState() {
    super.initState();
    // Initialize dietaryPreferences and allergens from widget.userPreferences
    dietaryPreferences = List<String>.from(widget.userPreferences?['dietary'] ?? []);
    allergens = List<String>.from(widget.userPreferences?['allergens'] ?? []);
  }

  Future<void> logout(BuildContext context) async {
    
    // Clear allergen cache before logout
    await _clearAllergenCache();


    auth0 = Auth0(
      'easibites.us.auth0.com',
      'bWF1PuPqEXqmIlsnl7ybbsFzUaWByFze',
    );

    await auth0.webAuthentication().logout(
      returnTo: 'com.example.easibite://easibites.us.auth0.com/android/com.example.easibite/callback',
    );

    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('userProfile');
    await prefs.setBool('isLoggedIn', false);

    Navigator.pushReplacement(
      context,
      MaterialPageRoute(builder: (context) => HomeLogin()),
    );
  }

  Future<void> _clearAllergenCache() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final keys = prefs.getKeys();
      
      for (String key in keys) {
        // Clear FoodCard allergen cache
        if (key.startsWith('foodCard_')) {
          await prefs.remove(key);
        }
        // Clear menu analysis cache
        else if (key.startsWith('analysis_')) {
          await prefs.remove(key);
        }
        // Clear individual user preference cache
        else if (key.startsWith('user_preference_')) {
          await prefs.remove(key);
        }
        // ✅ Clear saved restaurants (your current implementation)
        else if (key.startsWith('saved_restaurants')) {
          await prefs.remove(key);
        }
        // Clear restaurant statistics cache
        else if (key.startsWith('safeItemsCount_') ||
                key.startsWith('cautionCount_') ||
                key.startsWith('avoidCount_') ||
                key.startsWith('parsedData_')) {
          await prefs.remove(key);
        }
        // ✅ ADD: Clear menu cache
        else if (key.startsWith('menu_')) {
          await prefs.remove(key);
        }
        // ✅ ADD: Clear compatibility cache
        else if (key.startsWith('comp_percent_list')) {
          await prefs.remove(key);
        }
        // ✅ ADD: Clear restaurant cache
        else if (key == 'restaurants') {
          await prefs.remove(key);
        }
      }
      
      // Clear specific user data
      await prefs.remove('user_data');
      await prefs.remove('userPreferences');
      await prefs.remove('saved_restaurants');
      await prefs.remove('isOnboarded');
      
      print('✅ Cleared all user-specific cache on logout');
    } catch (e) {
      print('❌ Error clearing cache: $e');
    }
  }

  Future<void> updatePreferences({
    required dynamic dietary,
    required dynamic allergens,
  }) async {
    await widget.getUserPreferences();
    print("wuswr33");
    setState(() {
      dietaryPreferences = List<String>.from(dietary ?? []);
      this.allergens = List<String>.from(allergens ?? []);
    });
  }

  @override
  Widget build(BuildContext context) {

    final List<String> previewPreferences = [
      ...dietaryPreferences.take(1),
      ...allergens.take(1),
    ];
    return Scaffold(
      backgroundColor: Colors.white,
      body: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            SizedBox(height: 52,),
            // Profile Section
            Padding(
              padding: const EdgeInsets.all(16.0),
              child: Row(
                children: [
                  CircleAvatar(
                    radius: 36,
                    backgroundColor: Colors.grey[300],
                    child: Text(
                      widget.user.name.substring(0, 1).toUpperCase(),
                      style: TextStyle(fontSize: 24, color: Colors.orange),
                    ),
                  ),
                  SizedBox(width: 16),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        widget.user.name,
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      Text(
                        widget.user.email,
                        style: TextStyle(color: Colors.grey),
                      ),
                      // SizedBox(height: 8),
                      // Row(
                      //   // mainAxisAlignment: MainAxisAlignment.center,
                      //   children: previewPreferences.map((pref) {
                      //     return Container(
                      //       margin: EdgeInsets.symmetric(horizontal: 4),
                      //       padding: EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                      //       decoration: BoxDecoration(
                      //         color: Colors.orange[200],
                      //         border: Border.all(color: Colors.black38),
                      //         borderRadius: BorderRadius.circular(6),
                      //       ),
                      //       child: Text(
                      //         pref,
                      //         style: TextStyle(
                      //             color: Colors.black,
                      //             fontSize: 15
                      //         ),
                      //       ),
                      //     );
                      //   }).toList(),
                      // )
                    ],
                  )
                ],
              ),
            ),

            // Menu Buttons
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                _buildMenuButton(Icons.notifications, 'Invites',onTap: (){
                  Navigator.push(context, MaterialPageRoute(builder: (context) => GroupInvites(user: widget.user)));
                }),
                _buildMenuButton(Icons.group, 'My Groups',onTap: () {
                  widget.setIndex(1);
                },),
                _buildMenuButton(Icons.menu_book, 'Menu Database',onTap: (){
                  Navigator.push(context, MaterialPageRoute(builder: (context) => MenuDatabase(user: widget.user)));
                }),
              ],
            ),

            SizedBox(height: 20),

            // Menu Options
            _buildMenuOption(Icons.person, 'My Preferences'),
            // _buildMenuOption(Icons.shopping_bag, 'My Orders'),
            // _buildMenuOption(Icons.help, 'Help Center'),
            // _buildMenuOption(Icons.support_agent, 'Contact Support'),
            // _buildMenuOption(Icons.settings, 'Settings'),

            SizedBox(height: 20),

            // Logout Button
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16.0),
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.orange,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
                onPressed: () => logout(context),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.logout),
                    SizedBox(width: 8),
                    Text('Log Out'),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildChip(String label) {
    return Chip(
      label: Text(
        label,
        style: TextStyle(fontSize: 13), // Smaller font size
      ),
      padding: EdgeInsets.symmetric(horizontal: 2, vertical: 0), // Adjust padding
      backgroundColor: Colors.orange.shade100,
      materialTapTargetSize: MaterialTapTargetSize.shrinkWrap, // Reduces overall height
    );
  }


  Widget _buildMenuButton(IconData icon, String label, {VoidCallback? onTap}) {
    return GestureDetector(
      onTap: onTap,
      child: Column(
        children: [
          Icon(icon, size: 40, color: Colors.orange),
          SizedBox(height: 8),
          Text(label),
        ],
      ),
    );
  }

  Widget _buildMenuOption(IconData icon, String label) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
      child: ListTile(
        leading: Icon(icon, color: Colors.black),
        title: Text(label),
        onTap: () {
          if (label == "My Preferences"){
            Navigator.push(
              context,
              MaterialPageRoute(builder: (context) => MyProfilePage(user:widget.user ,userPreferences: widget.userPreferences,userPreferences2: userPreferences2, onUpdatePreferences: updatePreferences,)),
            );
          }
        },
      ),
    );
  }
}