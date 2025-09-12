// import 'package:auth0_flutter/auth0_flutter.dart';
// import 'package:easibite/screens/home_login.dart';
// import 'package:easibite/screens/onboarding_page.dart';
// import 'package:easibite/screens/scan_menu_page.dart';
// import 'package:flutter/material.dart';
// import 'package:shared_preferences/shared_preferences.dart';

// import 'package:geolocator/geolocator.dart';

// class MenuScreen extends StatefulWidget {
//   final UserProfile? user;
//   MenuScreen({Key? key, this.user});

//   @override
//   _MenuScreenState createState() => _MenuScreenState();
// }

// class _MenuScreenState extends State<MenuScreen> {
//   late Auth0 auth0;
//   Position? _currentPosition;
//   bool _isLoading = true;  // Track loading state

//   @override
//   void initState() {
//     super.initState();
//     _getCurrentLocation();  // Call to fetch current location when the widget builds
//   }

//   Future<void> _getCurrentLocation() async {
//     // Check location permission
//     LocationPermission permission = await Geolocator.checkPermission();
//     if (permission == LocationPermission.denied) {
//       permission = await Geolocator.requestPermission();
//       if (permission == LocationPermission.deniedForever) {
//         // Handle the case when permissions are permanently denied
//         print('Location permissions are permanently denied.');
//         return;
//       }
//     }

//     // Get the current position
//     Position position = await Geolocator.getCurrentPosition(
//         desiredAccuracy: LocationAccuracy.high);

//     setState(() {
//       _currentPosition = position;
//       _isLoading = false;  // Set loading state to false once location is fetched
//     });

//     print('Latitude: ${position.latitude}, Longitude: ${position.longitude}');
//   }

//   Future<void> _logout(BuildContext context) async {
//     auth0 = Auth0(
//       'easibites.us.auth0.com',
//       'bWF1PuPqEXqmIlsnl7ybbsFzUaWByFze',
//     );

//     await auth0.webAuthentication().logout(
//         returnTo:
//         'com.example.easibite://easibites.us.auth0.com/android/com.example.easibite/callback');

//     final prefs = await SharedPreferences.getInstance();
//     await prefs.remove('userProfile');
//     await prefs.setBool('isLoggedIn', false);

//     Navigator.pushReplacement(
//       context,
//       MaterialPageRoute(builder: (context) => HomeLogin()),
//     );
//   }

