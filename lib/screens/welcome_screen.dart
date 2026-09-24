import 'package:flutter/material.dart';
import 'package:monitrack/l10n/app_localizations.dart';
import 'onboarding_screen.dart';
import '../utils/app_theme.dart';

class WelcomeScreen extends StatelessWidget {
  const WelcomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final theme = Theme.of(context);

    return Scaffold(
      // Ecran illustre : `logo_splash.png` est une image opaque a fond sombre.
      // On garde le blanc historique en clair (continuite avec le splash natif)
      // et on bascule sur `surface` en sombre, ou un fond blanc jurerait avec
      // le visuel. Le seul texte de l'ecran est le bouton, qui force deja
      // primary/onPrimary ci-dessous.
      backgroundColor: theme.colorScheme.tone(
        light: Colors.white,
        dark: theme.colorScheme.surface,
      ),
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: Center(
                child: Image.asset(
                  'logo_splash.png',
                  fit: BoxFit.contain,
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(24.0),
              child: SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () {
                    Navigator.pushReplacement(
                      context,
                      MaterialPageRoute(builder: (_) => const OnboardingScreen()),
                    );
                  },
                  style: ElevatedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    backgroundColor: theme.colorScheme.primary,
                    foregroundColor: theme.colorScheme.onPrimary,
                  ),
                  child: Text(
                    l10n.startAction,
                    style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, letterSpacing: 1),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
