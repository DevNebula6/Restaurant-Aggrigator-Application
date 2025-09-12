import 'dart:convert';
import 'package:auth0_flutter/auth0_flutter.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'menu_analysis_page.dart';

class MenuDatabase extends StatefulWidget {
  final UserProfile? user;
  final Function(List<dynamic>)? setSavedRestaurant;

  const MenuDatabase({
    super.key,
    required this.user,
    this.setSavedRestaurant,
  });

  @override
  State<MenuDatabase> createState() => _MenuDatabaseState();
}

class _MenuDatabaseState extends State<MenuDatabase> {
  List<Map<String, dynamic>> savedRestaurants = [];
  List<Map<String, dynamic>> filteredRestaurants = [];
  bool isLoading = true;
  String searchQuery = '';
  String selectedSortOption = 'name';
  bool isAscending = true;

  @override
  void initState() {
    super.initState();
    loadSavedRestaurants();
  }

  // ✅ Cache-first loading strategy
  Future<void> loadSavedRestaurants() async {
    setState(() => isLoading = true);
    
    try {
      SharedPreferences prefs = await SharedPreferences.getInstance();
      
      // 1. First, try to load from cache
      String? cachedData = prefs.getString('saved_restaurants');
      
      if (cachedData != null && cachedData.isNotEmpty) {
        // Load from cache immediately
        List<dynamic> decoded = json.decode(cachedData);
        savedRestaurants = decoded.map((item) => 
          Map<String, dynamic>.from(item)).toList();
        
        print('✅ Loaded ${savedRestaurants.length} restaurants from cache');
        
        // Add savedAt timestamp if missing (for older saved restaurants)
        bool needsUpdate = false;
        for (var restaurant in savedRestaurants) {
          if (!restaurant.containsKey('savedAt')) {
            restaurant['savedAt'] = DateTime.now().toIso8601String();
            needsUpdate = true;
          }
        }
        
        // Update cache if we added timestamps
        if (needsUpdate) {
          await prefs.setString('saved_restaurants', json.encode(savedRestaurants));
        }
        
        filteredRestaurants = List.from(savedRestaurants);
        _sortRestaurants();
        
        setState(() => isLoading = false);
        
        // 2. Optional: Sync with backend in background (without showing loading)
        _syncWithBackendInBackground();
        
      } else {
        // 3. If cache is empty, try loading from backend
        print('📡 Cache empty, loading from backend...');
        await loadSavedRestaurantsFromBackend();
        setState(() => isLoading = false);
      }
      
    } catch (e) {
      print('❌ Error loading saved restaurants: $e');
      savedRestaurants = [];
      filteredRestaurants = [];
      setState(() => isLoading = false);
    }
  }

