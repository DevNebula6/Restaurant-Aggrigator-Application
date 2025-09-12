import 'dart:convert';
import 'package:auth0_flutter/auth0_flutter.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

class Members extends StatefulWidget {
  final Function(Map<String, dynamic>) updateGroupDataFunc;
  final Map<String, dynamic> groupData;
  final UserProfile? user;
  final String groupId;
  final List<String> users;
  final void Function(String)? onRemoveGroup;
  final Function(String)? onClearGroupCache; 


  const Members({
    super.key,
    required this.groupId,
    this.user,
    this.onClearGroupCache,
    required this.groupData,
    required this.users, required this.onRemoveGroup, required this.updateGroupDataFunc, // Fixed constructor to include users
  });

  @override
  State<Members> createState() => _MembersState();
}

class _MembersState extends State<Members> {
  late List<String> users;

  @override
  void initState() {
    super.initState();
    // Initialize the users list from widget.users instead of groupData directly
    users = widget.users.isNotEmpty
        ? widget.users.toSet().toList() // Remove duplicates
        : [];
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
    print("Updating user data...${userData["groups"].runtimeType}");
    for (var item in userData["groups"]) {
      // Print the type of each item
      print('Type of item in userData["groups"]: ${item.runtimeType}');
    }
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
        "name": userData["name"] ?? "Unknown"
      };
      print("JSON Payload being sent: ${jsonEncode(requestBody)}");

