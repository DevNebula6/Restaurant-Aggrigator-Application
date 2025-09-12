import 'dart:convert';
import 'package:auth0_flutter/auth0_flutter.dart';
import 'package:flutter/material.dart' show Colors;
import 'package:get/get.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';


class PreferenceResult {
  final Map<String, List<Map<String, String>>>? parsedData;
  final List<Map<String, dynamic>>? menu;

  PreferenceResult({this.parsedData, this.menu});
}

class MenuAnalysisController extends GetxController {
  final String restaurantId;
  final String restaurantName;
  final UserProfile? user;
  final Function(List<dynamic>)? setSavedRestaurant;
  final Map<String, List<Map<String, String>>>? initialParsedData;
  final int? initialSafeCount;
  final int? initialCautionCount;
  final int? initialAvoidCount;
  final List<String>? users;
  final String? groupId;
  final String? compPercent;
  final List<Map<String, dynamic>>? initialMenuList;

  var restaurantMenu = <Map<String, dynamic>>[].obs;
  var filteredMenu = <Map<String, dynamic>>[].obs;
  var selectedIndex = 0.obs;
  var isLoading = true.obs;
  var isMenuInitialized = false.obs;
  var isAnalyzed = false.obs;
  var commonSafeCount = 0.obs;
  var someCanEatCount = 0.obs;
  var noneCanEatCount = 0.obs;
  var parsedData = Rxn<Map<String, List<Map<String, String>>>>();

  MenuAnalysisController({
    required this.restaurantId,
    required this.restaurantName,
    this.user,
    this.setSavedRestaurant,
    this.initialParsedData,
    this.initialSafeCount,
    this.initialCautionCount,
    this.initialAvoidCount,
    this.users,
    this.groupId,
    this.compPercent,
    this.initialMenuList,
  });

  @override
  void onInit() {
    super.onInit();
    initializeData().then((_) {
      debugParsedData();
    });
  }

  Future<void> initializeData() async {
    isLoading.value = true;
    
    // Check if we have initial analyzed data
    if (initialParsedData != null && 
        initialSafeCount != null && 
        initialCautionCount != null && 
        initialAvoidCount != null) {
      
      print("✅ Initializing with cached analysis data");
      parsedData.value = initialParsedData;
      commonSafeCount.value = initialSafeCount!;
      someCanEatCount.value = initialCautionCount!;
      noneCanEatCount.value = initialAvoidCount!;
      isAnalyzed.value = true; // Set analyzed state
      
      // Also set the filtered menu to show all items initially
      selectedIndex.value = 0;
    }
    
    await fetchRestaurantMenu();
    
    // If we have analyzed data, apply initial filter
    if (isAnalyzed.value) {
      handleFilterSelected(0); // Show all items initially
    }
    
    isLoading.value = false;
  }

  Future<void> fetchRestaurantMenu() async {
    if (initialMenuList != null && initialMenuList!.isNotEmpty) {
      restaurantMenu.assignAll(initialMenuList!);
      filteredMenu.assignAll(initialMenuList!);
      isMenuInitialized.value = true;
      return;
    }

    try {
      String cacheKey = 'menu_$restaurantId';
      SharedPreferences prefs = await SharedPreferences.getInstance();
      String? cachedData = prefs.getString(cacheKey);

      if (cachedData != null) {
        final Map<String, dynamic> data = json.decode(cachedData);
        final List<dynamic> menuData = data['menu'];
        restaurantMenu.assignAll(menuData.map((item) => item as Map<String, dynamic>).toList());
        filteredMenu.assignAll(restaurantMenu);
        isMenuInitialized.value = true;
        return;
      }

      final response = await http.get(
        Uri.parse('http://13.57.29.10:7000/menu/$restaurantId'),
      ).timeout(const Duration(seconds: 180));

      if (response.statusCode == 200) {
        final Map<String, dynamic> data = json.decode(response.body);
        final List<dynamic> menuData = data['menu'];

        prefs.setString(cacheKey, response.body);

        restaurantMenu.assignAll(menuData.map((item) => item as Map<String, dynamic>).toList());
        filteredMenu.assignAll(restaurantMenu);
        isMenuInitialized.value = true;
      }
    } catch (e) {
      print('Error fetching menu: $e');
    }
  }
  void debugParsedData() {
    print("==== DEBUG: MenuAnalysisController parsedData ====");
    if (parsedData.value == null) {
      print("parsedData is null");
      return;
    }
    
    print("SAFE items: ${parsedData.value!['SAFE']?.length ?? 0}");
    if (parsedData.value!['SAFE'] != null && parsedData.value!['SAFE']!.isNotEmpty) {
      print("Sample SAFE id: ${parsedData.value!['SAFE']?[0]['id']}");
    }
    
    print("CAUTION items: ${parsedData.value!['CAUTION']?.length ?? 0}");
    if (parsedData.value!['CAUTION'] != null && parsedData.value!['CAUTION']!.isNotEmpty) {
      print("Sample CAUTION id: ${parsedData.value!['CAUTION']?[0]['id']}");
    }
    
    print("AVOID items: ${parsedData.value!['AVOID']?.length ?? 0}");
    if (parsedData.value!['AVOID'] != null && parsedData.value!['AVOID']!.isNotEmpty) {
      print("Sample AVOID id: ${parsedData.value!['AVOID']?[0]['id']}");
    }
    
    // Check for a specific item format
    final firstItemId = restaurantMenu.isNotEmpty && 
        restaurantMenu[0]['items'] is List && 
        (restaurantMenu[0]['items'] as List).isNotEmpty ? 
        (restaurantMenu[0]['items'] as List)[0]['itemId']?.toString() : null;
        
    if (firstItemId != null) {
      print("First menu itemId: $firstItemId");
      print("Normalized: ${firstItemId.contains('.') ? firstItemId.split('.')[0] : firstItemId}");
    }
    print("======================================");
  }

