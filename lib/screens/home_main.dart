// import 'package:auth0_flutter/auth0_flutter.dart';
// import 'package:easibite/screens/login_page.dart';
// import 'package:easibite/screens/onboarding_page.dart';
// import 'package:flutter/material.dart';
// import 'package:shared_preferences/shared_preferences.dart';



// class HomeMain extends StatefulWidget {
//   final UserProfile? user;  // Accept the UserProfile

//   HomeMain({Key? key, this.user});
//   @override
//   _HomeMainState createState() => _HomeMainState();
// }

// class _HomeMainState extends State<HomeMain> {
//   TextEditingController _searchController = TextEditingController();

//   late Auth0 auth0;
//   Future<void> _logout(BuildContext context) async {
//     auth0 = Auth0(
//       'easibites.us.auth0.com',
//       'bWF1PuPqEXqmIlsnl7ybbsFzUaWByFze',
//     );

//     await auth0.webAuthentication().logout(returnTo: 'com.example.easibite://easibites.us.auth0.com/android/com.example.easibite/callback');


//     final prefs = await SharedPreferences.getInstance();

//     // Remove user data from SharedPreferences
//     await prefs.remove('userProfile');
//     await prefs.setBool('isLoggedIn', false);

//     // Navigate to LoginPage
//     Navigator.pushReplacement(
//       context,
//       MaterialPageRoute(builder: (context) => const LoginPage()),
//     );
//   }

//   // Initialize Auth0 and authenticate
//   @override
//   void initState() {
//     super.initState();
//     print("ss4");
//   }
//   @override
//   Widget build(BuildContext context) {
//     return Scaffold(
//       appBar: AppBar(
//         title: Text('Home'),
//         actions: [
//           IconButton(
//             icon: Icon(Icons.exit_to_app), // Icon for logout button
//             onPressed: () => _logout(context), // Call logout method on press
//           ),
//         ],
//         automaticallyImplyLeading: false, // Hide the back button
//       ),
//       body: Column(
//         children: [
//           SizedBox(height: 30),
//           Padding(
//             padding: const EdgeInsets.all(16.0),
//             child: TextField(
//               controller: _searchController,
//               decoration: InputDecoration(
//                 hintText: 'Search restaurants or dishes..',
//                 prefixIcon: Icon(Icons.search),
//                 border: OutlineInputBorder(),
//               ),
//             ),
//           ),
//           if (widget.user != null) ...[
//             CircleAvatar(
//               radius: 50,
//               backgroundImage: NetworkImage(widget.user?.pictureUrl.toString() ?? 'https://www.example.com/default-avatar.png'),
//             ),
//             SizedBox(height: 16),
//             Text(
//               'Welcome, ${widget.user?.name ?? 'User'}!',
//               style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
//             ),
//             SizedBox(height: 16),
//             Text(
//               'Email: ${widget.user?.email ?? 'No email available'}',
//               style: TextStyle(fontSize: 18),
//             ),
//           ] ,
//           Expanded(
//             child: Container(
//               margin: const EdgeInsets.only(left: 10, right: 10, bottom: 10),
//               color: Color(0xFFEEEEEE),
//               child: Center(
//                 child: Text(
//                   'Content goes here',
//                   style: TextStyle(fontSize: 18),
//                 ),
//               ),
//             ),
//           ),
//         ],
//       ),
//       bottomNavigationBar: BottomAppBar(
//         color: Colors.white,
//         child: Row(
//           mainAxisAlignment: MainAxisAlignment.spaceEvenly,
//           children: [
//             TextButton(
//               onPressed: () {
//                 // Menu action
//               },
//               child: Text('Menu', style: TextStyle(fontSize: 16)),
//             ),
//             TextButton(
//               onPressed: () {
//                 // Search action
//               },
//               child: Text('Search', style: TextStyle(fontSize: 16)),
//             ),
//             // TextButton(
//             //   onPressed: () {
//             //     // Scan action
//             //   },
//             //   child: Text('Scan', style: TextStyle(fontSize: 16)),
//             // ),
//             TextButton(
//               onPressed: () async {
//                 final prefs = await SharedPreferences.getInstance();
//                 // await prefs.clear();

//                 await prefs.setBool('isOnboarded', false);
//                 Navigator.pushReplacement(
//                   context,
//                   MaterialPageRoute(builder: (context) => OnboardingScreen(user: widget.user,)),
//                 );
//                 ScaffoldMessenger.of(context).showSnackBar(
//                   const SnackBar(content: Text("All preferences cleared")),
//                 );
//               },
//               child: const Text(
//                 'Clear Preferences',
//                 style: TextStyle(fontSize: 16),
//               ),
//             ),
//           ],
//         ),
//       ),
//     );
//   }
// }