      final response = await http.put(
        Uri.parse('http://13.57.29.10:7000/users/update'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode(requestBody),
      );

      if (response.statusCode == 200) {
        print("User updated successfully: ${response.body}");
        final responseData = jsonDecode(response.body);
        print("Response Data from updating user data : $responseData");
      } else {
        print("Failed to update user: ${response.statusCode} - ${response.body}");
      }
    } catch (e) {
      print("Error updating user: $e");
    }
  }

  Future<void> removeUser(String userId) async {
    // Check if admins is a list or single value
    final admins = widget.groupData['admins'];
    final isUserAdmin = admins is List
        ? (admins).contains(userId)
        : admins == userId;

    // Show confirmation dialog
    bool? confirm = await showDialog<bool>(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Confirm Deletion'),
          content: Text(
            isUserAdmin && userId == widget.user?.email
                ? 'As an admin, removing yourself will disband the group. Do you wish to proceed?'
                : 'Are you sure you want to remove this member?',
          ),
          actions: <Widget>[
            TextButton(
              child: const Text('Cancel'),
              onPressed: () => Navigator.of(context).pop(false),
            ),
            TextButton(
              child: const Text('Delete'),
              onPressed: () => Navigator.of(context).pop(true),
            ),
          ],
        );
      },
    );

    if (confirm == true) {
      // ✅ CHECK IF WIDGET IS STILL MOUNTED BEFORE PROCEEDING
      if (!mounted) return;
      
      // Check if user is removing themselves (admin leaving group)
      final isLeavingGroup = (isUserAdmin && userId == widget.user?.email);
      
      // Update local state immediately
      setState(() {
        users.remove(userId);
      });
      print('Deleted user: $userId');

      try {
        // Update the group data and send to server
        Map<String, dynamic> updatedGroupData = Map<String, dynamic>.from(widget.groupData);
        updatedGroupData['user_ids'] = users;

        final response = await http.put(
          Uri.parse('http://13.57.29.10:7000/groups/update/${widget.groupId}'),
          headers: {'Content-Type': 'application/json'},
          body: jsonEncode(updatedGroupData),
        );

        // ✅ CHECK MOUNTED BEFORE CONTINUING
        if (!mounted) return;

        if (response.statusCode == 200) {
          final userResponse = await getUserByEmail(userId);

          // ✅ CHECK MOUNTED AGAIN
          if (!mounted) return;

          if (userResponse['status'] == 'success') {
            var existingData = Map<String, dynamic>.from(userResponse['data'][0]);

            // Check and update groups list
            List<dynamic> updatedGroups = List.from(existingData['groups'] ?? []);
            if (updatedGroups.contains(widget.groupId)) {
              updatedGroups.remove(widget.groupId);
            }

            await _updateUserData({
              "name": existingData["name"] ?? "John Doe",
              "phonenumber": existingData["phonenumber"] ?? "1234567890",
              "emailid": userId,
              "dietary": existingData['dietary'],
              "allergens": existingData['allergens'],
              "spiceLevel": existingData['spiceLevel'],
              "foodTemperature": existingData['foodTemperature'],
              "additionalNotes": existingData['additionalNotes'],
              "onboardingCompleted": true,
              "groups": updatedGroups,
              "groupinvites": existingData["groupinvites"] ?? [],
              "emergency": existingData['emergency']
            });

            // ✅ Invalidate compatibility cache since group composition changed
            await _invalidateCompatibilityCache(widget.groupId);

            // ✅ CHECK MOUNTED BEFORE NAVIGATION/UI UPDATES
            if (!mounted) return;
            
            // Handle navigation for user leaving their own group
            if (isLeavingGroup) {
              // Remove group from MyGroupsScreen and navigate back
              if (widget.onRemoveGroup != null) {
                widget.onRemoveGroup!(widget.groupId);
              }
              if (widget.onClearGroupCache != null) {
                widget.onClearGroupCache!(widget.groupId);
              }
              // Navigate back to groups screen
              Navigator.of(context).pop();
            }
          }
        } else {
          print("Failed to update group data: ${response.body}");
          
          // ✅ CHECK MOUNTED BEFORE SHOWING SNACKBAR
          if (!mounted) return;
          
          // Revert the UI change if the API fails
          setState(() {
            users.add(userId);
          });
          
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Failed to remove user')),
          );
        }
      } catch (e) {
        print("Error during user removal: $e");
        
        // ✅ CHECK MOUNTED BEFORE UI UPDATES
        if (!mounted) return;
        
        // Revert the UI change on error
        setState(() {
          users.add(userId);
        });
        
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error removing user: $e')),
        );
      }
    }
  }

  // Cache invalidation method
  Future<void> _invalidateCompatibilityCache(String groupId) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      String? storedData = prefs.getString('comp_percent_list');
      if (storedData != null) {
        List<Map<String, dynamic>> compPercentList = List<Map<String, dynamic>>.from(
          jsonDecode(storedData).map((item) => Map<String, dynamic>.from(item)),
        );
        compPercentList.removeWhere((entry) => entry['groupId'] == groupId);
        await prefs.setString('comp_percent_list', jsonEncode(compPercentList));
        
        print('🗑️ Members: Invalidated compatibility cache for group $groupId due to user removal');
        
        // ✅ ADD: Also clear any in-memory caches
        
        if (mounted) {
          // Trigger UI refresh if needed
          setState(() {});
        }
      }
    } catch (e) {
      print('❌ Members: Error invalidating compatibility cache: $e');
    }
  }

  Future<void> cancelInvite(String selectedEmail) async {
    try {
      // Step 1: Update group data to remove selectedEmail from pendingids
      Map<String, dynamic> updatedGroupData = Map<String, dynamic>.from(widget.groupData);

      // Ensure pendingids exists
      if (!updatedGroupData.containsKey('pendingids') || updatedGroupData['pendingids'] == null) {
        updatedGroupData['pendingids'] = [];
      }

      // Remove selectedEmail from pendingids
      if (updatedGroupData['pendingids'] is List) {
        List<dynamic> pendingIds = List.from(updatedGroupData['pendingids']);
        if (pendingIds.contains(selectedEmail)) {
          pendingIds.remove(selectedEmail);
          updatedGroupData['pendingids'] = pendingIds;

          // Send update to the API
          final response = await http.put(
            Uri.parse('http://13.57.29.10:7000/groups/update/${widget.groupId}'),
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode(updatedGroupData),
          );

          if (response.statusCode == 200) {
            widget.updateGroupDataFunc(updatedGroupData);
            print('Group updated successfully: ${response.body}');
          } else {
            throw Exception('Failed to update group: ${response.body}');
          }
        } else {
          print('Email $selectedEmail not in pendingids');
        }
      }

      // Step 2: Update user data to remove groupId from groupinvites
      final result = await getUserByEmail(selectedEmail);
      
      // ✅ CHECK MOUNTED BEFORE CONTINUING
      if (!mounted) return;
      
      if (result['status'] == 'success') {
        print('User Data - called during cancle invite: ${result['data'][0]}');

        var payload = Map<String, dynamic>.from(result['data'][0]);

        List<dynamic> groupInvites = payload['groupinvites'] ?? [];
        if (groupInvites.contains(widget.groupId)) {
          groupInvites.remove(widget.groupId);
          payload['groupinvites'] = groupInvites;

          await _updateUserData(payload);

          // ✅ CHECK MOUNTED BEFORE SHOWING SNACKBAR
          if (!mounted) return;
          
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Invite cancelled successfully!')),
          );
        } else {
          // ✅ CHECK MOUNTED BEFORE SHOWING SNACKBAR
          if (!mounted) return;
          
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('No invite found for this group!')),
          );
        }
      } else {
        throw Exception('Failed to retrieve user data: ${result['message']}');
      }
    } catch (e) {
      print('Error cancelling invite: $e');
      
      // ✅ CHECK MOUNTED BEFORE SHOWING SNACKBAR
      if (!mounted) return;
      
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error cancelling invite: $e')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    print("kle ${widget.groupData}");
    // Extract user_ids and pendingids
    final userIds = (widget.groupData['user_ids'] is List)
        ? List<dynamic>.from(widget.groupData['user_ids'])
        : [];
    final pendingIds = (widget.groupData['pendingids'] is List)
        ? List<dynamic>.from(widget.groupData['pendingids'])
        : [];

    return Container(
      padding: const EdgeInsets.all(8.0),
      decoration: BoxDecoration(
        border: Border.all(color: Colors.black12, width: 1.0),
        borderRadius: BorderRadius.circular(8.0),
      ),
      child: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Users from user_ids
            ...userIds.map((userId) {
              final regex = RegExp(r'^[^@]+');
              final match = regex.firstMatch(userId);
              final displayName = match != null ? match.group(0)! : 'Unknown User';

              final isCurrentUser = userId == widget.user?.email;
              final admins = widget.groupData['admins'];
              final isAdmin = admins is List
                  ? (admins).contains(widget.user?.email)
                  : admins == widget.user?.email;
              final isUserAdmin = admins is List
                  ? (admins).contains(userId)
                  : admins == userId;

              return Padding(
                padding: const EdgeInsets.symmetric(vertical: 4.0),
                child: ListTile(
                  leading: CircleAvatar(
                    backgroundColor: isCurrentUser ? Colors.orange[400] : Colors.transparent,
                    child: Text(
                      isCurrentUser
                          ? 'You'
                          : match != null && match.group(0)!.isNotEmpty
                          ? match.group(0)![0].toUpperCase()
                          : '?',
                      style: TextStyle(
                        color: isCurrentUser ? Colors.white : Colors.black45,
                      ),
                    ),
                  ),
                  title: Text(
                    displayName,
                    style: const TextStyle(fontSize: 17.0),
                  ),
                  subtitle: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        userId,
                        style: const TextStyle(fontSize: 14.0, color: Colors.black54),
                      ),
                      Text(
                        isUserAdmin ? 'Admin' : 'Normal',
                        style: const TextStyle(fontSize: 12.0, color: Colors.black38),
                      ),
                    ],
                  ),
                  trailing: (isAdmin || isCurrentUser)
                      ? IconButton(
                    icon: const Icon(Icons.delete),
                    onPressed: () => removeUser(userId),
                  )
                      : null,
                  onTap: () {
                    print('Tapped on $userId');
                  },
                ),
              );
            }),
            // Pending invitees from pendingids
            ...pendingIds.map((pendingId) {
              final regex = RegExp(r'^[^@]+');
              final match = regex.firstMatch(pendingId);
              final displayName = match != null ? match.group(0)! : 'Unknown User';

              return Padding(
                padding: const EdgeInsets.symmetric(vertical: 4.0),
                child: ListTile(
                  leading: CircleAvatar(
                    backgroundColor: Colors.grey[300], // Different color to indicate pending
                    child: Text(
                      match != null && match.group(0)!.isNotEmpty
                          ? match.group(0)![0].toUpperCase()
                          : '?',
                      style: const TextStyle(color: Colors.black45),
                    ),
                  ),
                  title: Text(
                    displayName,
                    style: const TextStyle(fontSize: 17.0),
                  ),
                  subtitle: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        pendingId,
                        style: const TextStyle(fontSize: 14.0, color: Colors.black54),
                      ),
                      const Text(
                        'Pending Invite',
                        style: TextStyle(color: Colors.blue, fontSize: 14.0),
                      )
                    ],
                  ),
                  trailing: TextButton(onPressed: (){
                    cancelInvite(pendingId);
                  }, child: Text("Cancel",style: TextStyle(color: Colors.red),)),
                ),
              );
            }),
          ],
        ),
      ),
    );
  }
}