  Map<String, List<Map<String, String>>> aggregatePreferences(
      List<Map<String, List<Map<String, String>>>> allUserPreferences,
      List<Map<String, dynamic>> menuList) {
    final Map<String, List<Map<String, String>>> aggregatedData = {
      'SAFE': [],
      'CAUTION': [],
      'AVOID': [],
    };

    final allItemIds = menuList
        .expand((category) =>
        (category['items'] as List<dynamic>).map((item) => item['itemId'].toString()))
        .toSet();

    final itemClassifications = <String, List<String>>{};

    for (var userPrefs in allUserPreferences) {
      for (var category in ['SAFE', 'CAUTION', 'AVOID']) {
        final items = userPrefs[category] ?? [];
        for (var item in items) {
          final id = item['id']!;
          itemClassifications.putIfAbsent(id, () => []).add(category);
        }
      }
    }

    for (var id in allItemIds) {
      final classifications = itemClassifications[id] ?? [];
      final item = allUserPreferences
          .expand((prefs) => prefs.values.expand((items) => items))
          .firstWhere((i) => i['id'] == id, orElse: () => {'id': id, 'name': 'Unknown'});

      if (classifications.length == allUserPreferences.length) {
        if (classifications.every((c) => c == 'SAFE')) {
          aggregatedData['SAFE']!.add(item);
        } else if (classifications.every((c) => c == 'AVOID')) {
          aggregatedData['AVOID']!.add(item);
        } else {
          aggregatedData['CAUTION']!.add(item);
        }
      } else if (classifications.isEmpty) {
        aggregatedData['AVOID']!.add(item);
      } else {
        aggregatedData['CAUTION']!.add(item);
      }
    }
    return aggregatedData;
  }

  Future<Map<String, dynamic>?> getCachedAnalysis(String key) async {
    final prefs = await SharedPreferences.getInstance();
    String? data = prefs.getString(key);
    return data != null ? json.decode(data) : null;
  }

