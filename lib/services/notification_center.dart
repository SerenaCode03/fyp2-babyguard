// services/notification_center.dart
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:fyp2_babyguard/components/notification_card.dart';
import 'package:fyp2_babyguard/utilities/color.dart';

import 'db/notification_dao.dart';
import 'db/notification_record.dart';
import '../services/database_helper.dart';

class NotificationCenter {
  NotificationCenter._();
  static final NotificationCenter instance = NotificationCenter._();
  final ValueNotifier<List<NotificationItem>> _items =
      ValueNotifier<List<NotificationItem>>([]);
  ValueListenable<List<NotificationItem>> get items => _items;

  final NotificationDao _dao = NotificationDao();

  // In-memory only (old API)
  void add(NotificationItem item) {
    final list = List<NotificationItem>.from(_items.value);
    list.insert(0, item); // newest on top
    _items.value = list;
  }

  void clear() {
    _items.value = [];
  }

  // DB-backed helpers
  /// Call this after login / when you know the current userId.
   Future<void> loadForUser(int userId) async {
    final db = await DatabaseHelper.instance.database;

    final rows = await db.query(
      'notifications',
      where: 'userId = ?',
      whereArgs: [userId],
      orderBy: 'timestamp DESC',
    );

    final List<NotificationItem> list = rows.map((row) {
      final category = row['category'] as String;
      final visuals = _visualsForCategory(category);

      return NotificationItem(
        kind: visuals.kind,
        title: row['title'] as String,
        time: DateTime.parse(row['timestamp'] as String),
        icon: visuals.icon,
        tint: visuals.tint,
      );
    }).toList();

    _items.value = list;
  }

  /// Add a notification and persist it to SQLite.
  /// `category` could be: 'pose', 'cry', 'expression', 'system', etc.
  Future<void> addAndPersist({
    required int userId,
    required String category,
    required String title,
    DateTime? timestamp,
    VoidCallback? onTap,
  }) async {
    final ts = timestamp ?? DateTime.now();

    final record = NotificationRecord(
      userId: userId,
      timestamp: ts,
      category: category,
      title: title,
    );

    await _dao.insert(record);

    final item = _fromRecord(record, onTap: onTap);
    final list = List<NotificationItem>.from(_items.value);
    list.insert(0, item);
    _items.value = list;
  }

  /// Clear this user's notifications from DB + UI.
  Future<void> clearForUser(int userId) async {
    await _dao.clearForUser(userId);
    _items.value = [];
  }

  // Mapping DB <-> UI model
  NotificationItem _fromRecord(
    NotificationRecord r, {
    VoidCallback? onTap,
  }) {
    final visuals = _visualsForCategory(r.category);

    return NotificationItem(
      kind: visuals.kind,
      title: r.title,
      time: r.timestamp,
      icon: visuals.icon,
      tint: visuals.tint,
      onTap: onTap,
    );
  }

  /// Small helper struct for visual mapping.
  ({NoticeKind kind, IconData icon, Color tint}) _visualsForCategory(
    String category,
  ) {
    // unified alert tint (soft yellow)
    const alertTint = Color(0xFFF0AD00);   // choose any light yellow you like
    const systemTint = Color(0xFF2ECC71);  // keep green for notices

    switch (category) {
      case 'cry':
        return (
          kind: NoticeKind.alert,
          icon: Icons.volume_up_rounded,
          tint: alertTint,
        );

      case 'pose':
        return (
          kind: NoticeKind.alert,
          icon: Icons.bed_rounded,
          tint: alertTint,
        );

      case 'expression':
        return (
          kind: NoticeKind.alert,
          icon: Icons.sentiment_dissatisfied_rounded,
          tint: alertTint,
        );

      case 'system':
        return (
          kind: NoticeKind.notice,
          icon: Icons.check_circle_rounded,
          tint: systemTint,
        );

      default:
        return (
          kind: NoticeKind.notice,
          icon: Icons.notifications_none_rounded,
          tint: systemTint,
        );
    }
  }
}
