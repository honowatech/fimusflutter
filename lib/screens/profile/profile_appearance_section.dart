import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:monitrack/l10n/app_localizations.dart';
import '../../providers/theme_provider.dart';
import 'profile_preference_block.dart';

/// Bloc « Couleur du thème » : palette de couleurs de marque.
class ProfileBrandColorBlock extends StatelessWidget {
  const ProfileBrandColorBlock({super.key});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;

    return Padding(
      padding: kProfileBlockPadding,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          ProfilePreferenceBlockHeader(
            icon: Icons.color_lens,
            label: l10n.themeColor,
          ),
          const SizedBox(height: 8),
          Consumer<ThemeProvider>(
            builder: (context, themeProvider, child) {
              final colors = [
                Colors.deepOrange,
                Colors.blue,
                Colors.green,
                Colors.purple,
                Colors.red,
                Colors.teal,
                Colors.indigo,
                Colors.pink,
              ];
              return Wrap(
                spacing: 8.0,
                runSpacing: 8.0,
                children: colors.map((c) {
                  final isSelected =
                      themeProvider.primaryColor.toARGB32() == c.toARGB32();
                  return GestureDetector(
                    onTap: () => themeProvider.setPrimaryColor(c),
                    child: CircleAvatar(
                      backgroundColor: c,
                      radius: 18,
                      child: isSelected
                          ? const Icon(
                              Icons.check,
                              color: Colors.white,
                              size: 20,
                            )
                          : null,
                    ),
                  );
                }).toList(),
              );
            },
          ),
        ],
      ),
    );
  }
}
