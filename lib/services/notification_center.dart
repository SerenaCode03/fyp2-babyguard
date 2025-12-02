// services/notification_center.dart
import 'package:flutter/foundation.dart';
import 'package:fyp2_babyguard/components/notification_card.dart';

class NotificationCenter {
  NotificationCenter._();
  static final NotificationCenter instance = NotificationCenter._();

  // Latest first
  final ValueNotifier<List<NotificationItem>> _items =
      ValueNotifier<List<NotificationItem>>([]);

  ValueListenable<List<NotificationItem>> get items => _items;

  void add(NotificationItem item) {
    final list = List<NotificationItem>.from(_items.value);
    list.insert(0, item); // newest on top
    _items.value = list;
  }

  void clear() {
    _items.value = [];
  }
}
