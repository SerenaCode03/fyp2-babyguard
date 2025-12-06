import 'package:sqflite/sqflite.dart';
import 'database_helper.dart';
import '../utils/hash_util.dart';
import '../services/session_manager.dart';

class AuthService {
  AuthService._();
  static final AuthService instance = AuthService._();

  Future<Database> get _db async => await DatabaseHelper.instance.database;

  /// Sign up a new user.
  /// Returns the new user id, or null if email already exists.
  Future<int?> signUp({
    required String email,
    required String username,
    required String password,
    required String securityQuestion,
    required String securityAnswer,
  }) async {
    final db = await _db;

    // Check existing email
    final existing = await db.query(
      'users',
      where: 'email = ?',
      whereArgs: [email],
    );
    if (existing.isNotEmpty) {
      return null; // email already used
    }

    final passwordHash = hashText(password);
    final answerHash = hashText(securityAnswer);

    final id = await db.insert('users', {
      'email': email.trim(),
      'username': username,
      'passwordHash': passwordHash,
      'securityQuestion': securityQuestion,
      'securityAnswerHash': answerHash,
      'createdAt': DateTime.now().toIso8601String(),
    });

    return id;
  }

  /// Login with email & password.
  /// Returns user id if success, null if fail.
  Future<int?> login({
    required String email,
    required String password,
  }) async {
    final db = await _db;
    final rows = await db.query(
      'users',
      where: 'email = ?',
      whereArgs: [email.trim()],
    );
    if (rows.isEmpty) return null;

    final user = rows.first;
    final storedHash = user['passwordHash'] as String;
    final inputHash = hashText(password);

    if (storedHash == inputHash) {
      final id = user['id'] as int;
      final username = user['username'] as String;

      SessionManager.login(id, email.trim(), username);

      return id;
    }
    return null;
  }

  /// Get security question for an email (for forgot password flow).
  Future<String?> getSecurityQuestion(String email) async {
    final db = await _db;
    final rows = await db.query(
      'users',
      columns: ['securityQuestion'],
      where: 'email = ?',
      whereArgs: [email.trim()],
    );
    if (rows.isEmpty) return null;
    return rows.first['securityQuestion'] as String;
  }

  /// Reset password after verifying security answer.
  /// Returns true on success, false on wrong answer or user not found.
  Future<bool> resetPasswordWithSecurityAnswer({
    required String email,
    required String answer,
    required String newPassword,
  }) async {
    final db = await _db;

    final rows = await db.query(
      'users',
      where: 'email = ?',
      whereArgs: [email.trim()],
    );
    if (rows.isEmpty) return false;

    final user = rows.first;
    final storedAnswerHash = user['securityAnswerHash'] as String;
    final inputAnswerHash = hashText(answer);

    if (storedAnswerHash != inputAnswerHash) {
      return false; // wrong security answer
    }

    final newPasswordHash = hashText(newPassword);
    await db.update(
      'users',
      {'passwordHash': newPasswordHash},
      where: 'email = ?',
      whereArgs: [email.trim()],
    );

    return true;
  }
}