  Future<void> cacheAnalysis(String key, Map<String, dynamic> analysis) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(key, json.encode(analysis));
  }

  /// ANALYZE (checks SharedPreferences first, saves the whole result)
  Future<void> handleAnalyse(bool isGroup) async {
    isLoading.value = true;
    List<Map<String, List<Map<String, String>>>> allUserPreferences = [];
    List<Map<String, dynamic>> fetchedMenuList = [];
    final String analysisKey = groupId != null
        ? 'analysis_${restaurantId}_group_${groupId}_${users?.join("_") ?? ""}'
        : 'analysis_${restaurantId}_${user?.email ?? ""}';

    // 1. Try to get cached analysis
    Map<String, dynamic>? cached = await getCachedAnalysis(analysisKey);
    if (cached != null) {
      parsedData.value = Map<String, List<Map<String, String>>>.from(
        (cached['parsedData'] as Map).map((k, v) =>
            MapEntry(k, List<Map<String, String>>.from((v as List).map((i) => Map<String, String>.from(i)))),
        ),
      );
      fetchedMenuList = List<Map<String, dynamic>>.from(cached['menu']);
      restaurantMenu.assignAll(fetchedMenuList);
      filteredMenu.assignAll(fetchedMenuList);
      commonSafeCount.value = parsedData.value?['SAFE']?.length ?? 0;
      someCanEatCount.value = parsedData.value?['CAUTION']?.length ?? 0;
      noneCanEatCount.value = parsedData.value?['AVOID']?.length ?? 0;
      isAnalyzed.value = true;
      isLoading.value = false;
      return;
    }

    // 2. Else, call backend and cache result
    try {
      if (isGroup && groupId != null && users != null) {
        final futures = users!.map((email) => _fetchUserPreference(email));
        final results = await Future.wait(futures);

        for (final result in results) {
          if (result.parsedData != null) {
            allUserPreferences.add(result.parsedData!);
          }
          if (result.menu != null && fetchedMenuList.isEmpty) {
            fetchedMenuList = result.menu!;
          }
        }
      } else if (user != null) {
        final result = await _fetchUserPreference(user!.email!);
        if (result.parsedData != null) {
          allUserPreferences.add(result.parsedData!);
        }
        if (result.menu != null) {
          fetchedMenuList = result.menu!;
        }
      }

      if (allUserPreferences.isNotEmpty) {
        if (fetchedMenuList.isEmpty && restaurantMenu.isNotEmpty) {
          fetchedMenuList = restaurantMenu;
        }

        if (fetchedMenuList.isNotEmpty) {
          Map<String, List<Map<String, String>>> aggregatedData =
          aggregatePreferences(allUserPreferences, fetchedMenuList);

          restaurantMenu.assignAll(fetchedMenuList);
          filteredMenu.assignAll(fetchedMenuList);
          parsedData.value = aggregatedData;
          commonSafeCount.value = aggregatedData['SAFE']?.length ?? 0;
          someCanEatCount.value = aggregatedData['CAUTION']?.length ?? 0;
          noneCanEatCount.value = aggregatedData['AVOID']?.length ?? 0;
          isAnalyzed.value = true;

          // Save analysis to local preference
          await cacheAnalysis(
            analysisKey,
            {'parsedData': aggregatedData, 'menu': fetchedMenuList},
          );
        }
      }
    } catch (e) {
      print('Error in analysis: $e');
    } finally {
      isLoading.value = false;
    }
  }

  /// Fetch preferences for a single user (no duplicate network calls)
  Future<PreferenceResult> _fetchUserPreference(String email) async {
    final String prefKey = 'user_preference_${restaurantId}_$email';
    final SharedPreferences prefs = await SharedPreferences.getInstance();

    // Try to get from cache first
    String? cachedData = prefs.getString(prefKey);
    if (cachedData != null) {
      try {
        final data = json.decode(cachedData);
        var menuRaw = data['menu'];
        List<Map<String, dynamic>>? menuList;
        if (menuRaw is List) {
          menuList = menuRaw.map<Map<String, dynamic>>((e) => Map<String, dynamic>.from(e)).toList();
        } else {
          menuList = null;
        }
        return PreferenceResult(
          parsedData: Map<String, List<Map<String, String>>>.from(
            (data['parsedData'] as Map).map((k, v) =>
                MapEntry(k, List<Map<String, String>>.from((v as List).map((i) => Map<String, String>.from(i))))
            ),
          ),
          menu: menuList,
        );
      } catch (e, stack) {
        print("Cache decode error: $e\n$stack");
      }
    }

    try {
      Map<String, dynamic> payload = {
        "restuarant_id": restaurantId,
        "email_id": email,
      };

      final response = await http.post(
        Uri.parse('http://13.57.29.10:7000/users/get_preferences'),
        headers: {"Content-Type": "application/json"},
        body: json.encode(payload),
      ).timeout(const Duration(seconds: 300));

      if (response.statusCode == 200) {
        final responseData = json.decode(response.body);

        List<Map<String, dynamic>>? menuList;
        if (responseData.containsKey('response_menu') && responseData['response_menu'] != null) {
          var menuRaw = responseData['response_menu'];
          if (menuRaw is Map && menuRaw.containsKey('menu')) {
            var menuField = menuRaw['menu'];
            if (menuField is List) {
              menuList = menuField.map<Map<String, dynamic>>((e) => Map<String, dynamic>.from(e)).toList();
            }
          } else if (menuRaw is List) {
            menuList = menuRaw.map<Map<String, dynamic>>((e) => Map<String, dynamic>.from(e)).toList();
          }
        }

        if (responseData.containsKey('result')) {
          dynamic resultRaw = responseData['result'];
          print('resultRaw type: ${resultRaw.runtimeType}, value: $resultRaw');
          String resultText = '';
          if (resultRaw is List && resultRaw.isNotEmpty && resultRaw[0] is Map && resultRaw[0].containsKey('text')) {
            resultText = resultRaw[0]['text'];
          } else if (resultRaw is String) {
            resultText = resultRaw;
          } else {
            print("Unexpected result type: ${resultRaw.runtimeType}, value: $resultRaw");
            return PreferenceResult();
          }

          final regex = RegExp(r'id=([^\s]+)\sclass=([^\>]+)>(.*?)<');
          final matches = regex.allMatches(resultText);
          final Map<String, List<Map<String, String>>> parsedData = {};

          print('--- Start Regex Parse ---');
          for (final match in matches) {
            final id = match.group(1) ?? '';
            final category = match.group(2) ?? '';
            final name = match.group(3) ?? '';
            print('Regex match: id="$id", category="$category", name="$name"');
            if (id.isNotEmpty && category.isNotEmpty && name.isNotEmpty) {
              parsedData.putIfAbsent(category, () => []);
              parsedData[category]!.add({'id': id, 'name': name});
              print(' --> Added to "$category": {id: $id, name: $name}');
            } else {
              print(' --> SKIPPED: id="$id", category="$category", name="$name"');
            }
          }
          print('--- End Regex Parse ---');
          // Print summary of all categories
          parsedData.forEach((key, value) {
            print('Category "$key": ${value.length} items');
            for (var item in value) {
              print('   - ${item['id']} : ${item['name']}');
            }
          });

          await prefs.setString(
            prefKey,
            json.encode({
              'parsedData': parsedData,
              'menu': menuList ?? [],
            }),
          );

          return PreferenceResult(parsedData: parsedData, menu: menuList);
        }
      }
    } catch (e, stack) {
      print('Error fetching preference for $email: $e\n$stack');
    }

    return PreferenceResult();
  }

  void handleFilterSelected(int index) {
    if (!isMenuInitialized.value || parsedData.value == null) return;
    selectedIndex.value = index;

    if (index == 0) {
      filteredMenu.assignAll(restaurantMenu);
    } else {
      String category;
      switch (index) {
        case 1:
          category = 'SAFE';
          break;
        case 2:
          category = 'CAUTION';
          break;
        case 3:
          category = 'AVOID';
          break;
        default:
          category = 'SAFE';
      }

      final ids = parsedData.value![category]?.map((item) => item['id']!).toList() ?? [];
      filteredMenu.assignAll(_filterMenuByIds(ids));
    }
  }

  List<Map<String, dynamic>> _filterMenuByIds(List<String> ids) {
    if (ids.isEmpty) return [];
    return restaurantMenu
        .map((category) {
      final categoryMap = Map<String, dynamic>.from(category);
      final items = (categoryMap['items'] as List<dynamic>)
          .where((item) => ids.contains(item['itemId'].toString()))
          .toList();
      if (items.isNotEmpty) {
        return {...categoryMap, 'items': items};
      }
      return null;
    })
        .where((category) => category != null)
        .cast<Map<String, dynamic>>()
        .toList();
  }

  Future<Map<String, dynamic>> getUserByEmail(String emailid) async {
    final response = await http.get(Uri.parse('http://13.57.29.10:7000/users/$emailid'));

    if (response.statusCode == 200) {
      final data = json.decode(response.body);
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

  Future<void> _updateUserData(Map<String, dynamic> userData) async {
    print("Updating user data with saved restaurants...");
    try {
      final Map<String, dynamic> requestBody = {
        "additionalNotes": userData["additionalNotes"] ?? "",
        "groups": userData["groups"] ?? [],
        "onboardingCompleted": userData["onboardingCompleted"] ?? true,
        "foodTemperature": userData["foodTemperature"] ?? [],
        "userid": userData["userid"] ?? "",
        "allergens": userData["allergens"] ?? [],
        "phonenumber": userData["phonenumber"] ?? "",
        "spiceLevel": userData["spiceLevel"] ?? "Medium",
        "emailid": userData["emailid"] ?? "",
        "dietary": userData["dietary"] ?? [],
        "name": userData["name"] ?? "Unknown",
        "groupinvites": userData["groupinvites"] ?? [],
        "emergency": userData["emergency"] ?? [],
        "saved": userData["saved"] ?? {},
      };

      print("📤 Full update payload: ${json.encode(requestBody)}");

      final response = await http.put(
        Uri.parse('http://13.57.29.10:7000/users/update'),
        headers: {'Content-Type': 'application/json'},
        body: json.encode(requestBody),
      );

      if (response.statusCode == 200) {
        print("✅ User updated successfully with saved restaurants: ${response.body}");
      } else {
        print("❌ Failed to update user: ${response.statusCode} - ${response.body}");
        throw Exception('Failed to update user data: ${response.body}');
      }
    } catch (e) {
      print("❌ Error updating user: $e");
      throw e;
    }
  }

  Future<void> _syncSavedRestaurantsToBackend(List<dynamic> restaurantList) async {
    if (user?.email == null) return;
    
    try {
      print('🔄 Fetching current user data to update saved restaurants...');
      
      // 1. Get current user data (same pattern as acceptInvite)
      final userResponse = await getUserByEmail(user!.email!);
      if (userResponse['status'] != 'success') {
        throw Exception('Failed to fetch user data: ${userResponse['message']}');
      }

      final userData = userResponse['data'][0];
      print('📊 Current user data retrieved for: ${userData['emailid']}');

      // 2. Convert restaurant list to the format expected by backend
      Map<String, dynamic> savedData = {};
      for (var restaurant in restaurantList) {
        savedData[restaurant['id']] = {
          'name': restaurant['name'],
          'id': restaurant['id'],
          'safeItemCount': restaurant['safeItemCount'],
          'cautionCount': restaurant['cautionCount'],
          'avoidCount': restaurant['avoidCount'],
          'parsedData': restaurant['parsedData'],
          'analysis': restaurant['analysis'],
          'savedAt': restaurant['savedAt'],
          'lastAnalyzed': restaurant['lastAnalyzed'],
        };
      }

      // 3. Update user data with new saved restaurants (preserve all existing fields)
      Map<String, dynamic> updatedUserData = Map<String, dynamic>.from(userData);
      updatedUserData['saved'] = savedData;

      print('💾 Updating user with ${savedData.length} saved restaurants');
      
      // 4. Update user data in backend using the centralized method
      await _updateUserData(updatedUserData);
      
      print('✅ Saved restaurants synced to backend successfully');
    } catch (e) {
      print('❌ Error syncing saved restaurants to backend: $e');
      // Don't throw here to avoid breaking the save flow
    }
  }

  Future<void> saveRestaurant() async {
    if (setSavedRestaurant == null) return;

    try {
      if (!isAnalyzed.value) {
        Get.snackbar(
          'Analyzing Menu', 
          'Please wait while we analyze the menu for you...',
          duration: Duration(seconds: 2),
        );
        
        await handleAnalyse(groupId != null);
        
        if (!isAnalyzed.value || parsedData.value == null) {
          Get.snackbar(
            'Analysis Failed', 
            'Unable to analyze menu. Please try again.',
            backgroundColor: Colors.red,
            colorText: Colors.white,
          );
          return;
        }
      }

      // Get existing restaurants from cache
      SharedPreferences prefs = await SharedPreferences.getInstance();
      String key = 'saved_restaurants';
      List<dynamic> restaurantList = [];
      String? existingData = prefs.getString(key);
      if (existingData != null) {
        restaurantList = json.decode(existingData);
      }

      bool isRestaurantAlreadySaved = restaurantList.any(
        (restaurant) => restaurant['id'] == restaurantId
      );

      if (isRestaurantAlreadySaved) {
        Get.snackbar('Already Saved', 'Restaurant already saved!');
        return;
      }

      Map<String, dynamic> currentRestaurant = {
        'name': restaurantName,
        'id': restaurantId,
        'safeItemCount': commonSafeCount.value,
        'cautionCount': someCanEatCount.value,
        'avoidCount': noneCanEatCount.value,
        'parsedData': parsedData.value,
        'analysis': 'Analyzed on ${DateTime.now().toString()}',
        'savedAt': DateTime.now().toIso8601String(), 
        'lastAnalyzed': DateTime.now().toIso8601String(),
      };

      // Add to local list
      restaurantList.add(currentRestaurant);
      
      // 1. ✅ Update cache immediately
      await prefs.setString(key, json.encode(restaurantList));
      
      // 2. ✅ Update parent (which updates HomeController)
      setSavedRestaurant!(restaurantList);
      
      // 3. ✅ Sync to backend in background (no await)
      _syncSavedRestaurantsToBackend(restaurantList);

      Get.snackbar(
        'Success', 
        'Restaurant analyzed and saved successfully!',
      );
    } catch (e) {
      print('Error saving restaurant: $e');
      Get.snackbar(
        'Error', 
        'Failed to save restaurant: $e',
        backgroundColor: Colors.red,
        colorText: Colors.white,
      );
    }
  }
}