// services/db/notification_dao.dart
import '../database_helper.dart';
import 'notification_record.dart';

class NotificationDao {
  final _dbHelper = DatabaseHelper.instance;

  Future<List<NotificationRecord>> getNotificationsForUser(int userId) async {
    final db = await _dbHelper.database;
    final rows = await db.query(
      'notifications',
      where: 'userId = ?',
      whereArgs: [userId],
      orderBy: 'timestamp DESC',
    );
    return rows.map((m) => NotificationRecord.fromMap(m)).toList();
  }

  Future<int> insert(NotificationRecord record) async {
    final db = await _dbHelper.database;
    return db.insert('notifications', record.toMap());
  }

  Future<int> clearForUser(int userId) async {
    final db = await _dbHelper.database;
    return db.delete(
      'notifications',
      where: 'userId = ?',
      whereArgs: [userId],
    );
  }
}
