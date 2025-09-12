import 'dart:convert';
import 'package:auth0_flutter/auth0_flutter.dart';
import 'package:geolocator/geolocator.dart';
import 'package:get/get.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

class HomeController extends GetxController {
  var userPreferences = <String, dynamic>{}.obs;
  var isLoading = true.obs;
  var restaurants = <dynamic>[].obs;
  var filteredRestaurants = <dynamic>[].obs;
  var currentPosition = Rx<Position?>(null);
  var safeItemsCount = <String, int>{}.obs;
  var cautionCount = <String, int>{}.obs;
  var avoidCount = <String, int>{}.obs;
  var restaurantParsedData = <String, Map<String, List<Map<String, String>>>>{}.obs;
  var failedRestaurantIds = <String>[].obs;
  var savedRestaurants = <Map<String, dynamic>>[].obs;
  var isLoadingSaved = true.obs;
  var analysis = ''.obs;
  var loadingRestaurants = <String>{}.obs;
  var selectedIndex = 0.obs;
  var currentStartIndex = 0.obs;
  var currentEndIndex = 4.obs;
  var isLoadingMore = false.obs;
  UserProfile? user;

  HomeController({this.user});

  @override
  void onInit() {
    initializeHomeData();
    getCurrentLocation();
    super.onInit();
  }

  // Initialize all home data
  Future<void> initializeHomeData() async {

    // Load saved restaurants using cache-first approach
    await loadSavedRestaurants();
    // Load other data (restaurants, user preferences, etc.)
    await getUserPreferences();
    await getCurrentLocation();
    // ... other initialization
  }

  void setSelectedIndex(int index) {
    selectedIndex.value = index;
  }

  Future<void> getUserPreferences() async {
    final prefs = await SharedPreferences.getInstance();
    String? userPreferencesString = prefs.getString('userPreferences');
    if (userPreferencesString != null) {
      userPreferences.value = jsonDecode(userPreferencesString);
    }
  }

