import 'dart:async';

import 'package:flutter/material.dart';
import 'package:monitrack/l10n/app_localizations.dart';

import '../services/app_update_service.dart';

/// Rend l'application inutilisable tant qu'une mise à jour publiée sur le
/// Play Store n'est pas installée — mais seulement quand l'appareil est en
/// ligne : hors connexion, l'utilisateur garde l'accès à ses données (le
/// téléchargement serait de toute façon impossible).
///
/// Vérifie au démarrage, à chaque retour du réseau et à chaque retour au
/// premier plan. Dès qu'une mise à jour est détectée, le flux plein écran de
/// Google Play est lancé ; si l'utilisateur le referme, cet écran bloquant
/// reste affiché par-dessus toute l'application avec un bouton pour relancer.
///
/// Posé dans `MaterialApp.builder`, il couvre aussi les dialogues et feuilles
/// ouverts par le Navigator, qu'il garde montés (aucun état n'est perdu si le
/// réseau disparaît et que l'écran se retire).
class ForceUpdateGate extends StatefulWidget {
  const ForceUpdateGate({
    super.key,
    required this.child,
    this.service = const AppUpdateService(),
  });

  final Widget child;
  final AppUpdateService service;

  @override
  State<ForceUpdateGate> createState() => _ForceUpdateGateState();
}

class _ForceUpdateGateState extends State<ForceUpdateGate>
    with WidgetsBindingObserver {
  StreamSubscription<bool>? _onlineSub;
  bool _online = false;
  AppUpdateStatus _status = AppUpdateStatus.none;
  bool _busy = false;
  bool _failed = false;

  bool get _blocking => _online && _status.updateRequired;

  @override
  void initState() {
    super.initState();
    if (!widget.service.isSupported) return;
    WidgetsBinding.instance.addObserver(this);
    _onlineSub = widget.service.onlineChanges.listen(_onConnectivity);
    widget.service.isOnline().then(_onConnectivity, onError: (_) {});
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _onlineSub?.cancel();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    // Au retour (après avoir refermé Google Play, ou après une longue mise en
    // arrière-plan), on revérifie. Le flux n'est relancé d'office que s'il
    // était en cours : sinon l'écran bloquant suffit, et relancer Google Play
    // à chaque reprise empêcherait même de lire le message.
    if (state == AppLifecycleState.resumed && _online) {
      _check(autoLaunch: false);
    }
  }

  void _onConnectivity(bool online) {
    if (!mounted) return;
    final cameOnline = online && !_online;
    setState(() => _online = online);
    if (cameOnline) _check(autoLaunch: true);
  }

  Future<void> _check({required bool autoLaunch}) async {
    if (_busy) return;
    _setBusy(true);
    try {
      final status = await widget.service.check();
      if (!mounted) return;
      setState(() => _status = status);
      if (status.updateRequired) {
        FocusManager.instance.primaryFocus?.unfocus();
        if (status.immediateAllowed && (autoLaunch || status.inProgress)) {
          await _launch();
        }
      }
    } catch (e) {
      // Play Store injoignable ou indisponible : on garde l'état précédent
      // et on retentera au prochain retour réseau / premier plan.
      debugPrint('ForceUpdateGate: vérification impossible: $e');
    } finally {
      _setBusy(false);
    }
  }

  void _setBusy(bool value) {
    if (mounted) setState(() => _busy = value);
  }

  Future<void> _launch() async {
    var ok = false;
    try {
      if (_status.immediateAllowed) {
        ok = await widget.service.startImmediateUpdate();
      } else {
        await widget.service.openStoreListing(_status.packageName);
        ok = true;
      }
    } catch (e) {
      debugPrint('ForceUpdateGate: lancement impossible: $e');
    }
    if (mounted) setState(() => _failed = !ok);
  }

  Future<void> _onUpdatePressed() async {
    if (_busy) return;
    _setBusy(true);
    try {
      await _launch();
    } finally {
      _setBusy(false);
    }
  }

  @override
  Widget build(BuildContext context) {
    // Structure constante : changer l'arbre autour de `child` démonterait le
    // Navigator et ferait perdre la pile d'écrans.
    return Stack(
      textDirection: TextDirection.ltr,
      children: [
        ExcludeFocus(
          excluding: _blocking,
          child: ExcludeSemantics(excluding: _blocking, child: widget.child),
        ),
        if (_blocking)
          Positioned.fill(
            child: _ForceUpdateScreen(
              busy: _busy,
              failed: _failed,
              onUpdate: _onUpdatePressed,
            ),
          ),
      ],
    );
  }
}

class _ForceUpdateScreen extends StatelessWidget {
  const _ForceUpdateScreen({
    required this.busy,
    required this.failed,
    required this.onUpdate,
  });

  final bool busy;
  final bool failed;
  final VoidCallback onUpdate;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;

    return Material(
      color: scheme.surface,
      child: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(32),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  Icons.system_update_rounded,
                  size: 72,
                  color: scheme.primary,
                ),
                const SizedBox(height: 24),
                Text(
                  l10n.forceUpdateTitle,
                  textAlign: TextAlign.center,
                  style: theme.textTheme.headlineSmall
                      ?.copyWith(fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 12),
                Text(
                  l10n.forceUpdateMessage,
                  textAlign: TextAlign.center,
                  style: theme.textTheme.bodyLarge
                      ?.copyWith(color: scheme.onSurfaceVariant),
                ),
                if (failed) ...[
                  const SizedBox(height: 16),
                  Text(
                    l10n.forceUpdateFailed,
                    textAlign: TextAlign.center,
                    style: theme.textTheme.bodyMedium
                        ?.copyWith(color: scheme.error),
                  ),
                ],
                const SizedBox(height: 32),
                SizedBox(
                  width: double.infinity,
                  child: FilledButton.icon(
                    onPressed: busy ? null : onUpdate,
                    icon: busy
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.download_rounded),
                    label: Text(l10n.forceUpdateButton),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
