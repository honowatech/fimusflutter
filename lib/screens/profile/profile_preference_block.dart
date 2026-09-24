import 'package:flutter/material.dart';

/// Padding commun à tous les blocs de la carte « Préférences ».
const EdgeInsets kProfileBlockPadding = EdgeInsets.symmetric(
  horizontal: 16,
  vertical: 8,
);

/// En-tête (icône grise + titre) d'un bloc de la carte « Préférences ».
/// Repris à l'identique des quatre blocs d'origine (langue, pays, devise,
/// couleur du thème).
class ProfilePreferenceBlockHeader extends StatelessWidget {
  const ProfilePreferenceBlockHeader({
    super.key,
    required this.icon,
    required this.label,
  });

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(
          icon,
          size: 20,
          color: Colors.grey,
        ),
        const SizedBox(width: 8),
        Text(
          label,
          style: const TextStyle(
            fontWeight: FontWeight.bold,
            fontSize: 16,
          ),
        ),
      ],
    );
  }
}
