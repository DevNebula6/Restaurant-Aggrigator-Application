import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

class FoodCard extends StatefulWidget {
  final String name;
  final String price;
  final String description;
  final List<String> tags;
  final String allergenStatus;  // This will be 'Pending' until analysis is done
  final String allergenDetails;
  final String modificationOptions;
  final String link;
  String ? id;
  
  FoodCard({
    required this.name,
    required this.price,
    required this.description,
    required this.tags,
    required this.allergenStatus,
    required this.allergenDetails,
    required this.modificationOptions,
    required this.link,
    super.key, this.id,
  });

  @override
  State<FoodCard> createState() => _FoodCardState();
}

class _FoodCardState extends State<FoodCard> {
  late Future<Map<String, dynamic>> _allergenDataFuture;
  bool _isDescriptionExpanded = false;
  bool _isLoading = true;
  bool _cancelled = false;

  String _localAllergenStatus = "";
  String _localAllergenDetails = "";
  String _localModificationOptions = "";
  double _safetyPercentage = 0.0;
  int _rawPercentage = 0; // Store the original percentage value
  
  @override
  void dispose() {
    _cancelled = true;
    super.dispose();
  }

  @override
  void initState() {
    super.initState();
    // Initialize with passed values in case we already have data from analysis
    _localAllergenStatus = widget.allergenStatus;
    _localAllergenDetails = widget.allergenDetails;
    _localModificationOptions = widget.modificationOptions;
    // Always fetch allergen data from API for consistent display
    _allergenDataFuture = _fetchAllergenData();
  }

  Future<Map<String, dynamic>> _fetchAllergenData() async {

    final prefs = await SharedPreferences.getInstance();
    final cacheKey = 'foodCard_${widget.name}';
    final cachedData = prefs.getString(cacheKey);
    
    if (_cancelled) {
      return {'contains': 'Request cancelled', 'percentage': 0, 'modifications': 'Not available'};
    }

    if (cachedData != null && cachedData.isNotEmpty) {
      print("Using cached allergen data for ${widget.name}");
      print("Cached data: $cachedData");
      final data = jsonDecode(cachedData);
          
      if (mounted) {
        setState(() {
          _localAllergenDetails = data['contains'] ?? 'Not specified';
          _localModificationOptions = data['modifications'] ?? 'No modifications available';
          
          // Store percentage for visualization
          int rawPercentage = (data['percentage'] as num).toInt();
          _rawPercentage = rawPercentage;
          _safetyPercentage = rawPercentage / 100.0;
          
          _isLoading = false;
          
          // Only override allergen status if we don't have a confirmed one yet
          if (widget.allergenStatus == 'Pending' || widget.allergenStatus == 'Unknown') {
            _localAllergenStatus = _getSafetyLevelFromPercentage(_safetyPercentage);
          }
        });
      }
      return data;
    }

    // If no cache, call the API
    try {

      if (_cancelled) {
        return {'contains': 'Request cancelled', 'percentage': 0, 'modifications': 'Not available'};
      }

      final url = Uri.parse('http://13.57.29.10:7000/allergens');
      final prefs = await SharedPreferences.getInstance();
      String? userPreferencesString = prefs.getString('userPreferences');
      
      if (userPreferencesString != null) {
        Map<String, dynamic> userPreferences = jsonDecode(userPreferencesString);
        List<String> allergens = List<String>.from(userPreferences["allergens"]);
        
          print("=== DEBUG: User Allergen Data ===");
          print("User has preferences: ${userPreferences.toString()}");
          print("User allergens: $allergens");
          print("Making API call for: ${widget.name}");
          print("================================");

        final payload = {
          "allergens": allergens.join(','),
          "menuitem": "name: ${widget.name}, description: ${widget.description}",
        };
        print("Payload: $payload");

        final response = await http.post(
          url,
          headers: {'Content-Type': 'application/json'},
          body: jsonEncode(payload),
        );

        if (response.statusCode == 200) {

          if (_cancelled) {
            return {'contains': 'Request cancelled', 'percentage': 0, 'modifications': 'Not available'};
          }

          String cleanedResponseBody = response.body.replaceAll(r'\"', '"');
          print("Response: $cleanedResponseBody");

          // Parse allergen contents
          RegExp contentsRegex = RegExp(r'<p class="allergiccontents">\s*(.*?)\s*</p>');
          Match? contentsMatch = contentsRegex.firstMatch(cleanedResponseBody);
          String contains = contentsMatch?.group(1) ?? 'Not specified';
          
          // Parse safety percentage
          RegExp percRegex = RegExp(r'<p class="perc">(\d+)</p>');
          Match? percMatch = percRegex.firstMatch(cleanedResponseBody);
          int perc = percMatch != null ? int.tryParse(percMatch.group(1)!) ?? 0 : 0;
          print("percentage: $perc");
          double percentage = perc / 100.0;
          int rawPercentage = perc; // Store original percentage

          // Parse modifications
          RegExp modiRegex = RegExp(r'<p class="modifications">\s*(.*?)\s*</p>');
          Match? modiMatch = modiRegex.firstMatch(cleanedResponseBody);
          String modifications = modiMatch?.group(1) ?? 'No modifications available';

          print("Extracted percentage: $percentage");
          print("Contains: $contains");
          print("Modifications: $modifications");
          
          if (_cancelled || !mounted) {
            return {'contains': 'Request cancelled', 'percentage': 0, 'modifications': 'Not available'};
          }

          // Update state with API response
          if (mounted) {
            setState(() {
              _localAllergenDetails = contains;
              _localModificationOptions = modifications;
              _safetyPercentage = percentage;
              _rawPercentage = rawPercentage;
              _isLoading = false;
              
              // Only override allergen status if we don't have a confirmed one yet
              if (widget.allergenStatus == 'Pending' || widget.allergenStatus == 'Unknown') {
                _localAllergenStatus = _getSafetyLevelFromPercentage(percentage);
              }
            });
          }
          // Cache the results
          final dataToCache = {
            'contains': contains,
            'percentage': perc,
            'modifications': modifications,
          };
          await prefs.setString(cacheKey, jsonEncode(dataToCache));
          return dataToCache;
        }
      } else {
        print("=== DEBUG: NO USER PREFERENCES FOUND ===");
        print("Cannot fetch allergen data without user preferences");
        print("Check if user is properly onboarded");
        print("====================================");
      }
    } catch (e) {
      print("Error fetching allergen data: $e");
    }
    
    if (mounted) {
      setState(() {
        _isLoading = false;
      });
    }    
    return {'contains': 'Not available', 'percentage': 0, 'modifications': 'Not available'};
  }
  
