
import 'dart:convert';

import 'package:easibite/widgets/CustomUIContainer.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:share_plus/share_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:http/http.dart' as http;

import '../widgets/ContactsDialog.dart';

class MyProfilePage extends StatefulWidget {
  final void Function({required dynamic dietary, required dynamic allergens}) onUpdatePreferences;
  final dynamic user; // Replace with the actual user model
  final Map<String, dynamic>? userPreferences;
  final Map<String, dynamic> userPreferences2;
  MyProfilePage({Key? key, this.user, this.userPreferences, required this.userPreferences2, required this.onUpdatePreferences}) : super(key: key);

  @override
  _MyProfilePageState createState() => _MyProfilePageState();
}

class _MyProfilePageState extends State<MyProfilePage> {
  List<bool> isSelected = [true, false];
  int selectedIndex = 0;

  bool editPreference = false;
  bool editAllergens = false;
  bool editSpice = false;

  String selectedLanguage = 'English';

  late List<String> dietaryPreferences;
  late List<String> allergens;
  late Map<String, dynamic> editablePreferences;
  late Map<String, dynamic> originalPreferences;
  Future<bool> _requestContactsPermission() async {
    try {
      print('Requesting contacts permission...');
      final status = await Permission.contacts.status;
      print('Current permission status: $status');

      if (status.isGranted) {
        print('Permission already granted');
        return true;
      }

      if (status.isPermanentlyDenied) {
        print('Permission permanently denied, opening settings');
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Contacts permission is permanently denied. Please enable it in settings.'),
            action: SnackBarAction(
              label: 'Settings',
              onPressed: openAppSettings,
            ),
          ),
        );
        return false;
      }

