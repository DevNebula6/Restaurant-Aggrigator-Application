// import 'dart:convert';
// import 'package:auth0_flutter/auth0_flutter.dart';
// import 'package:easibite/screens/error_page.dart';
// import 'package:easibite/screens/home_screen.dart';
// import 'package:firebase_auth/firebase_auth.dart';
// import 'package:flutter/material.dart';
// import 'package:google_sign_in/google_sign_in.dart';
// import 'package:http/http.dart' as http show get;
// import 'package:shared_preferences/shared_preferences.dart';
// import 'onboarding_page.dart';

// class LoginPage extends StatefulWidget {
//   const LoginPage({super.key});

//   @override
//   _LoginPageState createState() => _LoginPageState();
// }

// class _LoginPageState extends State<LoginPage> {
//   String errorMessage = '';
//   UserProfile? _user;
//   Credentials? _credentials;
//   bool _isLoading = false;

//   late Auth0 auth0;
//   final _emailController = TextEditingController();
//   final _passwordController = TextEditingController();

//   final String correctEmail = "user@easibite.com";
//   final String correctPassword = "password123";

//   Future<void> _login() async {
//     final email = _emailController.text;
//     final password = _passwordController.text;

//     if (email == correctEmail && password == correctPassword) {
//       final prefs = await SharedPreferences.getInstance();
//       await prefs.setBool('isLoggedIn', true);
//       setState(() {
//         _isLoading = false;
//       });

//       // Call onboarding completion check
//       _checkOnboardingCompletion();
//     } else {
//       ScaffoldMessenger.of(context).showSnackBar(
//         const SnackBar(content: Text("Invalid email or password")),
//       );
//     }
//   }

//   Future<void> _handleGoogleSignIn(BuildContext context) async {
//     try {
//       setState(() {
//         _isLoading = true;
//       });
      
//       auth0 = Auth0(
//         'easibites.us.auth0.com',
//         'bWF1PuPqEXqmIlsnl7ybbsFzUaWByFze',
//       );

//       final credentials = await auth0.webAuthentication().login(
//         redirectUrl: 'com.example.easibite://easibites.us.auth0.com/android/com.example.easibite/callback'
//       );

//       setState(() {
//         _credentials = credentials;
//         _user = credentials.user;
//       });
      
//       final prefs = await SharedPreferences.getInstance();
//       await _saveUserDataToLocal();
//       await prefs.setBool('isLoggedIn', true);
      
//       // Load user preferences from backend
//       if (_user?.email != null) {
//         final isOnboarded = await _loadUserPreferencesAndCheckOnboarding(_user!.email!);
        
//         setState(() {
//           _isLoading = false;
//         });
        
//         if (isOnboarded) {
//           // User has preferences, go to home
//           Navigator.pushReplacement(
//             context,
//             MaterialPageRoute(builder: (context) => HomeScreen(user: _user!)),
//           );
//         } else {
//           // User needs onboarding
//           Navigator.pushReplacement(
//             context,
//             MaterialPageRoute(builder: (context) => OnboardingScreen(user: _user)),
//           );
//         }
//       } else {
//         setState(() {
//           _isLoading = false;
//         });
//         // Handle error case
//         Navigator.pushReplacement(
//           context,
//           MaterialPageRoute(builder: (context) => OnboardingScreen(user: _user)),
//         );
//       }
      
//     } catch (e) {
//       print('Error during login: $e');
//       setState(() {
//         _isLoading = false;
//       });
      
//       Navigator.pushReplacement(
//         context,
//         MaterialPageRoute(
//           builder: (context) => ErrorPage(
//             errorMessage: "Error during login: $e",
//             onRetry: () => _handleGoogleSignIn(context),
//           ),
//         ),
//       );
//     }
//   }
//   final FirebaseAuth _auth = FirebaseAuth.instance;
//   final GoogleSignIn _googleSignIn = GoogleSignIn();
//   Future<void> _signInWithGoogle() async {
//     try {
//       print("222");
//       final GoogleSignInAccount? googleUser = await _googleSignIn.signIn();
//       final GoogleSignInAuthentication? googleAuth =
//       await googleUser?.authentication;

//       final credential = GoogleAuthProvider.credential(
//         accessToken: googleAuth?.accessToken,
//         idToken: googleAuth?.idToken,
//       );

//       final UserCredential userCredential =
//       await _auth.signInWithCredential(credential);
//       print("999");
//       print(userCredential.user!.displayName);
//       // setState(() {
//       //   _credentials = userCredential;
//       //   _user = userCredential.user;
//       // });

//     } catch (e) {
//       print(e);
//       return null;
//     }
//   }


//   Future<void> _saveUserDataToLocal() async {
//     final prefs = await SharedPreferences.getInstance();
//     final userJson = jsonEncode({
//       'name': _user?.name ?? '',
//       'email': _user?.email ?? '',
//       'profileUrl': _user?.profileUrl?.toString() ?? '',
//       'picture': _user?.pictureUrl?.toString() ?? '',
//       'nickname': _user?.nickname ?? '',
//       'givenName': _user?.givenName ?? '',
//       'familyName': _user?.familyName ?? '',
//       'locale': _user?.locale ?? '',
//       'sub': _user?.sub ?? '',
//     });

