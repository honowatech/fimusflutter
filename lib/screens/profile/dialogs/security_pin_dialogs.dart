import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:monitrack/l10n/app_localizations.dart';
import '../../../providers/security_provider.dart';

/// Indicateur de progression affiché à la place du libellé d'un bouton
/// pendant le traitement (le hachage PBKDF2 du code PIN prend quelques
/// centaines de millisecondes : le bouton reste neutralisé jusqu'au retour).
const Widget _buttonSpinner = SizedBox(
  height: 18,
  width: 18,
  child: CircularProgressIndicator(strokeWidth: 2),
);

/// Activation du verrou applicatif : saisie et confirmation d'un nouveau PIN.
void showSetPinDialog(BuildContext context) {
  final l10n = AppLocalizations.of(context)!;
  final securityProvider = Provider.of<SecurityProvider>(
    context,
    listen: false,
  );
  final pinController = TextEditingController();
  final confirmController = TextEditingController();
  final formKey = GlobalKey<FormState>();

  showDialog(
    context: context,
    builder: (ctx) {
      bool isLoading = false;
      return StatefulBuilder(
        builder: (ctx, setModalState) => AlertDialog(
          title: Text(l10n.enableLock),
          content: Form(
            key: formKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(l10n.enableLockDesc),
                const SizedBox(height: 16),
                TextFormField(
                  controller: pinController,
                  obscureText: true,
                  keyboardType: TextInputType.number,
                  maxLength: 4,
                  decoration: InputDecoration(
                    labelText: l10n.newPinCode,
                    prefixIcon: const Icon(Icons.lock_outline),
                  ),
                  validator: (val) {
                    if (val == null ||
                        val.length != 4 ||
                        int.tryParse(val) == null) {
                      return l10n.enter4Digits;
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 8),
                TextFormField(
                  controller: confirmController,
                  obscureText: true,
                  keyboardType: TextInputType.number,
                  maxLength: 4,
                  decoration: InputDecoration(
                    labelText: l10n.confirmPinCode,
                    prefixIcon: const Icon(Icons.lock_outline),
                  ),
                  validator: (val) {
                    if (val != pinController.text) {
                      return l10n.pinCodesDoNotMatch;
                    }
                    return null;
                  },
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: isLoading ? null : () => Navigator.pop(ctx),
              child: Text(l10n.cancel),
            ),
            TextButton(
              onPressed: isLoading
                  ? null
                  : () async {
                      if (formKey.currentState!.validate()) {
                        setModalState(() => isLoading = true);
                        await securityProvider.enableAppLock(
                          pinController.text,
                        );
                        if (ctx.mounted) Navigator.pop(ctx);
                        if (context.mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text(l10n.pinLockActivated),
                            ),
                          );
                        }
                      }
                    },
              child: isLoading ? _buttonSpinner : Text(l10n.activate),
            ),
          ],
        ),
      );
    },
  );
}

/// Désactivation du verrou applicatif : vérification du PIN courant.
void showDisablePinDialog(BuildContext context) {
  final l10n = AppLocalizations.of(context)!;
  final securityProvider = Provider.of<SecurityProvider>(
    context,
    listen: false,
  );
  final pinController = TextEditingController();
  final formKey = GlobalKey<FormState>();

  showDialog(
    context: context,
    builder: (ctx) {
      bool isLoading = false;
      return StatefulBuilder(
        builder: (ctx, setModalState) => AlertDialog(
          title: Text(l10n.disableLock),
          content: Form(
            key: formKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(l10n.disableLockDesc),
                const SizedBox(height: 16),
                TextFormField(
                  controller: pinController,
                  obscureText: true,
                  keyboardType: TextInputType.number,
                  maxLength: 4,
                  decoration: InputDecoration(
                    labelText: l10n.currentPinCode,
                    prefixIcon: const Icon(Icons.lock_outline),
                  ),
                  validator: (val) {
                    if (val == null || val.isEmpty) {
                      return l10n.pinRequired;
                    }
                    return null;
                  },
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: isLoading ? null : () => Navigator.pop(ctx),
              child: Text(l10n.cancel),
            ),
            TextButton(
              onPressed: isLoading
                  ? null
                  : () async {
                      if (formKey.currentState!.validate()) {
                        setModalState(() => isLoading = true);
                        final success = await securityProvider.disableAppLock(
                          pinController.text,
                        );
                        if (success) {
                          if (ctx.mounted) Navigator.pop(ctx);
                          if (context.mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(content: Text(l10n.pinLockDisabled)),
                            );
                          }
                        } else {
                          if (ctx.mounted) {
                            setModalState(() => isLoading = false);
                            ScaffoldMessenger.of(ctx).showSnackBar(
                              SnackBar(
                                content: Text(l10n.incorrectPinCode),
                                backgroundColor: Colors.red,
                              ),
                            );
                          }
                        }
                      }
                    },
              child: isLoading
                  ? _buttonSpinner
                  : Text(
                      l10n.disable,
                      style: const TextStyle(color: Colors.red),
                    ),
            ),
          ],
        ),
      );
    },
  );
}