      final newStatus = await Permission.contacts.request();
      print('Permission request result: $newStatus');
      return newStatus.isGranted;
    } catch (e) {
      print('Error requesting permission: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error requesting contacts permission: $e')),
      );
      return false;
    }
  }
  void _showContactsDialog() async {
    print('Opening contacts dialog...');
    final hasPermission = await _requestContactsPermission();
    if (!hasPermission) {
      print('Permission not granted, showing snackbar');
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Permission to access contacts denied')),
      );
      return;
    }
    print('Permission granted, showing contacts dialog');
    if (!mounted) {
      print('Widget not mounted, aborting dialog');
      return;
    }
    await showDialog(
      context: context,
      builder: (dialogContext) {
        return ContactsDialog(
          onContactSelected: (contact) {
            final phoneNumber = contact.phones.isNotEmpty
                ? contact.phones.first.number.trim()
                : '';
            if (phoneNumber.isNotEmpty) {
              setState(() {
                (editablePreferences['emergency'] as List).add(phoneNumber);
              });
              // Show snackbar after dialog closes
              Navigator.pop(dialogContext);
              WidgetsBinding.instance.addPostFrameCallback((_) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Emergency Contact Added!')),
                );
              });
            } else {
              ScaffoldMessenger.of(dialogContext).showSnackBar(
                const SnackBar(content: Text('Contact has no phone number')),
              );
            }
          },
        );
      },
    );
  }

  final List<String> dietaryOptions = ["Halal", "Kosher", "Vegetarian", "Vegan"];
  final List<String> spiceLevels = ["Mild", "Medium", "Spicy"];
  final List<String> foodTemperatures = ["Hot", "Cold"];
  final List<String> allergenOptions = [
    "Peanuts", "Tree Nuts", "Milk", "Eggs", "Fish",
    "Shellfish", "Soy", "Wheat", "Sesame"
  ];
  String dietaryRequirement = '';
  String emergencyString = '';
  List<String> kosherOptions = [
    "Strict Kosher (Certified Only)",
    "Kosher Style – Dairy & Pareve Only",
    "Kosher Meat & Fish",
    "Basic Kosher"
  ];
  final TextEditingController _controller = TextEditingController();

  void _submitNotes() {
    if (editablePreferences['additionalNotes']!.isNotEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Additional notes added successfully!',
            style: TextStyle(color: Colors.white, fontWeight: FontWeight.w500),
          ),
          backgroundColor: Colors.greenAccent.shade400,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          duration: Duration(seconds: 2),
          elevation: 8,
        ),
      );
      setState(() {
        editablePreferences['additionalNotes'] = '';
        _controller.clear();
      });
    }
  }

  final Map<String, Map<String, String>> descriptions = {
    'Vegan': {
      'English': 'A diet that avoids all animal products, including meat, fish, poultry, dairy, eggs, and even honey, focusing entirely on plant-based foods.',
      'Portuguese': 'Uma dieta que evita todos os produtos animais, incluindo carne, peixe, aves, laticínios, ovos e até mesmo mel, focando exclusivamente em alimentos de origem vegetal.',
      'French': 'Un régime qui évite tous les produits animaux, y compris la viande, le poisson, la volaille, les produits laitiers, les œufs et même le miel, se concentrant uniquement sur les aliments d\'origine végétale.',
      'Spanish': 'Una dieta que evita todos los productos animales, incluida la carne, el pescado, la aves, los lácteos, los huevos e incluso la miel, centrándose completamente en alimentos de origen vegetal.',
    },
    'Halal': {
      'English': 'Food prepared and consumed in compliance with Islamic dietary laws, which include specific slaughtering methods, prohibition of pork and alcohol, and requirements for cleanliness.',
      'Portuguese': 'Comida preparada e consumida em conformidade com as leis dietéticas islâmicas, que incluem métodos específicos de abate, proibição de carne de porco e álcool, e exigências de limpeza.',
      'French': 'Nourriture préparée et consommée conformément aux lois alimentaires islamiques, qui incluent des méthodes d\'abattage spécifiques, l\'interdiction de la viande de porc et de l\'alcool, et des exigences en matière de propreté.',
      'Spanish': 'Alimentos preparados y consumidos de acuerdo con las leyes dietéticas islámicas, que incluyen métodos de sacrificio específicos, prohibición de carne de cerdo y alcohol, y requisitos de limpieza.',
    },
    'Kosher': {
      'English': 'Food that adheres to Jewish dietary laws (kashrut), including specific rules about animal slaughter, prohibition of mixing dairy and meat, and exclusion of non-kosher animals like pork and shellfish.',
      'Portuguese': 'Comida que segue as leis dietéticas judaicas (kashrut), incluindo regras específicas sobre o abate de animais, proibição de misturar laticínios e carne, e exclusão de animais não kosher como porco e mariscos.',
      'French': 'Nourriture qui suit les lois alimentaires juives (kashrut), y compris des règles spécifiques sur l\'abattage des animaux, l\'interdiction de mélanger les produits laitiers et la viande, et l\'exclusion d\'animaux non casher tels que le porc et les fruits de mer.',
      'Spanish': 'Alimentos que se adhieren a las leyes dietéticas judías (kashrut), incluyendo reglas específicas sobre el sacrificio de animales, prohibición de mezclar lácteos y carne, y exclusión de animales no kosher como el cerdo y los mariscos.',
    },
    'Vegetarian': {
      'English': 'A diet that excludes meat, fish, and poultry but may include dairy products and eggs, focusing on plant-based foods.',
      'Portuguese': 'Uma dieta que exclui carne, peixe e aves, mas pode incluir laticínios e ovos, focando em alimentos de origem vegetal.',
      'French': 'Un régime qui exclut la viande, le poisson et la volaille, mais peut inclure des produits laitiers et des œufs, se concentrant sur les aliments d\'origine végétale.',
      'Spanish': 'Una dieta que exclue la carne, el pescado y la aves, pero puede incluir lácteos y huevos, centrándose en alimentos de origen vegetal.',
    },
  };

  Color? _getColorForPref(String pref) {
    final Map<String, Color?> colorMap = {
      'Vegan': Colors.green[100],
      'Halal': Colors.red[100],
      'Kosher': Colors.blue[100],
      'Vegetarian': Colors.purple[100],
    };
    return colorMap[pref];
  }

  void showLanguageDialog() {
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: Text('Select Language'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ListTile(
                title: Text('English'),
                onTap: () {
                  setState(() {
                    selectedLanguage = 'English';
                  });
                  Navigator.pop(context);
                },
                selected: selectedLanguage == 'English',
              ),
              ListTile(
                title: Text('Portuguese'),
                onTap: () {
                  setState(() {
                    selectedLanguage = 'Portuguese';
                  });
                  Navigator.pop(context);
                },
                selected: selectedLanguage == 'Portuguese',
              ),
              ListTile(
                title: Text('French'),
                onTap: () {
                  setState(() {
                    selectedLanguage = 'French';
                  });
                  Navigator.pop(context);
                },
                selected: selectedLanguage == 'French',
              ),
              ListTile(
                title: Text('Spanish'),
                onTap: () {
                  setState(() {
                    selectedLanguage = 'Spanish';
                  });
                  Navigator.pop(context);
                },
                selected: selectedLanguage == 'Spanish',
              ),
            ],
          ),
        );
      },
    );
  }

  void handleFilterSelected(int index) {
    setState(() {
      selectedIndex = index;
    });
  }

  void _showKosherOptions(BuildContext context) {
    showModalBottomSheet(
      context: context,
      builder: (BuildContext context) {
        return Column(
          mainAxisSize: MainAxisSize.min,
          children: kosherOptions.map((option) {
            return ListTile(
              title: Text(option),
              onTap: () {
                setState(() {
                  editablePreferences['kosherType'] = option;
                });
                Navigator.pop(context);
              },
              selected: editablePreferences['kosherType'] == option,
            );
          }).toList(),
        );
      },
    );
  }

  @override
  void initState() {
    super.initState();
    print("data4 : ${widget.userPreferences}");
    dietaryPreferences = List<String>.from(widget.userPreferences?['dietary'] ?? []);
    allergens = List<String>.from(widget.userPreferences?['allergens'] ?? []);

    originalPreferences = Map<String, dynamic>.from(widget.userPreferences ?? {});
    editablePreferences = Map<String, dynamic>.from(widget.userPreferences ?? {});

    var defaults = {
      'dietary': [],
      'allergens': [],
      'emergency': [],
      'spiceLevel': "Medium",
      'foodTemperature': "Hot",
      'additionalNotes': "",
    };

    defaults.forEach((key, value) {
      originalPreferences[key] ??= value;
      editablePreferences[key] ??= value;
    });

    editablePreferences['dietary'] = List<String>.from(editablePreferences['dietary']);
    editablePreferences['allergens'] = List<String>.from(editablePreferences['allergens']);
    editablePreferences['emergency'] = List<String>.from(editablePreferences['emergency']);
  }

  Future<Map<String, dynamic>> getUserByEmail(String emailid) async {
    final response = await http.get(Uri.parse('http://13.57.29.10:7000/users/$emailid'));

    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);
      if (data["code"] == 404) {
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
    try {
      final Map<String, dynamic> requestBody = {
        "additionalNotes": userData["additionalNotes"],
        "groups": userData["groups"] ?? [],
        "onboardingCompleted": userData["onboardingCompleted"] ?? true,
        "foodTemperature": userData["foodTemperature"],
        "userid": userData["userid"] ?? "",
        "allergens": userData["allergens"],
        "phonenumber": userData["phonenumber"] ?? "1234567890",
        "spiceLevel": userData["spiceLevel"],
        "emailid": userData["emailid"],
        "dietary": userData["dietary"],
        "name": userData["name"],
        "groupinvites": userData["groupinvites"] ?? [],
        "emergency": userData["emergency"]
      };

      final response = await http.put(
        Uri.parse('http://13.57.29.10:7000/users/update'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode(requestBody),
      );

      if (response.statusCode == 200 || response.statusCode == 201) {
        final responseData = jsonDecode(response.body);
        final prefs = await SharedPreferences.getInstance();

        await prefs.setBool('isOnboarded', true);
        await prefs.setString("user_data", jsonEncode(responseData['data']));
        await prefs.setString('userPreferences', jsonEncode(requestBody));

        setState(() {
          editPreference = false;
          dietaryPreferences = List<String>.from(userData["dietary"]);
          allergens = List<String>.from(userData["allergens"]);
          originalPreferences = Map<String, dynamic>.from(requestBody);
          editablePreferences = Map<String, dynamic>.from(requestBody);
        });

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Preferences saved successfully!")),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Failed to save preferences: ${response.body}")),
        );
      }
    } catch (e) {
      print("Error updating user: $e");
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Error saving preferences")),
      );
    }
  }
  void _showDetailedPreferencesDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return Dialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          elevation: 8,
          backgroundColor: Colors.white,
          child: Stack(
            children: [
              SizedBox(
                width: 400,
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 700),
                  child: SingleChildScrollView(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const SizedBox(height: 48), // Space for close button
                        for (var pref in dietaryPreferences)
                          _buildInfoCardDetailed(
                            icon: Icons.restaurant,
                            pref: pref,
                            color: _getColorForPref(pref),
                            textColor: Colors.black,
                          ),
                        const SizedBox(height: 16), // Bottom padding
                      ],
                    ),
                  ),
                ),
              ),
              Positioned(
                top: 8,
                right: 8,
                child: IconButton(
                  icon: Icon(Icons.close, color: Colors.grey[600]),
                  onPressed: () {
                    Navigator.of(context).pop(); // Close the dialog
                  },
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Future<void> onSubmit() async {
    Map<String, dynamic> finalUserPreferences = {
      "dietary": editablePreferences['dietary'].isNotEmpty
          ? editablePreferences['dietary']
          : originalPreferences['dietary'],
      "allergens": editablePreferences['allergens'].isNotEmpty
          ? editablePreferences['allergens']
          : originalPreferences['allergens'],
      "spiceLevel": editablePreferences['spiceLevel'] != "Medium" || originalPreferences['spiceLevel'] == null
          ? editablePreferences['spiceLevel']
          : originalPreferences['spiceLevel'],
      "foodTemperature": editablePreferences['foodTemperature'] != "Hot" || originalPreferences['foodTemperature'] == null
          ? editablePreferences['foodTemperature']
          : originalPreferences['foodTemperature'],
      "additionalNotes": editablePreferences['additionalNotes'].isNotEmpty
          ? editablePreferences['additionalNotes']
          : originalPreferences['additionalNotes'],
      "emergency": editablePreferences['emergency'].isNotEmpty
          ? editablePreferences['emergency']
          : originalPreferences['emergency'],
    };
    widget.onUpdatePreferences(
      dietary: finalUserPreferences['dietary'],
      allergens: finalUserPreferences['allergens'],
    );
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('userPreferences', jsonEncode(finalUserPreferences));
    print("iwen32 ${jsonEncode(finalUserPreferences)}");

    try {
      final prefs = await SharedPreferences.getInstance();
      final userResponse = await getUserByEmail(widget.user!.email!);

      if (userResponse['status'] == 'success') {
        var existingData = Map<String, dynamic>.from(userResponse['data'][0]);

        await _updateUserData({
          "name": widget.user?.name ?? "John Doe",
          "phonenumber": existingData["phonenumber"] ?? "1234567890",
          "emailid": widget.user?.email ?? "john.doe@example.com",
          "dietary": finalUserPreferences['dietary'],
          "allergens": finalUserPreferences['allergens'],
          "spiceLevel": finalUserPreferences['spiceLevel'],
          "foodTemperature": [finalUserPreferences['foodTemperature']],
          "additionalNotes": finalUserPreferences['additionalNotes'],
          "onboardingCompleted": true,
          "groups": existingData['groups'] ?? [],
          "groupinvites": existingData["groupinvites"] ?? [],
          "emergency": finalUserPreferences['emergency']
        });
      } else {
        final response = await http.post(
          Uri.parse("http://13.57.29.10:7000/users/update"),
          headers: {"Content-Type": "application/json"},
          body: jsonEncode({
            "name": widget.user?.name ?? "John Doe",
            "phonenumber": widget.user?.phone ?? "1234567890",
            "emailid": widget.user?.email ?? "john.doe@example.com",
            "dietary": finalUserPreferences['dietary'],
            "allergens": finalUserPreferences['allergens'],
            "spiceLevel": finalUserPreferences['spiceLevel'],
            "foodTemperature": [finalUserPreferences['foodTemperature']],
            "additionalNotes": finalUserPreferences['additionalNotes'],
            "onboardingCompleted": true,
            "groups": [],
            "groupinvites": [],
            "emergency": finalUserPreferences['emergency']
          }),
        );

        if (response.statusCode == 200 || response.statusCode == 201) {
          final responseData = jsonDecode(response.body);
          await prefs.setBool('isOnboarded', true);
          await prefs.setString("user_data", jsonEncode(responseData['data']));
          await prefs.setString('userPreferences', jsonEncode(finalUserPreferences));
          print("iwen32 ${jsonEncode(finalUserPreferences)}");


          setState(() {
            dietaryPreferences = List<String>.from(finalUserPreferences['dietary']);
            allergens = List<String>.from(finalUserPreferences['allergens']);
            originalPreferences = Map<String, dynamic>.from(finalUserPreferences);
          });


          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text("Preferences saved successfully!")),
          );
        }
      }
    } catch (e) {
      print("Error saving preferences: $e");
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Error saving preferences")),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    List<String> slicedAllergens = [];
    int cumulativeLength = 0;
    for (String allergen in allergens) {
      if (cumulativeLength + allergen.length <= 20) {
        slicedAllergens.add(allergen);
        cumulativeLength += allergen.length;
      } else {
        break;
      }
    }

    List<String> slicedDietaryPreferences = [];
    int cumulativeLengthDietary = 0;
    final translations = {
      'English': {'dietaryPreferences': ['Halal', 'Kosher', 'Vegetarian', 'Vegan']},
      'Portuguese': {'dietaryPreferences': ['Halal', 'Kosher', 'Vegetariano', 'Vegano']},
      'French': {'dietaryPreferences': ['Halal', 'Casher', 'Végétarien', 'Végan']},
      'Spanish': {'dietaryPreferences': ['Halal', 'Kosher', 'Vegetariano', 'Vegano']},
    };
    final englishPrefs = translations['English']!['dietaryPreferences'] as List<String>;
    final translatedPrefs = translations[selectedLanguage]!['dietaryPreferences'] as List<String>;
    for (String dietary in dietaryPreferences) {
      final index = englishPrefs.indexOf(dietary);
      final translated = index != -1 && translations.containsKey(selectedLanguage)
          ? translatedPrefs[index]
          : dietary;
      if (cumulativeLengthDietary + translated.length <= 20) {
        slicedDietaryPreferences.add(translated);
        cumulativeLengthDietary += translated.length;
      } else {
        break;
      }
    }
    void _copyUserDataToClipboard() {
      String copyText = """
My Dietary Profile

Dietary Preferences:
${dietaryPreferences.isNotEmpty ? dietaryPreferences.map((pref) => "- $pref").join("\n") : "- None specified"}

Allergens:
${allergens.isNotEmpty ? allergens.map((allergen) => "- $allergen").join("\n") : "- None specified"}

Emergency Contact:
- ${widget.userPreferences?['emergency'] ?? "Not provided"}
""";

      Clipboard.setData(ClipboardData(text: copyText));
    }

    void _shareUserData() {
      String shareText = """
        My Dietary Profile
        
        Dietary Preferences:
        ${dietaryPreferences.isNotEmpty ? dietaryPreferences.map((pref) => "- $pref").join("\n") : "- None specified"}
        
        Allergens:
        ${allergens.isNotEmpty ? allergens.map((allergen) => "- $allergen").join("\n") : "- None specified"}
        
        Emergency Contact:
        - ${widget.userPreferences?['emergency'] ?? "Not provided"}
        """;

      Share.share(
        shareText,
        subject: "My Dietary Information",
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: Text('Dietary ID'),
        leading: IconButton(
          icon: Icon(Icons.arrow_back, color: Colors.black),
          onPressed: () {
            Navigator.pop(context);
          },
        ),
        backgroundColor: Colors.white,
        elevation: 0,
      ),
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              SizedBox(width: 22),
              Expanded(child: _buildToggleButton('Standard', 0)),
              // SizedBox(width: 28.0),
              // Expanded(child: _buildToggleButton('Detailed', 1)),
              // SizedBox(width: 22),
            ],
          ),
          SizedBox(height: 16.0),
          Center(
            child: FilterBar(
              selectedIndex: selectedIndex,
              onFilterSelected: handleFilterSelected,
            ),
          ),
          Expanded(
            child: SingleChildScrollView(
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: selectedIndex == 0
                    ? Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Expanded(
                          child: GestureDetector(
                            onTap: _shareUserData,
                            child: Container(
                              padding: EdgeInsets.symmetric(vertical: 10.0),
                              decoration: BoxDecoration(
                                border: Border.all(color: Colors.grey.shade400),
                                borderRadius: BorderRadius.circular(8.0),
                                color: Colors.white,
                              ),
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Icon(Icons.ios_share, color: Colors.black87, size: 19),
                                  SizedBox(width: 12),
                                  Text(
                                    'Share Card',
                                    style: TextStyle(
                                      fontSize: 13,
                                      color: Colors.black87,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                        // SizedBox(width: 7),
                        // Expanded(
                        //   child: GestureDetector(
                        //     onTap: () {
                        //       showLanguageDialog();
                        //     },
                        //     child: Container(
                        //       padding: EdgeInsets.symmetric(vertical: 10.0),
                        //       decoration: BoxDecoration(
                        //         border: Border.all(color: Colors.grey.shade400),
                        //         borderRadius: BorderRadius.circular(8.0),
                        //         color: Colors.white,
                        //       ),
                        //       child: Row(
                        //         mainAxisAlignment: MainAxisAlignment.center,
                        //         children: [
                        //           Icon(Icons.chat_bubble_outline_sharp, color: Colors.black,size: 19,),
                        //           SizedBox(width: 7),
                        //           Text(
                        //             'Translate',
                        //             style: TextStyle(fontSize: 13, color: Colors.black, fontWeight: FontWeight.bold),
                        //           ),
                        //         ],
                        //       ),
                        //     ),
                        //   ),
                        // ),
                        SizedBox(width: 7,),
                        Expanded(
                          child: GestureDetector(
                            onTap: _copyUserDataToClipboard,
                            child: Container(
                              padding: EdgeInsets.symmetric(vertical: 10.0),
                              decoration: BoxDecoration(
                                border: Border.all(color: Colors.grey.shade400),
                                borderRadius: BorderRadius.circular(8.0),
                                color: Colors.white,
                              ),
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Icon(Icons.copy, color: Colors.black, size: 19),
                                  SizedBox(width: 12),
                                  Text(
                                    'Copy Text',
                                    style: TextStyle(
                                      fontSize: 13,
                                      color: Colors.black,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                    SizedBox(height: 16.0),
                    Card(
                      color: Colors.white,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12.0),
                      ),
                      child: Padding(
                        padding: const EdgeInsets.all(16.0),
                        child: Column(
                          children: [
                            Row(
                              children: [
                                CircleAvatar(
                                  radius: 36,
                                  backgroundColor: Colors.grey[300],
                                  child: Text(
                                    'A',
                                    style: TextStyle(fontSize: 24, color: Colors.black),
                                  ),
                                ),
                                SizedBox(width: 16.0),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        widget.user.name,
                                        style: TextStyle(
                                          fontSize: 18.0,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                      Row(
                                        children: [
                                          GestureDetector(
                                            onTap: () {
                                              showLanguageDialog();
                                            },
                                            child: Chip(
                                              label: Text(selectedLanguage),
                                            ),
                                          ),
                                        ],
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                            SizedBox(height: 16.0),
                            Column(
                              children: [
                                Row(
                                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                  children: [
                                    Expanded(
                                      child: GestureDetector(
                                        onTap: () => _showDetailedPreferencesDialog(context),
                                        child: _buildInfoCard(
                                          icon: Icons.restaurant,
                                          label: 'Diet Type',
                                          values: slicedDietaryPreferences,
                                          color: Colors.green[100],
                                          textColor: Colors.black,
                                          detailed: false, selectedLanguage: selectedLanguage,
                                        ),
                                      ),
                                    ),
                                    SizedBox(width: 16.0),
                                    Expanded(
                                      child: _buildInfoCard(
                                        icon: Icons.no_drinks,
                                        label: 'Preferences',
                                        values: ['No Alcohol'],
                                        color: Colors.blue[100],
                                        textColor: Colors.black,
                                        detailed: false,
                                        selectedLanguage: selectedLanguage,
                                      ),
                                    ),
                                  ],
                                ),
                                SizedBox(height: 8.0),
                                Row(
                                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                  children: [
                                    Expanded(
                                      child: _buildInfoCard(
                                        selectedLanguage: selectedLanguage,
                                        icon: Icons.warning_amber_outlined,
                                        label: 'Allergies',
                                        values: slicedAllergens,
                                        color: Colors.red[100],
                                        textColor: Colors.red,
                                        detailed: false,
                                      ),
                                    ),
                                    SizedBox(width: 16.0),
                                    Expanded(
                                      child: _buildInfoCard(
                                        selectedLanguage: selectedLanguage,
                                        icon: Icons.block,
                                        label: 'Restrictions',
                                        values: ['No Pork'],
                                        color: Colors.yellow[100],
                                        textColor: Colors.orange,
                                        detailed: false,
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                            SizedBox(height: 28.0),
                            Text(
                              'Cross-Contamination',
                              style: TextStyle(
                                fontSize: 18.0,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            SizedBox(height: 8.0),
                            Text(
                              'Please ensure separate preparation surfaces and utensils for allergen safety.',
                              style: TextStyle(fontSize: 16.0),
                            ),
                          ],
                        ),
                      ),
                    ),
                    SizedBox(height: 16.0),

                    CustomUIContainer(userPreferences: widget.userPreferences ?? widget.userPreferences2, editablePreferences:editablePreferences),
                  ],
                )
                    : Column(
                  children: [
                    editPreference
                        ? Column(
                      children: [
                        Row(
                          children: [
                            Spacer(),
                            IconButton(
                              onPressed: () {
                                setState(() {
                                  editPreference = !editPreference;
                                });
                              },
                              icon: Icon(Icons.close),
                            ),
                          ],
                        ),
                        Padding(
                          padding: const EdgeInsets.fromLTRB(0, 0, 0, 16),
                          child: Text(
                            "Tell us about your dietary needs",
                            style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
                          ),
                        ),
                        Text(
                          "Select your dietary preferences",
                          style: TextStyle(color: Colors.grey[600], fontSize: 16),
                        ),
                        SizedBox(height: 20),
                        ...dietaryOptions.map((option) {
                          return SwitchListTile(
                            title: Text(option, style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                            subtitle: Text(
                              option == "Halal"
                                  ? "Halal-certified food only"
                                  : option == "Kosher"
                                  ? "Follows kosher dietary laws (${editablePreferences['kosherType'] ?? 'Tap to select'})"
                                  : option == "Vegetarian"
                                  ? "No meat products"
                                  : "No animal products",
                              style: TextStyle(fontSize: 14, color: Colors.grey[600]),
                            ),
                            activeColor: Colors.orange,
                            value: editablePreferences['dietary'].contains(option),
                            onChanged: (value) {
                              setState(() {
                                if (value) {
                                  editablePreferences['dietary'].add(option);
                                  if (option == "Kosher") {
                                    _showKosherOptions(context);
                                  }
                                } else {
                                  editablePreferences['dietary'].remove(option);
                                  if (option == "Kosher") {
                                    editablePreferences.remove('kosherType');
                                  }
                                }
                              });
                            },
                          );
                        }).toList(),
                        Padding(
                          padding: const EdgeInsets.symmetric(vertical: 16.0),
                          child: Column(
                            children: [
                              Text(
                                "Allergens",
                                style: TextStyle(
                                  fontSize: 24,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.black,
                                ),
                              ),
                            ],
                          ),
                        ),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              "Categories",
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w600,
                                color: Colors.grey[700],
                              ),
                            ),
                            GestureDetector(
                              onTap: () {
                                setState(() {
                                  (editablePreferences['allergens'] as List).clear();
                                });
                              },
                              child: Text(
                                "Clear All",
                                style: TextStyle(
                                  fontSize: 14,
                                  color: Colors.orange[700],
                                  fontWeight: FontWeight.w900,
                                ),
                              ),
                            ),
                          ],
                        ),
                        SizedBox(height: 16),
                        Wrap(
                          spacing: 10,
                          runSpacing: 10,
                          children: allergenOptions.map((option) {
                            final isSelected = editablePreferences['allergens'].contains(option);
                            return ChoiceChip(
                              label: Text(
                                option,
                                style: TextStyle(
                                  color: isSelected ? Colors.white : Colors.black,
                                ),
                              ),
                              selected: isSelected,
                              selectedColor: Colors.orange[700],
                              showCheckmark: false,
                              backgroundColor: Colors.grey[200],
                              onSelected: (selected) {
                                setState(() {
                                  if (selected) {
                                    (editablePreferences['allergens'] as List).add(option);
                                  } else {
                                    (editablePreferences['allergens'] as List).remove(option);
                                  }
                                });
                              },
                            );
                          }).toList(),
                        ),
                        SizedBox(height: 20),
                        Text(
                          "Additional Allergens",
                          style: TextStyle(fontWeight: FontWeight.w600),
                        ),
                        TextField(
                          decoration: InputDecoration(
                            hintText: "Any other Allergens...",
                            hintStyle: TextStyle(color: Colors.grey[500]),
                            border: OutlineInputBorder(),
                            contentPadding: EdgeInsets.symmetric(horizontal: 10, vertical: 10),
                          ),
                          onChanged: (value) {
                            setState(() {
                              dietaryRequirement = value;
                            });
                          },
                        ),
                        SizedBox(height: 10),
                        ElevatedButton(
                          onPressed: () {
                            if (dietaryRequirement.trim().isNotEmpty) {
                              setState(() {
                                // Add to allergenOptions if not already present
                                if (!allergenOptions.contains(dietaryRequirement)) {
                                  allergenOptions.add(dietaryRequirement);
                                }

                                // Add to editablePreferences['allergens'] if not already present
                                if (!(editablePreferences['allergens'] as List).contains(dietaryRequirement)) {
                                  (editablePreferences['allergens'] as List).add(dietaryRequirement);
                                }

                                dietaryRequirement = ""; // clear input after submit
                              });
                            }
                          },
                          child: Text("Add Allergen"),
                        ),
                        SizedBox(height: 10),
                        Text(
                          "Additional Preferences",
                          style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                        ),
                        SizedBox(height: 20),
                        Text(
                          "Spice Level Preference",
                          style: TextStyle(fontWeight: FontWeight.w600),
                        ),
                        Wrap(
                          spacing: 10,
                          runSpacing: 10,
                          children: spiceLevels.map((level) {
                            return ChoiceChip(
                              label: Text(
                                level,
                                style: TextStyle(
                                  color: editablePreferences['spiceLevel'] == level ? Colors.white : Colors.black,
                                ),
                              ),
                              selected: editablePreferences['spiceLevel'] == level,
                              selectedColor: Colors.orange,
                              backgroundColor: Colors.grey[200],
                              showCheckmark: false,
                              onSelected: (selected) {
                                if (selected) {
                                  setState(() {
                                    editablePreferences['spiceLevel'] = level;
                                  });
                                }
                              },
                            );
                          }).toList(),
                        ),
                        SizedBox(height: 20),
                        const Text(
                          "Emergency Contacts",
                          style: TextStyle(fontWeight: FontWeight.w600),
                        ),
                        TextField(
                          controller: TextEditingController(
                            text: emergencyString,
                          ),
                          decoration: const InputDecoration(
                            hintText: "Add an Emergency Contact",
                            hintStyle: TextStyle(color: Colors.grey),
                            border: OutlineInputBorder(),
                            contentPadding: EdgeInsets.symmetric(horizontal: 10, vertical: 10),
                          ),
                          onChanged: (value) {
                            setState(() {
                              emergencyString = value;
                            });
                          },
                        ),
                        const SizedBox(height: 10),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Expanded(
                              child: ElevatedButton(
                                onPressed: () {
                                  if (emergencyString.isNotEmpty) {
                                    setState(() {
                                      (editablePreferences['emergency'] as List).add(emergencyString.trim());
                                      emergencyString = '';
                                    });
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      const SnackBar(content: Text('Emergency Contact Added!')),
                                    );
                                  }
                                },
                                child: const Text('Add Contact'),
                              ),
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: ElevatedButton(
                                onPressed: _showContactsDialog,
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: Colors.grey[200],
                                  foregroundColor: Colors.black,
                                ),
                                child: const Text('Choose from Contacts'),
                              ),
                            ),
                          ],
                        ),
                        Text(
                          "Additional Notes",
                          style: TextStyle(fontWeight: FontWeight.w600),
                        ),
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 0.0, vertical: 8.0),
                          child: Row(
                            children: [
                              Expanded(
                                child: TextField(
                                  controller: _controller,
                                  style: TextStyle(color: Colors.black87, fontSize: 16),
                                  decoration: InputDecoration(
                                    hintText: "Any other dietary requirements...",
                                    hintStyle: TextStyle(color: Colors.grey[500], fontStyle: FontStyle.italic),
                                    filled: true,
                                    fillColor: Colors.white,
                                    enabledBorder: OutlineInputBorder(
                                      borderRadius: BorderRadius.circular(16),
                                      borderSide: BorderSide(color: Colors.grey, width: 1.5),
                                    ),
                                    focusedBorder: OutlineInputBorder(
                                      borderRadius: BorderRadius.circular(16),
                                      borderSide: BorderSide(color: Colors.cyanAccent, width: 2.5, style: BorderStyle.solid),
                                    ),
                                    contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                                    suffixIcon: _controller.text.isNotEmpty
                                        ? IconButton(
                                      icon: Icon(Icons.clear, color: Colors.grey[400]),
                                      onPressed: () {
                                        setState(() {
                                          _controller.clear();
                                          editablePreferences['additionalNotes'] = '';
                                        });
                                      },
                                    )
                                        : null,
                                  ),
                                  cursorColor: Colors.cyanAccent,
                                  onChanged: (value) {
                                    setState(() {
                                      editablePreferences['additionalNotes'] = value;
                                    });
                                  },
                                ),
                              ),
                              SizedBox(width: 12),
                              ElevatedButton(
                                onPressed: _submitNotes,
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: Colors.white,
                                  foregroundColor: Colors.black87,
                                  padding: EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(16),
                                  ),
                                  elevation: 8,
                                ),
                                child: Text(
                                  "Submit",
                                  style: TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.bold,
                                    letterSpacing: 1.2,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                        SizedBox(height: 12),
                        ElevatedButton(
                          onPressed: () {
                            onSubmit();
                          },
                          child: Text('Submit'),
                        ),
                      ],
                    )
                        : Column(
                      children: [
                        Row(
                          children: [
                            Spacer(),
                            Padding(
                              padding: const EdgeInsets.symmetric(vertical: 16.0),
                              child: Text(
                                "Dietary Preferences",
                                style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
                              ),
                            ),
                            SizedBox(width: 10),
                            IconButton(
                              onPressed: () {
                                setState(() {
                                  editPreference = !editPreference;
                                });
                              },
                              icon: Icon(Icons.edit),
                            ),
                            SizedBox(width: 22),
                          ],
                        ),
                        ...dietaryPreferences.map((option) {
                          return ListTile(
                            contentPadding: EdgeInsets.symmetric(horizontal: 0),
                            title: Text(
                              option,
                              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                            ),
                            subtitle: Text(
                              option == "Halal"
                                  ? "Halal-certified food only"
                                  : option == "Kosher"
                                  ? "Follows kosher dietary laws"
                                  : option == "Vegetarian"
                                  ? "No meat products"
                                  : "No animal products",
                              style: TextStyle(fontSize: 14, color: Colors.grey[600]),
                            ),
                          );
                        }).toList(),
                        Padding(
                          padding: const EdgeInsets.symmetric(vertical: 16.0),
                          child: Column(
                            children: [
                              Text(
                                "Allergens",
                                style: TextStyle(
                                  fontSize: 24,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.black,
                                ),
                              ),
                            ],
                          ),
                        ),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [],
                        ),
                        SizedBox(height: 16),
                        Wrap(
                          spacing: 10,
                          runSpacing: 10,
                          children: allergens.map((option) {
                            final isSelected = (editablePreferences['allergens'] as List).contains(option);
                            return ChoiceChip(
                              label: Text(
                                option,
                                style: TextStyle(
                                  color: isSelected ? Colors.black : Colors.white,
                                ),
                              ),
                              selected: isSelected,
                              selectedColor: Colors.grey[200],
                              showCheckmark: false,
                              backgroundColor: Colors.orange[700],
                              onSelected: (selected) {
                                setState(() {
                                  if (selected) {
                                    (editablePreferences['allergens'] as List).add(option);
                                  } else {
                                    (editablePreferences['allergens'] as List).remove(option);
                                  }
                                });
                              },
                            );
                          }).toList(),
                        ),
                        SizedBox(height: 20),
                        Text(
                          "Spice Level Preference",
                          style: TextStyle(fontWeight: FontWeight.w600),
                        ),
                        ChoiceChip(
                          label: Text(
                            editablePreferences['spiceLevel']?.toString() ?? '',
                            style: TextStyle(
                              color: Colors.white,
                            ),
                          ),
                          selected: true,
                          selectedColor: Colors.orange,
                          backgroundColor: Colors.grey[200],
                          showCheckmark: false,
                          onSelected: (selected) {},
                        ),
                        SizedBox(height: 12),
                        Text(editablePreferences['additionalNotes']?.toString() ?? ''),
                        SizedBox(height: 12),
                        Text(
                          "Emergency Contact",
                          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 20),
                        ),
                        Wrap(
                          spacing: 10,
                          runSpacing: 10,
                          children: (editablePreferences['emergency'] as List).map((contact) {
                            return Chip(
                              label: Text(contact),
                            );
                          }).toList(),
                        ),
                        SizedBox(height: 20),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInfoCard({
    required IconData icon,
    required String selectedLanguage,
    required String label,
    required List<String> values,
    required Color? color,
    required Color textColor,
    double? width,
    double? height,
    bool detailed = true,
  }) {
    final Map<String, Map<String, String>> descriptions = {
      'Vegan': {
        'English': 'A diet that avoids all animal products, including meat, fish, poultry, dairy, eggs, and even honey, focusing entirely on plant-based foods.',
        'Portuguese': 'Uma dieta que evita todos os produtos animais, incluindo carne, peixe, aves, laticínios, ovos e até mesmo mel, focando exclusivamente em alimentos de origem vegetal.',
        'French': 'Un régime qui évite tous les produits animaux, y compris la viande, le poisson, la volaille, les produits laitiers, les œufs et même le miel, se concentrant uniquement sur les aliments d\'origine végétale.',
        'Spanish': 'Una dieta que evita todos los productos animales, incluida la carne, el pescado, la aves, los lácteos, los huevos e incluso la miel, centrándose completamente en alimentos de origen vegetal.',
      },
      'Halal': {
        'English': 'Food prepared and consumed in compliance with Islamic dietary laws, which include specific slaughtering methods, prohibition of pork and alcohol, and requirements for cleanliness.',
        'Portuguese': 'Comida preparada e consumida em conformidade com as leis dietéticas islâmicas, que incluem métodos específicos de abate, proibição de carne de porco e álcool, e exigências de limpeza.',
        'French': 'Nourriture préparée et consommée conformément aux lois alimentaires islamiques, qui incluent des méthodes d\'abattage spécifiques, l\'interdiction de la viande de porc et de l\'alcool, et des exigences en matière de propreté.',
        'Spanish': 'Alimentos preparados y consumidos de acuerdo con las leyes dietéticas islámicas, que incluyen métodos de sacrificio específicos, prohibición de carne de cerdo y alcohol, y requisitos de limpieza.',
      },
      'Kosher': {
        'English': 'Food that adheres to Jewish dietary laws (kashrut), including specific rules about animal slaughter, prohibition of mixing dairy and meat, and exclusion of non-kosher animals like pork and shellfish.',
        'Portuguese': 'Comida que segue as leis dietéticas judaicas (kashrut), incluindo regras específicas sobre o abate de animais, proibição de misturar laticínios e carne, e exclusão de animais não kosher como porco e mariscos.',
        'French': 'Nourriture qui suit les lois alimentaires juives (kashrut), y compris des règles spécifiques sur l\'abattage des animaux, l\'interdiction de mélanger les produits laitiers et la viande, et l\'exclusion d\'animaux non casher tels que le porc et les fruits de mer.',
        'Spanish': 'Alimentos que se adhieren a las leyes dietéticas judías (kashrut), incluyendo reglas específicas sobre el sacrificio de animales, prohibición de mezclar lácteos y carne, y exclusión de animales no kosher como el cerdo y los mariscos.',
      },
      'Vegetarian': {
        'English': 'A diet that excludes meat, fish, and poultry but may include dairy products and eggs, focusing on plant-based foods.',
        'Portuguese': 'Uma dieta que exclui carne, peixe e aves, mas pode incluir laticínios e ovos, focando em alimentos de origem vegetal.',
        'French': 'Un régime qui exclut la viande, le poisson et la volaille, mais peut inclure des produits laitiers et des œufs, se concentrant sur les aliments d\'origine végétale.',
        'Spanish': 'Una dieta que exclue la carne, el pescado y la aves, pero puede incluir lácteos y huevos, centrándose en alimentos de origen vegetal.',
      },
    };

    return Container(
      width: width,
      height: height,
      padding: EdgeInsets.all(8.0),
      margin: EdgeInsets.symmetric(vertical: 4, horizontal: 4),
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(8.0),
      ),
      child: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Icon(icon, size: 20.0, color: textColor),
            SizedBox(height: 5.0),
            Text(
              label,
              style: TextStyle(fontSize: 14.0, fontWeight: FontWeight.bold),
            ),
            SizedBox(height: 4.0),
            Wrap(
              children: values.map((pref) {
                print("pref $pref");
                return Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      margin: EdgeInsets.symmetric(horizontal: 2, vertical: 3),
                      padding: EdgeInsets.symmetric(horizontal: 3, vertical: 1),
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(6),
                        color: Colors.black,
                      ),
                      child: Text(
                            () {
                          final translations = {
                            'English': {
                              'dietaryPreferences': ['Halal', 'Kosher', 'Vegetarian', 'Vegan'],
                            },
                            'Portuguese': {
                              'dietaryPreferences': ['Halal', 'Kosher', 'Vegetariano', 'Vegano'],
                            },
                            'French': {
                              'dietaryPreferences': ['Halal', 'Casher', 'Végétarien', 'Végan'],
                            },
                            'Spanish': {
                              'dietaryPreferences': ['Halal', 'Kosher', 'Vegetariano', 'Vegano'],
                            },
                          };

                          final englishPrefs = translations['English']!['dietaryPreferences'] as List<String>;
                          final index = englishPrefs.indexOf(pref);

                          if (index != -1 && translations.containsKey(selectedLanguage)) {
                            return (translations[selectedLanguage]!['dietaryPreferences'] as List<String>)[index];
                          }
                          return pref;
                        }(),
                        style: TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                          fontSize: 12,
                        ),
                      ),
                    ),
                    if (detailed && descriptions.containsKey(pref) && descriptions[pref]!.containsKey(selectedLanguage))
                      Padding(
                        padding: const EdgeInsets.only(top: 4.0),
                        child: Text(
                          descriptions[pref]![selectedLanguage]!,
                          style: TextStyle(fontSize: 15.0, color: textColor),
                        ),
                      ),
                  ],
                );
              }).toList(),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildInfoCardDetailed({
    required IconData icon,
    required String pref,
    required Color? color,
    required Color textColor,
    double? width,
    double? height,
  }) {
    final Map<String, Map<String, String>> descriptions = {
      'Vegan': {
        'English': 'A diet that avoids all animal products, including meat, fish, poultry, dairy, eggs, and even honey, focusing entirely on plant-based foods.',
        'Portuguese': 'Uma dieta que evita todos os produtos animais, incluindo carne, peixe, aves, laticínios, ovos e até mesmo mel, focando exclusivamente em alimentos de origem vegetal.',
        'French': 'Un régime qui évite tous les produits animaux, y compris la viande, le poisson, la volaille, les produits laitiers, les œufs et même le miel, se concentrant uniquement sur les aliments d\'origine végétale.',
        'Spanish': 'Una dieta que evita todos los productos animales, incluida la carne, el pescado, la aves, los lácteos, los huevos e incluso la miel, centrándose completamente en alimentos de origen vegetal.',
      },
      'Halal': {
        'English': 'Food prepared and consumed in compliance with Islamic dietary laws, which include specific slaughtering methods, prohibition of pork and alcohol, and requirements for cleanliness.',
        'Portuguese': 'Comida preparada e consumida em conformidade com as leis dietéticas islâmicas, que incluem métodos específicos de abate, proibição de carne de porco e álcool, e exigências de limpeza.',
        'French': 'Nourriture préparée et consommée conformément aux lois alimentaires islamiques, qui incluent des méthodes d\'abattage spécifiques, l\'interdiction de la viande de porc et de l\'alcool, et des exigences en matière de propreté.',
        'Spanish': 'Alimentos preparados y consumidos de acuerdo con las leyes dietéticas islámicas, que incluyen métodos de sacrificio específicos, prohibición de carne de cerdo y alcohol, y requisitos de limpieza.',
      },
      'Kosher': {
        'English': 'Food that adheres to Jewish dietary laws (kashrut), including specific rules about animal slaughter, prohibition of mixing dairy and meat, and exclusion of non-kosher animals like pork and shellfish.',
        'Portuguese': 'Comida que segue as leis dietéticas judaicas (kashrut), incluindo regras específicas sobre o abate de animais, proibição de misturar laticínios e carne, e exclusão de animais não kosher como porco e mariscos.',
        'French': 'Nourriture qui suit les lois alimentaires juives (kashrut), y compris des règles spécifiques sur l\'abattage des animaux, l\'interdiction de mélanger les produits laitiers et la viande, et l\'exclusion d\'animaux non casher tels que le porc et les fruits de mer.',
        'Spanish': 'Alimentos que se adhieren a las leyes dietéticas judías (kashrut), incluyendo reglas específicas sobre el sacrificio de animales, prohibición de mezclar lácteos y carne, y exclusión de animales no kosher como el cerdo y los mariscos.',
      },
      'Vegetarian': {
        'English': 'A diet that excludes meat, fish, and poultry but may include dairy products and eggs, focusing on plant-based foods.',
        'Portuguese': 'Uma dieta que exclui carne, peixe e aves, mas pode incluir laticínios e ovos, focando em alimentos de origem vegetal.',
        'French': 'Un régime qui exclut la viande, le poisson et la volaille, mais peut inclure des produits laitiers et des œufs, se concentrant sur les aliments d\'origine végétale.',
        'Spanish': 'Una dieta que exclue la carne, el pescado y la aves, pero puede incluir lácteos y huevos, centrándose en alimentos de origen vegetal.',
      },
    };

    return Container(
      width: width,
      height: height,
      padding: EdgeInsets.all(8.0),
      margin: EdgeInsets.symmetric(vertical: 4, horizontal: 4),
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(8.0),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 20.0, color: textColor),
          SizedBox(height: 5.0),
        Text(
              () {
            final translations = {
              'English': {
                'dietaryPreferences': ['Halal', 'Kosher', 'Vegetarian', 'Vegan'],
              },
              'Portuguese': {
                'dietaryPreferences': ['Halal', 'Kosher', 'Vegetariano', 'Vegano'],
              },
              'French': {
                'dietaryPreferences': ['Halal', 'Casher', 'Végétarien', 'Végan'],
              },
              'Spanish': {
                'dietaryPreferences': ['Halal', 'Kosher', 'Vegetariano', 'Vegano'],
              },
            };

            final englishPrefs = translations['English']!['dietaryPreferences'] as List<String>;
            final index = englishPrefs.indexOf(pref);

            if (index != -1 && translations.containsKey(selectedLanguage)) {
              return (translations[selectedLanguage]!['dietaryPreferences'] as List<String>)[index];
            }
            return pref;
          }(),
          style: TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.bold,
            fontSize: 12,
          ),
        ),
          SizedBox(height: 4.0),
          if (descriptions.containsKey(pref) && descriptions[pref]!.containsKey(selectedLanguage))
            Padding(
              padding: const EdgeInsets.only(top: 4.0),
              child: Text(
                descriptions[pref]![selectedLanguage]!,
                style: TextStyle(fontSize: 15.0, color: textColor),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildToggleButton(String label, int index) {
    return GestureDetector(
      onTap: () {
        // setState(() {
        //   for (int i = 0; i < isSelected.length; i++) {
        //     isSelected[i] = i == index;
        //   }
        // });
      },
      child: Container(
        padding: EdgeInsets.symmetric(horizontal: 6.0, vertical: 5.0),
        decoration: BoxDecoration(
          color: isSelected[index] ? Colors.black : Colors.transparent,
          borderRadius: BorderRadius.circular(10.0),
          border: Border.all(color: Colors.black12),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              label,
              style: TextStyle(
                color: isSelected[index] ? Colors.white : Colors.black,
                fontWeight: FontWeight.bold,
                fontSize: 12,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
class FilterBar extends StatelessWidget {
  final int selectedIndex;
  final Function(int) onFilterSelected;

  const FilterBar({
    required this.selectedIndex,
    required this.onFilterSelected,
    Key? key,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final labels = ["Card", "Settings"];
    final screenWidth = MediaQuery.of(context).size.width;
    final buttonWidth = (screenWidth - 55) / 2;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 15.0, vertical: 0),
      child: Container(
        color: Colors.grey[200],
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8.0, vertical: 6.0), // Padding inside the border
          child: Stack(
            children: [
              // Sliding background
              Positioned(
                top: 0,
                left: selectedIndex * buttonWidth + 10,
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 100),
                  curve: Curves.easeInOut,
                  width: buttonWidth,
                  height: 30,
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(8.0),
                  ),
                ),
              ),
              // Filter buttons
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: List.generate(labels.length, (index) {
                  return Expanded( // Make each item take up the available space equally
                    child: GestureDetector(
                      onTap: () => onFilterSelected(index),
                      child: SizedBox(
                        height: 30,
                        child: Center(
                          child: Text(
                            labels[index],
                            style: TextStyle(
                              color: selectedIndex == index ? Colors.black : Colors.black54,
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