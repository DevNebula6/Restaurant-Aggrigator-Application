import 'dart:async';
import 'dart:convert';
import 'package:auth0_flutter/auth0_flutter.dart';
import 'package:easibite/screens/GroupPages/groupdinner.dart';
import 'package:easibite/screens/home_login.dart';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/activity_model.dart';
import 'package:http/http.dart' as http;


class MyGroupsScreen extends StatefulWidget {
  final List<ActivityItem> activities;
  final UserProfile user;
  final Function(int) setIndex;

  const MyGroupsScreen({
    super.key,
    required this.user,
    required this.activities,
    required this.setIndex,
  });

  @override
  State<MyGroupsScreen> createState() => _MyGroupsScreenState();
}

class _MyGroupsScreenState extends State<MyGroupsScreen> with RouteAware {
  final GlobalKey<ScaffoldMessengerState> _scaffoldMessengerKey = GlobalKey<ScaffoldMessengerState>();
  final apiUrl = 'http://13.57.29.10:7000';
  late List<dynamic> groups_of_user; // Changed to non-final for initialization
  bool userGroupisNull = false;
  bool isLoading = true; // Added loading state
  late final StreamController<List<dynamic>> _groupStreamController = StreamController<List<dynamic>>.broadcast();
  List<dynamic> allGroupsData = [];
  late Auth0 auth0;
  final Map<String, Future<String>> _compatibilityRequests = {};
  final Map<String, String> _memoryCache = {};

  @override
  void dispose() {
    _clearCompatibilityCache();
    _groupStreamController.close();
    super.dispose();
  }

