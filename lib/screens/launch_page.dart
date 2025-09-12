import 'dart:async';
import 'dart:convert';

import 'package:app_links/app_links.dart';
import 'package:auth0_flutter/auth0_flutter.dart';
import 'package:easibite/screens/home_login.dart';
import 'package:easibite/screens/home_screen.dart'as Home;
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'GroupPages/groupdinner.dart'as Group;
import 'login_page.dart';
import 'onboarding_page.dart';
import 'package:http/http.dart' as http;
final GlobalKey<ScaffoldMessengerState> _scaffoldMessengerKey = GlobalKey<ScaffoldMessengerState>();
final GlobalKey<NavigatorState> _navigatorKey = GlobalKey<NavigatorState>();

class LaunchPage extends StatefulWidget {
  const LaunchPage({Key? key}) : super(key: key);

  @override
  _LaunchPageState createState() => _LaunchPageState();
}

class _LaunchPageState extends State<LaunchPage> {
  UserProfile? _user;
  StreamSubscription<Uri>? _linkSubscription;

  @override
  void initState() {
    super.initState();
    _getInitialPage();
  }

  Future<void> _getInitialPage() async {
    final prefs = await SharedPreferences.getInstance();
    final userJson = prefs.getString('userProfile');

    if (userJson != null) {
      final userMap = jsonDecode(userJson);
      setState(() {
        _user = UserProfile(
          name: userMap['name'],
          email: userMap['email'],
          profileUrl: userMap['profileUrl'] != null ? Uri.parse(userMap['profileUrl']) : null,
          pictureUrl: userMap['picture'] != null ? Uri.parse(userMap['picture']) : null,
          nickname: userMap['nickname'],
          givenName: userMap['givenName'],
          familyName: userMap['familyName'],
          locale: userMap['locale'],
          sub: userMap['sub'],
        );
      });
    }

    _takeAction();
  }