//   @override
//   Widget build(BuildContext context) {
//     return Scaffold(
//       appBar: AppBar(
//         elevation: 0,
//         backgroundColor: Colors.white,
//         foregroundColor: Colors.black,
//         actions: [
//           TextButton(
//             onPressed: () async {
//               Navigator.pushReplacement(
//                 context,
//                 MaterialPageRoute(builder: (context) => ScanMenuPage()),
//               );
//             },
//             child: Text('Scan Menu', style: TextStyle(color: Colors.blue)),
//           ),
//           Spacer(),
//           TextButton(
//             onPressed: () async {
//               final prefs = await SharedPreferences.getInstance();
//               await prefs.setBool('isOnboarded', false);
//               Navigator.pushReplacement(
//                 context,
//                 MaterialPageRoute(builder: (context) => OnboardingScreen(user: widget.user)),
//               );
//               ScaffoldMessenger.of(context).showSnackBar(
//                 const SnackBar(content: Text("All preferences cleared")),
//               );
//             },
//             child: Text('Contribute', style: TextStyle(color: Colors.blue)),
//           ),
//           IconButton(
//             icon: Icon(Icons.exit_to_app),
//             onPressed: () => _logout(context),
//           ),
//         ],
//       ),
//       body: Padding(
//         padding: const EdgeInsets.all(16.0),
//         child: Column(
//           crossAxisAlignment: CrossAxisAlignment.start,
//           children: [
//             // Show loading indicator while fetching the location
//             if (!_isLoading)
//               Text('Current Location: Lat: ${_currentPosition!.latitude}, Lon: ${_currentPosition!.longitude}'),
//             // Search Box
//             TextField(
//               decoration: InputDecoration(
//                 hintText: 'Search menu, restaurant or etc',
//                 prefixIcon: Icon(Icons.search),
//                 suffixIcon: Icon(Icons.tune),
//                 border: OutlineInputBorder(
//                   borderRadius: BorderRadius.circular(8.0),
//                 ),
//               ),
//             ),
//             const SizedBox(height: 10),
//             Row(
//               mainAxisAlignment: MainAxisAlignment.spaceBetween,
//               children: [
//                 TextButton(
//                   onPressed: () {},
//                   child: Text('Verified', style: TextStyle(color: Colors.orange)),
//                 ),
//                 TextButton(
//                   onPressed: () {},
//                   child: Text('Recent', style: TextStyle(color: Colors.grey)),
//                 ),
//                 TextButton(
//                   onPressed: () {},
//                   child: Text('Popular', style: TextStyle(color: Colors.grey)),
//                 ),
//               ],
//             ),
//             const SizedBox(height: 10),
//             Expanded(
//               child: _isLoading
//                   ? Center(child: CircularProgressIndicator())
//                   : ListView(
//                 children: [
//                   for (int index = 0; index < 3; index++)
//                     Card(
//                       margin: const EdgeInsets.only(bottom: 16),
//                       elevation: 4,
//                       shape: RoundedRectangleBorder(
//                         borderRadius: BorderRadius.circular(8),
//                       ),
//                       child: Column(
//                         crossAxisAlignment: CrossAxisAlignment.start,
//                         children: [
//                           // Image Section
//                           ClipRRect(
//                             borderRadius: BorderRadius.vertical(top: Radius.circular(8)),
//                             child: Image.network(
//                               'https://www.top25restaurants.com/media/img/2024/11/dubai-best-restaurants-c%C3%A9-la-vi-asian-at-top-25-restaurants.jpg',
//                               fit: BoxFit.cover,
//                               height: 150,
//                               width: double.infinity,
//                               errorBuilder: (context, error, stackTrace) {
//                                 // Fallback widget when the image fails to load
//                                 return Container(
//                                   height: 150,
//                                   color: Colors.grey[300],
//                                   child: Center(
//                                     child: Icon(Icons.broken_image, color: Colors.grey, size: 50),
//                                   ),
//                                 );
//                               },
//                               loadingBuilder: (context, child, loadingProgress) {
//                                 if (loadingProgress == null) return child;
//                                 return Container(
//                                   height: 150,
//                                   color: Colors.grey[200],
//                                   child: Center(
//                                     child: CircularProgressIndicator(
//                                       value: loadingProgress.expectedTotalBytes != null
//                                           ? loadingProgress.cumulativeBytesLoaded /
//                                           (loadingProgress.expectedTotalBytes ?? 1)
//                                           : null,
//                                     ),
//                                   ),
//                                 );
//                               },
//                             ),
//                           ),
//                           // Info Section
//                           Padding(
//                             padding: const EdgeInsets.all(12.0),
//                             child: Column(
//                               crossAxisAlignment: CrossAxisAlignment.start,
//                               children: [
//                                 Row(
//                                   children: [
//                                     Icon(Icons.location_on_outlined, size: 16),
//                                     const SizedBox(width: 4),
//                                     Text('1.1 miles away'),
//                                   ],
//                                 ),
//                                 const SizedBox(height: 8),
//                                 Text(
//                                   'Restaurant ${index + 1}',
//                                   style: TextStyle(
//                                     fontSize: 16,
//                                     fontWeight: FontWeight.bold,
//                                   ),
//                                 ),
//                                 const SizedBox(height: 4),
//                                 Text('In Database 95%'),
//                                 const SizedBox(height: 8),
//                                 Row(
//                                   mainAxisAlignment: MainAxisAlignment.spaceBetween,
//                                   children: [
//                                     Text('86 Items | 12 Categories'),
//                                     Text(
//                                       '\$XXX For Two',
//                                       style: TextStyle(color: Colors.grey),
//                                     ),
//                                   ],
//                                 ),
//                                 const SizedBox(height: 8),
//                                 Row(
//                                   children: [
//                                     Icon(Icons.star, color: Colors.orange),
//                                     Text('4.1'),
//                                   ],
//                                 ),
//                               ],
//                             ),
//                           ),
//                         ],
//                       ),
//                     ),

//                   // Recent Contributions Section
//                   const SizedBox(height: 16),
//                   Text('Recent Contributions',
//                       style: TextStyle(
//                           fontSize: 16, fontWeight: FontWeight.bold)),
//                   const SizedBox(height: 8),
//                   Column(
//                     children: [
//                       ListTile(
//                         leading: CircleAvatar(child: Text('U1')),
//                         title: Text('Updated menu for Restaurant 1'),
//                         subtitle: Text('Added 15 new items'),
//                       ),
//                       ListTile(
//                         leading: CircleAvatar(child: Text('U2')),
//                         title: Text('Updated menu for Restaurant 2'),
//                         subtitle: Text('Added 15 new items'),
//                       ),
//                     ],
//                   ),
//                   const SizedBox(height: 16),

//                   // Contribution Button
//                   TextButton(
//                     onPressed: () {},
//                     child: Text(
//                       'Help improve our database by contributing menu information and verifying existing entries',
//                       style: TextStyle(color: Colors.blue),
//                       textAlign: TextAlign.center,
//                     ),
//                   ),
//                 ],
//               ),
//             ),
//           ],
//         ),
//       ),
//     );
//   }
// }