/// Changement du code PIN : vérification de l'ancien puis enregistrement
/// du nouveau.
void showChangePinDialog(BuildContext context) {
  final l10n = AppLocalizations.of(context)!;
  final securityProvider = Provider.of<SecurityProvider>(
    context,
    listen: false,
  );
  final oldPinController = TextEditingController();
  final newPinController = TextEditingController();
  final confirmController = TextEditingController();
  final formKey = GlobalKey<FormState>();

  showDialog(
    context: context,
    builder: (ctx) {
      bool isLoading = false;
      return StatefulBuilder(
        builder: (ctx, setModalState) => AlertDialog(
          title: Text(l10n.changePinCode),
          content: Form(
            key: formKey,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextFormField(
                    controller: oldPinController,
                    obscureText: true,
                    keyboardType: TextInputType.number,
                    maxLength: 4,
                    decoration: InputDecoration(
                      labelText: l10n.currentPinCode,
                      prefixIcon: const Icon(Icons.lock_outline),
                    ),
                    validator: (val) {
                      if (val == null || val.length != 4) {
                        return l10n.enter4Digits;
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 8),
                  TextFormField(
                    controller: newPinController,
                    obscureText: true,
                    keyboardType: TextInputType.number,
                    maxLength: 4,
                    decoration: InputDecoration(
                      labelText: l10n.newPinCode,
                      prefixIcon: const Icon(Icons.lock_outline),
                    ),
                    validator: (val) {
                      if (val == null ||
                          val.length != 4 ||
                          int.tryParse(val) == null) {
                        return l10n.enter4Digits;
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 8),
                  TextFormField(
                    controller: confirmController,
                    obscureText: true,
                    keyboardType: TextInputType.number,
                    maxLength: 4,
                    decoration: InputDecoration(
                      labelText: l10n.confirmPinCode,
                      prefixIcon: const Icon(Icons.lock_outline),
                    ),
                    validator: (val) {
                      if (val != newPinController.text) {
                        return l10n.pinCodesDoNotMatch;
                      }
                      return null;
                    },
                  ),
                ],
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: isLoading ? null : () => Navigator.pop(ctx),
              child: Text(l10n.cancel),
            ),
            TextButton(
              onPressed: isLoading
                  ? null
                  : () async {
                      if (formKey.currentState!.validate()) {
                        setModalState(() => isLoading = true);
                        final success = await securityProvider.changePin(
                          oldPinController.text,
                          newPinController.text,
                        );
                        if (success) {
                          if (ctx.mounted) Navigator.pop(ctx);
                          if (context.mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text(l10n.pinCodeChangedSuccess),
                              ),
                            );
                          }
                        } else {
                          if (ctx.mounted) {
                            setModalState(() => isLoading = false);
                            ScaffoldMessenger.of(ctx).showSnackBar(
                              SnackBar(
                                content: Text(l10n.incorrectCurrentPinCode),
                                backgroundColor: Colors.red,
                              ),
                            );
                          }
                        }
                      }
                    },
              child: isLoading ? _buttonSpinner : Text(l10n.modify),
            ),
          ],
        ),
      );
    },
  );
}