  Future<Map<String, dynamic>> getUserByEmail(String emailid) async {
    final response = await http.get(Uri.parse('http://13.57.29.10:7000/users/$emailid'));
    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);
      if (data["code"] == 404) {
        return {"status": "error", "message": "User not found", "code": 404};
      }
      return {"status": "success", "data": data["data"], "code": 200};
    } else if (response.statusCode == 404) {
      return {"status": "error", "message": "User not found", "code": 404};
    } else {
      return {
        "status": "error",
        "message": "Failed to retrieve user",
        "error": response.body,
        "code": response.statusCode
      };
    }
  }

  Future<void> _handleDeepLink(Uri uri) async {
    if (uri.path != '/join-group') {
      print('Not a join-group path: ${uri.path}');
      return;
    }

    try {
      final query = uri.query;
      if (query.isEmpty) {
        print('Query is empty');
        return;
      }

      print('URI3: ${query.toString()}');
      final decodedQuery = Uri.decodeComponent(query);

      final RegExp pattern = RegExp(r'^g(\d+)t\d+$');
      final match = pattern.firstMatch(decodedQuery);

      if (match == null || match.groupCount < 1) {
        print('Invalid group link format: no match');
        return;
      }

      final groupId = match.group(1);
      if (groupId == null) {
        print('GroupId is null');
        return;
      }

      print('Extracted groupId: $groupId');

      // Fetch and update user data
      final userResponse = await getUserByEmail(_user!.email!);
      if (userResponse['status'] != 'success') {
        throw Exception('Failed to fetch user data: ${userResponse['message']}');
      }

      final userData = userResponse['data'][0];
      List<String> groupInvites = List<String>.from(userData['groupinvites'] ?? []);
      List<String> groups = List<String>.from(userData['groups'] ?? []);

      // Remove groupId from invites if present
      if (groupInvites.contains(groupId)) {
        groupInvites.remove(groupId);
      }

      // Add groupId to groups if not already present
      if (!groups.contains(groupId)) {
        groups.add(groupId);
      }

      // Update user data
      Map<String, dynamic> updatedUserData = Map<String, dynamic>.from(userData);
      updatedUserData['groupinvites'] = groupInvites;
      updatedUserData['groups'] = groups;

      final userUpdateResponse = await http.put(
        Uri.parse('http://13.57.29.10:7000/users/update'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode(updatedUserData),
      );
      print("lll $userUpdateResponse");

      if (userUpdateResponse.statusCode != 200) {
        throw Exception('Failed to update user data: ${userUpdateResponse.body}');
      }
      // Fetch group data
      final groupResponse = await http.get(
        Uri.parse('http://13.57.29.10:7000/groups/$groupId'),
      );

      if (groupResponse.statusCode != 200) {
        throw Exception('Failed to fetch group: ${groupResponse.body}');
      }

      final groupData = jsonDecode(groupResponse.body);
      print('Group data: $groupData');

      if (groupData['status'] != 'success') {
        throw Exception('Group data fetch unsuccessful');
      }

      Map<String, dynamic> updatedGroupData = Map<String, dynamic>.from(groupData['data']);
      List<String> userIds = List<String>.from(updatedGroupData['user_ids'] ?? []);

      if (!userIds.contains(_user!.email!)) {
        // User not in group, add them
        userIds.add(_user!.email!);
        updatedGroupData['user_ids'] = userIds;

        final groupUpdateResponse = await http.put(
          Uri.parse('http://13.57.29.10:7000/groups/update/$groupId'),
          headers: {'Content-Type': 'application/json'},
          body: jsonEncode(updatedGroupData),
        );

        if (groupUpdateResponse.statusCode != 200) {
          throw Exception('Failed to update group: ${groupUpdateResponse.body}');
        }

        // Navigate to GroupDinner screen
        _navigatorKey.currentState?.pushReplacement(
          MaterialPageRoute(
            builder: (context) => Group.GroupDinner(
              user: _user!,
              groupId: groupId,
              activities: [], onRemoveGroup: (String groupId) {},
            ),
          ),
        );

        _scaffoldMessengerKey.currentState?.showSnackBar(
          const SnackBar(content: Text('Successfully joined the group!')),
        );
      } else {
        // User already in group
        print('User already in group');
        _scaffoldMessengerKey.currentState?.showSnackBar(
          const SnackBar(content: Text('You are already in the group!')),
        );

        // Navigate to HomeScreen
        _navigatorKey.currentState?.pushReplacement(
          MaterialPageRoute(
            builder: (context) => Home.HomeScreen(user: _user!),
          ),
        );
      }
    } catch (e) {
      print('Error processing deep link: $e');
      _scaffoldMessengerKey.currentState?.showSnackBar(
        SnackBar(content: Text('Error: $e')),
      );
    }
  }

  Future<void> _takeAction() async {
    final prefs = await SharedPreferences.getInstance();
    final isLoggedIn = prefs.getBool('isLoggedIn') ?? false;
    final isOnboarded = prefs.getBool('isOnboarded') ?? false;

    if (_user == null || !isLoggedIn) {
      _navigatorKey.currentState?.pushReplacement(
        MaterialPageRoute(builder: (context) => HomeLogin()),
      );
      return;
    }

    if (!isOnboarded) {
      _navigatorKey.currentState?.pushReplacement(
        MaterialPageRoute(builder: (context) => OnboardingScreen(user: _user!)),
      );
      return;
    }

    // Handle deep links only if logged in and onboarded
    final appLinks = AppLinks();
    try {
      final initialUri = await appLinks.getInitialLink();
      if (initialUri != null) {
        print('Initial URI: ${initialUri.toString()}');
        await _handleDeepLink(initialUri);
      } else {
        print('No initial URI found');
        _navigatorKey.currentState?.pushReplacement(
          MaterialPageRoute(builder: (context) => Home.HomeScreen(user: _user!)),
        );
      }
    } catch (e) {
      print('Error getting initial link: $e');
      _navigatorKey.currentState?.pushReplacement(
        MaterialPageRoute(builder: (context) => Home.HomeScreen(user: _user!)),
      );
    }

    // Set up stream listener only once
    if (_linkSubscription == null) {
      _linkSubscription = appLinks.uriLinkStream.listen(
            (uri) async {
          print('Stream URI: ${uri.toString()}');
          await _handleDeepLink(uri);
        },
        onError: (err) {
          print('Error with AppLinks: $err');
        },
        cancelOnError: false,
      );
    }
  }

  @override
  void dispose() {
    _linkSubscription?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      navigatorKey: _navigatorKey,
      scaffoldMessengerKey: _scaffoldMessengerKey,
      home: Scaffold(
        body: Center(
          child: const CircularProgressIndicator(),
        ),
      ),
    );
  }
}