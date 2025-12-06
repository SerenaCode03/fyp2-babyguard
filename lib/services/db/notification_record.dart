// services/db/notification_record.dart
class NotificationRecord {
  final int? id;
  final int userId;
  final DateTime timestamp;
  final String category; // e.g. 'pose', 'cry', 'expression', 'system'
  final String title;

  NotificationRecord({
    this.id,
    required this.userId,
    required this.timestamp,
    required this.category,
    required this.title,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'userId': userId,
      'timestamp': timestamp.toIso8601String(),
      'category': category,
      'title': title,
    };
  }

  factory NotificationRecord.fromMap(Map<String, dynamic> map) {
    return NotificationRecord(
      id: map['id'] as int?,
      userId: map['userId'] as int,
      timestamp: DateTime.parse(map['timestamp'] as String),
      category: map['category'] as String,
      title: map['title'] as String,
    );
  }
}
