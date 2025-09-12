import 'dart:convert';
import 'dart:io';

import 'package:auth0_flutter/auth0_flutter.dart';
import 'package:flutter/material.dart';
import 'package:http_parser/http_parser.dart';
import 'package:image_picker/image_picker.dart';
import 'package:file_picker/file_picker.dart';
import 'package:http/http.dart' as http;
import 'package:path/path.dart' as path;

import 'home_screen.dart';
import 'menu_analysis_page.dart';

class ScanMenuPage extends StatefulWidget {
  final UserProfile? user;
  ScanMenuPage({this.user});
  @override
  _ScanMenuPageState createState() => _ScanMenuPageState();
}

class _ScanMenuPageState extends State<ScanMenuPage> {
  final ImagePicker _picker = ImagePicker();
  int ? safeItemsCount;
  int ? cautionCount;
  int ? avoidCount;
  bool isLoading = false;

  Future<void> _getImageFromCamera() async {
    final pickedFile = await _picker.pickImage(source: ImageSource.camera);
    if (pickedFile != null) {
      print("Image picked from camera: ${pickedFile.path}");
      // Handle the picked file, e.g., display it or upload it
    }
  }

  Future<void> _getFileFromGallery() async {
    // Allow picking both PDFs and images
    FilePickerResult? result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['jpg', 'jpeg', 'png', 'pdf'], // Specify allowed file types
    );

    if (result != null && result.files.single.path != null) {
      String filePath = result.files.single.path!;
      print("File picked: $filePath");
      setState(() {
        isLoading = true;
      });

      // Check the file extension
      String extension = filePath.split('.').last.toLowerCase();
      if (extension == 'pdf') {
        _handlePdf(filePath);
      } else if (['jpg', 'jpeg', 'png'].contains(extension)) {
        _handleImage(filePath);
      } else {
        print("Unsupported file type: $extension");
      }
    } else {
      print("No file selected");
    }
  }

// Function to handle PDF files
  Future<void> _handlePdf(String filePath) async {
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
      print(json.encode({'pdflink': fileUrl}));

      if (analyzeResponse.statusCode == 200) {
        print("Analyze Success: ${analyzeResponse.body}");
        // Do something with response like updating UI
        var analysisData = json.decode(analyzeResponse.body);

        // Assuming the analysis response has a menu field
        var menuData = analysisData; // If the entire body is the menu, you may adjust this.

        // Construct the payload
        Map<String, dynamic> payload = {
          "restuarant_id": "",  // Add your restaurant ID here
          "nores": "yes",
          "email_id": widget.user!.email,
          "menu": menuData
        };
        try {
          final response = await http.post(
            Uri.parse('http://13.57.29.10:7000/users/get_preferences'),
            headers: {"Content-Type": "application/json"},
            body: json.encode(payload),
          );

          if (response.statusCode == 200) {
            final responseData = json.decode(response.body);
            print("Data sent successfully!");
            print(response.body); // Handle the response as needed
            print(responseData['result'][0]['text']);
            List<Map<String, dynamic>> menuList = [];
            print("00d");
            if (responseData.containsKey('response_menu')) {
              menuList = List<Map<String, dynamic>>.from(responseData['response_menu']);
              print(menuList);
            } else {
              print("No 'response_menu' key found in responseData");
            }
            if (responseData.containsKey('result')) {
              final resultText = responseData['result'][0]['text'];
              final regex = RegExp(r'id=(\w+)\sclass=(\w+)>(.*?)<');

              final matches = regex.allMatches(resultText);
              // final Map<String, List<Map<String, String>>> parsedData = {};
              final Map<String, List<Map<String, String>>> parsedData = {};

              for (final match in matches) {
                final id = match.group(1) ?? ''; // Extract the id
                final category = match.group(2) ?? ''; // Extract the class/category
                final name = match.group(3) ?? ''; // Extract the item name

                if (id.isNotEmpty && category.isNotEmpty && name.isNotEmpty) {
                  parsedData.putIfAbsent(category, () => []).add({
                    'id': id,
                    'name': name,
                  });
                }
              }
              safeItemsCount = parsedData['SAFE']?.length ?? 0;
              cautionCount = parsedData['CAUTION']?.length ?? 0;
              avoidCount = parsedData['AVOID']?.length ?? 0;
              print("LLLL377");
              print(parsedData);
              isLoading = false;
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => MenuAnalysisPage(
                    id:"",
                    name: "",
                    user: widget.user,
                    safeItemCount: safeItemsCount,
                    cautionCount: cautionCount,
                    avoidCount: avoidCount,
                    parsedData: parsedData,
                    analysisString: "",
                    menuList: menuList,
                  ),
                ),
              );
            } else {
              // If no result key is found, mark this restaurantId as failed
              // setState(() {
              //   safeItemsCount[restaurantId] = 0;
              // });

              throw Exception("Key 'result' not found in response");
            }
          } else {
            print("Failed to send data. Status code: ${response.statusCode}");
          }
        } catch (e) {
          print("Error: $e");
        }
      } else {
        print("Analyze Failed: ${analyzeResponse.statusCode}");
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Analyze Failed: ${analyzeResponse.statusCode}")),
        );
        setState(() {
          isLoading=false;
        });
      }
    } else {
      print("Upload Failed: ${uploadResponse.statusCode}");
    }
  }

// Function to handle image files
  Future<void> _handleImage(String filePath) async {
    print("Handling Image: $filePath");
    // Add your image handling logic here, e.g., display or upload
    File imageFile = File(filePath);
    // Example: Display the image or upload it
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Scan Menu', style: TextStyle(color: Colors.black)),
        backgroundColor: Colors.white,
        elevation: 0,
      ),
      body: isLoading?Center(child: CircularProgressIndicator(),):
      Column(
        children: [
          SizedBox(height: 20),

          // Camera and Upload options
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Expanded(
                  child: ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.orange,
                    ),
                    onPressed: _getImageFromCamera,
                    icon: Icon(Icons.camera_alt),
                    label: Text("Camera"),
                  ),
                ),
                SizedBox(width: 20),
                Expanded(
                  child: ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.grey.shade300,
                    ),
                    onPressed: _getFileFromGallery,
                    icon: Icon(Icons.upload),
                    label: Text("Upload"),
                  ),
                ),
              ],
            ),
          ),
          SizedBox(height: 20),

          // Frame with camera icon and instructions
          Expanded(
            child: Container(
              margin: EdgeInsets.symmetric(horizontal: 20),
              decoration: BoxDecoration(
                color: Colors.black,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.camera_alt, size: 50, color: Colors.white),
                    SizedBox(height: 10),
                    Text(
                      "Position menu within frame",
                      style: TextStyle(color: Colors.white),
                    ),
                    Text(
                      "Ensure good lighting and menu is clearly visible",
                      style: TextStyle(color: Colors.white70, fontSize: 12),
                    ),
                  ],
                ),
              ),
            ),
          ),
          SizedBox(height: 20),

          // Click to Start button
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: ElevatedButton(
              onPressed: () {
                // Start scan action
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.orange,
                minimumSize: Size.fromHeight(50), // Full width button
              ),
              child: Text("Click to start"),
            ),
          ),
          SizedBox(height: 20),
        ],
      ),
    );
  }
}
