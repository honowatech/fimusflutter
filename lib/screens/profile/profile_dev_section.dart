import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart' show kDebugMode;
import '../../widgets/dev_environment_card.dart';

/// Carte Environnement & Mode Développeur : masquée en release
/// (outil interne de bascule local/production, debug uniquement).
///
/// Le widget se replie sur [SizedBox.shrink] hors debug, ce qui reproduit
/// exactement l'ancien `if (kDebugMode) ...[ SizedBox(16), DevEnvironmentCard ]`.
class ProfileDevEnvironmentSection extends StatelessWidget {
  const ProfileDevEnvironmentSection({super.key});

  @override
  Widget build(BuildContext context) {
    if (!kDebugMode) return const SizedBox.shrink();

    return const Column(
      children: [
        SizedBox(height: 16),
        DevEnvironmentCard(),
      ],
    );
  }
}
