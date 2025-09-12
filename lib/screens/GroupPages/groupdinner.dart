import 'dart:convert';
import 'dart:io';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:get/get_core/src/get_main.dart' show Get;
import 'package:http/http.dart' as http;
import 'package:auth0_flutter/auth0_flutter.dart';
import 'package:http_parser/http_parser.dart';
import 'package:share_plus/share_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../models/activity_model.dart';
import '../home_screen.dart';
import 'members.dart';

class GroupDinner extends StatefulWidget {
  final UserProfile? user;
  final String groupId;
  final List<ActivityItem> activities;
  final void Function(String)? onRemoveGroup;

  const GroupDinner({
    Key? key,
    required this.user,
    required this.groupId,
    required this.activities, required this.onRemoveGroup,
  }) : super(key: key);

  @override
  _GroupDinnerState createState() => _GroupDinnerState();
}

class _GroupDinnerState extends State<GroupDinner> {
  final String apiUrl = 'http://13.57.29.10:7000';
  Map<String, dynamic>? groupData;
  bool isLoading = true;
  String errorMessage = '';
  List<ActivityItem> groupActivities = [];
  String? compPercent; // Compatibility percentage
  Map<String, List<Map<String, String>>>? parsedData2; // Menu data
  List<Map<String, dynamic>>? menuList; // Full menu list from API
  List<Map<String, dynamic>> filteredMenuList = [];
  int selectedIndex = 1; // Filter bar index
  int selectedIndex2 = 0;
  List<String> users = []; // Group members
  int? commonSafeCount = 0;
  int? someCanEatCount = 0;
  int? noneCanEatCount = 0;
  bool isLoading2 = false;
  List<String> allEmails = [];
  List<String> filteredEmails = [];
  String selectedEmail = '';
  Future<void>? _compatibilityRequest;
  String? _cachedCompPercent;

  @override
  void initState() {
    super.initState();
    fetchGroupDetails();
    filterGroupActivities();
    // fetchParsedData();
    filteredMenuList = menuList ?? [];
  }
    @override
  void dispose() {
    _compatibilityRequest = null;
    _cachedCompPercent = null;
    super.dispose();
  }

