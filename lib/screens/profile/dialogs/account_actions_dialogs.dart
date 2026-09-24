import 'package:flutter/material.dart';
import 'package:monitrack/l10n/app_localizations.dart';
import '../../../providers/auth_provider.dart';
import '../../login_screen.dart';

/// Déconnexion : confirmation puis retour à l'écran de connexion.
/// Déplacé tel quel depuis le `onTap` de la carte « Compte ».
Future<void> confirmAndLogout(
  BuildContext context,
  AuthProvider authProvider,
) async {
  final l10n = AppLocalizations.of(context)!;
  final confirm = await showDialog<bool>(
    context: context,
    builder: (_) => AlertDialog(
      title: Text(l10n.logoutTitle),
      content: Text(l10n.logoutConfirmBody),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context, false),
          child: Text(l10n.cancel),
        ),
        TextButton(
          onPressed: () => Navigator.pop(context, true),
          child: Text(
            l10n.logout,
            style: const TextStyle(
              color: Colors.red,
            ),
          ),
        ),
      ],
    ),
  );
  if (confirm == true && context.mounted) {
    await authProvider.logout(context: context);
    if (context.mounted) {
      Navigator.pushAndRemoveUntil(
        context,
        MaterialPageRoute(
          builder: (_) => const LoginScreen(),
        ),
        (route) => false,
      );
    }
  }
}

/// Suppression définitive du compte utilisateur : confirmation, voile de
/// progression bloquant, puis retour à l'écran de connexion.
/// Déplacé tel quel depuis le `onTap` de la carte « Compte ».
Future<void> confirmAndDeleteAccount(
  BuildContext context,
  AuthProvider authProvider,
) async {
  final l10n = AppLocalizations.of(context)!;
  final confirm = await showDialog<bool>(
    context: context,
    builder: (_) => AlertDialog(
      title: Text(l10n.deleteUserAccountConfirm),
      content: Text(l10n.deleteUserAccountWarning),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context, false),
          child: Text(l10n.cancel),
        ),
        TextButton(
          onPressed: () => Navigator.pop(context, true),
          child: Text(
            l10n.delete,
            style: const TextStyle(color: Colors.red),
          ),
        ),
      ],
    ),
  );
  if (confirm == true && context.mounted) {
    try {
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (_) => const Center(
          child: CircularProgressIndicator(),
        ),
      );
      await authProvider.deleteAccount(context: context);
      if (context.mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(l10n.accountDeletedSuccess),
            backgroundColor: Colors.green,
          ),
        );
        Navigator.pushAndRemoveUntil(
          context,
          MaterialPageRoute(
            builder: (_) => const LoginScreen(),
          ),
          (route) => false,
        );
      }
    } catch (e) {
      // Détail technique gardé dans les logs, message générique à l'écran.
      debugPrint('account_actions_dialogs : action de compte échouée : $e');
      if (context.mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(l10n.genericErrorRetry),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }
}
