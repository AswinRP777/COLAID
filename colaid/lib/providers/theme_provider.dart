// lib/providers/theme_provider.dart
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../services/user_service.dart';

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

  ThemeMode get themeMode => _themeMode;
  bool get isDark => _themeMode == ThemeMode.dark;
  CvdType get cvdType => _cvdType;
  bool get audioAlerts => _audioAlerts;
  String get fontSize => _fontSize;
  String get contrastMode => _contrastMode;

  Future<void> _loadFromPrefs() async {
    final prefs = await SharedPreferences.getInstance();
    final isDarkPref = prefs.getBool(_prefIsDark) ?? false;
    _themeMode = isDarkPref ? ThemeMode.dark : ThemeMode.light;
    
    final cvdIndex = prefs.getInt(_prefCvdType) ?? 0;
    if (cvdIndex >= 0 && cvdIndex < CvdType.values.length) {
      _cvdType = CvdType.values[cvdIndex];
    }
    
    _audioAlerts = prefs.getBool(_prefAudio) ?? false;
    _fontSize = prefs.getString(_prefFontSize) ?? 'Medium';
    _contrastMode = prefs.getString(_prefContrast) ?? 'Normal Contrast';
    
    notifyListeners();
  }

  Future<void> _saveToPrefs() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_prefIsDark, isDark);
    await prefs.setInt(_prefCvdType, _cvdType.index);
    await prefs.setBool(_prefAudio, _audioAlerts);
    await prefs.setString(_prefFontSize, _fontSize);
    await prefs.setString(_prefContrast, _contrastMode);
  }

  void setDarkMode(bool value) {
    _themeMode = value ? ThemeMode.dark : ThemeMode.light;
    _saveToPrefs();
    UserService().addNotification("Theme changed to ${value ? 'Dark' : 'Light'} Mode", countsForBadge: false);
    notifyListeners();
  }

  void setCvdType(CvdType type) {
    _cvdType = type;
    _saveToPrefs();
    notifyListeners();
  }

  void setAudioAlerts(bool value) {
    _audioAlerts = value;
    _saveToPrefs();
    notifyListeners();
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

  List<double> get currentCvdFilter {
    // Protanopia Correction (Red -> Orange, Green -> Blue-ish)
    // Attempting to shift colors to distinguishable ranges
    const protanParams = [
      1.0, 0.0, 0.0, 0.0, 0.0,  // R -> R
      0.7, 0.0, 0.0, 0.0, 0.0,  // G = 0.7R (Red becomes Orange)
      0.0, 1.0, 1.0, 0.0, 0.0,  // B = G + B (Green becomes Cyan/Blue)
      0.0, 0.0, 0.0, 1.0, 0.0 
    ];
    
    // Deuteranopia Correction (Green -> Blue, Red -> Yellow)
    const deutanParams = [
      1.0, 0.0, 0.0, 0.0, 0.0, 
      0.5, 0.0, 0.0, 0.0, 0.0, // Red -> Orange/Yellow
      0.0, 1.0, 1.0, 0.0, 0.0, // Green -> Blue
      0.0, 0.0, 0.0, 1.0, 0.0
    ];
    
    // Tritanopia Correction (Blue -> Cyan/Green)
    const tritanParams = [
      1.0, 0.0, 0.0, 0.0, 0.0, 
      0.0, 1.0, 0.5, 0.0, 0.0, // Blue contributes to Green
      0.0, 0.0, 0.0, 0.0, 0.0, // Kill Blue channel (simulating lack of S-cone sensitivity/shifting)
      0.0, 0.0, 0.0, 1.0, 0.0
    ];

    switch (_cvdType) {
      case CvdType.protanopia:
        return protanParams;
      case CvdType.deuteranopia:
        return deutanParams;
      case CvdType.tritanopia:
        return tritanParams;
      default:
        return [
            1.0, 0.0, 0.0, 0.0, 0.0,
            0.0, 1.0, 0.0, 0.0, 0.0,
            0.0, 0.0, 1.0, 0.0, 0.0,
            0.0, 0.0, 0.0, 1.0, 0.0,
        ];
    }
  }
}

enum CvdType { none, protanopia, deuteranopia, tritanopia }
