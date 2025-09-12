import 'dart:async';

import 'package:auth0_flutter/auth0_flutter.dart';
import 'package:easibite/screens/MyGroupsScreen.dart';
import 'package:easibite/screens/profile_page.dart';
import 'package:easibite/screens/scan_menu_page.dart';
import 'package:easibite/widgets/custom_bottom_nav_bar.dart';
import 'package:flutter/material.dart';

import '../ViewModel/HomeViewController.dart';
import '../widgets/custom_app_bar.dart';
import 'menu_analysis_page.dart';

import 'package:get/get.dart';

class HomeScreen extends StatelessWidget {
  final UserProfile? user;
  final String? groupId;
  final String? groupName;
  final List<String>? users;
  final String? compPercent;

  const HomeScreen({
    super.key,
    this.user,
    this.groupId,
    this.groupName,
    this.users,
    this.compPercent,
  });

  @override
  Widget build(BuildContext context) {
    final HomeController controller = Get.put(HomeController(user: user), tag: UniqueKey().toString());
    final ScrollController scrollController = ScrollController();

    scrollController.addListener(() {
      if (scrollController.position.pixels >= scrollController.position.maxScrollExtent - 200 &&
          !controller.isLoadingMore.value &&
          controller.currentEndIndex.value < 40) {
        controller.loadMoreRestaurants();
      }
    });

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: PreferredSize(
        preferredSize: const Size.fromHeight(kToolbarHeight),
        child: Obx(() => controller.selectedIndex.value == 1 ||
            controller.selectedIndex.value == 2 ||
            controller.selectedIndex.value == 3
            ? const SizedBox.shrink()
            : CustomAppBar(
          user: user,
          userPreferences: controller.userPreferences,
          setIndex: controller.setSelectedIndex,
          groupName: groupName,
        )),
      ),
      bottomNavigationBar: CustomBottomNavBar(
        user: user,
        setIndex: controller.setSelectedIndex,
        selectedIndex: controller.selectedIndex.value,
      ),
      body: Obx(() => controller.selectedIndex.value == 0
          ? Padding(
        padding: const EdgeInsets.all(16.0),
        child: SingleChildScrollView(
          controller: scrollController,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Hi ${user?.name ?? 'User'}, what\'s your craving today?',
                style: const TextStyle(
                  fontSize: 17.05,
                  fontWeight: FontWeight.w700,
                  height: 51.86 / 60.05,
                  decoration: TextDecoration.none,
                  decorationStyle: TextDecorationStyle.solid,
                ),
              ),
              const SizedBox(height: 17),
              TextField(
                decoration: InputDecoration(
                  hintText: 'Search menu, restaurant or etc',
                  prefixIcon: const Icon(Icons.search),
                  suffixIcon: IconButton(
                    icon: const Icon(Icons.tune),
                    onPressed: () {
                      double _sliderValue = 1000;
                      showDialog(
                        context: context,
                        builder: (BuildContext context) {
                          return StatefulBuilder(
                            builder: (context, setState) {
                              return AlertDialog(
                                title: const Text("Filter Options"),
                                content: Column(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    const Text("Select Range in Miles:"),
                                    const SizedBox(height: 20),
                                    Slider(
                                      value: _sliderValue,
                                      min: 900,
                                      max: 40000,
                                      divisions: 398,
                                      label: _sliderValue.round().toString(),
                                      onChanged: (double value) {
                                        setState(() {
                                          _sliderValue = value;
                                        });
                                      },
                                    ),
                                    Text(
                                        "Selected Value: ${_sliderValue.round()} Miles"),
                                  ],
                                ),
                                actions: [
                                  TextButton(
                                    onPressed: () async {
                                      if (controller.currentPosition.value != null) {
                                        controller.currentStartIndex.value = 0;
                                        controller.currentEndIndex.value = 4;
                                        controller.restaurants.clear();
                                        controller.filteredRestaurants.clear();
                                        controller.fetchRestaurants(
                                            controller.currentPosition.value!.latitude,
                                            controller.currentPosition.value!.longitude,
                                            20000,
                                            controller.currentStartIndex.value,
                                            controller.currentEndIndex.value);
                                      }
                                      Navigator.of(context).pop();
                                    },
                                    child: const Text("Reset"),
                                  ),
                                  const Spacer(),
                                  TextButton(
                                    onPressed: () => Navigator.of(context).pop(),
                                    child: const Text("Cancel"),
                                  ),
                                  TextButton(
                                    onPressed: () async {
                                      if (controller.currentPosition.value != null) {
                                        controller.currentStartIndex.value = 0;
                                        controller.currentEndIndex.value = 4;
                                        controller.restaurants.clear();
                                        controller.filteredRestaurants.clear();
                                        controller.fetchRestaurants(
                                            controller.currentPosition.value!.latitude,
                                            controller.currentPosition.value!.longitude,
                                            _sliderValue,
                                            controller.currentStartIndex.value,
                                            controller.currentEndIndex.value);
                                      }
                                      print("Selected distance: $_sliderValue");
                                      Navigator.of(context).pop();
                                    },
                                    child: const Text("Apply"),
                                  ),
                                ],
                              );
                            },
                          );
                        },
                      );
                    },
                  ),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8.0),
                  ),
                ),
                onChanged: controller.filterRestaurants,
              ),
              const SizedBox(height: 10),
              Obx(() => controller.isLoading.value
                  ? const Center(child: CircularProgressIndicator())
                  : (controller.filteredRestaurants.isEmpty
                  ? const Center(child: Text("No restaurants found"))
                  : Column(
                children: [
                  ListView.builder(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    itemCount: controller.filteredRestaurants.length,
                    itemBuilder: (context, index) {
                      var restaurant = controller.filteredRestaurants[index];
                      final restaurantId = restaurant['id'] ?? '';
                      final isLoading = controller.loadingRestaurants.contains(restaurantId);

                      // Only show Safe Items widget if safeItemsCount is present for this restaurant
                      final safeCount = controller.safeItemsCount[restaurantId];
                      final isSafeAvailable = safeCount != null;

                      return GestureDetector(
                        onTap: () {
                          if (restaurantId.isNotEmpty) {
                            Get.to(() => MenuAnalysisPage(
                              id: restaurantId,
                              name: restaurant['name'] ?? 'Unknown Restaurant',
                              user: user,
                              safeItemCount: controller.safeItemsCount[restaurantId] ?? 0,
                              cautionCount: controller.cautionCount[restaurantId] ?? 0,
                              avoidCount: controller.avoidCount[restaurantId] ?? 0,
                              parsedData: controller.restaurantParsedData[restaurantId],
                              analysisString: controller.analysis.value,
                              setSavedRestaurant: controller.setSavedRestaurant,
                              users: users,
                              groupId: groupId,
                              compPercent: compPercent,
                            ));
                          }
                        },
                        child: Card(
                          color: Colors.white,
                          margin: const EdgeInsets.only(bottom: 16),
                          elevation: 4,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Stack(
                                children: [
                                  ClipRRect(
                                    borderRadius: const BorderRadius.vertical(
                                        top: Radius.circular(8)),
                                    child: Image.network(
                                      restaurant['image_url'] ??
                                          'https://www.top25restaurants.com/media/img/2024/11/dubai-best-restaurants-c%C3%A9-la-vi-asian-at-top-25-restaurants.jpg',
                                      fit: BoxFit.cover,
                                      height: 160,
                                      width: double.infinity,
                                    ),
                                  ),
                                  Positioned(
                                    bottom: 0,
                                    left: 0,
                                    child: Container(
                                      padding: const EdgeInsets.fromLTRB(
                                          4.0, 4.0, 20.0, 4.0),
                                      decoration: const BoxDecoration(
                                        color: Colors.white,
                                        borderRadius: BorderRadius.only(
                                          topRight: Radius.circular(100000),
                                          topLeft: Radius.circular(7),
                                          bottomLeft: Radius.circular(7),
                                          bottomRight: Radius.circular(7),
                                        ),
                                      ),
                                      child: Text(
                                        '${(restaurant['distance'] as num? ?? 0.0).toStringAsFixed(1)} miles away',
                                        style: const TextStyle(
                                          color: Colors.black45,
                                          fontSize: 14,
                                          fontWeight: FontWeight.normal,
                                        ),
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                              Padding(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 10.0, vertical: 5.0),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Row(
                                      children: [
                                        Text(
                                          restaurant['name'] != null &&
                                              restaurant['name'].length > 26
                                              ? '${restaurant['name'].substring(0, 26)}...'
                                              : restaurant['name'] ??
                                              'Unknown Restaurant',
                                          style: const TextStyle(
                                              fontSize: 16,
                                              fontWeight: FontWeight.bold),
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                        const SizedBox(width: 8),
                                        // Show Safe Items widget only if it is available in cache
                                        if (isSafeAvailable)
                                          Container(
                                            padding: const EdgeInsets.symmetric(
                                                horizontal: 9.0, vertical: 6.0),
                                            decoration: BoxDecoration(
                                              color: Colors.deepOrangeAccent,
                                              borderRadius:
                                              BorderRadius.circular(8.0),
                                            ),
                                            child: Text(
                                              '$safeCount Safe Items',
                                              style: const TextStyle(
                                                fontSize: 12.0,
                                                color: Colors.white,
                                                fontWeight: FontWeight.bold,
                                              ),
                                              overflow: TextOverflow.ellipsis,
                                            ),
                                          ),
                                        if (!isSafeAvailable)
                                          const SizedBox.shrink(),
                                      ],
                                    ),
                                    const SizedBox(height: 8),
                                    Row(
                                      children: [
                                        Flexible(
                                          child: Text(
                                            (restaurant['categories'] != null)
                                                ? (restaurant['categories'] is List && (restaurant['categories'] as List).isNotEmpty)
                                                ? (restaurant['categories'] as List).length > 2
                                                ? '${(restaurant['categories'] as List).take(2).join(' - ')} - ...'
                                                : (restaurant['categories'] as List).join(' - ')
                                                : ''
                                                : '',
                                            style: const TextStyle(
                                              color: Colors.black38,
                                              fontSize: 13.40,
                                              fontWeight: FontWeight.w500,
                                              letterSpacing: 0.5,
                                            ),
                                          ),
                                        ),
                                        const Spacer(),
                                        Row(
                                          children: [
                                            const Icon(Icons.star,
                                                color: Colors.deepOrangeAccent),
                                            Text(
                                              '${(double.tryParse(restaurant['rating']?.toString() ?? '0') ?? 0.0) / 10}',
                                              style: const TextStyle(
                                                  color: Colors.deepOrangeAccent),
                                            ),
                                          ],
                                        ),
                                        const SizedBox(width: 10),
                                      ],
                                    ),
                                    const SizedBox(height: 7),
                                    const Text(
                                      "\$XXX for two",
                                      style: TextStyle(
                                        color: Colors.black38,
                                        fontSize: 14.0,
                                        fontWeight: FontWeight.w500,
                                        letterSpacing: 0.5,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
                  if (controller.isLoadingMore.value)
                    const Padding(
                      padding: EdgeInsets.all(16.0),
                      child: Center(child: CircularProgressIndicator()),
                    ),
                ],
              ))),
        ],
      ),
      ),
    )
        : controller.selectedIndex.value == 1
    ? MyGroupsScreen(
    user: user!,
    activities: [],
    setIndex: controller.setSelectedIndex,
    )
        : controller.selectedIndex.value == 2
    ? ScanMenuPage(user: user!)
        : controller.selectedIndex.value == 3
    ? ProfilePage(
    user: user,
    userPreferences: controller.userPreferences,
    setIndex: controller.setSelectedIndex,
    getUserPreferences: controller.getUserPreferences,
    )
        : const Center(
    child: Text("Default Page", style: TextStyle(fontSize: 24)),
    )),
    );
  }
}

