import 'dart:convert';
import 'package:auth0_flutter/auth0_flutter.dart';
import 'package:easibite/screens/home_main.dart';
import 'package:easibite/screens/home_screen.dart';
import 'package:easibite/screens/menu_screen.dart';
import 'package:easibite/widgets/bottom_nav_bar.dart';
import 'package:flutter/material.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:http/http.dart' as http;

import '../widgets/ContactsDialog.dart';

class OnboardingScreen extends StatefulWidget {
  final UserProfile? user;  // Accept the UserProfile

  OnboardingScreen({Key? key, this.user});
  @override
  _OnboardingScreenState createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen> {
  int currentStep = 0;
  Map<String, dynamic> userPreferences = {
    "dietary": [],
    "allergens": [],
    "spiceLevel": "Mild",
    "foodTemperature": "Hot",
    "emergency":[],
    "notes": "",
  };
  String dietaryRequirement = '';
  final TextEditingController _userAllergenController = TextEditingController();
  final TextEditingController _controller = TextEditingController();

  void _submitNotes() {
    if (userPreferences['notes']!.isNotEmpty) {
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
        userPreferences['notes'] = '';
        _controller.clear();
      });
    }
  }
  List<String> kosherOptions = [
    "Strict Kosher (Certified Only)",
    "Kosher Style – Dairy & Pareve Only",
    "Kosher Meat & Fish",
    "Basic Kosher"
  ];
  String emergencyString = '';

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
                  userPreferences['kosherType'] = option;
                });
                Navigator.pop(context);
              },
              selected: userPreferences['kosherType'] == option,
            );
          }).toList(),
        );
      },
    );
  }
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
                userPreferences['emergency'] ??= <String>[];
                (userPreferences['emergency'] as List).add(phoneNumber);
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
  final List<String> allergenOptions = [
    "Peanuts",
    "Tree Nuts",
    "Milk",
    "Eggs",
    "Fish",
    "Shellfish",
    "Soy",
    "Wheat",
    "Sesame",
  ];
  final List<String> spiceLevels = ["Mild", "Medium", "Spicy"];
  final List<String> foodTemperatures = ["Hot", "Cold"];

  @override
  void initState() {
    super.initState();
    if(widget.user != null){
      print(widget.user?.name);
    }
  }

  void _savePreferences() async {
    try {
      if (widget.user != null) {
        print(widget.user?.name);
      }
      final userEmail = widget.user?.email ?? "john.doe@example.com";

      // No need to check if user exists
      // Backend handles duplicate prevention automatically
      
      final payload = {
        "name": widget.user?.name ?? "Unknown User",
        "emailid": userEmail,
        "phonenumber": '+14155552671', // Use the demo number for now
        "dietary": userPreferences['dietary'] ?? [],        
        "allergens": userPreferences['allergens'] ?? [],
        "spiceLevel": userPreferences['spiceLevel'] ?? "Medium",
        "foodTemperature": [userPreferences['foodTemperature'] ?? "Hot"],
        "additionalNotes": userPreferences['notes'] ?? "",
        "onboardingCompleted": true,
        "groups": [],
        "groupinvites": [],
        "emergency": userPreferences['emergency'] ?? [],
      };

      print("Payload: ${jsonEncode(payload)}");

      // Always POST, backend handles existing users
      final response = await http.post(
        Uri.parse("http://13.57.29.10:7000/users"),
        headers: {"Content-Type": "application/json"},
        body: jsonEncode(payload),
      ).timeout(Duration(seconds: 30));

      print("Response status: ${response.statusCode}");
      print("Response body: ${response.body}");

      if (response.statusCode == 200 || response.statusCode == 201) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Preferences saved successfully!")),
        );

        // Save to local storage
        final prefs = await SharedPreferences.getInstance();
        await prefs.setBool('isOnboarded', true);
        await prefs.setString('userPreferences', jsonEncode(userPreferences));

        print("Local preferences saved: ${jsonEncode(userPreferences)}");

        // Navigate to home
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (context) => HomeScreen(user: widget.user)),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text("Failed to save preferences: ${response.body}"),
          ),
        );
      }
    } catch (e) {
      print("Error saving preferences: $e");
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text("Error saving preferences: $e"),
        ),
      );
    }
  }
  Widget _buildStepContent() {
    switch (currentStep) {
      case 0:
        return Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            SizedBox(height: 5),
            Text(
              "Welcome to MenuSense",
              style: TextStyle(fontSize: 27, fontWeight: FontWeight.bold),
              textAlign: TextAlign.center,
            ),
            SizedBox(height: 15),
            Text(
              "Let's personalize your dining \n experience",
              style: TextStyle(color: Colors.grey[600], fontSize: 16),
              textAlign: TextAlign.center,
            ),
          ],
        );
      case 1:
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 16.0),
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
                      ? "Follows kosher dietary laws (${userPreferences['kosherType'] ?? 'Tap to select'})"
                      : option == "Vegetarian"
                      ? "No meat products"
                      : "No animal products",
                  style: TextStyle(fontSize: 14, color: Colors.grey[600]),
                ),
                activeColor: Colors.orange,
                value: userPreferences['dietary'].contains(option),
                onChanged: (value) {
                  setState(() {
                    if (value) {
                      userPreferences['dietary'].add(option);
                      if (option == "Kosher") {
                        _showKosherOptions(context);
                      }
                    } else {
                      userPreferences['dietary'].remove(option);
                      if (option == "Kosher") {
                        userPreferences.remove('kosherType');
                      }
                    }
                  });
                },
              );
            }).toList(),

          ],
        );

      case 2:
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 0),
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
                  SizedBox(height: 8),
                  Text(
                    "Select any allergies or intolerances",
                    style: TextStyle(
                      fontSize: 16,
                      color: Colors.grey,
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
                      userPreferences['allergens'].clear();
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
                final isSelected = userPreferences['allergens'].contains(option);
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
                        if (!userPreferences['allergens'].contains(option)) {
                          userPreferences['allergens'].add(option);
                        }
                      } else {
                        userPreferences['allergens'].remove(option);
                      }
                    });
                  },
                );
              }).toList(),
            ),
            SizedBox(height: 20),

