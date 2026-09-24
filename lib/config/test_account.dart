import 'package:flutter/foundation.dart';

/// Compte de test local (debug / mode dev uniquement).
/// En release le mot de passe est vide : la connexion locale est refusée.
class TestAccount {
  static const email = 'fimustrack@gmail.com';
  static const pseudo = 'fimustrack';

  /// Fourni au lancement (`--dart-define=FIMUS_TEST_PASSWORD=...`, cf.
  /// `.vscode/launch.json`), jamais dans le code source.
  static const _debugPassword = String.fromEnvironment('FIMUS_TEST_PASSWORD');

  static bool get isEnabled => kDebugMode && _debugPassword.isNotEmpty;

  static String get password => isEnabled ? _debugPassword : '';

  static bool matches(String emailInput, String passwordInput) {
    if (!isEnabled) return false;
    return emailInput.trim().toLowerCase() == email &&
        passwordInput == password;
  }

  static bool isUser(Map<String, dynamic> user) {
    final userEmail = user['email']?.toString().trim().toLowerCase();
    return userEmail == email;
  }
}
