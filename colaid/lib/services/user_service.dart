// lib/services/user_service.dart
import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:intl/intl.dart';

class NotificationItem {
  final String message;
  final DateTime timestamp;
  final bool countsForBadge;

  NotificationItem({
    required this.message,
    required this.timestamp,
    required this.countsForBadge,
  });
}

class UserService {
  static final UserService _instance = UserService._internal();
  factory UserService() => _instance;
  UserService._internal();

  String? _userEmail;
  String? _userName;
  List<Map<String, dynamic>> _testResults = [];

  // Notifications List
  final List<NotificationItem> _notifications = [];

  // Profile Picture
  String? _profilePicPath;

  static const _emailKey = 'user_email';
  static const _nameKey = 'user_name';
  static const _resultsKey = 'test_results';
  static const _profilePicKey = 'profile_pic_path';
  static const _cookieKey = 'auth_cookie'; // New key

  String? _authCookie; // Store the session cookie

  /// Call this once at app startup (before runApp)
  Future<void> init() async {
    final prefs = await SharedPreferences.getInstance();
    _userEmail = prefs.getString(_emailKey);
    _userName = prefs.getString(_nameKey);
    _profilePicPath = prefs.getString(_profilePicKey);
    _authCookie = prefs.getString(_cookieKey); // Load cookie

    final resultsString = prefs.getString(_resultsKey);
    if (resultsString != null) {
      try {
        final List<dynamic> decoded = jsonDecode(resultsString);
        _testResults = decoded.cast<Map<String, dynamic>>();
      } catch (e) {
        _testResults = [];
      }
    }

    if (_userEmail != null) {
      addNotification("Welcome back! Session restored.", countsForBadge: true);
    }
  }

  /// Save user info in memory AND persist it
  Future<void> setUserData({required String email, String? name}) async {
    _userEmail = email;
    _userName = name ?? _extractNameFromEmail(email);

    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_emailKey, _userEmail!);
    await prefs.setString(_nameKey, _userName!);

    // Clear old "Logged in" notifications to keep badge at 1 max for login events
    _notifications.removeWhere((n) => n.message.startsWith("Logged in"));

    addNotification(
      "Logged in at ${DateFormat('yyyy-MM-dd HH:mm').format(DateTime.now())}",
      countsForBadge: true,
    );
  }

  Future<void> setProfilePic(String path) async {
    _profilePicPath = path;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_profilePicKey, path);
    // Notify with BADGE
    addNotification("Profile picture updated", countsForBadge: true);
  }

  Future<void> removeProfilePic() async {
    _profilePicPath = null;
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_profilePicKey);
    // Notify with BADGE
    addNotification("Profile picture removed", countsForBadge: true);
  }

  /// Save a new test result with full details
  Future<void> saveTestResult(
    String type,
    int incorrectCount,
    List<Map<String, dynamic>> plates,
    Map<int, String> userAnswers,
  ) async {
    // Convert Map<int, String> to Map<String, String> for JSON
    final answersStringKey = userAnswers.map(
      (key, value) => MapEntry(key.toString(), value),
    );

    final result = {
      'date': DateTime.now().toIso8601String(),
      'type': type,
      'incorrect': incorrectCount,
      'plates': plates,
      'userAnswers': answersStringKey,
    };

    _testResults.insert(0, result); // Add to top

    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_resultsKey, jsonEncode(_testResults));

    // Trigger notification
    addNotification(
      "Ishihara Test Completed at ${DateFormat('HH:mm').format(DateTime.now())}",
      countsForBadge: false,
    );
  }

  /// Delete specific test results by date
  Future<void> deleteTestResults(Set<String> datesToDelete) async {
    _testResults.removeWhere(
      (result) => datesToDelete.contains(result['date']),
    );

    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_resultsKey, jsonEncode(_testResults));
  }

  List<Map<String, dynamic>> getTestResults() {
    return List.from(_testResults);
  }

  Future<void> setAuthCookie(String? cookie) async {
    _authCookie = cookie;
    final prefs = await SharedPreferences.getInstance();
    if (cookie != null) {
      await prefs.setString(_cookieKey, cookie);
    } else {
      await prefs.remove(_cookieKey);
    }
  }

  String? get userEmail => _userEmail;
  String? get userName => _userName;
  String? get profilePicPath => _profilePicPath;
  String? get authCookie => _authCookie; // Getter for cookie

  bool get isLoggedIn => _userEmail != null;

  /// Convert "john.doe@example.com" → "John Doe"
  String _extractNameFromEmail(String email) {
    final username = email.split('@')[0];
    final parts = username.split(RegExp(r'[._-]'));
    return parts
        .where((p) => p.isNotEmpty)
        .map((p) => p[0].toUpperCase() + p.substring(1))
        .join(' ');
  }

  /// Clear memory + persistent storage
  Future<void> clearUserData() async {
    try {
      await FirebaseAuth.instance.signOut();
    } catch (e) {
      // Ignore errors if firebase isn't initialized or other issues
    }

    _userEmail = null;
    _userName = null;
    _profilePicPath = null;
    _authCookie = null; // Clear cookie from memory
    _testResults = [];
    _notifications.clear();

    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_emailKey);
    await prefs.remove(_nameKey);
    await prefs.remove(_resultsKey);
    await prefs.remove(_profilePicKey);
    await prefs.remove(_cookieKey); // Clear cookie from storage
  }

  // --- Notification Methods ---

  void addNotification(String message, {bool countsForBadge = false}) {
    _notifications.insert(
      0,
      NotificationItem(
        message: message,
        timestamp: DateTime.now(),
        countsForBadge: countsForBadge,
      ),
    );
  }

  void removeNotification(int index) {
    if (index >= 0 && index < _notifications.length) {
      _notifications.removeAt(index);
    }
  }

  int getUnreadBadgeCount() {
    return _notifications.where((n) => n.countsForBadge).length;
  }

  void markNotificationsAsRead() {
    for (int i = 0; i < _notifications.length; i++) {
      if (_notifications[i].countsForBadge) {
        _notifications[i] = NotificationItem(
          message: _notifications[i].message,
          timestamp: _notifications[i].timestamp,
          countsForBadge: false,
        );
      }
    }
  }

  List<NotificationItem> getAllNotifications() {
    return List.from(_notifications);
  }
}