// Additional Notes
            Text(
              "Additional Allergens",
              style: TextStyle(fontWeight: FontWeight.w600),
            ),
            TextField(
              controller: _userAllergenController,
              decoration: InputDecoration(
                hintText: "Any other dietary requirements...",
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
                    // Add to allergenOptions if new
                    if (!allergenOptions.contains(dietaryRequirement)) {
                      allergenOptions.add(dietaryRequirement);
                    }

                    // Add to userPreferences['allergens'] if new
                    if (!(userPreferences['allergens'] as List).contains(dietaryRequirement)) {
                      userPreferences['allergens'].add(dietaryRequirement);
                    }

                    _userAllergenController.clear();
                    dietaryRequirement = '';
                  });
                }
              },
              child: Text("Add Allergen"),
            ),

          ],
        );
      case 3:
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Title
            Text(
              "Additional Preferences",
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
            ),
            SizedBox(height: 10),
            Text(
              "Customize your experience",
              style: TextStyle(color: Colors.grey),
            ),
            SizedBox(height: 20),

            // Spice Level Preference
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
                      color: userPreferences['spiceLevel'] == level ? Colors.white : Colors.black,
                    ),
                  ),
                  selected: userPreferences['spiceLevel'] == level,
                  selectedColor: Colors.orange,
                  backgroundColor: Colors.grey[200],
                  showCheckmark: false, // Removes the tick icon
                  onSelected: (selected) {
                    if (selected) {
                      setState(() {
                        userPreferences['spiceLevel'] = level;
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

                          (userPreferences['emergency'] as List).add(emergencyString.trim());
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

            // Food Temperature
            // Text(
            //   "Food Temperature",
            //   style: TextStyle(fontWeight: FontWeight.w600),
            // ),
            // Wrap(
            //   spacing: 10,
            //   runSpacing: 10,
            //   children: foodTemperatures.map((temp) {
            //     return ChoiceChip(
            //       label: Text(
            //         temp,
            //         style: TextStyle(
            //           color: userPreferences['foodTemperature'] == temp ? Colors.white : Colors.black,
            //         ),
            //       ),
            //       selected: userPreferences['foodTemperature'] == temp,
            //       selectedColor: Colors.orange,
            //       backgroundColor: Colors.grey[200],
            //       showCheckmark: false, // Removes the tick icon
            //       onSelected: (selected) {
            //         if (selected) {
            //           setState(() {
            //             userPreferences['foodTemperature'] = temp;
            //           });
            //         }
            //       },
            //     );
            //   }).toList(),
            // ),
            // SizedBox(height: 20),

            // Additional Notes
            Text(
              "Additional Notes",
              style: TextStyle(
                fontWeight: FontWeight.w600,
                fontSize: 16,
                color: Colors.black87,
              ),
            ),
            SizedBox(height: 8),
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
                          borderSide: BorderSide(color: Colors.black87, width: 1.5, style: BorderStyle.solid),
                        ),
                        contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                        suffixIcon: _controller.text.isNotEmpty
                            ? IconButton(
                          icon: Icon(Icons.clear, color: Colors.grey[400]),
                          onPressed: () {
                            setState(() {
                              _controller.clear();
                              userPreferences['notes'] = '';
                            });
                          },
                        )
                            : null,
                      ),
                      cursorColor: Colors.cyanAccent,
                      onChanged: (value) {
                        setState(() {
                          userPreferences['notes'] = value;
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
                      shadowColor: Colors.cyanAccent.withOpacity(0.5),
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
            )

          ],
        );

      case 4:
        return Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Container(
              width: 70,
              height: 70,
              decoration: const BoxDecoration(
                color: Colors.orange,
                shape: BoxShape.circle,
              ),
              child: Center(
                child: Image.asset(
                  'assets/Vector-6.png',
                  width: 40,
                  height: 40,
                  fit: BoxFit.contain,
                ),
              ),
            ),
            SizedBox(height: 6,),
            RichText(
              textAlign: TextAlign.center,
              text: TextSpan(
                children: [
                  TextSpan(
                    text: "You're All\n",
                    style: TextStyle(
                      fontSize: 32,
                      fontWeight: FontWeight.bold,
                      color: Colors.black, // Black color for "You're All"
                    ),
                  ),
                  TextSpan(
                    text: "Set!",
                    style: TextStyle(
                      fontSize: 34,
                      fontWeight: FontWeight.bold,
                      color: Colors.orange, // Orange color for "Set!"
                    ),
                  ),
                ],
              ),
            ),
            SizedBox(height: 10),
            Text(
              "Your profile is ready. Let's start finding\nsafe and delicious food options for you.",
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 16, color: Colors.grey[700]),
            ),
            SizedBox(height: 20),
            Container(
              padding: EdgeInsets.all(10),
              margin: EdgeInsets.symmetric(horizontal: 20),
              decoration: BoxDecoration(
                border: Border.all(color: Colors.grey),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Column(
                children: [
                  Text(
                    "Your Profile Summary:",
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                  SizedBox(height: 10),
                  Wrap(
                    spacing: 10,
                    runSpacing: 10,
                    children: userPreferences.entries.expand<Widget>((entry) {
                      if (entry.value != null && entry.value.toString().isNotEmpty) {
                        // Check if the value is a List
                        if (entry.value is List) {
                          return (entry.value as List).map<Widget>((item) {
                            return Container(
                              padding: EdgeInsets.symmetric(horizontal: 15, vertical: 8),
                              decoration: BoxDecoration(

                                border: Border.all(color: Colors.orange),
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: Text(
                                item.toString(), // Display each item in the list
                                style: TextStyle(color: Colors.orange, fontWeight: FontWeight.bold),
                              ),
                            );
                          });
                        } else {
                          // For non-list values
                          return [
                            Container(
                              padding: EdgeInsets.symmetric(horizontal: 15, vertical: 8),
                              decoration: BoxDecoration(

                                border: Border.all(color: Colors.orange),
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: Text(
                                entry.value.toString(), // Display the single value
                                style: TextStyle(color: Colors.orange, fontWeight: FontWeight.bold),
                              ),
                            ),
                          ];
                        }
                      }
                      return []; // Return an empty list if the condition is not met
                    }).toList(), // Convert the Iterable<Widget> to a List<Widget>
                  ),

                ],
              ),
            ),
          ],
        );
      default:
        return Container();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text("Onboarding"),
        automaticallyImplyLeading: false,
      ),
      body: SingleChildScrollView(
        child: Column(
          children: [
            LinearProgressIndicator(
              value: (currentStep + 1) / 5,
            ),
            Container(
              margin: EdgeInsets.all(16),
              padding: EdgeInsets.all(16),
              decoration: BoxDecoration(
                border: Border.all(
                  color: Colors.grey.shade300,
                  width: 2.0,
                ),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      if (currentStep > 0)
                        Container(
                          child: IconButton(
                            onPressed: () {
                              setState(() {
                                currentStep--;
                              });
                            },
                            icon: Icon(Icons.arrow_back),
                            color: Colors.black,
                            padding: EdgeInsets.all(12), // Adjust size of the button
                            iconSize: 28, // Adjust icon size
                          ),
                        )
                      else
                        SizedBox(width: 0),
                      Padding(
                        padding: EdgeInsets.only(top: 16.0, left: 12.0,bottom: 12),
                        child: Align(
                          alignment: Alignment.centerLeft,
                          child: Text("Step ${currentStep + 1} of 5"),
                        ),
                      ),
                    ],
                  ),
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 26.0),
                    child: SingleChildScrollView(
                      child: _buildStepContent(),
                    ),
                  ),
                ],
              ),
            ),
            // Button Row for navigation
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16.0),
              child: SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () {
                    if (currentStep == 0) {
                      setState(() {
                        currentStep++;
                      });
                    }else if (currentStep == 2) {
                      print("444eqwdqw");
                      showDialog(
                        context: context,
                        builder: (BuildContext context) {
                          return AlertDialog(
                            title: const Text('Confirm allergens'),
                            content: Text(
                              'Are you sure about the allergens: ${userPreferences['allergens'].map((allergen) => allergen).join(', ')}?',
                            ),
                            actions: [
                              TextButton(
                                onPressed: () {
                                  Navigator.of(context).pop(); // Close dialog on cancel
                                  // Optionally, handle cancellation (e.g., stay on step)
                                },
                                child: const Text('Cancel'),
                              ),
                              TextButton(
                                onPressed: () {
                                  Navigator.of(context).pop(); // Close dialog on confirm
                                  // Proceed to next step, e.g., update currentStep
                                  setState(() {
                                    currentStep++;
                                  });
                                },
                                child: const Text('Confirm'),
                              ),
                            ],
                          );
                        },
                      );
                    } else if (currentStep < 4) {
                      setState(() {
                        currentStep++;
                      });
                    }else {
                      print("00022");
                      _savePreferences();
                    }
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.orange[700],
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                    padding: EdgeInsets.symmetric(vertical: 10), // vertical only now
                  ),
                  child: Text(
                    currentStep == 0
                        ? "Get Started"
                        : currentStep == 3
                        ? "Done"
                        : currentStep == 4
                        ? "Start Exploring"
                        : "Continue",
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 20,
                    ),
                  ),
                ),
              ),
            ),
            SizedBox(height: 20),
          ],
        ),
      ),
    );
  }
}