//     await prefs.setString('userProfile', userJson);
//     await prefs.setBool('isLoggedIn', true);
//     print("User data saved locally");
//   }

//   // Method to fetch user preferences from backend
//   Future<Map<String, dynamic>?> _fetchUserPreferencesFromBackend(String email) async {
//     try {
//       print("Fetching user preferences from backend for: $email");
      
//       final response = await http.get(
//         Uri.parse("http://13.57.29.10:7000/users/$email"),
//         headers: {"Content-Type": "application/json"},
//       ).timeout(Duration(seconds: 30));
      
//       print("Backend response status: ${response.statusCode}");
//       print("Backend response body: ${response.body}");
      
//       if (response.statusCode == 200) {
//         final data = jsonDecode(response.body);
        
//         // Handle backend's inconsistent response format
//         if (data['status'] == 'error' || data['code'] == 404) {
//           print("User not found in backend");
//           return null;
//         }
        
//         if (data['data'] != null && data['data'].isNotEmpty) {
//           final userData = data['data'][0];
          
//           // Check if user has completed onboarding
//           if (userData['onboardingCompleted'] == true) {
//             return {
//               'dietary': userData['dietary'] ?? [],
//               'allergens': userData['allergens'] ?? [],
//               'spiceLevel': userData['spiceLevel'] ?? 'Medium',
//               'foodTemperature': userData['foodTemperature'] ?? 'Hot',
//               'emergency': userData['emergency'] ?? [],
//               'notes': userData['additionalNotes'] ?? '',
//             };
//           } else {
//             print("User exists but hasn't completed onboarding");
//             return null;
//           }
//         }
//       }
      
//       print("Failed to fetch user preferences: ${response.statusCode}");
//       return null;
//     } catch (e) {
//       print("Error fetching user preferences: $e");
//       return null;
//     }
//   }

//   // Method to save preferences to local cache
//   Future<void> _savePreferencesToLocalCache(Map<String, dynamic> preferences) async {
//     try {
//       final prefs = await SharedPreferences.getInstance();
//       await prefs.setString('userPreferences', jsonEncode(preferences));
//       await prefs.setBool('isOnboarded', true);
      
//       print("User preferences cached locally: ${jsonEncode(preferences)}");
//     } catch (e) {
//       print("Error caching user preferences: $e");
//     }
//   }

//   // Combined method to check user status and preferences
//   Future<bool> _loadUserPreferencesAndCheckOnboarding(String email) async {
//     try {
//       // Fetch preferences from backend
//       final preferences = await _fetchUserPreferencesFromBackend(email);
      
//       if (preferences != null) {
//         // User has completed onboarding, save to cache
//         await _savePreferencesToLocalCache(preferences);
//         return true; // User is fully onboarded
//       } else {
//         // User needs onboarding or doesn't exist
//         return false;
//       }
//     } catch (e) {
//       print("Error loading user preferences: $e");
//       return false;
//     }
//   }
//   @override
//   Widget build(BuildContext context) {
//     return _isLoading
//         ? LoadingScreen()
//         : EasiBiteUI(
//       onLoginPressed: _handleGoogleSignIn,
//       emailController: _emailController,
//       passwordController: _passwordController,
//       loginFunction: _login,
//       signInWithGoogle: _signInWithGoogle,
//     );
//   }
// }

// class LoadingScreen extends StatelessWidget {
//   @override
//   Widget build(BuildContext context) {
//     return Scaffold(
//       body: Center(
//         child: CircularProgressIndicator(color: Colors.orange),
//       ),
//     );
//   }
// }

import 'package:flutter/material.dart';

class EasiBiteUI extends StatelessWidget {
  final Function(BuildContext) onLoginPressed;
  final TextEditingController emailController;
  final TextEditingController passwordController;
  final VoidCallback loginFunction;
  final VoidCallback signInWithGoogle;

  const EasiBiteUI({
    Key? key,
    required this.onLoginPressed,
    required this.emailController,
    required this.passwordController,
    required this.loginFunction,
    required this.signInWithGoogle,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // Logo and text components
            Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                children: [
                  TextField(
                    controller: emailController,
                    decoration: const InputDecoration(
                      labelText: "Email",
                      border: OutlineInputBorder(),
                    ),
                    keyboardType: TextInputType.emailAddress,
                  ),
                  const SizedBox(height: 16),
                  TextField(
                    controller: passwordController,
                    decoration: const InputDecoration(
                      labelText: "Password",
                      border: OutlineInputBorder(),
                    ),
                    obscureText: true,
                  ),
                  const SizedBox(height: 16),
                  ElevatedButton(
                    onPressed: loginFunction,
                    child: const Text("Login"),
                  ),
                  const SizedBox(height: 20,),
                  ElevatedButton(
                    onPressed: () => onLoginPressed(context),

                    child: Text("Sign in with Google"),
                  ),
                ],
              ),
            ),
            // Buttons
            // Uncommented buttons
            // Row(
            //   mainAxisAlignment: MainAxisAlignment.center,
            //   children: [
            //     OutlinedButton(
            //       onPressed: () {},
            //       child: const Text("Log In"),
            //     ),
            //     const SizedBox(width: 20),
            //     ElevatedButton(
            //       onPressed: () {},
            //       child: const Text("Sign Up"),
            //     ),
            //   ],
            // ),
          ],
        ),
      ),
    );
  }
}