  void updateGroupDataFunc(Map<String, dynamic> newGroupData) {
    setState(() {
      groupData = Map<String, dynamic>.from(newGroupData);
    });
    print("lld $newGroupData");
  }
  Future<void> _handlePdf(String filePath) async {
    setState(() {
      isLoading2 = true;
    });
    print("Handling PDF: $filePath");
    File pdfFile = File(filePath);

    // 1. Upload PDF to /upload-img
    var uri = Uri.parse('http://13.57.29.10:7000/upload-img');
    var request = http.MultipartRequest('POST', uri);
    request.files.add(await http.MultipartFile.fromPath(
      'file',
      pdfFile.path,
      contentType: MediaType('application', 'pdf'),
    ));

    var uploadResponse = await request.send();

    if (uploadResponse.statusCode == 200) {
      var responseBody = await uploadResponse.stream.bytesToString();
      var responseJson = json.decode(responseBody);

      String fileUrl = responseJson['file_url'];
      print("Upload Success: $responseJson");

      // 2. Send file_url to /aimenu
      var analyzeUri = Uri.parse('http://13.57.29.10:7000/aimenu');
      var analyzeResponse = await http.post(
        analyzeUri,
        headers: {'Content-Type': 'application/json'},
        body: json.encode({'pdflink': fileUrl}),
      );

      if (analyzeResponse.statusCode == 200) {
        print("Analyze Success: ${analyzeResponse.body}");
        var analysisData = json.decode(analyzeResponse.body);

        // Fetch preferences for all users
        List<Map<String, List<Map<String, String>>>> allUserPreferences = [];
        List<Map<String, dynamic>> fetchedMenuList = [];

        for (String email in users) {
          Map<String, dynamic> payload = {
            "restuarant_id": "", // Add restaurant ID if available
            "nores": "yes",
            "email_id": email,
            "menu": analysisData,
          };

          final response = await http.post(
            Uri.parse('http://13.57.29.10:7000/users/get_preferences'),
            headers: {"Content-Type": "application/json"},
            body: json.encode(payload),
          );

          if (response.statusCode == 200) {
            final responseData = json.decode(response.body);
            print("Data for $email: ${response.body}");

            // Extract menu list (only once, assuming it’s consistent across users)
            if (fetchedMenuList.isEmpty && responseData.containsKey('response_menu')) {
              fetchedMenuList = List<Map<String, dynamic>>.from(responseData['response_menu']);
            }

            // Parse preference data
            if (responseData.containsKey('result')) {
              final resultText = responseData['result'][0]['text'];
              final regex = RegExp(r'id=(\w+)\sclass=(\w+)>(.*?)<');
              final matches = regex.allMatches(resultText);
              final Map<String, List<Map<String, String>>> parsedData = {};

              for (final match in matches) {
                final id = match.group(1) ?? '';
                final category = match.group(2) ?? '';
                final name = match.group(3) ?? '';
                if (id.isNotEmpty && category.isNotEmpty && name.isNotEmpty) {
                  parsedData.putIfAbsent(category, () => []).add({'id': id, 'name': name});
                }
              }
              allUserPreferences.add(parsedData);
            } else {
              print("Warning: No 'result' key found for $email");
            }
          } else {
            print("Failed to fetch preferences for $email: ${response.statusCode}");
          }
        }

        // Aggregate preferences across all users
        if (allUserPreferences.isNotEmpty && fetchedMenuList.isNotEmpty) {
          Map<String, List<Map<String, String>>> aggregatedData = _aggregatePreferences(allUserPreferences, fetchedMenuList);

          setState(() {
            menuList = fetchedMenuList;
            filteredMenuList = fetchedMenuList; // Initially show all
            parsedData2 = aggregatedData;
            selectedIndex=0;
            commonSafeCount = aggregatedData['SAFE']?.length ?? 0;
            someCanEatCount = aggregatedData['CAUTION']?.length ?? 0;
            noneCanEatCount = aggregatedData['AVOID']?.length ?? 0;
            isLoading2 = false;
          });

          print("Aggregated Parsed Data: $parsedData2");
          print("Menu List: $menuList");
        } else {
          print("Error: No preferences or menu data fetched for any user");
          setState(() => isLoading2 = false);
        }
      } else {
        print("Analyze Failed: ${analyzeResponse.statusCode}");
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Analyze Failed: ${analyzeResponse.statusCode}")),
        );
        setState(() => isLoading2 = false);
      }
    } else {
      print("Upload Failed: ${uploadResponse.statusCode}");
      setState(() => isLoading2 = false);
    }
  }

  Map<String, List<Map<String, String>>> _aggregatePreferences(
      List<Map<String, List<Map<String, String>>>> allUserPreferences,
      List<Map<String, dynamic>> menuList) {
    // Initialize result categories
    final Map<String, List<Map<String, String>>> aggregatedData = {
      'SAFE': [],
      'CAUTION': [],
      'AVOID': [],
    };

    // Get all unique item IDs from menuList
    final allItemIds = menuList
        .expand((category) => (category['items'] as List<dynamic>).map((item) => item['itemId'] as String))
        .toSet();

    // Map to track classifications for each item across users
    final itemClassifications = <String, List<String>>{};

    // Populate classifications for each item
    for (var userPrefs in allUserPreferences) {
      for (var category in ['SAFE', 'CAUTION', 'AVOID']) {
        final items = userPrefs[category] ?? [];
        for (var item in items) {
          final id = item['id']!;
          itemClassifications.putIfAbsent(id, () => []).add(category);
        }
      }
    }

    // Classify each item based on the new rules
    for (var id in allItemIds) {
      final classifications = itemClassifications[id] ?? [];
      // Find the item details from the first user's preferences that mentions it
      final item = allUserPreferences
          .expand((prefs) => prefs.values.expand((items) => items))
          .firstWhere((i) => i['id'] == id, orElse: () => {'id': id, 'name': 'Unknown'});

      if (classifications.length == allUserPreferences.length) {
        // Item is classified by all users
        if (classifications.every((c) => c == 'SAFE')) {
          aggregatedData['SAFE']!.add(item);
        } else if (classifications.every((c) => c == 'CAUTION')) {
          aggregatedData['CAUTION']!.add(item);
        } else {
          aggregatedData['AVOID']!.add(item);
        }
      } else {
        // Item not classified by all users defaults to AVOID
        aggregatedData['AVOID']!.add(item);
      }
    }

    return aggregatedData;
  }

  void _filterMenu(int index) {
    print("Filter triggered with index: $index");
    setState(() {
      selectedIndex2 = index; // Update the filter index
      print("Menu List: $menuList");
      print("Parsed Data: $parsedData2");

      if (index == 0) {
        // Show all items
        filteredMenuList = menuList ?? [];
        print("Showing all items: $filteredMenuList");
      } else if (index == 1) {
        // None Can Eat (Avoid)
        final avoidIds = parsedData2?['AVOID']?.map((item) => item['id']).whereType<String>().toList() ?? [];
        print("Avoid IDs: $avoidIds");
        filteredMenuList = _filterByIds(avoidIds);
        print("Filtered None Can Eat: $filteredMenuList");
      } else if (index == 2) {
        // Some Can Eat (Caution)
        final cautionIds = parsedData2?['CAUTION']?.map((item) => item['id']).whereType<String>().toList() ?? [];
        print("Caution IDs: $cautionIds");
        filteredMenuList = _filterByIds(cautionIds);
        print("Filtered Some Can Eat: $filteredMenuList");
      } else if (index == 3) {
        // Safe for All (Safe)
        final safeIds = parsedData2?['SAFE']?.map((item) => item['id']).whereType<String>().toList() ?? [];
        print("Safe IDs: $safeIds");
        filteredMenuList = _filterByIds(safeIds);
        print("Filtered Safe for All: $filteredMenuList");
      }
    });
  }

  List<Map<String, dynamic>> _filterByIds(List<String> ids) {
    if (menuList == null || menuList!.isEmpty) {
      print("Menu list is null or empty");
      return [];
    }
    final filtered = menuList!.map((category) {
      final items = (category['items'] as List<dynamic>)
          .where((item) => ids.contains(item['itemId'] as String?))
          .toList();
      print("Category: ${category['category']}, Filtered Items: $items");
      return items.isNotEmpty ? {...category, 'items': items} : null;
    }).whereType<Map<String, dynamic>>().toList();
    return filtered;
  }
  Future<Map<String, dynamic>> getUserByEmail(String emailid) async {
    final response = await http.get(Uri.parse('http://13.57.29.10:7000/users/$emailid'));

    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);
      if(data["code"] == 404){
        return {
          "status": "error",
          "message": "User not found",
          "code": 404,
        };
      }
      return {
        "status": "success",
        "data": data["data"],
        "code": 200,
      };
    } else if (response.statusCode == 404) {
      return {
        "status": "error",
        "message": "User not found",
        "code": 404,
      };
    } else {
      return {
        "status": "error",
        "message": "Failed to retrieve user",
        "error": response.body,
        "code": response.statusCode,
      };
    }
  }
  Future<void> _updateUserData(Map<String, dynamic> userData) async {
    print("Updating user data...");
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
        "name": userData["name"] ?? "Unknown",
        "groupinvites":userData["groupinvites"] ?? [],
        "emergency":userData['emergency'] ?? []
      };
      print("JSON Payload being sent: ${jsonEncode(requestBody)}");

      final response = await http.put(
        Uri.parse('http://13.57.29.10:7000/users/update'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode(requestBody),
      );

      if (response.statusCode == 200 || response.statusCode == 201) {
        print(response);
        final responseData = jsonDecode(response.body);
        print("User updated successfully: ${responseData}");

      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text("Failed to save updating user: ${response.body}"),
          ),
        );
      }
    } catch (e) {
      print("Error updating user: $e");
    }
  }
  void _generateInviteLink() async {
    const String apiUrl = "http://13.57.29.10:7000/generate_group_link";

    try {
      final response = await http.post(
        Uri.parse(apiUrl),
        headers: {"Content-Type": "application/json"},
        body: jsonEncode({"group_id": widget.groupId}),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (data.containsKey('invite_link')) {
          final String inviteLink = data['invite_link'];

          Share.share(
            inviteLink,
            subject: 'Join Invitation', // Optional: subject for email
          );
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Failed to generate link')),
          );
        }
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Server error: ${response.statusCode}')),
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error: $e')),
      );
    }
  }
  Future<void> sendInviteOnEmail() async {
    try {
      // Get current group data first
      final response = await http.get(
        Uri.parse('$apiUrl/groups/${widget.groupId}'),
        headers: {'Content-Type': 'application/json'},
      );

      if (response.statusCode != 200) {
        throw Exception('Failed to fetch current group data');
      }

      final currentGroupData = jsonDecode(response.body);
      if (currentGroupData['status'] != 'success') {
        throw Exception('Failed to fetch group data: ${currentGroupData['message']}');
      }

      Map<String, dynamic> updatedGroupData = Map<String, dynamic>.from(currentGroupData['data']);

      // Initialize pendingids if it doesn't exist
      if (!updatedGroupData.containsKey('pendingids') || updatedGroupData['pendingids'] == null) {
        updatedGroupData['pendingids'] = [];
      }

      // Check and add selectedEmail to pendingids
      if (updatedGroupData['pendingids'] is List) {
        List<dynamic> pendingIds = List.from(updatedGroupData['pendingids']);
        if (!pendingIds.contains(selectedEmail)) {
          pendingIds.add(selectedEmail);
          updatedGroupData['pendingids'] = pendingIds;

          // Update group in backend
          final groupUpdateResponse = await http.put(
            Uri.parse('$apiUrl/groups/update/${widget.groupId}'),
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode(updatedGroupData),
          );

          if (groupUpdateResponse.statusCode == 200) {
            // ✅ Update local state immediately
            setState(() {
              groupData = Map<String, dynamic>.from(updatedGroupData);
              users = List<String>.from(groupData?['user_ids'] ?? []);
            });
            
            print('Group updated successfully: ${groupUpdateResponse.body}');
          } else {
            throw Exception('Failed to update group: ${groupUpdateResponse.body}');
          }
        } else {
          throw Exception('User already invited');
        }
      }

      // Update user's group invites
      final result = await getUserByEmail(selectedEmail);
      if (result['status'] == 'success') {
        print('User Data FR: ${result['data'][0]}');

        var payload = Map<String, dynamic>.from(result['data'][0]);

        List<dynamic> groupInvites = payload['groupinvites'] ?? [];
        if (groupInvites.contains(widget.groupId)) {
          throw Exception('User already has this group invite');
        } else {
          groupInvites.add(widget.groupId);
          payload['groupinvites'] = groupInvites;
          await _updateUserData(payload);
        }

        // ✅ Show success message
        Get.snackbar(
          'Invite Sent',
          'Invitation sent to $selectedEmail successfully!',
          snackPosition: SnackPosition.BOTTOM,
          duration: Duration(seconds: 3),
        );

        // ✅ Clear the selected email
        setState(() {
          selectedEmail = '';
        });
      } else {
        throw Exception('Failed to fetch user data: ${result['message']}');
      }
    } catch (e) {
      print('Error sending invite: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error sending invite: $e')),
      );
    }
  }

  Future<void> fetchGroupDetails() async {
    try {
      final response = await http.get(
        Uri.parse('$apiUrl/groups/${widget.groupId}'),
        headers: {'Content-Type': 'application/json'},
      );

      if (response.statusCode == 200) {
        final responseData = jsonDecode(response.body);
        if (responseData['status'] == 'success') {
          setState(() {
            groupData = responseData['data'];
            users = List<String>.from(groupData?['user_ids'] ?? []);
            isLoading = false;
          });
          _getCompatibility();
        } else {
          setState(() {
            errorMessage = 'Failed to fetch group: ${responseData['message']}';
            isLoading = false;
          });
        }
      } else {
        setState(() {
          errorMessage = 'Failed to fetch group: ${response.body}';
          isLoading = false;
        });
      }
    } catch (e) {
      setState(() {
        errorMessage = 'Error fetching group: $e';
        isLoading = false;
      });
    }
  }

  void filterGroupActivities() {
    setState(() {
      groupActivities = widget.activities
          .where((activity) => activity.groupId == widget.groupId)
          .toList();
    });
  }

  Future<String?> _getCachedCompatibility(String groupId, List<String> currentUserIds) async {
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
          
          // Sort both lists to ensure accurate comparison
          cachedUserIds.sort();
          currentUserIds.sort();
          
          if (_areUserListsEqual(cachedUserIds, currentUserIds)) {
            print('✅ Found cached compatibility for group $groupId: ${cachedEntry['percentage']}%');
            print('👥 User composition unchanged: $currentUserIds');
            return cachedEntry['percentage'];
          } else {
            print('⚠️ User composition changed for group $groupId');
            print('🔄 Cached users: $cachedUserIds');
            print('🔄 Current users: $currentUserIds');
            
            // Remove old cache entry since user composition changed
            compPercentList.removeWhere((entry) => entry['groupId'] == groupId);
            await prefs.setString('comp_percent_list', jsonEncode(compPercentList));
          }
        }
      }
    } catch (e) {
      print('❌ Error checking cached compatibility: $e');
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

  Future<void> _cacheCompatibilityResult(String groupId, List<String> userIds, String percentage) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      String? storedData = prefs.getString('comp_percent_list');
      
      List<Map<String, dynamic>> compPercentList = [];
      if (storedData != null) {
        compPercentList = List<Map<String, dynamic>>.from(
          jsonDecode(storedData).map((item) => Map<String, dynamic>.from(item)),
        );
      }
      
      // ✅ Remove any existing entry for this group to avoid duplicates
      compPercentList.removeWhere((entry) => entry['groupId'] == groupId);
      
      // Add new entry with user_ids and timestamp
      compPercentList.add({
        'groupId': groupId,
        'user_ids': List<String>.from(userIds)..sort(),
        'percentage': percentage,
        'timestamp': DateTime.now().toIso8601String(),
      });
      
      await prefs.setString('comp_percent_list', jsonEncode(compPercentList));
      print('💾 GroupDinner: Cached compatibility: $percentage% for group $groupId with users: $userIds');
      
      // ✅ Clear any conflicting memory cache in other screens by setting a flag
      await prefs.setBool('compatibility_cache_updated_$groupId', true);
      print('🔄 GroupDinner: Set cache update flag for group $groupId');
      
    } catch (e) {
      print('❌ GroupDinner: Error caching compatibility: $e');
    }
  }

  Future<void> _getCompatibility() async {
    // Return if already calculating
    if (_compatibilityRequest != null) {
      print('⏳ GroupDinner: Compatibility calculation already in progress');
      await _compatibilityRequest;
      return;
    }

    // Use cached value if available
    if (_cachedCompPercent != null) {
      setState(() {
        compPercent = _cachedCompPercent;
      });
      return;
    }

    if (groupData?['user_ids'] == null) return;
    
    List<String> currentUserIds = List<String>.from(groupData!['user_ids']);
    
    // Check persistent cache first
    String? cachedPercent = await _getCachedCompatibility(widget.groupId, currentUserIds);
    if (cachedPercent != null) {
      setState(() {
        compPercent = cachedPercent;
        _cachedCompPercent = cachedPercent;
      });
      return;
    }
    
    // Start calculation
    _compatibilityRequest = _performCompatibilityCalculation(currentUserIds);
    await _compatibilityRequest;
    _compatibilityRequest = null;
  }

  Future<void> _performCompatibilityCalculation(List<String> currentUserIds) async {
    try {
      print('📡 GroupDinner: Calculating compatibility for group ${widget.groupId} with users: $currentUserIds');
      
      // Add small delay to prevent race conditions
      await Future.delayed(Duration(milliseconds: 300));
      
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

      print("📤 GroupDinner: Compatibility payload: ${jsonEncode(jsonobj)}");

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
          final percentValue = match.group(1)!;
          setState(() {
            compPercent = percentValue;
            _cachedCompPercent = percentValue;
          });
          
          // Cache the result with user_ids
          await _cacheCompatibilityResult(widget.groupId, currentUserIds, percentValue);
          
          print('✅ GroupDinner: Calculated and cached compatibility: $percentValue%');
        }
      }
    } catch (e) {
      print("❌ GroupDinner: Error calculating compatibility: $e");
    }
  }

  Future<void> leaveGroup() async {
    if (widget.user?.email == null || groupData == null) return;

    try {
      // Get current group data
      final response = await http.get(
        Uri.parse('$apiUrl/groups/${widget.groupId}'),
        headers: {'Content-Type': 'application/json'},
      );

      if (response.statusCode == 200) {
        final currentGroupData = jsonDecode(response.body);
        if (currentGroupData['status'] == 'success') {
          Map<String, dynamic> updatedGroupData = Map<String, dynamic>.from(currentGroupData['data']);
          
          // Remove user from group
          List<String> userIds = List<String>.from(updatedGroupData['user_ids'] ?? []);
          userIds.remove(widget.user!.email!);
          updatedGroupData['user_ids'] = userIds;

          // Update group
          final groupUpdateResponse = await http.put(
            Uri.parse('$apiUrl/groups/update/${widget.groupId}'),
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode(updatedGroupData),
          );

          if (groupUpdateResponse.statusCode == 200) {
            // Update user's groups
            await updateUserGroups();
            
            // ✅ Call onRemoveGroup callback to update MyGroupsScreen
            if (widget.onRemoveGroup != null) {
              widget.onRemoveGroup!(widget.groupId);
            }

            // Navigate back
            Navigator.pop(context);
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Left group successfully')),
            );
          }
        }
      }
    } catch (e) {
      print('Error leaving group: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error leaving group: $e')),
      );
    }
  }

  Future<void> updateUserGroups() async {
    if (widget.user?.email == null) return;

    try {
      final userResponse = await http.get(
        Uri.parse('$apiUrl/users/${widget.user!.email}'),
        headers: {'Content-Type': 'application/json'},
      );

      if (userResponse.statusCode == 200) {
        final userData = jsonDecode(userResponse.body)['data'][0];
        List<String> userGroups = List<String>.from(userData['groups'] ?? []);
        userGroups.remove(widget.groupId);

        final updateResponse = await http.put(
          Uri.parse('$apiUrl/users/update'),
          headers: {'Content-Type': 'application/json'},
          body: jsonEncode({
            'emailid': widget.user!.email,
            'groups': userGroups,
            'name': userData['name'] ?? '',
            'phonenumber': userData['phonenumber'] ?? 0,
            'dietaryPreferences': userData['dietaryPreferences'] ?? [],
            'allergens': userData['allergens'] ?? [],
            'spiceLevel': userData['spiceLevel'] ?? 'Medium',
            'foodTemperature': userData['foodTemperature'] ?? [],
            'additionalNotes': userData['additionalNotes'] ?? '',
            'onboardingCompleted': userData['onboardingCompleted'] ?? false,
          }),
        );

        if (updateResponse.statusCode != 200) {
          print('Failed to update user groups: ${updateResponse.body}');
        }
      }
    } catch (e) {
      print('Error updating user groups: $e');
    }
  }

  void handleFilterSelected(int index) {
    setState(() {
      selectedIndex = index;
    });
  }

  Future<void> fetchEmails() async {
    const String apiUrl = "http://13.57.29.10:7000/users/emails/all";

    try {
      final response = await http.get(Uri.parse(apiUrl));

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (data['status'] == 'success') {
          List<String> emails = List<String>.from(data['emails']);
          setState(() {
            allEmails = emails;
            filteredEmails = List.from(allEmails);
          });
        } else {
          print('Failed to fetch emails: ${data['status']}');
        }
      } else {
        print('Server responded with status code: ${response.statusCode}');
      }
    } catch (e) {
      print('Error fetching emails: $e');
    }
  }

  void filterEmails(String query) {
    setState(() {
      filteredEmails = allEmails
          .where((email) => email.toLowerCase().contains(query.toLowerCase()))
          .toList();
    });
  }
  Future<void> _showInviteByEmailDialog() async {
    // Fetch emails from the API
    await fetchEmails();

    // Show the dialog
    await showDialog(
      context: context,
      builder: (BuildContext context) {
        String enteredEmail = ''; // Store typed email separately
        TextEditingController emailController = TextEditingController();

        return StatefulBuilder(
          builder: (context, setState) {
            return Dialog(
              backgroundColor: Colors.transparent,
              child: LayoutBuilder(
                builder: (context, constraints) {
                  return SingleChildScrollView(
                    child: ConstrainedBox(
                      constraints: BoxConstraints(
                        maxHeight: constraints.maxHeight,
                      ),
                      child: Container(
                        padding: EdgeInsets.only(
                          left: 16.0,
                          right: 16.0,
                          top: 16.0,
                          bottom: MediaQuery.of(context).viewInsets.bottom + 16.0,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(10.0),
                        ),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            TextField(
                              controller: emailController,
                              onChanged: (value) {
                                setState(() {
                                  enteredEmail = value; // Update typed email
                                  filterEmails(value);
                                });
                              },
                              decoration: InputDecoration(hintText: 'Type to search'),
                            ),
                            SizedBox(height: 16),
                            filteredEmails.isEmpty
                                ? Text('No matching emails')
                                : Expanded(
                              child: ListView.builder(
                                shrinkWrap: true,
                                itemCount: filteredEmails.length,
                                itemBuilder: (context, index) {
                                  return ListTile(
                                    title: Text(filteredEmails[index]),
                                    onTap: () {
                                      setState(() {
                                        enteredEmail = filteredEmails[index];
                                        emailController.text = enteredEmail; // Fill the TextField
                                      });
                                    },
                                  );
                                },
                              ),
                            ),
                            SizedBox(height: 16),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.end,
                              children: [
                                TextButton(
                                  onPressed: () {
                                    Navigator.pop(context);
                                  },
                                  child: Text('Cancel'),
                                ),
                                SizedBox(width: 8),
                                TextButton(
                                  onPressed: () {
                                    // Check if entered email is valid
                                    if (allEmails.contains(enteredEmail)) {
                                      setState(() {
                                        selectedEmail = enteredEmail; // Select it
                                      });
                                      sendInviteOnEmail();
                                      Navigator.pop(context);

                                    } else {
                                      // Show error message if email is invalid
                                      ScaffoldMessenger.of(context).showSnackBar(
                                        SnackBar(
                                          content: Text('Invalid email! Please select from the list.'),
                                        ),
                                      );
                                    }
                                  },
                                  child: Text('Invite'),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ),
                  );
                },
              ),
            );
          },
        );
      },
    );
  }


  void _getImageFromGallery() {
    // Placeholder for image scanning
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Scan feature coming soon!')),
    );
  }

  Widget buildMenuList() {
    if (filteredMenuList.isEmpty && selectedIndex2 != 0) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.all(16.0),
          child: Text("No menu items available for this filter"),
        ),
      );
    }

    List<Widget> sections = [];
    const List<Map<String, dynamic>> sectionConfig = [
      {"key": "AVOID", "icon": Icons.cancel, "color": Colors.red},
      {"key": "CAUTION", "icon": Icons.warning, "color": Colors.orange},
      {"key": "SAFE", "icon": Icons.check_circle, "color": Colors.green},
    ];

    // If showing all items (selectedIndex2 == 0), group by SAFE, CAUTION, AVOID
    if (selectedIndex2 == 0) {
      for (var config in sectionConfig) {
        String key = config["key"];
        IconData icon = config["icon"];
        Color color = config["color"];

        // Get IDs for this category from parsedData2
        final categoryIds = parsedData2?[key]?.map((item) => item['id']).toList() ?? [];
        // Filter menuList items that match these IDs
        final filteredItems = menuList?.expand((category) => (category['items'] as List<dynamic>)
            .where((item) => categoryIds.contains(item['itemId']))).toList() ?? [];

        if (filteredItems.isNotEmpty) {
          sections.add(
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 8.0, horizontal: 16.0),
              child: Text(
                key,
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: color),
              ),
            ),
          );
          sections.addAll(
            filteredItems.map((item) {
              return ListTile(
                leading: Icon(icon, color: color),
                title: Text(item["name"] ?? "Unknown"),
                subtitle: Text(item["description"] ?? "Menu item"),
                trailing: Text("\$${item['price'] != null ? item['price'] / 100 : 0}"),
              );
            }).toList(),
          );
        }
      }
    } else {
      // For filtered views (Safe, Caution, Avoid), use filteredMenuList
      String key;
      IconData icon;
      Color color;
      switch (selectedIndex2) {
        case 1: // None Can Eat (Avoid)
          key = "AVOID";
          icon = Icons.cancel;
          color = Colors.red;
          break;
        case 2: // Some Can Eat (Caution)
          key = "CAUTION";
          icon = Icons.warning;
          color = Colors.orange;
          break;
        case 3: // Safe for All (Safe)
          key = "SAFE";
          icon = Icons.check_circle;
          color = Colors.green;
          break;
        default:
          return const SizedBox.shrink(); // Shouldn’t happen
      }

      sections.add(
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 8.0, horizontal: 16.0),
          child: Text(
            key,
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: color),
          ),
        ),
      );
      sections.addAll(
        filteredMenuList.expand((category) => (category['items'] as List<dynamic>)).map((item) {
          return ListTile(
            leading: Icon(icon, color: color),
            title: Text(item["name"] ?? "Unknown"),
            subtitle: Text(item["description"] ?? "Menu item"),
            trailing: Text("\$${item['price'] != null ? item['price'] / 100 : 0}"),
          );
        }).toList(),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: sections,
    );
  }

  @override
  Widget build(BuildContext context) {
    Color progressColor = Colors.grey;
    if (compPercent != null) {
      double progressValue = double.parse(compPercent!) / 100;
      if (progressValue < 0.40) {
        progressColor = Colors.red;
      } else if (progressValue < 0.82) {
        progressColor = Colors.orange;
      } else {
        progressColor = Colors.green;
      }
    }

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () {
            Navigator.pop(context);
          },
        ),
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              groupData?["group_name"] ?? '',
              style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 4),
            Text(
              '${groupData?["user_ids"]?.length ?? 0} members',
              style: const TextStyle(fontSize: 16),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => HomeScreen(
                    user: widget.user,
                    groupId: widget.groupId,
                    groupName: groupData?["group_name"],
                    users : users,
                    compPercent: compPercent,
                  ),
                ),
              );
            },
            child: const Text('Restaurant',style: TextStyle(color: Colors.black87),),
          ),
          TextButton(onPressed: () async {
            FilePickerResult? result = await FilePicker.platform.pickFiles(
              type: FileType.custom,
              allowedExtensions: ['pdf'],
            );
            if (result != null && result.files.single.path != null) {
              await _handlePdf(result.files.single.path!);
            }
          }, child: const Text('Scan',style: TextStyle(color: Colors.black87))),
        ],
      ),
      body: isLoading
          ? const Center(child: CircularProgressIndicator())
          : groupData == null
          ? Center(child: Text(errorMessage))
          : Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 16),
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: [
                  Row(
                    children: [
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 4.0),
                        child: CircleAvatar(
                          radius: 27,
                          backgroundColor: Colors.orange[400],
                          child: const Text(
                            'You',
                            style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                          ),
                        ),
                      ),
                      ...users.asMap().entries.map((entry) {
                        int index = entry.key;
                        String userId = entry.value;
                        RegExp regex = RegExp(r'(?<=.{4})[^@]+(?=@)');
                        Match? match = regex.firstMatch(userId);

                        if (userId == widget.user?.email) return const SizedBox.shrink();

                        return Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 4.0),
                          child: Container(
                            padding: const EdgeInsets.all(2),
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              border: Border.all(color: Colors.grey, width: 1.0),
                            ),
                            child: CircleAvatar(
                              radius: 23,
                              backgroundColor: Colors.transparent,
                              child: Text(
                                match != null && match.group(0)!.isNotEmpty
                                    ? match.group(0)![0].toUpperCase()
                                    : '?',
                                style: const TextStyle(color: Colors.black45),
                              ),
                            ),
                          ),
                        );
                      }).toList(),
                    ],
                  ),
                  const SizedBox(width: 8),
                  Container(
                    padding: const EdgeInsets.all(2.0),
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      border: Border.all(color: Colors.grey),
                    ),
                    child: IconButton(
                      onPressed: () async {
                        // Show the invite option popup
                        await showDialog(
                          context: context,
                          builder: (BuildContext context) {
                            return AlertDialog(
                              title: const Text('Invite Options'),
                              content: const Text('How would you like to invite?'),
                              actions: [
                                TextButton(
                                  onPressed: () {
                                    Navigator.pop(context); // Close dialog
                                    _showInviteByEmailDialog(); // Show the email invite flow
                                  },
                                  child: const Text('Invite by Email'),
                                ),
                                TextButton(
                                  onPressed: () {
                                    Navigator.pop(context); // Close dialog
                                    _generateInviteLink();
                                  },
                                  child: const Text('Generate Link'),
                                ),
                              ],
                            );
                          },
                        );
                      },
                      icon: const Icon(Icons.add),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 10),
            Container(
              padding: const EdgeInsets.symmetric(vertical: 0, horizontal: 10),
              decoration: BoxDecoration(
                border: Border.all(color: Colors.black12),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      const Text(
                        'Group Compatibility',
                        style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                      ),
                      const Spacer(),
                      Center(
                        child: compPercent == null
                            ? const SizedBox(
                          height: 20,
                          width: 20,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                            : Text(
                          '$compPercent% Match',
                          style: const TextStyle(color: Colors.orange, fontWeight: FontWeight.w700),
                        ),
                      ),
                    ],
                  ),
                  if (compPercent != null) ...[
                    const SizedBox(height: 10),
                    TweenAnimationBuilder<double>(
                      tween: Tween<double>(begin: 0, end: double.parse(compPercent!) / 100),
                      duration: const Duration(milliseconds: 500),
                      builder: (context, value, child) {
                        return LinearProgressIndicator(
                          value: value,
                          color: progressColor,
                          backgroundColor: Colors.grey[300],
                        );
                      },
                    ),
                    const SizedBox(height: 20),
                  ],
                ],
              ),
            ),
            const SizedBox(height: 16),
            FilterBar2(selectedIndex: selectedIndex, onFilterSelected: handleFilterSelected, parsedData2: parsedData2,),
            Expanded(
              child: SingleChildScrollView(
                child: isLoading2 ? Center(child: CircularProgressIndicator(),):
                Column(
                  children: [
                    if (selectedIndex == 0) ...[
                      const SizedBox(height: 16),
                      Row(
                        children: [
                          Expanded(
                            child: GestureDetector(
                              onTap: () => _filterMenu(3), // Safe for All
                              child: Card(
                                color: Colors.green[100],
                                child: Padding(
                                  padding: const EdgeInsets.all(8.0),
                                  child: Column(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      Text(
                                        isLoading2 ? 'loading..' : '$commonSafeCount',
                                        style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                                      ),
                                      const Text('Safe for All', style: TextStyle(fontSize: 12)),
                                    ],
                                  ),
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: GestureDetector(
                              onTap: () => _filterMenu(2), // Some Can Eat
                              child: Card(
                                color: Colors.yellow[100],
                                child: Padding(
                                  padding: const EdgeInsets.all(8.0),
                                  child: Column(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      Text(
                                        isLoading2 ? 'loading..' : '$someCanEatCount',
                                        style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                                      ),
                                      const Text('Some Can Eat', style: TextStyle(fontSize: 12)),
                                    ],
                                  ),
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: GestureDetector(
                              onTap: () => _filterMenu(1), // None Can Eat
                              child: Card(
                                color: Colors.pink[100],
                                child: Padding(
                                  padding: const EdgeInsets.all(8.0),
                                  child: Column(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      Text(
                                        isLoading2 ? 'loading..' : '$noneCanEatCount',
                                        style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                                      ),
                                      const Text('None Can Eat', style: TextStyle(fontSize: 12)),
                                    ],
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      if (parsedData2 != null && menuList != null)
                        buildMenuList()
                    ] else if (selectedIndex == 1)
                      Column(
                        children: [
                          const SizedBox(height: 23),
                          Members(
                            user: widget.user,
                            groupId: widget.groupId,
                            groupData: groupData!,
                            users: users, 
                            onRemoveGroup: widget.onRemoveGroup, 
                            updateGroupDataFunc: updateGroupDataFunc,
                            onClearGroupCache: (groupId) async {
                              // Make API request to clear cache
                              try {
                                final prefs = await SharedPreferences.getInstance();
                                String? storedData = prefs.getString('comp_percent_list');
                                if (storedData != null) {
                                  List<Map<String, String>> compPercentList = List<Map<String, String>>.from(
                                    jsonDecode(storedData).map((item) => Map<String, String>.from(item)),
                                  );
                                  compPercentList.removeWhere((entry) => entry['id'] == groupId);
                                  await prefs.setString('comp_percent_list', jsonEncode(compPercentList));
                                }
                              } catch (e) {
                                print("Error clearing group cache: $e");
                              }
                            },
                          ),
                        ],
                      )
                    else
                      const Text("Suggestions"),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> removeUserFromGroup(String userEmail) async {
    // 1. Remove user from group on backend
    final groupResponse = await http.get(
      Uri.parse('http://13.57.29.10:7000/groups/${widget.groupId}'),
    );
    if (groupResponse.statusCode == 200) {
      final groupDataRaw = jsonDecode(groupResponse.body);
      if (groupDataRaw['status'] == 'success') {
        Map<String, dynamic> updatedGroupData = Map<String, dynamic>.from(groupDataRaw['data']);
        List<String> userIds = List<String>.from(updatedGroupData['user_ids'] ?? []);
        userIds.remove(userEmail);
        updatedGroupData['user_ids'] = userIds;

        // Update group in backend
        final groupUpdateResponse = await http.put(
          Uri.parse('http://13.57.29.10:7000/groups/update/${widget.groupId}'),
          headers: {'Content-Type': 'application/json'},
          body: jsonEncode(updatedGroupData),
        );

        if (groupUpdateResponse.statusCode == 200) {
          // 2. Remove group from user's group list on backend
          final userResponse = await http.get(
            Uri.parse('http://13.57.29.10:7000/users/$userEmail'),
          );
          if (userResponse.statusCode == 200) {
            final userDataRaw = jsonDecode(userResponse.body);
            if (userDataRaw['status'] == 'success') {
              Map<String, dynamic> userData = Map<String, dynamic>.from(userDataRaw['data'][0]);
              List<String> groups = List<String>.from(userData['groups'] ?? []);
              groups.remove(widget.groupId);
              userData['groups'] = groups;

              // Update user in backend
              await http.put(
                Uri.parse('http://13.57.29.10:7000/users/update'),
                headers: {'Content-Type': 'application/json'},
                body: jsonEncode(userData),
              );
            }
          }

          // 3. ✅ Update local state instantly
          setState(() {
            groupData = updatedGroupData;
            // If you have a local member list, update it here as well:
            // members = List<String>.from(updatedGroupData['user_ids'] ?? []);
          });

          // 4. Optionally, call parent callback to update MyGroupsScreen
          if (widget.onRemoveGroup != null && userEmail == widget.user?.email) {
            widget.onRemoveGroup!(widget.groupId);
          }

          // 5. Show feedback
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('User removed successfully')),
          );
        }
      }
    }
  }
}

class FilterBar2 extends StatelessWidget {
  final Map<String, List<Map<String, String>>>? parsedData2;
  final int selectedIndex;
  final Function(int) onFilterSelected;

  const FilterBar2({
    Key? key,
    required this.parsedData2,
    required this.selectedIndex,
    required this.onFilterSelected,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    // Determine filter labels based on parsedData2
    final labels = parsedData2 == null ? ["Members"] : ["Common Safe", "Members"];
    final screenWidth = MediaQuery.of(context).size.width;
    final buttonWidth = (screenWidth - 50) / labels.length;

    // Adjust selectedIndex if parsedData2 is null (only "Members" at index 0)
    final effectiveSelectedIndex = parsedData2 == null ? 0 : selectedIndex;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 0, vertical: 8.0),
      child: Container(
        decoration: BoxDecoration(
          border: Border.all(color: Colors.black12, width: 1.0),
          borderRadius: BorderRadius.circular(8.0),
        ),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8.0, vertical: 6.0),
          child: Stack(
            children: [
              Positioned(
                top: 0,
                left: effectiveSelectedIndex * buttonWidth,
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 300),
                  curve: Curves.easeInOut,
                  width: buttonWidth,
                  height: 30,
                  decoration: BoxDecoration(
                    color: Colors.orange,
                    borderRadius: BorderRadius.circular(8.0),
                  ),
                ),
              ),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: List.generate(labels.length, (index) {
                  return Expanded(
                    child: GestureDetector(
                      onTap: () => onFilterSelected(index),
                      child: SizedBox(
                        height: 30,
                        child: Center(
                          child: Text(
                            labels[index],
                            style: TextStyle(
                              color: effectiveSelectedIndex == index ? Colors.white : Colors.black54,
                              fontWeight: FontWeight.w500,
                              fontSize: 14,
                            ),
                          ),
                        ),
                      ),
                    ),
                  );
                }),
              ),
            ],
          ),
        ),
      ),
    );
  }
}