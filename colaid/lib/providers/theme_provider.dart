// lib/providers/theme_provider.dart
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../services/user_service.dart';
import '../services/bluetooth_service.dart';

class ThemeProvider extends ChangeNotifier {
  static const _prefIsDark = 'isDark';
  static const _prefCvdType = 'cvdType';
  static const _prefAudio = 'audioAlerts';
  static const _prefFontSize = 'fontSize';
  static const _prefContrast = 'contrastMode';

  ThemeMode _themeMode = ThemeMode.light;
  CvdType _cvdType = CvdType.none;
  bool _audioAlerts = false;
  String _fontSize = 'Medium';
  String _contrastMode = 'Normal Contrast';

  ThemeProvider() {
    _loadFromPrefs();
  }

  // Helper to get key based on current user
  String _key(String base) {
    final email = UserService().userEmail;
    return email != null ? '${base}_$email' : base;
  }

  ThemeMode get themeMode => _themeMode;
  bool get isDark => _themeMode == ThemeMode.dark;
  CvdType get cvdType => _cvdType;
  bool get audioAlerts => _audioAlerts;
  String get fontSize => _fontSize;
  String get contrastMode => _contrastMode;

  Future<void> _loadFromPrefs() async {
    final prefs = await SharedPreferences.getInstance();

    // Use user-specific keys
    final isDarkPref = prefs.getBool(_key(_prefIsDark)) ?? false;
    _themeMode = isDarkPref ? ThemeMode.dark : ThemeMode.light;

    final cvdIndex = prefs.getInt(_key(_prefCvdType)) ?? 0;
    if (cvdIndex >= 0 && cvdIndex < CvdType.values.length) {
      _cvdType = CvdType.values[cvdIndex];
    } else {
      _cvdType = CvdType.none;
    }

    _audioAlerts = prefs.getBool(_key(_prefAudio)) ?? false;
    _fontSize = prefs.getString(_key(_prefFontSize)) ?? 'Medium';
    _contrastMode = prefs.getString(_key(_prefContrast)) ?? 'Normal Contrast';

    notifyListeners();
  }

  // Public method to reload prefs (e.g. after login/logout)
  Future<void> refresh() async {
    await _loadFromPrefs();
  }

  Future<void> _saveToPrefs() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_key(_prefIsDark), isDark);
    await prefs.setInt(_key(_prefCvdType), _cvdType.index);
    await prefs.setBool(_key(_prefAudio), _audioAlerts);
    await prefs.setString(_key(_prefFontSize), _fontSize);
    await prefs.setString(_key(_prefContrast), _contrastMode);
  }

  void setDarkMode(bool value) {
    _themeMode = value ? ThemeMode.dark : ThemeMode.light;
    _saveToPrefs();
    UserService().addNotification(
      "Theme changed to ${value ? 'Dark' : 'Light'} Mode",
      countsForBadge: false,
    );
    notifyListeners();
  }

  void setCvdType(CvdType type) {
    _cvdType = type;
    _saveToPrefs();
    notifyListeners();
    // Sync with Eyewear
    ColaidBluetoothService().sendCVDProfile(type.name);
  }

  void setAudioAlerts(bool value) {
    _audioAlerts = value;
    _saveToPrefs();
    notifyListeners();
    // Sync with Eyewear
    ColaidBluetoothService().sendAudioState(value);
  }

  void setFontSize(String value) {
    _fontSize = value;
    _saveToPrefs();
    notifyListeners();
  }

  void setContrastMode(String value) {
    _contrastMode = value;
    _saveToPrefs();
    notifyListeners();
  }

  void resetToDefaults() {
    _themeMode = ThemeMode.light;
    _cvdType = CvdType.none;
    _audioAlerts = false;
    _fontSize = 'Medium';
    _contrastMode = 'Normal Contrast';
    _saveToPrefs();
    notifyListeners();
  }

  /// Returns color correction matrix for ColorFiltered widgets.
  /// Uses the same Daltonization algorithm as Live Video for consistency.
  List<double> get currentCvdFilter {
    // Identity matrix (4x5 color matrix format)
    // [ R',  G',  B',  A', offset ]
    const identity = [
      // R    G    B    A   offset
      1.0, 0.0, 0.0, 0.0, 0.0, // Red channel
      0.0, 1.0, 0.0, 0.0, 0.0, // Green channel
      0.0, 0.0, 1.0, 0.0, 0.0, // Blue channel
      0.0, 0.0, 0.0, 1.0, 0.0, // Alpha channel
    ];

    // Correction matrices (from daltonize.py algorithm)
    // These are ADDED to identity matrix
    const protCorrection = [
      // R       G       B      A   offset
      0.0, 0.0, 0.0, 0.0, 0.0, // Red
      0.303, -0.303, 0.0, 0.0, 0.0, // Green
      0.433, -0.433, 0.0, 0.0, 0.0, // Blue
      0.0, 0.0, 0.0, 0.0, 0.0, // Alpha
    ];

    const deutCorrection = [
      // R       G       B      A   offset
      -0.7, 0.7, 0.0, 0.0, 0.0, // Red
      0.0, 0.0, 0.0, 0.0, 0.0, // Green
      -0.49, 0.49, 0.0, 0.0, 0.0, // Blue
      0.0, 0.0, 0.0, 0.0, 0.0, // Alpha
    ];

    const tritCorrection = [
      // R       G       B      A   offset
      0.0, -0.332, 0.332, 0.0, 0.0, // Red
      0.0, -0.475, 0.475, 0.0, 0.0, // Green
      0.0, 0.0, 0.0, 0.0, 0.0, // Blue
      0.0, 0.0, 0.0, 0.0, 0.0, // Alpha
    ];

    List<double> correction;
    switch (_cvdType) {
      case CvdType.protanopia:
        correction = protCorrection;
        break;
      case CvdType.deuteranopia:
        correction = deutCorrection;
        break;
      case CvdType.tritanopia:
        correction = tritCorrection;
        break;
      default:
        return identity;
    }

    // Apply correction: Final = Identity + (Correction * 2.0)
    // 2.0 multiplier matches backend intensity level
    return List.generate(20, (i) => identity[i] + correction[i] * 2.0);
  }
}

enum CvdType { none, protanopia, deuteranopia, tritanopia }
