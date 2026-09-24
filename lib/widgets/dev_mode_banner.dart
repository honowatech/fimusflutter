import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/app_config_provider.dart';
import '../utils/app_theme.dart';

class DevModeBanner extends StatelessWidget {
  const DevModeBanner({super.key});

  @override
  Widget build(BuildContext context) {
    return Consumer<AppConfigProvider>(
      builder: (context, appConfig, child) {
        if (!appConfig.isDevMode) {
          return const SizedBox.shrink();
        }

        // Bandeau d'alerte volontairement très visible : teinte ambre fixe en
        // clair, légèrement assombrie en sombre pour ne pas éblouir, avec un
        // contenu toujours blanc (contraste > 7:1 dans les deux cas).
        final scheme = Theme.of(context).colorScheme;
        final bannerBackground = scheme.tone(
          light: const Color(0xFFFF6F00), // Colors.amber.shade900 historique
          dark: const Color(0xFF8A3D00),
        );

        return Container(
          width: double.infinity,
          color: bannerBackground,
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(
                Icons.bug_report_rounded,
                color: Colors.white,
                size: 16,
              ),
              const SizedBox(width: 6),
              Flexible(
                child: Text(
                  'MODE DEV : ${appConfig.activeBaseUrl} (${appConfig.activeDatabaseName})',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 0.3,
                  ),
                  overflow: TextOverflow.ellipsis,
                  maxLines: 1,
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}
