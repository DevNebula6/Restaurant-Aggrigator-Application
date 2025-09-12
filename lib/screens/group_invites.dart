import 'dart:convert';

import 'package:auth0_flutter/auth0_flutter.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:shimmer/shimmer.dart';

class GroupInvites extends StatefulWidget {
  final UserProfile? user;
  GroupInvites({Key? key, this.user}) : super(key: key);

  @override
  _GroupInvitesState createState() => _GroupInvitesState();
}

class _GroupInvitesState extends State<GroupInvites> {
  List<Map<String, dynamic>> groupDataList = [];
  bool isLoading = true;

  Future<Map<String, dynamic>> getUserByEmail(String emailid) async {
    // Your existing getUserByEmail function remains unchanged
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

  Future<void> fetchGroupData() async {
    setState(() => isLoading = true);
    try {
      final userResponse = await getUserByEmail(widget.user!.email!);
      if (userResponse['status'] == 'success') {
        final userData = userResponse['data'][0];
        final groupInvites = List<String>.from(userData['groupinvites'] ?? []);

        groupDataList.clear();

        for (String groupId in groupInvites) {
          final groupResponse = await http.get(
            Uri.parse('http://13.57.29.10:7000/groups/$groupId'),
          );

          if (groupResponse.statusCode == 200) {
            final groupData = jsonDecode(groupResponse.body);
            print("gropws3 : ${groupData}");
            if (groupData['status'] == 'success') {
              groupDataList.add(groupData['data']);
            }
          }
        }
      }
    } catch (e) {
      print("Error fetching group data: $e");
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Error fetching group data")),
      );
    }
    setState(() => isLoading = false);
  }
  Future<void> _acceptInvite(String groupId) async {
    try {
      // 1. Get current user data
      final userResponse = await getUserByEmail(widget.user!.email!);
      if (userResponse['status'] != 'success') {
        throw Exception('Failed to fetch user data');
      }

      final userData = userResponse['data'][0];
      List<String> groupInvites = List<String>.from(userData['groupinvites'] ?? []);

      // 2. Check if groupId exists in invites and remove it
      if (groupInvites.contains(groupId)) {
        groupInvites.remove(groupId);

        // 3. Add groupId to groups list if it doesn't exist
        List<String> groups = List<String>.from(userData['groups'] ?? []);
        if (!groups.contains(groupId)) {
          groups.add(groupId);
        }

        // Update user data with new groupInvites and groups lists
        Map<String, dynamic> updatedUserData = Map<String, dynamic>.from(userData);
        updatedUserData['groupinvites'] = groupInvites;
        updatedUserData['groups'] = groups;

        // 4. Update user data in backend
        final userUpdateResponse = await http.put(
          Uri.parse('http://13.57.29.10:7000/users/update'),
          headers: {'Content-Type': 'application/json'},
          body: jsonEncode(updatedUserData),
        );

        if (userUpdateResponse.statusCode != 200) {
          throw Exception('Failed to update user data: ${userUpdateResponse.body}');
        }

        // 5. Get group data
        final groupResponse = await http.get(
          Uri.parse('http://13.57.29.10:7000/groups/$groupId'),
        );

        if (groupResponse.statusCode == 200) {
          final groupData = jsonDecode(groupResponse.body);
          if (groupData['status'] == 'success') {
            Map<String, dynamic> updatedGroupData = Map<String, dynamic>.from(groupData['data']);
            List<String> userIds = List<String>.from(updatedGroupData['user_ids'] ?? []);

            // 6. Check if user email isn't already in group and add it
            if (!userIds.contains(widget.user!.email!)) {
              userIds.add(widget.user!.email!);
              updatedGroupData['user_ids'] = userIds;
            }

            // 7. Remove user email from pendingids if it exists
            List<String> pendingIds = List<String>.from(updatedGroupData['pendingids'] ?? []);
            if (pendingIds.contains(widget.user!.email!)) {
              pendingIds.remove(widget.user!.email!);
              updatedGroupData['pendingids'] = pendingIds;
            }

            // 8. Update group data in backend
            final groupUpdateResponse = await http.put(
              Uri.parse('http://13.57.29.10:7000/groups/update/$groupId'),
              headers: {'Content-Type': 'application/json'},
              body: jsonEncode(updatedGroupData),
            );

            if (groupUpdateResponse.statusCode == 200) {
              // ✅ Immediately update local UI state
              setState(() {
                groupDataList.removeWhere((group) => group['group_id'].toString() == groupId);
              });

              // ✅ Invalidate compatibility cache since group composition changed
              await _invalidateCompatibilityCache(groupId);

              // ✅ Show success message
              if (mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Group invite accepted successfully')),
                );
              }

              // ✅ Don't call fetchGroupData() - UI is already updated
            } else {
              throw Exception('Failed to update group: ${groupUpdateResponse.body}');
            }
          } else {
            throw Exception('Group fetch failed: ${groupData['message']}');
          }
        } else {
          throw Exception('Failed to fetch group: ${groupResponse.body}');
        }
      } else {
        throw Exception('Group invite not found');
      }
    } catch (e) {
      print('Error accepting invite: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to accept invite: $e')),
        );
      }
    }
  }

  // ✅ Enhanced cache invalidation method
  Future<void> _invalidateCompatibilityCache(String groupId) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      String? storedData = prefs.getString('comp_percent_list');
      if (storedData != null) {
        List<Map<String, dynamic>> compPercentList = List<Map<String, dynamic>>.from(
          jsonDecode(storedData).map((item) => Map<String, dynamic>.from(item)),
        );
        
        // ✅ Remove all entries for this group (in case there are duplicates)
        int removedCount = compPercentList.length;
        compPercentList.removeWhere((entry) => entry['groupId'] == groupId);
        removedCount = removedCount - compPercentList.length;
        
        await prefs.setString('comp_percent_list', jsonEncode(compPercentList));
        print('🗑️ GroupInvites: Removed $removedCount compatibility cache entries for group $groupId due to new member');
        
        // ✅ Also clear any group-specific analysis cache that might exist
        final keys = prefs.getKeys();
        for (String key in keys) {
          if (key.startsWith('analysis_') && key.contains('group_$groupId')) {
            await prefs.remove(key);
            print('🗑️ GroupInvites: Cleared analysis cache: $key');
          }
        }
      }
    } catch (e) {
      print('❌ GroupInvites: Error invalidating compatibility cache: $e');
    }
  }
  
  @override
  void initState() {
    super.initState();
    fetchGroupData();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[100],
      appBar: AppBar(
        title: Text(
          'Group Invites',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        elevation: 0,
        backgroundColor: Colors.white,
      ),
      body: isLoading
          ? _buildLoadingShimmer()
          : groupDataList.isEmpty
          ? _buildEmptyState()
          : _buildGroupList(),
    );
  }

  Widget _buildLoadingShimmer() {
    return ListView.builder(
      padding: EdgeInsets.all(16),
      itemCount: 5,
      itemBuilder: (context, index) => Shimmer.fromColors(
        baseColor: Colors.grey[300]!,
        highlightColor: Colors.grey[100]!,
        child: Container(
          margin: EdgeInsets.only(bottom: 8),
          height: 80,
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(12),
          ),
        ),
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.group_outlined, size: 80, color: Colors.grey[400]),
          SizedBox(height: 16),
          Text(
            'No Group Invites',
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: Colors.grey[600],
            ),
          ),
          SizedBox(height: 8),
          Text(
            'You\'ll see your group invitations here',
            style: TextStyle(color: Colors.grey[500]),
          ),
        ],
      ),
    );
  }

  Widget _buildGroupList() {
    return RefreshIndicator(
      onRefresh: fetchGroupData,
      child: ListView.builder(
        padding: EdgeInsets.all(16),
        itemCount: groupDataList.length,
        itemBuilder: (context, index) {
          final group = groupDataList[index];
          final groupName = group['group_name'] is String
              ? group['group_name'] as String
              : 'Unknown Group';
          final description = group['group_preferences'] is Map
              ? (group['group_preferences']['title'] as String? ?? 'No description')
              : 'No description';

          return Card(
            elevation: 2,
            margin: EdgeInsets.only(bottom: 8),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
            child: ListTile(
              contentPadding: EdgeInsets.all(16),
              leading: CircleAvatar(
                backgroundColor: Colors.blue[100],
                child: Text(
                  groupName.isNotEmpty ? groupName[0].toUpperCase() : 'G',
                  style: TextStyle(
                    color: Colors.blue[800],
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              title: Text(
                groupName,
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
              subtitle: Text(
                description,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              trailing: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextButton(
                    onPressed: () async {
                      await _acceptInvite(group['group_id'].toString());
                    },
                    child: Text(
                      "Accept",
                      style: TextStyle(color: Colors.green),
                    ),
                  ),
                  // IconButton(
                  //   icon: Icon(Icons.cancel_outlined, color: Colors.red),
                  //   onPressed: () {
                  //     // Add decline invite logic here if needed
                  //   },
                  // ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}