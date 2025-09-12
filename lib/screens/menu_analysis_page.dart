import 'dart:convert';

import 'package:auth0_flutter/auth0_flutter.dart';
import 'package:easibite/widgets/FoodCard.dart';
import 'package:easibite/widgets/menu_stats2.dart';
import 'package:flutter/material.dart';
import 'package:get/get_core/src/get_main.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

import '../ViewModel/MenuAnalysisController.dart';

import '../widgets/menu_stats.dart';

import 'package:get/get.dart';

class MenuAnalysisPage extends StatelessWidget {
  final String id;
  final String name;
  final UserProfile? user;
  final int? safeItemCount;
  final int? cautionCount;
  final int? avoidCount;
  final String? groupId;
  final List<String>? users;
  final Map<String, List<Map<String, String>>>? parsedData;
  final List<Map<String, dynamic>>? menuList;
  final String? compPercent;
  final Function(List<dynamic>)? setSavedRestaurant;

  MenuAnalysisPage({
    Key? key,
    required this.id,
    required this.name,
    this.safeItemCount,
    this.cautionCount,
    this.avoidCount,
    this.parsedData,
    this.user,
    required String analysisString, // Required but not used directly
    this.setSavedRestaurant,
    this.menuList,
    this.groupId,
    this.users,
    this.compPercent,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final controller = Get.put(MenuAnalysisController(
      restaurantId: id,
      restaurantName: name,
      user: user,
      setSavedRestaurant: setSavedRestaurant,
      initialParsedData: parsedData,
      initialSafeCount: safeItemCount,
      initialCautionCount: cautionCount,
      initialAvoidCount: avoidCount,
      users: users,
      groupId: groupId,
      compPercent: compPercent,
      initialMenuList: menuList,
    ));

    return Scaffold(
      body: Obx(() => controller.isLoading.value
          ? const Center(child: CircularProgressIndicator())
          : Column(
        children: [
          SizedBox(height: 24),
          _buildHeader(context, controller),
          if (controller.isAnalyzed.value) _buildGroupCompatibility(controller),
          if (controller.isAnalyzed.value) _buildMenuStats(controller),
          if (controller.isAnalyzed.value) _buildFilterTabs(controller),
          _buildMenuContent(controller),
        ],
      )),
    );
  }

  Widget _buildHeader(BuildContext context, MenuAnalysisController controller) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 12.0),
      color: Colors.white,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          IconButton(
            icon: const Icon(Icons.arrow_back),
            onPressed: () {
              print('[DEBUG] Going back with id: $id');
              Get.back(result: id);
            },
          ),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Text(
                  name.isNotEmpty ? name : "Menu Analysis",
                  style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
                if (controller.isAnalyzed.value)
                  const Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        "Analyzed just now",
                        style: TextStyle(fontSize: 13, color: Colors.grey),
                      ),
                    ],
                  ),
              ],
            ),
          ),
          setSavedRestaurant != null && groupId == null
              ? IconButton(
            color: Colors.black87,
            onPressed: () => controller.saveRestaurant(),
            icon: const Icon(Icons.save_as_outlined),
          )
              : const SizedBox.shrink(),
          const SizedBox(width: 12),
          if (!controller.isAnalyzed.value)
            ElevatedButton(
              onPressed: () => controller.handleAnalyse(groupId != null),
              style: ElevatedButton.styleFrom(
                elevation: 2,
                backgroundColor: const Color(0xFFFF9800),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              ),
              child: const Text(
                'Analyze',
                style: TextStyle(fontWeight: FontWeight.w600, color: Colors.white),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildGroupCompatibility(MenuAnalysisController controller) {
    if (controller.groupId == null) return SizedBox.shrink();

    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        const Text(
          'Group Compatibility',
          style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
        ),
        const SizedBox(width: 30),
        Center(
          child: controller.compPercent == null
              ? const SizedBox(
            height: 20,
            width: 20,
            child: CircularProgressIndicator(strokeWidth: 2),
          )
              : Text(
            '${controller.compPercent}% Match',
            style: const TextStyle(color: Colors.orange, fontWeight: FontWeight.w700),
          ),
        ),
      ],
    );
  }

  Widget _buildMenuStats(MenuAnalysisController controller) {
    return Obx(() => controller.groupId == null
        ? MenuStats(
      safeCount: controller.commonSafeCount.value,
      cautionCount: controller.someCanEatCount.value,
      avoidCount: controller.noneCanEatCount.value,
    )
        : MenuStats2(
      safeCount: controller.commonSafeCount.value,
      cautionCount: controller.someCanEatCount.value,
      avoidCount: controller.noneCanEatCount.value,
    ));
  }

  Widget _buildFilterTabs(MenuAnalysisController controller) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.shade300),
      ),
      child: Row(
        children: [
          _buildFilterTab('All', 0, controller),
          _buildFilterTab('Safe', 1, controller),
          _buildFilterTab('Caution', 2, controller),
          _buildFilterTab('Avoid', 3, controller),
        ],
      ),
    );
  }

  Widget _buildFilterTab(String label, int index, MenuAnalysisController controller) {
    return Expanded(
      child: Obx(() => GestureDetector(
        onTap: () => controller.handleFilterSelected(index),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 10),
          decoration: BoxDecoration(
            color: controller.selectedIndex.value == index
                ? const Color(0xFFFF9800)
                : Colors.transparent,
            borderRadius: BorderRadius.circular(8),
          ),
          alignment: Alignment.center,
          child: Text(
            label,
            style: TextStyle(
              fontWeight: FontWeight.w600,
              color: controller.selectedIndex.value == index
                  ? Colors.white
                  : Colors.grey[800],
            ),
          ),
        ),
      )),
    );
  }

  Widget _buildMenuContent(MenuAnalysisController controller) {
    return Expanded(
      child: Obx(() => controller.filteredMenu.isEmpty
          ? Center(child: Text('No menu items found'))
          : ListView.builder(
        padding: const EdgeInsets.all(16.0),
        itemCount: controller.filteredMenu.length,
        itemBuilder: (context, index) {
          final category = controller.filteredMenu[index];
          if (category['items'] == null || (category['items'] as List).isEmpty) {
            return SizedBox.shrink();
          }

          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                category['category'] ?? 'Uncategorized',
                style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 16.0),
              ...List.from((category['items'] as List).map((item) {
                // print(item as Map<String, dynamic>);
                
                return FoodCard(
                  key: ValueKey('${item['itemId']}_${controller.selectedIndex.value}_${controller.isAnalyzed.value}'),
                  id: id,
                  name: item['name'] ?? 'Unknown Item',
                  price: ((item['price'] ?? 0) / 100).toStringAsFixed(2),
                  description: item['description'] ?? "",
                  link: item["link"] ??
                      "https://s3-alpha-sig.figma.com/img/318f/285f/5d79d6d02e19079121dea2d1367cb3df?Expires=1745193600&Key-Pair-Id=APKAQ4GOSFWCW27IBOMQ&Signature=cLEqUMqdG5jFaMHpJhYM-Ir994fFD1bn1IqKNEkxuRQgGgYIn00LB40iUYn2mh73PeXOBtPStYAhN9aiydkR9rI308F7dimMNVcsYX4gUdupnYY6cJIjJq0RbG-Et3tQxfzTpp641Vo2~5BLcEowhijUzObPQTHyZWK8CgvJEMaK0CTRAd0Io4P6G5yInZcHMmfX3FgSOcdrTe7FWZPQyazRK6KsnuIN8Bycj4OuHmDQWanz~dnDyDCI8OuQT7JtKMXCmV2WvweAHLCSbsFyeHmDHRnu~gYTFIutMyJaJ1Tfjj-7I1xxrZ1JTdHNKZSuz5t8Romg2o7BMQjvoqGrcQ__",
                  tags: _extractTags(item),
                  allergenStatus: _getAllergenStatus(item, controller),
                  allergenDetails: _getAllergenDetails(item),
                  modificationOptions: item['modification_options'] ?? "No modifications available",
                );
              })),
            ],
          );
        },
      )),
    );
  }

  // Helper methods for processing food items
  List<String> _extractTags(dynamic item) {
    if (item['tags'] is List) {
      return List<String>.from(item['tags']);
    }
    return ["No tags available"];
  }

  String _getAllergenStatus(dynamic item, MenuAnalysisController controller) {
    final itemId = item['itemId']?.toString();
    if (itemId == null || controller.parsedData.value == null) return 'Unknown';

    if (controller.parsedData.value!['SAFE']?.any((i) => i['id'] == itemId) ?? false) {
      return 'Safe';
    } else if (controller.parsedData.value!['CAUTION']?.any((i) => i['id'] == itemId) ?? false) {
      return 'Caution';
    } else {
      return 'Avoid';
    }
  }

  String _getAllergenDetails(dynamic item) {
    if (item['allergens'] is List && (item['allergens'] as List).isNotEmpty) {
      return "Contains: ${(item['allergens'] as List).join(', ')}";
    }
    return "Allergen information not available";
  }
}