  Future<void> createGroup(BuildContext context, String groupName, String groupPreferences) async {
    try {
      if (widget.user.email == null) {
        print("USER IS NULL");
        return;
      }

      Map<String, dynamic> groupPreferencesJson;
      try {
        groupPreferencesJson = jsonDecode(groupPreferences);
      } catch (e) {
        groupPreferencesJson = {"title": groupPreferences};
      }

      Map<String, dynamic> requestBody = {
        "user_ids": [widget.user.email ?? ''],
        "group_name": groupName,
        "group_preferences": jsonEncode(groupPreferencesJson),
      };

      final response = await http.post(
        Uri.parse('$apiUrl/groups'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode(requestBody),
      );

      if (response.statusCode == 200) {
        final responseData = jsonDecode(response.body);
        print('Group created: $responseData');
        print('GroupID: ${responseData["data"]["group_id"]}');

        // Add the group to local data immediately
        await fetchSingleGroup(responseData["data"]["group_id"].toString());

        _scaffoldMessengerKey.currentState?.showSnackBar(
          const SnackBar(content: Text('Group created successfully!')),
        );

        // Update user data in backend
        getUserByEmail(widget.user.email!).then((result) async {
          if (result['status'] == 'success') {
            print('User Data called during create group: ${result['data'][0]}');
            var payload = Map<String, dynamic>.from(result['data'][0]);
            if (payload.containsKey('groups') && payload['groups'] is List) {
              payload['groups'].add(responseData["data"]["group_id"].toString());
            } else {
              payload['groups'] = [responseData["data"]["group_id"].toString()];
            }
            
            // Update local state immediately
            setState(() {
              if (groups_of_user.isEmpty) {
                groups_of_user = [responseData["data"]["group_id"].toString()];
                userGroupisNull = false; // ✅ Important: Set this to false
              } else {
                groups_of_user.add(responseData["data"]["group_id"].toString());
              }
            });
            
            await _updateUserData(payload);
          } else {
            print('Error: ${result['message']}');
          }
        }).catchError((error) {
          print('Error: $error');
        });
      } else {
        print('Failed to create group: ${response.body}');
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to create group: ${response.body}')),
        );
      }
    } catch (e) {
      print('Error: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error: $e')),
      );
    }
  }

  Future<void> fetchSingleGroup(String groupId) async {
    try {
      final response = await http.get(
        Uri.parse('$apiUrl/groups/$groupId'),
        headers: {'Content-Type': 'application/json'},
      );

      if (response.statusCode == 200) {
        final responseData = jsonDecode(response.body);
        if (responseData['status'] == 'success') {
          print("GROUPINFOSINGLE ${responseData['data']}");
          setState(() {
            allGroupsData.add(responseData['data']);
            _groupStreamController.add(List.from(allGroupsData));
            userGroupisNull = false; // Ensure UI shows groups
            isLoading = false; // Stop loading state
          });
        } else {
          print('Failed to fetch group: ${responseData['message']}');
        }
      } else {
        print('Failed to fetch group: ${response.body}');
      }
    } catch (e) {
      print('Error fetching group: $e');
    }
  }

  void openCreateGroupModal(BuildContext context) {
    final groupNameController = TextEditingController();
    final groupPreferencesController = TextEditingController();

    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Create Group'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: groupNameController,
                decoration: const InputDecoration(labelText: 'Group Name'),
              ),
              TextField(
                controller: groupPreferencesController,
                decoration: const InputDecoration(labelText: 'Group Preferences'),
                maxLines: 3,
              ),
            ],
          ),
          actions: <Widget>[
            TextButton(
              child: const Text('Cancel'),
              onPressed: () => Navigator.of(context).pop(),
            ),
            TextButton(
              child: const Text('Create'),
              onPressed: () async {
                print("CREATE__");
                await createGroup(context, groupNameController.text, groupPreferencesController.text);
                Navigator.of(context).pop();
              },
            ),
          ],
        );
      },
    );
  }

  Future<Map<String, dynamic>> getUserByEmail(String emailid) async {
    try {
      print('Fetching user data for: $emailid');
      final response = await http.get(
        Uri.parse('$apiUrl/users/$emailid'),
        headers: {'Content-Type': 'application/json'},
      ).timeout(
        Duration(seconds: 30),
        onTimeout: () {
          print('Request timed out for user: $emailid');
          return http.Response('{"error":"timeout"}', 408);
        },
      );
      
      print('Response status: ${response.statusCode}');
      print('Response body: ${response.body}');
      
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (data["code"] == 404) {
          return {"status": "error", "message": "User not found", "code": 404};
        }
        return {"status": "success", "data": data["data"], "code": 200};
      } else if (response.statusCode == 404) {
        return {"status": "error", "message": "User not found", "code": 404};
      } else if (response.statusCode == 408) {
        return {"status": "error", "message": "Request timeout", "code": 408};
      } else {
        return {
          "status": "error",
          "message": "Failed to retrieve user (${response.statusCode})",
          "error": response.body,
          "code": response.statusCode,
        };
      }
    } catch (e) {
      print('Exception in getUserByEmail: $e');
      return {
        "status": "error",
        "message": "Network error: $e",
        "code": 500,
      };
    }
  }

  Future<void> fetchAllGroups() async {
    setState(() => isLoading = true); // Start loading
    List<dynamic> fetchedGroups = []; // Temporary list to collect all groups
    List<String> validGroupIds = [];

    for (String groupId in groups_of_user) {
      try {
        final response = await http.get(
          Uri.parse('$apiUrl/groups/$groupId'),
          headers: {'Content-Type': 'application/json'},
        );

        if (response.statusCode == 200) {
          final responseData = jsonDecode(response.body);
          if (responseData['status'] == 'success') {
            final group = responseData['data'];
            // Check if group has at least one member
            if (group['user_ids'] is List && (group['user_ids'] as List).isNotEmpty) {
              fetchedGroups.add(group);
              validGroupIds.add(groupId);
            } else {
              print('Group $groupId has 0 members, will remove from user.');
            }
          } else {
            print('Failed to fetch group: ${responseData['message']}');
          }
        } else if (response.statusCode == 404) {
          print('Group $groupId not found (404), will remove from user.');
        } else {
          print('Failed to fetch group: ${response.body}');
        }
      } catch (e) {
        print('Error fetching group: $e');
      }
    }

    // Remove invalid group IDs from user's group list if needed
    if (validGroupIds.length != groups_of_user.length) {
      print('Updating user group list to remove deleted/empty groups...');
      groups_of_user = validGroupIds;
      // Update backend user data
      getUserByEmail(widget.user.email!).then((result) async {
        if (result['status'] == 'success') {
          var payload = Map<String, dynamic>.from(result['data'][0]);
          payload['groups'] = validGroupIds;
          await _updateUserData(payload);
        }
      });
    }

    // Update allGroupsData and emit to stream only once
    setState(() {
      allGroupsData = fetchedGroups;
      _groupStreamController.add(List.from(allGroupsData));
      isLoading = false; // Done loading
    });
  }

  @override
  void didPopNext() {
    // Called when returning to this page from another page
    super.didPopNext();
    print('🔄 MyGroupsScreen: Returned to page, refreshing data...');
    _refreshGroupDataAndClearCache();
  }

  Future<void> _refreshGroupDataAndClearCache() async {
    // ✅ Clear memory cache when returning from group pages
    print('🗑️ Clearing memory cache on page return');
    _memoryCache.clear();
    _compatibilityRequests.clear();
    
    final email = widget.user.email;
    if (email != null) {
      await _initializeUserGroups(email);
    }
  }

  Future<void> _refreshGroupData() async {
    final email = widget.user.email;
    if (email != null) {
      await _initializeUserGroups(email);
    }
  }

  void removeGroup(String groupId) {
    setState(() {
      // Remove from local data
      allGroupsData.removeWhere((group) => group['group_id'].toString() == groupId);
      groups_of_user.remove(groupId);
      
      // Update stream
      _groupStreamController.add(List.from(allGroupsData));
      
      // Clear compatibility cache for this group
      _memoryCache.remove(groupId);
      
      // Update userGroupisNull state
      if (allGroupsData.isEmpty) {
        userGroupisNull = true;
      }
    });
    
    // Clear persistent cache
    _clearCompatibilityPersistentCache(groupId);
  }

  Future<void> _clearCompatibilityPersistentCache(String groupId) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      String? storedData = prefs.getString('comp_percent_list');
      if (storedData != null) {
        List<Map<String, dynamic>> compPercentList = List<Map<String, dynamic>>.from(
          jsonDecode(storedData).map((item) => Map<String, dynamic>.from(item)),
        );
        compPercentList.removeWhere((entry) => entry['groupId'] == groupId);
        await prefs.setString('comp_percent_list', jsonEncode(compPercentList));
        print('🗑️ Cleared compatibility cache for removed group $groupId');
      }
    } catch (e) {
      print('❌ Error clearing compatibility cache: $e');
    }
  }

  Future<void> _updateUserData(Map<String, dynamic> userData) async {
    print("Updating user data...${userData["groups"].runtimeType}");
    for (var item in userData["groups"]) {
      print('Type of item in userData["groups"]: ${item.runtimeType}');
    }
    try {
      final Map<String, dynamic> requestBody = {
        "additionalNotes": userData["additionalNotes"] ?? "",
        "groups": userData["groups"] ?? [],
        "onboardingCompleted": userData["onboardingCompleted"] ?? false,
        "foodTemperature": userData["foodTemperature"] ?? [],
        "userid": userData["userid"] ?? "",
        "allergens": userData["allergens"] ?? [],
        "phonenumber": userData["phonenumber"] ?? 0,
        "spiceLevel": userData["spiceLevel"] ?? "Medium",
        "emailid": userData["emailid"] ?? "",
        "dietary": userData["dietary"] ?? [],
        "dietaryPreferences": userData["dietaryPreferences"] ?? userData["dietary"] ?? [], // Add both for backend compatibility
        "name": userData["name"] ?? "Unknown",
        "groupinvites": userData["groupinvites"] ?? [],
        "emergency": userData["emergency"] ?? [],
      };
      print("JSON Payload being sent: ${jsonEncode(requestBody)}");

      final response = await http.put(
        Uri.parse('$apiUrl/users/update'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode(requestBody),
      );

      if (response.statusCode == 200) {
        print("User updated successfully: ${response.body}");
        final responseData = jsonDecode(response.body);
        
        List<String> updatedGroups = [];
        
        if (responseData['data'] != null && responseData['data'].isNotEmpty) {
          // Format 1: data array exists
          updatedGroups = List<String>.from(responseData['data'][0]["groups"] ?? []);
        } else if (responseData['updated_data'] != null) {
          // Format 2: updated_data exists
          updatedGroups = List<String>.from(responseData['updated_data']["groups"] ?? []);
        } else {
          // Format 3: Use the groups from request body as fallback
          updatedGroups = List<String>.from(requestBody["groups"]);
        }
        
        setState(() {
          groups_of_user = updatedGroups;
        });
        
        // Immediately fetch the new group data to update UI
        if (updatedGroups.isNotEmpty) {
          await fetchAllGroups();
        }
        
      } else {
        print("Failed to update user: ${response.statusCode} - ${response.body}");
      }
    } catch (e) {
      print("Error updating user: $e");
    }
  }

  @override
  void initState() {
    super.initState();
    groups_of_user = [];
    
    final email = widget.user.email;
    if (email != null) {
      _initializeUserGroups(email);
    } else {
      print('Email is null, cannot fetch user data.');
      setState(() {
        userGroupisNull = true;
        isLoading = false;
      });
    }
  }

  // Add this new method to handle user initialization more gracefully:
  Future<void> _initializeUserGroups(String email) async {
    try {
      final result = await getUserByEmail(email);
      
      if (result['status'] == 'success') {
        print('User Data: ${result['data'][0]["groups"]}');
        setState(() {
          if (result['data'][0]["groups"] != null && result['data'][0]["groups"].isNotEmpty) {
            groups_of_user = result['data'][0]["groups"];
            fetchAllGroups();
          } else {
            print("User has no groups");
            userGroupisNull = true;
            isLoading = false;
          }
        });
      } else {
        // Handle error without logging out
        print('Error fetching user data: ${result['message']}');
        _handleUserDataError(result);
      }
    } catch (error) {
      print('Error in _initializeUserGroups: $error');
      setState(() {
        userGroupisNull = true;
        isLoading = false;
      });
      
      // Show error message to user instead of logging out
      _scaffoldMessengerKey.currentState?.showSnackBar(
        SnackBar(
          content: Text('Unable to load groups. Please try again.'),
          action: SnackBarAction(
            label: 'Retry',
            onPressed: () => _initializeUserGroups(email),
          ),
        ),
      );
    }
  }

  void _handleUserDataError(Map<String, dynamic> result) {
    setState(() {
      userGroupisNull = true;
      isLoading = false;
    });

    // Only logout if it's a specific authentication error
    if (result['code'] == 401 || result['message']?.contains('unauthorized') == true) {
      _showLogoutDialog();
    } else {
      // For other errors, just show the error and let user try again
      _scaffoldMessengerKey.currentState?.showSnackBar(
        SnackBar(
          content: Text('Unable to load groups: ${result['message'] ?? 'Unknown error'}'),
          duration: Duration(seconds: 5),
          action: SnackBarAction(
            label: 'Retry',
            onPressed: () => _initializeUserGroups(widget.user.email!),
          ),
        ),
      );
    }
  }

  void _showLogoutDialog() {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Text('Authentication Required'),
          content: Text('Your session has expired. Would you like to log in again?'),
          actions: [
            TextButton(
              child: Text('Stay Here'),
              onPressed: () => Navigator.of(context).pop(),
            ),
            TextButton(
              child: Text('Log In'),
              onPressed: () async {
                Navigator.of(context).pop();
                await logout(context);
              },
            ),
          ],
        );
      },
    );
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
        // Clear restaurant statistics cache
        else if (key.startsWith('safeItemsCount_') ||
                key.startsWith('cautionCount_') ||
                key.startsWith('avoidCount_') ||
                key.startsWith('parsedData_')) {
          await prefs.remove(key);
        }
      }
      
      // Clear specific user data
      await prefs.remove('user_data');
      await prefs.remove('userPreferences');
      await prefs.remove('saved_restaurants');
      
      print('Cleared all user-specific cache on logout');
    } catch (e) {
      print('Error clearing cache: $e');
    }
  }

  // ✅ Update the cache checking method to be more robust
  Future<String?> _getCachedCompatibilityWithUserCheck(String groupId, List<String> currentUserIds) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      String? storedData = prefs.getString('comp_percent_list');
      
      if (storedData != null) {
        List<Map<String, dynamic>> compPercentList = List<Map<String, dynamic>>.from(
          jsonDecode(storedData).map((item) => Map<String, dynamic>.from(item)),
        );
        
        final cachedEntry = compPercentList.firstWhere(
          (entry) => entry['groupId'] == groupId,
          orElse: () => {},
        );
        
        if (cachedEntry.isNotEmpty) {
          // Check if user_ids match exactly
          List<String> cachedUserIds = List<String>.from(cachedEntry['user_ids'] ?? []);
          
          // Sort both lists for accurate comparison
          cachedUserIds.sort();
          currentUserIds.sort();
          
          if (_areUserListsEqual(cachedUserIds, currentUserIds)) {
            print('✅ MyGroups: Using persistent cached compatibility for group $groupId: ${cachedEntry['percentage']}%');
            return cachedEntry['percentage'];
          } else {
            print('⚠️ MyGroups: User composition changed for group $groupId, will recalculate');
            // ✅ Clear the invalid cache entry
            compPercentList.removeWhere((entry) => entry['groupId'] == groupId);
            await prefs.setString('comp_percent_list', jsonEncode(compPercentList));
          }
        }
      }
    } catch (e) {
      print('❌ MyGroups: Error checking cached compatibility: $e');
    }
    return null;
  }
  
  bool _areUserListsEqual(List<String> list1, List<String> list2) {
    if (list1.length != list2.length) return false;
    for (int i = 0; i < list1.length; i++) {
      if (list1[i] != list2[i]) return false;
    }
    return true;
  }

  Future<String> getMatchPercentage(String groupId) async {
    // ✅ Don't use memory cache immediately - check persistent cache first
    print('🔍 MyGroups: Getting match percentage for group $groupId');
    
    // Check if request is already in progress
    if (_compatibilityRequests.containsKey(groupId)) {
      print('⏳ Waiting for existing compatibility request for group $groupId');
      String result = await _compatibilityRequests[groupId]!;
      return '$result% Match';
    }

    // Find the group data
    var groupData = allGroupsData.firstWhere(
      (group) => group['group_id'].toString() == groupId,
      orElse: () => null,
    );
    
    if (groupData == null) {
      print("❌ Group data not found for $groupId");
      return "N/A";
    }
    
    List<String> currentUserIds = List<String>.from(groupData['user_ids'] ?? []);
    
    // ✅ Always check persistent cache first (most reliable)
    String? cachedPercent = await _getCachedCompatibilityWithUserCheck(groupId, currentUserIds);
    if (cachedPercent != null) {
      // ✅ Update memory cache with the correct value
      _memoryCache[groupId] = cachedPercent;
      print('💾 MyGroups: Updated memory cache with persistent cache value: $cachedPercent%');
      return "$cachedPercent% Match";
    }
    
    // ✅ If persistent cache is invalid/missing, clear memory cache and recalculate
    if (_memoryCache.containsKey(groupId)) {
      print('🗑️ MyGroups: Removing stale memory cache for group $groupId');
      _memoryCache.remove(groupId);
    }
    
    // Create and store the request future
    _compatibilityRequests[groupId] = _calculateCompatibilityForGroup(groupId, currentUserIds);
    
    try {
      String result = await _compatibilityRequests[groupId]!;
      _memoryCache[groupId] = result;
      return '$result% Match';
    } finally {
      // Clean up the request
      _compatibilityRequests.remove(groupId);
    }
  }
  Future<String> _calculateCompatibilityForGroup(String groupId, List<String> currentUserIds) async {
    try {
      print('🔄 MyGroups: Calculating compatibility for group $groupId with users: $currentUserIds');
      
      // Add delay to prevent rapid fire requests
      await Future.delayed(Duration(milliseconds: 500));
      
      // Initialize JSON object
      Map<String, dynamic> jsonobj = {"members": []};
      
      await Future.wait(
        currentUserIds.map((email) async {
          var result = await getUserByEmail(email);
          if (result['status'] == 'success') {
            List<String> preferences = [];
            if (result['data'][0]['dietaryPreferences'] != null) {
              preferences.addAll(List<String>.from(result['data'][0]['dietaryPreferences']));
            }
            if (result['data'][0]['spiceLevel'] != null) {
              preferences.add(result['data'][0]['spiceLevel'] as String);
            }
            if (result['data'][0]['allergens'] != null) {
              preferences.addAll(List<String>.from(result['data'][0]['allergens']));
            }
            
            jsonobj["members"].add({
              "email": email,
              "preferences": preferences,
            });
          }
        }),
      );
      
      print("📤 MyGroups: Compatibility payload: ${jsonEncode(jsonobj)}");
      
      // Use the working /gc endpoint with retry logic
      var response = await _makeCompatibilityRequest(jsonobj);
      
      if (response != null && response.statusCode == 200) {
        String cleanedResponse = response.body.replaceAll('\\"', '"');
        RegExp regex = RegExp(r'<p class="perc">(\d+)</p>');
        Match? match = regex.firstMatch(cleanedResponse.trim());
        
        if (match != null) {
          String percentage = match.group(1)!;
          print("✅ MyGroups: Calculated compatibility: $percentage%");
          
          // Cache the result with user_ids
          await _cacheCompatibilityWithUserIds(groupId, currentUserIds, percentage);
          
          return percentage;
        }
      }
      
      return "N/A";
    } catch (e) {
      print("❌ MyGroups: Error calculating compatibility: $e");
      return "Error";
    }
  }
  // ✅ Add retry logic for API calls
  Future<http.Response?> _makeCompatibilityRequest(Map<String, dynamic> payload) async {
    for (int attempt = 1; attempt <= 3; attempt++) {
      try {
        print("🔄 Compatibility API attempt $attempt/3");
        
        var response = await http.post(
          Uri.parse("http://13.57.29.10:7000/gc"),
          headers: {"Content-Type": "application/json"},
          body: jsonEncode(payload),
        ).timeout(Duration(seconds: 30));
        
        if (response.statusCode == 200) {
          return response;
        } else {
          print("⚠️ API attempt $attempt failed: ${response.statusCode}");
          if (attempt < 3) {
            await Future.delayed(Duration(seconds: attempt * 2)); // Exponential backoff
          }
        }
      } catch (e) {
        print("❌ API attempt $attempt error: $e");
        if (attempt < 3) {
          await Future.delayed(Duration(seconds: attempt * 2));
        }
      }
    }
    return null;
  }

  // calculateAndCacheMatchPercentage method
  Future<String> calculateAndCacheMatchPercentage(String groupId, List<String> userIds) async {
    try {
      print('🔄 MyGroups: Calculating compatibility for group $groupId with users: $userIds');
      
      // Initialize JSON object (same as GroupDinner.dart)
      Map<String, dynamic> jsonobj = {"members": []};
      
      await Future.wait(
        userIds.map((email) async {
          var result = await getUserByEmail(email);
          if (result['status'] == 'success') {
            // Extract user preferences (same logic as GroupDinner.dart)
            List<String> preferences = [];
            if (result['data'][0]['dietaryPreferences'] != null) {
              preferences.addAll(List<String>.from(result['data'][0]['dietaryPreferences']));
            }
            if (result['data'][0]['spiceLevel'] != null) {
              preferences.add(result['data'][0]['spiceLevel'] as String);
            }
            if (result['data'][0]['allergens'] != null) {
              preferences.addAll(List<String>.from(result['data'][0]['allergens']));
            }
            
            jsonobj["members"].add({
              "email": email,
              "preferences": preferences,
            });
          }
        }),
      );
      
      print("📤 MyGroups: Compatibility payload: ${jsonEncode(jsonobj)}");
      
      // Use the working /gc endpoint
      var response = await http.post(
        Uri.parse("http://13.57.29.10:7000/gc"),
        headers: {"Content-Type": "application/json"},
        body: jsonEncode(jsonobj),
      ).timeout(Duration(seconds: 30));
      
      if (response.statusCode == 200) {
        String cleanedResponse = response.body.replaceAll('\\"', '"');
        RegExp regex = RegExp(r'<p class="perc">(\d+)</p>');
        Match? match = regex.firstMatch(cleanedResponse.trim());
        
        if (match != null) {
          String percentage = match.group(1)!;
          print("✅ MyGroups: Calculated compatibility: $percentage%");
          
          // Cache the result with user_ids
          await _cacheCompatibilityWithUserIds(groupId, userIds, percentage);
          
          return "$percentage% Match";
        }
      }
      
      return "N/A";
    } catch (e) {
      print("❌ MyGroups: Error calculating compatibility: $e");
      return "Error";
    }
  }

  Future<void> _cacheCompatibilityWithUserIds(String groupId, List<String> userIds, String percentage) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      String? storedData = prefs.getString('comp_percent_list');
      
      List<Map<String, dynamic>> compPercentList = [];
      if (storedData != null) {
        compPercentList = List<Map<String, dynamic>>.from(
          jsonDecode(storedData).map((item) => Map<String, dynamic>.from(item)),
        );
      }
      
      // Remove existing entry for this group
      compPercentList.removeWhere((entry) => entry['groupId'] == groupId);
      
      // Add new entry with user_ids and timestamp
      compPercentList.add({
        'groupId': groupId,
        'user_ids': List<String>.from(userIds)..sort(),
        'percentage': percentage,
        'timestamp': DateTime.now().toIso8601String(),
      });
      
      await prefs.setString('comp_percent_list', jsonEncode(compPercentList));
      print('💾 MyGroups: Cached compatibility: $percentage% for group $groupId with users: $userIds');
    } catch (e) {
      print('❌ MyGroups: Error caching compatibility: $e');
    }
  }
    void _clearCompatibilityCache() {
    _memoryCache.clear();
    _compatibilityRequests.clear();
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      minimum: const EdgeInsets.only(top: 16.0),
      child: Scaffold(
        key: _scaffoldMessengerKey,
        appBar: AppBar(
          backgroundColor: Colors.white,
          elevation: 0,
          title: const Text(
            "My Groups",
            style: TextStyle(color: Colors.black, fontSize: 20, fontWeight: FontWeight.bold),
          ),
          actions: [
            TextButton.icon(
              onPressed: () => openCreateGroupModal(context),
              icon: const Icon(Icons.add, color: Colors.black),
              label: const Text(
                "Create Group",
                style: TextStyle(color: Colors.black, fontWeight: FontWeight.w500),
              ),
            ),
            IconButton(
              onPressed: _refreshGroupData,
              icon: const Icon(Icons.refresh, color: Colors.black),
              tooltip: 'Refresh Groups',
            ),
          ],
        ),
        body: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              TextField(
                decoration: InputDecoration(
                  hintText: "Search groups",
                  prefixIcon: const Icon(Icons.search),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(8.0)),
                ),
              ),
              const SizedBox(height: 16),
              // ✅ Add pull-to-refresh
              Expanded(
                child: RefreshIndicator(
                  onRefresh: _refreshGroupData,
                  child: StreamBuilder<List<dynamic>>(
                    stream: _groupStreamController.stream,
                    builder: (context, snapshot) {
                      if (isLoading) {
                        return const Center(child: CircularProgressIndicator());
                      } else if (snapshot.hasError) {
                        return Center(child: Text('Error: ${snapshot.error}'));
                      } else if (userGroupisNull || !snapshot.hasData || snapshot.data!.isEmpty) {
                        return Center(
                          child: ElevatedButton(
                            onPressed: () => openCreateGroupModal(context),
                            child: const Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(Icons.add, color: Colors.black),
                                SizedBox(width: 12),
                                Text(
                                  "Create your first group",
                                  style: TextStyle(color: Colors.black, fontWeight: FontWeight.w500),
                                ),
                              ],
                            ),
                          ),
                        );
                      } else {
                        final data = snapshot.data!;
                        return ListView.builder(
                          itemCount: data.length,
                          itemBuilder: (context, index) {
                            final group = data[index];
                            return FutureBuilder<String>(
                              future: getMatchPercentage(group['group_id'].toString()),
                              builder: (context, percentageSnapshot) {
                                String matchPercentage;
                                if (percentageSnapshot.connectionState == ConnectionState.waiting) {
                                  matchPercentage = "Loading...";
                                } else if (percentageSnapshot.hasData) {
                                  matchPercentage = percentageSnapshot.data!;
                                } else {
                                  matchPercentage = "-1";
                                }
                                return GroupCard(
                                  groupName: group['group_name'] ?? 'Unnamed Group',
                                  members: "${group['user_ids']?.length ?? 0} members",
                                  activeStatus: "Active Today",
                                  date: "Tomorrow, 7 PM",
                                  matchPercentage: matchPercentage,
                                  groupId: group['group_id'].toString(),
                                  user: widget.user,
                                  totalMembers: group['user_ids']?.length ?? 0,
                                  group: group,
                                  onRemoveGroup: removeGroup,
                                );
                              },
                            );
                          },
                        );
                      }
                    },
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}


class GroupCard extends StatelessWidget {
  final String groupName;
  final String members;
  final String activeStatus;
  final String date;
  final String? restaurant;
  final String matchPercentage;
  final String groupId;
  final UserProfile? user;
  final Map<String, dynamic> group;
  final int totalMembers;
  final void Function(String)? onRemoveGroup;

  const GroupCard({
    Key? key,
    required this.groupName,
    required this.members,
    required this.activeStatus,
    required this.date,
    this.restaurant,
    this.user,
    required this.matchPercentage,
    required this.groupId,
    required this.totalMembers,
    required this.group, required this.onRemoveGroup,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    // Validate user_ids
    final userIds = group['user_ids'] is List ? List<dynamic>.from(group['user_ids']) : [];
    final actualMemberCount = userIds.length;

    return InkWell(
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => GroupDinner(
              user: user,
              groupId: groupId,
              activities: [], onRemoveGroup: onRemoveGroup,
            ),
          ),
        );
      },
      child: Card(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12.0)),
        elevation: 2.0,
        margin: const EdgeInsets.symmetric(vertical: 8.0),
        child: Padding(
          padding: const EdgeInsets.all(12.0),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Text(
                          groupName,
                          style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      "$members  $activeStatus",
                      style: const TextStyle(color: Colors.black54),
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        const Icon(Icons.calendar_today_outlined, size: 16, color: Colors.black54),
                        const SizedBox(width: 4),
                        // Text(date),
                        if (restaurant != null)
                          Padding(
                            padding: const EdgeInsets.only(left: 8.0),
                            child: Chip(
                              label: Text(
                                restaurant!,
                                style: const TextStyle(color: Colors.redAccent, fontSize: 12),
                              ),
                              backgroundColor: Colors.white,
                            ),
                          ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        // Dynamically generate CircleAvatars based on actualMemberCount
                        ...List.generate(
                          actualMemberCount > 3 ? 3 : actualMemberCount,
                              (index) {
                            final userId = userIds[index]; // Safe access
                            // Handle userId as String or convert if needed
                            final initials = userId.toString().split('@').first.replaceAll(RegExp(r'[^0-9]'), '');
                            final displayInitial = initials.isNotEmpty ? initials[0] : '?';

                            return Padding(
                              padding: const EdgeInsets.only(right: 4.0),
                              child: CircleAvatar(
                                backgroundColor: Colors.orange,
                                radius: 12,
                                child: Text(
                                  displayInitial,
                                  style: const TextStyle(color: Colors.white, fontSize: 12),
                                ),
                              ),
                            );
                          },
                        ),
                        if (actualMemberCount > 3) ...[
                          const SizedBox(width: 8),
                          Text(
                            "+${actualMemberCount - 3}",
                            style: const TextStyle(color: Colors.orange, fontWeight: FontWeight.bold),
                          ),
                        ],
                        const Spacer(),
                        if (matchPercentage != "-1")
                          Chip(
                            label: Text(
                              matchPercentage,
                              style: const TextStyle(color: Colors.white),
                            ),
                            backgroundColor: Colors.green,
                          ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              const Icon(Icons.groups, size: 40, color: Colors.black45),
            ],
          ),
        ),
      ),
    );
  }
}