  // ✅ Background sync with backend (no UI loading indicator)
  Future<void> _syncWithBackendInBackground() async {
    if (widget.user?.email == null) return;
    
    try {
      final response = await http.get(
        Uri.parse('http://13.57.29.10:7000/users/${widget.user!.email}'),
        headers: {'Content-Type': 'application/json'},
      );

      if (response.statusCode == 200) {
        final userData = json.decode(response.body);
        print('User data fetched from backend: $userData');
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
            
            // Check if backend data is different from cache
            if (_isDifferentFromCache(backendRestaurants)) {
              print('🔄 Backend data differs from cache, updating...');
              
              // Update cache with backend data
              SharedPreferences prefs = await SharedPreferences.getInstance();
              await prefs.setString('saved_restaurants', json.encode(backendRestaurants));
              
              // Update UI if mounted
              if (mounted) {
                setState(() {
                  savedRestaurants = backendRestaurants;
                  filteredRestaurants = List.from(savedRestaurants);
                  _sortRestaurants();
                });
              }
              
              print('✅ Synced ${backendRestaurants.length} restaurants from backend');
            } else {
              print('✅ Cache and backend are in sync');
            }
          }
        }
      }
    } catch (e) {
      print('⚠️ Background sync failed (cache will be used): $e');
    }
  }

  // ✅ Check if backend data differs from current cache
  bool _isDifferentFromCache(List<Map<String, dynamic>> backendData) {
    if (backendData.length != savedRestaurants.length) return true;
    
    // Create sets of IDs for quick comparison
    Set<String> cacheIds = savedRestaurants.map((r) => r['id'].toString()).toSet();
    Set<String> backendIds = backendData.map((r) => r['id'].toString()).toSet();
    
    return !cacheIds.containsAll(backendIds) || !backendIds.containsAll(cacheIds);
  }

  // ✅ Fallback: Load from backend (only when cache is empty)
  Future<void> loadSavedRestaurantsFromBackend() async {
    if (widget.user?.email == null) {
      savedRestaurants = [];
      filteredRestaurants = [];
      return;
    }
    
    try {
      final response = await http.get(
        Uri.parse('http://13.57.29.10:7000/users/${widget.user!.email}'),
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
            
            // Save to cache for future use
            SharedPreferences prefs = await SharedPreferences.getInstance();
            await prefs.setString('saved_restaurants', json.encode(backendRestaurants));
            
            savedRestaurants = backendRestaurants;
            filteredRestaurants = List.from(savedRestaurants);
            _sortRestaurants();
            
            print('✅ Loaded ${backendRestaurants.length} restaurants from backend and cached');
          } else {
            savedRestaurants = [];
            filteredRestaurants = [];
          }
        }
      } else {
        print('❌ Failed to load from backend: ${response.statusCode}');
        savedRestaurants = [];
        filteredRestaurants = [];
      }
    } catch (e) {
      print('❌ Error loading from backend: $e');
      savedRestaurants = [];
      filteredRestaurants = [];
    }
  }

  // ✅ sync method to update backend with current saved restaurants
  // This should be called whenever the saved restaurants list changes
  Future<void> _syncSavedRestaurantsToBackend(List<Map<String, dynamic>> restaurantList) async {
    if (widget.user?.email == null) return;
    
    try {
      // Convert restaurant list to the format expected by backend
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

      // Update user's saved restaurants in backend
      final response = await http.put(
        Uri.parse('http://13.57.29.10:7000/users/update'),  // ✅ Fixed endpoint
        headers: {'Content-Type': 'application/json'},
        body: json.encode({
          'emailid': widget.user!.email,  // ✅ Use emailid
          'saved': savedData,
        }),
      );

      if (response.statusCode == 200) {
        print('✅ Saved restaurants synced to backend successfully');
      } else {
        print('❌ Failed to sync saved restaurants to backend: ${response.body}');
      }
    } catch (e) {
      print('❌ Error syncing saved restaurants to backend: $e');
    }
  }

  Future<void> _removeRestaurant(String restaurantId) async {
    try {
      // Show confirmation dialog
      bool? confirmed = await showDialog<bool>(
        context: context,
        builder: (BuildContext context) {
          return AlertDialog(
            title: const Text('Remove Restaurant'),
            content: const Text('Are you sure you want to remove this restaurant from your saved list?'),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(context).pop(false),
                child: const Text('Cancel'),
              ),
              TextButton(
                onPressed: () => Navigator.of(context).pop(true),
                style: TextButton.styleFrom(foregroundColor: Colors.red),
                child: const Text('Remove'),
              ),
            ],
          );
        },
      );

      if (confirmed == true) {
        // 1. Update local state and cache immediately
        savedRestaurants.removeWhere((restaurant) => restaurant['id'] == restaurantId);
        filteredRestaurants.removeWhere((restaurant) => restaurant['id'] == restaurantId);
        
        SharedPreferences prefs = await SharedPreferences.getInstance();
        await prefs.setString('saved_restaurants', json.encode(savedRestaurants));
        
        // 2. Update UI immediately
        setState(() {});
        
        // 3. Update parent callback
        if (widget.setSavedRestaurant != null) {
          widget.setSavedRestaurant!(savedRestaurants);
        }
        
        // 4. Sync to backend in background
        _syncSavedRestaurantsToBackend(savedRestaurants);
        
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Restaurant removed successfully'),
          ),
        );
      }
    } catch (e) {
      print('Error removing restaurant: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Failed to remove restaurant'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  // ✅ clear all restaurants from backend and cache
  Future<void> _clearAllRestaurants() async {
    if (savedRestaurants.isEmpty) return;

    bool? confirmed = await showDialog<bool>(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Clear All Saved Restaurants'),
          content: Text('Are you sure you want to remove all ${savedRestaurants.length} saved restaurants? This action cannot be undone.'),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: const Text('Cancel'),
            ),
            TextButton(
              onPressed: () => Navigator.of(context).pop(true),
              style: TextButton.styleFrom(foregroundColor: Colors.red),
              child: const Text('Clear All'),
            ),
          ],
        );
      },
    );

    if (confirmed == true) {
      try {
        // 1. Clear local cache immediately
        SharedPreferences prefs = await SharedPreferences.getInstance();
        await prefs.remove('saved_restaurants');
        
        // 2. Update UI immediately
        setState(() {
          savedRestaurants.clear();
          filteredRestaurants.clear();
        });
        
        // 3. Update parent callback
        if (widget.setSavedRestaurant != null) {
          widget.setSavedRestaurant!([]);
        }
        
        // 4. Clear from backend in background
        if (widget.user?.email != null) {
          http.put(
            Uri.parse('http://13.57.29.10:7000/users/update'),  // ✅ Fixed endpoint
            headers: {'Content-Type': 'application/json'},
            body: json.encode({
              'emailid': widget.user!.email,
              'saved': {},
            }),
          ).then((response) {
            if (response.statusCode == 200) {
              print('✅ Cleared all saved restaurants from backend');
            }
          }).catchError((e) {
            print('❌ Error clearing from backend: $e');
          });
        }
        
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('All saved restaurants cleared'),
            backgroundColor: Colors.green,
          ),
        );
      } catch (e) {
        print('Error clearing restaurants: $e');
      }
    }
  }

  void _searchRestaurants(String query) {
    setState(() {
      searchQuery = query;
      if (query.isEmpty) {
        filteredRestaurants = List.from(savedRestaurants);
      } else {
        filteredRestaurants = savedRestaurants.where((restaurant) {
          final name = (restaurant['name'] ?? '').toString().toLowerCase();
          return name.contains(query.toLowerCase());
        }).toList();
      }
      _sortRestaurants();
    });
  }

  void _sortRestaurants() {
    setState(() {
      filteredRestaurants.sort((a, b) {
        int comparison = 0;
        
        switch (selectedSortOption) {
          case 'name':
            comparison = (a['name'] ?? '').toString().compareTo((b['name'] ?? '').toString());
            break;
          case 'date':
            final dateA = DateTime.tryParse(a['savedAt'] ?? '') ?? DateTime.now();
            final dateB = DateTime.tryParse(b['savedAt'] ?? '') ?? DateTime.now();
            comparison = dateA.compareTo(dateB);
            break;
          case 'safeCount':
            final safeA = a['safeItemCount'] ?? 0;
            final safeB = b['safeItemCount'] ?? 0;
            comparison = safeA.compareTo(safeB);
            break;
        }
        
        return isAscending ? comparison : -comparison;
      });
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Saved Restaurants"),
        backgroundColor: Colors.white,
        foregroundColor: Colors.black,
        elevation: 1,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.black),
          onPressed: () => Navigator.pop(context),
        ),
        actions: [
          if (savedRestaurants.isNotEmpty)
            PopupMenuButton<String>(
              onSelected: (value) {
                if (value == 'clear_all') {
                  _clearAllRestaurants();
                }
              },
              itemBuilder: (context) => [
                const PopupMenuItem(
                  value: 'clear_all',
                  child: Row(
                    children: [
                      Icon(Icons.clear_all, color: Colors.red),
                      SizedBox(width: 8),
                      Text('Clear All', style: TextStyle(color: Colors.red)),
                    ],
                  ),
                ),
              ],
            ),
        ],
      ),
      body: isLoading
          ? const Center(child: CircularProgressIndicator())
          : savedRestaurants.isEmpty
              ? _buildEmptyState()
              : Column(
                  children: [
                    _buildSearchAndSort(),
                    Expanded(
                      child: filteredRestaurants.isEmpty
                          ? _buildNoResultsState()
                          : _buildRestaurantsList(),
                    ),
                  ],
                ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.bookmark_border,
            size: 80,
            color: Colors.grey[400],
          ),
          const SizedBox(height: 16),
          Text(
            'No Saved Restaurants',
            style: TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.bold,
              color: Colors.grey[600],
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Save restaurants from menu analysis\nto access them quickly here',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 16,
              color: Colors.grey[500],
            ),
          ),
          const SizedBox(height: 24),
          ElevatedButton.icon(
            onPressed: () => Navigator.pop(context),
            icon: const Icon(Icons.explore),
            label: const Text('Explore Restaurants'),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFFF9800),
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildNoResultsState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.search_off,
            size: 64,
            color: Colors.grey[400],
          ),
          const SizedBox(height: 16),
          Text(
            'No restaurants found',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: Colors.grey[600],
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Try adjusting your search terms',
            style: TextStyle(
              fontSize: 14,
              color: Colors.grey[500],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSearchAndSort() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withOpacity(0.1),
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        children: [
          // Search Bar
          TextField(
            onChanged: _searchRestaurants,
            decoration: InputDecoration(
              hintText: 'Search saved restaurants...',
              prefixIcon: const Icon(Icons.search),
              suffixIcon: searchQuery.isNotEmpty
                  ? IconButton(
                      icon: const Icon(Icons.clear),
                      onPressed: () {
                        _searchRestaurants('');
                        setState(() => searchQuery = '');
                      },
                    )
                  : null,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(color: Colors.grey[300]!),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: const BorderSide(color: Color(0xFFFF9800)),
              ),
            ),
          ),
          const SizedBox(height: 12),
          // Sort Options
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                '${filteredRestaurants.length} restaurant${filteredRestaurants.length != 1 ? 's' : ''}',
                style: TextStyle(
                  fontSize: 14,
                  color: Colors.grey[600],
                ),
              ),
              Row(
                children: [
                  DropdownButton<String>(
                    value: selectedSortOption,
                    underline: const SizedBox(),
                    items: const [
                      DropdownMenuItem(value: 'name', child: Text('Name')),
                      DropdownMenuItem(value: 'date', child: Text('Date Saved')),
                      DropdownMenuItem(value: 'safeCount', child: Text('Safe Items')),
                    ],
                    onChanged: (value) {
                      setState(() {
                        selectedSortOption = value!;
                        _sortRestaurants();
                      });
                    },
                  ),
                  IconButton(
                    icon: Icon(
                      isAscending ? Icons.arrow_upward : Icons.arrow_downward,
                      size: 20,
                    ),
                    onPressed: () {
                      setState(() {
                        isAscending = !isAscending;
                        _sortRestaurants();
                      });
                    },
                  ),
                ],
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildRestaurantsList() {
    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: filteredRestaurants.length,
      itemBuilder: (context, index) {
        final restaurant = filteredRestaurants[index];
        return _buildRestaurantCard(restaurant);
      },
    );
  }

  Widget _buildRestaurantCard(Map<String, dynamic> restaurant) {
    final safeCount = restaurant['safeItemCount'] ?? 0;
    final cautionCount = restaurant['cautionCount'] ?? 0;
    final avoidCount = restaurant['avoidCount'] ?? 0;
    final savedAt = DateTime.tryParse(restaurant['savedAt'] ?? '') ?? DateTime.now();

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: () async {
          // Navigate to MenuAnalysisPage with cached data
          final result = await Get.to(() => MenuAnalysisPage(
            id: restaurant['id'],
            name: restaurant['name'],
            user: widget.user,
            safeItemCount: safeCount,
            cautionCount: cautionCount,
            avoidCount: avoidCount,
            parsedData: restaurant['parsedData'] != null 
                ? Map<String, List<Map<String, String>>>.from(
                    (restaurant['parsedData'] as Map).map((k, v) =>
                        MapEntry(k, List<Map<String, String>>.from(
                            (v as List).map((i) => Map<String, String>.from(i))))))
                : null,
            analysisString: restaurant['analysis'] ?? 'No analysis available',
            setSavedRestaurant: widget.setSavedRestaurant,
          ));
          
          // Refresh the list when returning
          if (result != null) {
            loadSavedRestaurants();
          }
        },
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Text(
                      restaurant['name'] ?? 'Unknown Restaurant',
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  PopupMenuButton<String>(
                    onSelected: (value) {
                      if (value == 'remove') {
                        _removeRestaurant(restaurant['id']);
                      }
                    },
                    itemBuilder: (context) => [
                      const PopupMenuItem(
                        value: 'remove',
                        child: Row(
                          children: [
                            Icon(Icons.delete, color: Colors.red),
                            SizedBox(width: 8),
                            Text('Remove', style: TextStyle(color: Colors.red)),
                          ],
                        ),
                      ),
                    ],
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Text(
                'Saved ${_formatDate(savedAt)}',
                style: TextStyle(
                  fontSize: 12,
                  color: Colors.grey[600],
                ),
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  _buildStatChip('Safe', safeCount, Colors.green),
                  const SizedBox(width: 8),
                  _buildStatChip('Caution', cautionCount, Colors.orange),
                  const SizedBox(width: 8),
                  _buildStatChip('Avoid', avoidCount, Colors.red),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildStatChip(String label, int count, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Text(
        '$count $label',
        style: TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w500,
          color: color.withOpacity(0.9),
        ),
      ),
    );
  }

  String _formatDate(DateTime date) {
    final now = DateTime.now();
    final difference = now.difference(date);

    if (difference.inDays == 0) {
      if (difference.inHours == 0) {
        return '${difference.inMinutes} minutes ago';
      }
      return '${difference.inHours} hours ago';
    } else if (difference.inDays == 1) {
      return 'yesterday';
    } else if (difference.inDays < 7) {
      return '${difference.inDays} days ago';
    } else {
      return '${date.day}/${date.month}/${date.year}';
    }
  }
}