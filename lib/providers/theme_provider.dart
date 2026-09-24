import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Préférences d'apparence : couleur de marque et mode d'affichage.
///
/// Les deux réglages sont persistés dans SharedPreferences et rechargés au
/// démarrage. Le mode d'affichage vaut [ThemeMode.system] par défaut :
/// l'application suit alors le réglage clair/sombre de l'appareil.
class ThemeProvider with ChangeNotifier {
  static const String _colorKey = 'theme_color';
  static const String _modeKey = 'theme_mode';

  Color _primaryColor = const Color(0xFF07929C); // Default to #07929C
  ThemeMode _themeMode = ThemeMode.system;

  Color get primaryColor => _primaryColor;

  /// Mode d'affichage choisi (système / clair / sombre).
  ThemeMode get themeMode => _themeMode;

  ThemeProvider() {
    _loadPreferences();
  }

  Future<void> _loadPreferences() async {
    final prefs = await SharedPreferences.getInstance();
    var changed = false;

    final int? colorValue = prefs.getInt(_colorKey);
    if (colorValue != null) {
      _primaryColor = Color(colorValue);
      changed = true;
    }

    final String? modeName = prefs.getString(_modeKey);
    final ThemeMode? storedMode = _decodeMode(modeName);
    if (storedMode != null && storedMode != _themeMode) {
      _themeMode = storedMode;
      changed = true;
    }

    if (changed) notifyListeners();
  }

  Future<void> setPrimaryColor(Color color) async {
    _primaryColor = color;
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_colorKey, color.toARGB32());
  }

  /// Change le mode d'affichage et le persiste.
  Future<void> setThemeMode(ThemeMode mode) async {
    if (mode == _themeMode) return;
    _themeMode = mode;
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_modeKey, mode.name);
  }

  /// Lit un mode stocké ; tolère une valeur absente ou corrompue.
  static ThemeMode? _decodeMode(String? name) {
    if (name == null) return null;
    for (final mode in ThemeMode.values) {
      if (mode.name == name) return mode;
    }
    return null;
  }
}
