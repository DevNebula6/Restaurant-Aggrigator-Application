// models/activity_model.dart

class ActivityItem {
  final String id; // Unique identifier for the activity
  final String title; // Title of the activity
  final String description; // Description of the activity
  final DateTime date; // Date and time of the activity
  final String groupId; // Associated group ID (if applicable)
  final String userId; // Associated user ID (if applicable)
  final bool isCompleted; // Whether the activity is completed

  ActivityItem({
    required this.id,
    required this.title,
    required this.description,
    required this.date,
    required this.groupId,
    required this.userId,
    this.isCompleted = false,
  });

  // Factory method to create an ActivityItem from JSON (e.g., from an API response)
  factory ActivityItem.fromJson(Map<String, dynamic> json) {
    return ActivityItem(
      id: json['id']?.toString() ?? '',
      title: json['title']?.toString() ?? '',
      description: json['description']?.toString() ?? '',
      date: DateTime.tryParse(json['date']?.toString() ?? '') ?? DateTime.now(),
      groupId: json['groupId']?.toString() ?? '',
      userId: json['userId']?.toString() ?? '',
      isCompleted: json['isCompleted'] == true,
    );
  }

  // Method to convert an ActivityItem to JSON (e.g., for sending to an API)
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'title': title,
      'description': description,
      'date': date.toIso8601String(),
      'groupId': groupId,
      'userId': userId,
      'isCompleted': isCompleted,
    };
  }

  // Optional: Override toString for better debugging
  @override
  String toString() {
    return 'ActivityItem(id: $id, title: $title, description: $description, date: $date, groupId: $groupId, userId: $userId, isCompleted: $isCompleted)';
  }
}