  Future<void> getCurrentLocation() async {
    LocationPermission permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.deniedForever) {
        print('Location permissions are permanently denied.');
        return;
      }
    }

    Position position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high);
    currentPosition.value = position;
    await fetchRestaurants(
        position.latitude,
        position.longitude,
        20000,
        currentStartIndex.value,
        currentEndIndex.value
    );
  }

  Future<void> fetchRestaurants(double latitude, double longitude, double radius, int startIndex, int endIndex) async {
    final url = Uri.parse(
        'http://13.57.29.10:7000/nearest_restaurants?x=$startIndex&y=$endIndex&latitude=$longitude&longitude=$latitude');

    print('Fetching restaurants from: $url');

    try {
      isLoadingMore.value = true;
      final response = await http.get(url).timeout(const Duration(seconds: 10));
      if (response.statusCode == 200) {
        final decodedResponse = json.decode(response.body);
        if (decodedResponse['data'] is List) {
          final normalizedRestaurants = (decodedResponse['data'] as List).map((restaurant) {
            return {
              'id': restaurant['restuarantid'] ?? '',
              'name': restaurant['name_rest'] ?? 'Unknown Restaurant',
              'price_level': restaurant['price_level'],
              'rating': restaurant['rating'],
              'address': restaurant['address'],
              'hours': restaurant['hours'],
              'review_count': restaurant['review_count'],
              'city': restaurant['city'],
              'photos': restaurant['photos'],
              'updated_at': restaurant['updated_at'],
              'categories': restaurant['categories'] ?? [],
              'longitude': restaurant['longitude'],
              'website_url': restaurant['website_url'],
              'latitude': restaurant['latitude'],
              'phone': restaurant['phone'],
              'distance': restaurant['distance'] ?? 0.0,
              'image_url': restaurant['photos'] is List && (restaurant['photos'] as List).isNotEmpty
                  ? (restaurant['photos'] as List)[0]
                  : null,
            };
          }).toList();

          final existingIds = restaurants.map((r) => r['id']).toSet();
          final newRestaurants = normalizedRestaurants.where((r) => !existingIds.contains(r['id'])).toList();
          restaurants.addAll(newRestaurants);
          filteredRestaurants.value = List<dynamic>.from(restaurants);

          isLoading.value = false;

          await loadAllCachedData();

          // No API call here! Only load cache.
        } else {
          print("Error: 'data' is not a list");
        }
      } else {
        print('Error: ${response.statusCode}');
      }
    } catch (e) {
      print('Failed to fetch restaurants: $e');
    } finally {
      isLoadingMore.value = false;
    }
  }

  Future<void> loadMoreRestaurants() async {
    if (currentEndIndex.value >= 40 || isLoadingMore.value) return;

    currentStartIndex.value = currentEndIndex.value;
    currentEndIndex.value += 4;

    if (currentPosition.value != null) {
      await fetchRestaurants(
        currentPosition.value!.latitude,
        currentPosition.value!.longitude,
        20000,
        currentStartIndex.value,
        currentEndIndex.value,
      );
    }
  }

  Future<void> loadSingleRestaurantCache(String restaurantId) async {
    final prefs = await SharedPreferences.getInstance();

    String? safeCountJson = prefs.getString('safeItemsCount_$restaurantId');
    if (safeCountJson != null) {
      final val = jsonDecode(safeCountJson);
      print('[DEBUG] safeItemsCount for $restaurantId: $val');
      safeItemsCount[restaurantId] = val as int;
    } else {
      print('[DEBUG] safeItemsCount for $restaurantId not found in prefs');
      safeItemsCount.remove(restaurantId);
    }

    String? cautionCountJson = prefs.getString('cautionCount_$restaurantId');
    if (cautionCountJson != null) {
      final val = jsonDecode(cautionCountJson);
      print('[DEBUG] cautionCount for $restaurantId: $val');
      cautionCount[restaurantId] = val as int;
    } else {
      print('[DEBUG] cautionCount for $restaurantId not found in prefs');
      cautionCount.remove(restaurantId);
    }

    String? avoidCountJson = prefs.getString('avoidCount_$restaurantId');
    if (avoidCountJson != null) {
      final val = jsonDecode(avoidCountJson);
      print('[DEBUG] avoidCount for $restaurantId: $val');
      avoidCount[restaurantId] = val as int;
    } else {
      print('[DEBUG] avoidCount for $restaurantId not found in prefs');
      avoidCount.remove(restaurantId);
    }

    String? parsedDataJson = prefs.getString('parsedData_$restaurantId');
    if (parsedDataJson != null) {
      final parsedMap = (jsonDecode(parsedDataJson) as Map<String, dynamic>).map(
            (key, value) => MapEntry(
          key,
          (value as List).map((item) => Map<String, String>.from(item)).toList(),
        ),
      );
      print('[DEBUG] parsedData for $restaurantId loaded, keys: ${parsedMap.keys}');
      restaurantParsedData[restaurantId] = parsedMap;
    } else {
      print('[DEBUG] parsedData for $restaurantId not found in prefs');
      restaurantParsedData.remove(restaurantId);
    }

    // If you use .obs maps, call refresh()
    safeItemsCount.refresh();
    cautionCount.refresh();
    avoidCount.refresh();
    restaurantParsedData.refresh();

    print('[DEBUG] Refreshed obs maps after loadSingleRestaurantCache for $restaurantId');
    print('[DEBUG] Current safeItemsCount: $safeItemsCount');
    print('[DEBUG] Current cautionCount: $cautionCount');
    print('[DEBUG] Current avoidCount: $avoidCount');
  }

  Future<void> loadSavedRestaurants() async {
    isLoadingSaved.value = true;
    
    try {
      SharedPreferences prefs = await SharedPreferences.getInstance();
      
      // 1. First, try to load from cache
      String? cachedData = prefs.getString('saved_restaurants');
      
      if (cachedData != null && cachedData.isNotEmpty) {
        // Load from cache immediately
        List<dynamic> decoded = json.decode(cachedData);
        savedRestaurants.value = decoded.map((item) => 
          Map<String, dynamic>.from(item)).toList();
        
        print('✅ Home: Loaded ${savedRestaurants.length} restaurants from cache');
        isLoadingSaved.value = false;
        
        // Optional: Sync with backend in background
        _syncSavedRestaurantsFromBackend(savedRestaurants);
        
      } else {
        // 2. If cache is empty, load from backend during login
        print('📡 Home: Cache empty, loading from backend...');
        await _loadSavedRestaurantsFromBackend();
        isLoadingSaved.value = false;
      }
      
    } catch (e) {
      print('❌ Home: Error loading saved restaurants: $e');
      savedRestaurants.value = [];
      isLoadingSaved.value = false;
    }
  }

  // ✅ Load from backend and cache the result
  Future<void> _loadSavedRestaurantsFromBackend() async {
    if (user?.email == null) {
      savedRestaurants.value = [];
      return;
    }
    
    try {
      final response = await http.get(
        Uri.parse('http://13.57.29.10:7000/users/${user!.email}'),
        headers: {'Content-Type': 'application/json'},
      );

      if (response.statusCode == 200) {
        final userData = json.decode(response.body);
        if (userData['status'] == 'success' && userData['data'] != null) {
          final userInfo = userData['data'][0];
          final savedData = userInfo['saved'] ?? {};
          
          if (savedData is Map && savedData.isNotEmpty) {
            // Convert backend format to local format
            List<Map<String, dynamic>> backendRestaurants = [];
            savedData.forEach((key, value) {
              if (value is Map<String, dynamic>) {
                backendRestaurants.add(Map<String, dynamic>.from(value));
              }
            });
            
            // Update observable
            savedRestaurants.value = backendRestaurants;
            
            // Cache for future use
            SharedPreferences prefs = await SharedPreferences.getInstance();
            await prefs.setString('saved_restaurants', json.encode(backendRestaurants));
            
            print('✅ Home: Loaded and cached ${backendRestaurants.length} restaurants from backend');
          } else {
            savedRestaurants.value = [];
          }
        }
      }
    } catch (e) {
      print('❌ Home: Error loading from backend: $e');
      savedRestaurants.value = [];
    }
  }

  // ✅ Background sync (no loading indicator)
  Future<void> _syncSavedRestaurantsFromBackend(List<dynamic> restaurantList) async {
    if (user?.email == null) return;
    
    try {
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

      final response = await http.put(
        Uri.parse('http://13.57.29.10:7000/users/update'),  // ✅ Fixed endpoint
        headers: {'Content-Type': 'application/json'},
        body: json.encode({
          'emailid': user!.email, 
          'saved': savedData,
        }),
      );

      if (response.statusCode == 200) {
        print('✅ Home: Restaurants synced to backend successfully');
      } else {
        print('❌ Home: Backend sync failed: ${response.statusCode} - ${response.body}');
      }
    } catch (e) {
      print('❌ Home: Backend sync error: $e');
    }
  }

  // ✅ Update setSavedRestaurant to use cache-first approach
  void setSavedRestaurant(List<dynamic> restaurants) {
    // Update observable immediately
    savedRestaurants.value = restaurants.map((item) => 
      Map<String, dynamic>.from(item)).toList();
    
    // Update cache immediately
    _updateCache(restaurants);
    
    // Sync to backend in background (no await)
    _syncSavedRestaurantsToBackend(restaurants);
  }

  // ✅ Update cache immediately
  Future<void> _updateCache(List<dynamic> restaurants) async {
    try {
      SharedPreferences prefs = await SharedPreferences.getInstance();
      await prefs.setString('saved_restaurants', json.encode(restaurants));
      print('✅ Home: Cache updated with ${restaurants.length} restaurants');
    } catch (e) {
      print('❌ Home: Cache update failed: $e');
    }
  }

  // ✅ Background sync to backend
  Future<void> _syncSavedRestaurantsToBackend(List<dynamic> restaurantList) async {
    if (user?.email == null) return;
    
    try {
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

      final updatePayload = {
        'emailid': user!.email,
        'saved': savedData,
      };

      print('🔄 Home: Syncing ${restaurantList.length} restaurants to backend...');
      print('📤 Home: Payload: ${json.encode(updatePayload)}');

      // ✅ Use the CORRECT endpoint
      final response = await http.put(
        Uri.parse('http://13.57.29.10:7000/users/update'),
        headers: {'Content-Type': 'application/json'},
        body: json.encode(updatePayload),
      );
      print('🔄 Home: Backend response: ${response.statusCode} - ${response.body}');
      if (response.statusCode == 200) {
        print('✅ Home: Restaurants synced to backend successfully');
      } else {
        print('❌ Home: Backend sync failed: ${response.statusCode} - ${response.body}');
      }
    } catch (e) {
      print('❌ Home: Backend sync error: $e');
    }
  }


  Future<void> loadAllCachedData() async {
    final prefs = await SharedPreferences.getInstance();
    for (var restaurant in restaurants) {
      String id = restaurant['id'];
      String? safeCountJson = prefs.getString('safeItemsCount_$id');
      if (safeCountJson != null) {
        safeItemsCount[id] = jsonDecode(safeCountJson) as int;
      }
      String? cautionCountJson = prefs.getString('cautionCount_$id');
      if (cautionCountJson != null) {
        cautionCount[id] = jsonDecode(cautionCountJson) as int;
      }
      String? avoidCountJson = prefs.getString('avoidCount_$id');
      if (avoidCountJson != null) {
        avoidCount[id] = jsonDecode(avoidCountJson) as int;
      }
      String? parsedDataJson = prefs.getString('parsedData_$id');
      if (parsedDataJson != null) {
        restaurantParsedData[id] = (jsonDecode(parsedDataJson) as Map<String, dynamic>).map(
              (key, value) => MapEntry(
            key,
            (value as List).map((item) => Map<String, String>.from(item)).toList(),
          ),
        );
      }
    }
  }

  // No API call for safe/caution/avoid/parsedData here.
  // These are only set when MenuAnalysisPage's analyze button is pressed and that controller saves to shared prefs.

  void filterRestaurants(String query) {
    if (query.isEmpty) {
      filteredRestaurants.value = restaurants;
    } else {
      filteredRestaurants.value = restaurants
          .where((restaurant) => restaurant['name'].toLowerCase().contains(query.toLowerCase()))
          .toList();
    }
  }

  Future<void> saveRestaurantsToLocalStorage() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('restaurants', json.encode(restaurants));
  }
}