  String _getSafetyLevelFromPercentage(double percentage) {
    if (percentage <= 0.5) return 'Safe';
    if (percentage <= 0.8) return 'Caution';
    return 'Avoid';
  }

  Color _getColorForStatus(String status) {
    switch(status.toLowerCase()) {
      case 'safe': return Colors.green;
      case 'caution': return Colors.orange;
      case 'avoid': return Colors.red;
      default: return Colors.grey;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: EdgeInsets.only(bottom: 16.0),
      padding: EdgeInsets.all(16.0),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12.0),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withOpacity(0.1),
            blurRadius: 6,
            offset: Offset(0, 3),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Food name and price
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Text(
                  widget.name,
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.w500),
                ),
              ),
              Text(
                '\$${widget.price}',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.w500),
              ),
            ],
          ),
          SizedBox(height: 6),
          
          // Description
          if (widget.description.isNotEmpty)
            GestureDetector(
              onTap: () {
                setState(() {
                  _isDescriptionExpanded = !_isDescriptionExpanded;
                });
              },
              child: Text(
                widget.description,
                style: TextStyle(fontSize: 14, color: Colors.grey[700]),
                maxLines: _isDescriptionExpanded ? null : 2,
                overflow: _isDescriptionExpanded ? null : TextOverflow.ellipsis,
              ),
            ),
          
          SizedBox(height: 12),
          
          // Tags and image
          Row(
            children: [
              Expanded(
                child: SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    children: widget.tags.map((tag) => 
                      Padding(
                        padding: const EdgeInsets.only(right: 8.0),
                        child: _buildTag(tag),
                      )
                    ).toList(),
                  ),
                ),
              ),
              SizedBox(
                height: 70,
                width: 90,
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(12),
                  child: widget.link.isNotEmpty ? Image.network(
                    widget.link,
                    fit: BoxFit.cover,
                    errorBuilder: (context, error, stackTrace) {
                      return Container(
                        color: Colors.grey[200],
                        child: Icon(Icons.restaurant, color: Colors.grey[400]),
                      );
                    },
                  ) : Container(
                    color: Colors.grey[200],
                    child: Icon(Icons.restaurant, color: Colors.grey[400]),
                  ),
                ),
              )
            ],
          ),
          
          SizedBox(height: 16),
          
          // Allergen Status
          Text(
            'Allergen Status',
            style: TextStyle(fontWeight: FontWeight.bold),
          ),
          SizedBox(height: 4),
          
          // Show loading indicator or results
          _isLoading
            ? LinearProgressIndicator()
            : Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  LinearProgressIndicator(
                    value: _safetyPercentage,
                    backgroundColor: Colors.grey[200],
                    valueColor: AlwaysStoppedAnimation<Color>(_getColorForStatus(_localAllergenStatus)),
                  ),
                  SizedBox(height: 4),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        _localAllergenStatus,
                        style: TextStyle(
                          fontSize: 14, 
                          fontWeight: FontWeight.bold,
                          color: _getColorForStatus(_localAllergenStatus),
                        ),
                      ),
                      Text(
                        "Allergen content: $_rawPercentage%",
                        style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                      ),
                    ],
                  ),
                ],
            ),
          
          SizedBox(height: 8),
          
          // Allergen details
          Text(
            'Contains: ${_localAllergenDetails}',
            style: TextStyle(fontSize: 13, color: Colors.grey[700]),
          ),
          
          SizedBox(height: 12),
          
          // Modification options
          Text(
            'Modification Options',
            style: TextStyle(fontWeight: FontWeight.bold),
          ),
          SizedBox(height: 4),
          Text(
            _localModificationOptions,
            style: TextStyle(fontSize: 13, color: Colors.grey[700]),
          ),
        ],
      ),
    );
  }
  
  Widget _buildTag(String label) {
    return Container(
      padding: EdgeInsets.symmetric(vertical: 4, horizontal: 10),
      decoration: BoxDecoration(
        border: Border.all(color: Color(0xFFFF9800)),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        label,
        style: TextStyle(color: Color(0xFFFF9800), fontSize: 12),
      ),
    );
  }
}