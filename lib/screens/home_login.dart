import 'package:auth0_flutter/auth0_flutter.dart';
import 'package:easibite/screens/error_page.dart';
import 'package:easibite/screens/onboarding_page.dart';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:http/http.dart' as http; 

import 'home_screen.dart';
import 'dart:convert';

class HomeLogin extends StatefulWidget {
  @override
  _HomeLoginState createState() => _HomeLoginState();
}

class _HomeLoginState extends State<HomeLogin> {
  String errorMessage = '';
  UserProfile? _user;
  Credentials? _credentials;
  bool _isLoading = false;
  bool _isDoingSignup = false;
  late Auth0 auth0;
  
  // Method to fetch user preferences from backend
  Future<Map<String, dynamic>?> _fetchUserPreferencesFromBackend(String email) async {
    try {
      print("Fetching user preferences from backend for: $email");
      
      final response = await http.get(
        Uri.parse("http://13.57.29.10:7000/users/$email"),
        headers: {"Content-Type": "application/json"},
      ).timeout(Duration(seconds: 30));
      
      print("Backend response status: ${response.statusCode}");
      print("Backend response body: ${response.body}");
      
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        
        // Handle backend's inconsistent response format
        if (data['status'] == 'error' || data['code'] == 404) {
          print("User not found in backend");
          return null;
        }
        
        if (data['data'] != null && data['data'].isNotEmpty) {
          final userData = data['data'][0];
          
          // Check if user has completed onboarding
          if (userData['onboardingCompleted'] == true) {
            return {
              'dietary': userData['dietaryPreferences'] ?? [],
              'allergens': userData['allergens'] ?? [],
              'spiceLevel': userData['spiceLevel'] ?? 'Medium',
              'foodTemperature': userData['foodTemperature'] ?? 'Hot',
              'emergency': userData['emergency'] ?? [],
              'notes': userData['additionalNotes'] ?? '',
            };
          } else {
            print("User exists but hasn't completed onboarding");
            return null;
          }
        }
      }
      
      print("Failed to fetch user preferences: ${response.statusCode}");
      return null;
    } catch (e) {
      print("Error fetching user preferences: $e");
      return null;
    }
  }

  // Method to save preferences to local cache
  Future<void> _savePreferencesToLocalCache(Map<String, dynamic> preferences) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('userPreferences', jsonEncode(preferences));
      await prefs.setBool('isOnboarded', true);
      
      print("User preferences cached locally: ${jsonEncode(preferences)}");
    } catch (e) {
      print("Error caching user preferences: $e");
    }
  }

  // Combined method to check user status and preferences
  Future<bool> _loadUserPreferencesAndCheckOnboarding(String email) async {
    try {
      // Fetch preferences from backend
      final preferences = await _fetchUserPreferencesFromBackend(email);
      
      if (preferences != null) {
        // User has completed onboarding, save to cache
        await _savePreferencesToLocalCache(preferences);
        return true; // User is fully onboarded
      } else {
        // User needs onboarding or doesn't exist
        return false;
      }
    } catch (e) {
      print("Error loading user preferences: $e");
      return false;
    }
  }

  Future<void> _handleGoogleSignIn(BuildContext context) async {
    try {
      setState(() {
        _isLoading = true;
      });

      auth0 = Auth0(
        'easibites.us.auth0.com',
        'bWF1PuPqEXqmIlsnl7ybbsFzUaWByFze',
      );

      final credentials = await auth0.webAuthentication().login(
        redirectUrl: 'com.example.easibite://easibites.us.auth0.com/android/com.example.easibite/callback',
      );

      print('Access Token: ${credentials.accessToken}');
      print('ID Token: ${credentials.idToken}');

      setState(() {
        _credentials = credentials;
        _user = credentials.user;
      });

      final prefs = await SharedPreferences.getInstance();
      await _saveUserDataToLocal();
      await prefs.setBool('isLoggedIn', true);

      // Load user preferences from backend before navigation
      if (_user?.email != null) {
        final isOnboarded = await _loadUserPreferencesAndCheckOnboarding(_user!.email!);
        
        setState(() {
          _isLoading = false;
        });
        
        if (_isDoingSignup) {
          // User clicked Sign Up - always go to onboarding
          setState(() {
            _isDoingSignup = false;
          });
          Navigator.pushReplacement(
            context,
            MaterialPageRoute(builder: (context) => OnboardingScreen(user: credentials.user)),
          );
        } else {
          // User clicked Log In - check if they have preferences
          if (isOnboarded) {
            // User has preferences, go to home
            Navigator.pushReplacement(
              context,
              MaterialPageRoute(builder: (context) => HomeScreen(user: _user!)),
            );
          } else {
            // User needs onboarding
            Navigator.pushReplacement(
              context,
              MaterialPageRoute(builder: (context) => OnboardingScreen(user: _user)),
            );
          }
        }
      } else {
        setState(() {
          _isLoading = false;
        });
        // Handle error case
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (context) => OnboardingScreen(user: _user)),
        );
      }
      
    } catch (e) {
      print('Error during login: $e');
      setState(() {
        _isLoading = false;
      });

      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder: (context) => ErrorPage(
            errorMessage: "Error during login: $e",
            onRetry: () => _handleGoogleSignIn(context),
          ),
        ),
      );
    }
  }

  // ✅ REMOVE THE OLD _checkOnboardingCompletion METHOD
  // (No longer needed since we handle this in _handleGoogleSignIn)

  // Keep all other existing methods unchanged...
  Future<void> _handleSignup(BuildContext context) async {
    setState(() {
      _isDoingSignup = true;
    });
    final prefs = await SharedPreferences.getInstance();

    bool? isLogin = prefs.getBool('isLoggedIn') ?? false;
    if (isLogin) {
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (context) => OnboardingScreen(user: _user)),
      );
    } else {
      _handleGoogleSignIn(context);
    }
  }

  Future<void> _takeToBoarding() async {
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(builder: (context) => OnboardingScreen(user: _user)),
    );
  }

  Future<void> _saveUserDataToLocal() async {
    final prefs = await SharedPreferences.getInstance();
    final userJson = jsonEncode({
      'name': _user?.name ?? '',
      'email': _user?.email ?? '',
      'profileUrl': _user?.profileUrl?.toString() ?? '',
      'picture': _user?.pictureUrl?.toString() ?? '',
      'nickname': _user?.nickname ?? '',
      'givenName': _user?.givenName ?? '',
      'familyName': _user?.familyName ?? '',
      'locale': _user?.locale ?? '',
      'sub': _user?.sub ?? '',
    });

    await prefs.setString('userProfile', userJson);
    await prefs.setBool('isLoggedIn', true);
    print("User data saved locally");
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // Circle Logo with Bite (We will use a custom clipper for the bite effect)
            CircleWithBite(),

            SizedBox(height: 20),

            // Welcome Text
            Text(
              'Welcome to',
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
                color: Colors.black,
              ),
            ),

            // Easibite Text
            Text(
              'EasiBite',
              style: TextStyle(
                fontSize: 40,
                fontWeight: FontWeight.bold,
                color: Colors.orange,
              ),
            ),

            SizedBox(height: 10),

            // Subtitle Text
            Text(
              'Let’s personalize your dining experience',
              style: TextStyle(
                fontSize: 16,
                color: Colors.grey,
              ),
            ),

            SizedBox(height: 50),

            // Log In and Sign Up buttons
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                OutlinedButton(
                  style: OutlinedButton.styleFrom(
                    padding: EdgeInsets.symmetric(horizontal: 30, vertical: 15),
                    side: BorderSide(color: Colors.orange),
                  ),
                  onPressed: () => _handleGoogleSignIn(context),
                  child: Text(
                    'Log In',
                    style: TextStyle(
                      color: Colors.orange,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                SizedBox(width: 20),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    padding: EdgeInsets.symmetric(horizontal: 30, vertical: 15),
                    backgroundColor: Colors.orange, // Sign Up button color
                  ),
                  onPressed: () => _handleSignup(context),
                  child: Text(
                    'Sign Up',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

// Custom circle widget with bite effect
class CircleWithBite extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Stack(
      alignment: Alignment.center,
      children: [
        ClipPath(
          clipper: BiteClipper(),
          child: Container(
            width: 200,
            height: 200,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: Colors.orange,
            ),
          ),
        ),
        Text(
          'EasiBite',
          style: TextStyle(
            fontSize: 33,
            fontWeight: FontWeight.bold,
            color: Colors.white,
          ),
        ),
      ],
    );
  }
}

// Custom Clipper to create bite effect on the circle
class BiteClipper extends CustomClipper<Path> {
  @override
  Path getClip(Size size) {
    var path = Path();
    path.addOval(Rect.fromCircle(center: Offset(size.width / 2, size.height / 2), radius: size.width / 2));

    // Add bite shape (using two small circles for bite effect)
    path.addOval(Rect.fromCircle(center: Offset(size.width * 0.8, size.height * 0.2), radius: size.width * 0.15));

    return path;
  }

  @override
  bool shouldReclip(CustomClipper<Path> oldClipper) => false;
}
