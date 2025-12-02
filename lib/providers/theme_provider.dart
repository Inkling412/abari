import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

class ThemeProvider extends ChangeNotifier {
  bool _isDarkMode;
  static const String _themeKey = 'isDarkMode';

  // Constructor que recibe el valor inicial (cargado antes de iniciar la app)
  ThemeProvider({bool isDarkMode = false}) : _isDarkMode = isDarkMode;

  bool get isDarkMode => _isDarkMode;

  ThemeMode get themeMode => _isDarkMode ? ThemeMode.dark : ThemeMode.light;

  // Método estático para cargar preferencias antes de crear el provider
  static Future<bool> loadSavedTheme() async {
    final prefs = await SharedPreferences.getInstance();
    final value = prefs.getBool(_themeKey) ?? false;
    debugPrint('🎨 ThemeProvider.loadSavedTheme: $value');
    return value;
  }

  // Guardar preferencia
  Future<void> _saveThemePreference(bool value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_themeKey, value);
    debugPrint('🎨 ThemeProvider._saveThemePreference: $value guardado');
  }

  void toggleTheme() {
    _isDarkMode = !_isDarkMode;
    _saveThemePreference(_isDarkMode);
    notifyListeners();
  }

  void setTheme(bool isDark) {
    _isDarkMode = isDark;
    _saveThemePreference(isDark);
    notifyListeners();
  }
}
