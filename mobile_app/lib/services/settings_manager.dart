import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

class SettingsManager extends ChangeNotifier {
  static final SettingsManager _instance = SettingsManager._internal();
  factory SettingsManager() => _instance;
  SettingsManager._internal();

  ThemeMode _themeMode = ThemeMode.system;
  String _language = 'hi'; // Default Hindi / English support
  bool _isAppLockEnabled = true;
  String _upiId = 'kushbinary@okaxis';
  String _businessName = 'MyLibbook';

  ThemeMode get themeMode => _themeMode;
  String get language => _language;
  bool get isHindi => _language == 'hi';
  bool get isAppLockEnabled => _isAppLockEnabled;
  String get upiId => _upiId;
  String get businessName => _businessName;

  Future<void> init() async {
    final prefs = await SharedPreferences.getInstance();
    
    // Theme
    final savedTheme = prefs.getString('app_theme_mode') ?? 'system';
    if (savedTheme == 'light') {
      _themeMode = ThemeMode.light;
    } else if (savedTheme == 'dark') {
      _themeMode = ThemeMode.dark;
    } else {
      _themeMode = ThemeMode.system;
    }

    // Language
    _language = prefs.getString('app_language') ?? 'hi';

    // App Lock
    _isAppLockEnabled = prefs.getBool('app_lock_4digit_enabled') ?? true;

    // UPI & Business Name
    _upiId = prefs.getString('library_custom_upi_id') ?? 'kushbinary@okaxis';
    _businessName = prefs.getString('library_custom_business_name') ?? 'MyLibbook';

    notifyListeners();
  }

  Future<void> setThemeMode(ThemeMode mode) async {
    _themeMode = mode;
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    String val = 'system';
    if (mode == ThemeMode.light) val = 'light';
    if (mode == ThemeMode.dark) val = 'dark';
    await prefs.setString('app_theme_mode', val);
  }

  Future<void> setLanguage(String lang) async {
    _language = lang;
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('app_language', lang);
  }

  Future<void> setAppLockEnabled(bool enabled) async {
    _isAppLockEnabled = enabled;
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('app_lock_4digit_enabled', enabled);
  }

  Future<void> updateUpiSettings(String newUpi, String newName) async {
    _upiId = newUpi;
    _businessName = newName;
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('library_custom_upi_id', newUpi);
    await prefs.setString('library_custom_business_name', newName);
  }

  Future<String?> getUserPin(String user) async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString('library_user_4digit_pin_$user');
  }

  Future<void> setUserPin(String user, String pin) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('library_user_4digit_pin_$user', pin);
  }
}
