class SessionManager {
  static int? currentUserId;
  static String? currentUserEmail;
  static String? currentUsername;

  static bool get isLoggedIn => currentUserId != null;

  static void login(int id, String email, String username) {
    currentUserId = id;
    currentUserEmail = email;
    currentUsername = username;
  }

  static void logout() {
    currentUserId = null;
    currentUserEmail = null;
    currentUsername = null;
  }
}