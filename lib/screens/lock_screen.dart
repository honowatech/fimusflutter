import 'dart:async';

import 'package:flutter/material.dart';
import 'package:monitrack/l10n/app_localizations.dart';
import 'package:provider/provider.dart';
import '../providers/security_provider.dart';
import '../providers/auth_provider.dart';
import '../services/notification_service.dart';
import 'login_screen.dart';

class LockScreen extends StatefulWidget {
  const LockScreen({super.key});

  @override
  State<LockScreen> createState() => _LockScreenState();
}

class _LockScreenState extends State<LockScreen> with SingleTickerProviderStateMixin {
  String _inputPin = '';
  bool _hasError = false;
  bool _isVerifying = false;
  bool _reauthDialogShown = false;
  bool _wasLockedOut = false;
  Timer? _lockoutTicker;
  late AnimationController _shakeController;
  late Animation<double> _shakeAnimation;

  @override
  void initState() {
    super.initState();
    _shakeController = AnimationController(
      duration: const Duration(milliseconds: 500),
      vsync: this,
    );
    _shakeAnimation = Tween<double>(begin: 0.0, end: 24.0)
        .chain(CurveTween(curve: Curves.elasticIn))
        .animate(_shakeController);

    // Rafraîchit le compte à rebours du blocage une fois par seconde.
    // On ne reconstruit que pendant un blocage actif, plus une fois au moment
    // où il expire : inutile de faire tourner l'UI à 1 Hz le reste du temps.
    _lockoutTicker = Timer.periodic(const Duration(seconds: 1), (_) {
      if (!mounted) return;
      final securityProvider =
          Provider.of<SecurityProvider>(context, listen: false);
      final isLockedOut = securityProvider.isLockedOut;
      if (isLockedOut) {
        _wasLockedOut = true;
        setState(() {});
      } else if (_wasLockedOut) {
        // Le blocage vient d'expirer : on redonne la main sans remettre le
        // compteur cumulé d'échecs à zéro.
        _wasLockedOut = false;
        securityProvider.refreshLockoutState();
        setState(() {});
      }
    });

    // Auto-trigger biometrics on launch if enabled
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _triggerBiometrics();
    });
  }

  @override
  void dispose() {
    _lockoutTicker?.cancel();
    _shakeController.dispose();
    super.dispose();
  }

  Future<void> _triggerBiometrics() async {
    final securityProvider = Provider.of<SecurityProvider>(context, listen: false);
    if (securityProvider.isLockedOut || securityProvider.requiresFullReauth) {
      return;
    }
    if (securityProvider.isBiometricEnabled && securityProvider.isBiometricsAvailable) {
      final unlocked = await securityProvider.authenticateWithBiometrics();
      if (unlocked) _consumePendingNotificationIntents();
    }
  }

  /// Rejeu des intentions de notification mises en attente pendant que l'app
  /// était verrouillée (tap de navigation, bouton « Confirmer » / « Annuler »).
  ///
  /// Le rejeu est différé : `_AuthGate` doit d'abord remplacer LockScreen par
  /// MainScreen, sinon la navigation viserait un écran pas encore monté.
  /// `MainScreen` relance le même rejeu à son montage, l'opération étant
  /// idempotente (l'intention est retirée du stockage avant exécution).
  void _consumePendingNotificationIntents() {
    Future.delayed(const Duration(milliseconds: 400), () {
      NotificationService().consumePendingOnLaunch();
    });
  }

  void _onKeyPress(String digit) {
    final securityProvider = Provider.of<SecurityProvider>(context, listen: false);
    if (securityProvider.isLockedOut ||
        securityProvider.requiresFullReauth ||
        _isVerifying) {
      return;
    }

    if (_hasError) {
      setState(() {
        _hasError = false;
        _inputPin = '';
      });
    }

    if (_inputPin.length < 4) {
      setState(() {
        _inputPin += digit;
      });

      if (_inputPin.length == 4) {
        _verifyPin();
      }
    }
  }

  void _onDelete() {
    final securityProvider = Provider.of<SecurityProvider>(context, listen: false);
    if (securityProvider.isLockedOut || _isVerifying) return;

    if (_inputPin.isNotEmpty) {
      setState(() {
        _hasError = false;
        _inputPin = _inputPin.substring(0, _inputPin.length - 1);
      });
    }
  }

  Future<void> _verifyPin() async {
    final securityProvider = Provider.of<SecurityProvider>(context, listen: false);

    // La dérivation PBKDF2 prend quelques centaines de millisecondes (isolate) :
    // on neutralise le clavier pendant la vérification pour éviter les doubles
    // saisies et les compteurs d'échecs incrémentés deux fois.
    setState(() => _isVerifying = true);
    final success = await securityProvider.authenticateWithPin(_inputPin);
    if (!mounted) return;
    setState(() => _isVerifying = false);

    if (success) {
      _consumePendingNotificationIntents();
      return;
    }

    setState(() {
      _hasError = true;
    });
    _shakeController.forward(from: 0.0);
  }

  /// Message d'état affiché sous le logo : compte à rebours du blocage ou
  /// essais restants avant le prochain palier, sans divulguer le compteur
  /// cumulé ni le seuil de déconnexion forcée.
  String _statusMessage(
    AppLocalizations l10n,
    SecurityProvider securityProvider,
  ) {
    if (securityProvider.requiresFullReauth) {
      return l10n.lockTooManyAttemptsReauth;
    }
    if (securityProvider.isLockedOut) {
      return l10n.lockTooManyAttemptsRetryIn(
          _formatRemaining(securityProvider.remainingLockout));
    }
    if (_isVerifying) return l10n.verifying;
    if (_hasError) {
      final remaining = securityProvider.remainingAttemptsBeforeLockout;
      return remaining <= 2
          ? l10n.lockIncorrectPinAttemptsLeft(remaining)
          : l10n.incorrectPinCode;
    }
    return l10n.enterYourPin;
  }

  String _formatRemaining(Duration remaining) {
    final total = remaining.inSeconds < 0 ? 0 : remaining.inSeconds;
    final hours = total ~/ 3600;
    final minutes = (total % 3600) ~/ 60;
    final seconds = total % 60;
    if (hours > 0) {
      return '${hours}h ${minutes.toString().padLeft(2, '0')}min';
    }
    return '${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}';
  }

  /// Seuil d'échecs atteint : le PIN ne suffit plus, on impose une
  /// réauthentification complète. Les données locales sont conservées.
  void _promptFullReauth() {
    final l10n = AppLocalizations.of(context)!;
    if (_reauthDialogShown) return;
    _reauthDialogShown = true;
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => PopScope(
        canPop: false,
        child: AlertDialog(
          title: Text(l10n.securityTitle),
          content: Text(l10n.lockFullReauthBody),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.pop(ctx);
                _logoutAndReturnToLogin();
              },
              child: Text(l10n.reconnectAction),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _logoutAndReturnToLogin() async {
    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    await authProvider.logout(context: context);
    if (!mounted) return;
    Navigator.pushAndRemoveUntil(
      context,
      MaterialPageRoute(builder: (_) => const LoginScreen()),
      (route) => false,
    );
  }

  void _forgotPin() {
    final l10n = AppLocalizations.of(context)!;
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(l10n.forgotPassword),
        content: Text(l10n.lockForgotPinBody),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text(l10n.cancel),
          ),
          TextButton(
            onPressed: () async {
              Navigator.pop(ctx);
              await _logoutAndReturnToLogin();
            },
            child: Text(
              l10n.logout,
              style: TextStyle(color: Theme.of(context).colorScheme.error),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final theme = Theme.of(context);
    final securityProvider = Provider.of<SecurityProvider>(context);
    final isBlocked =
        securityProvider.isLockedOut || securityProvider.requiresFullReauth;
    final canType = !isBlocked && !_isVerifying;

    if (securityProvider.requiresFullReauth) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _promptFullReauth();
      });
    }

    return Scaffold(
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              theme.colorScheme.primary.withValues(alpha: 0.05),
              theme.colorScheme.surface,
            ],
          ),
        ),
        child: SafeArea(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              // Logo and Header
              Column(
                children: [
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: theme.colorScheme.primaryContainer.withValues(alpha: 0.4),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      Icons.lock_outline_rounded,
                      size: 48,
                      color: theme.colorScheme.primary,
                    ),
                  ),
                  const SizedBox(height: 20),
                  Text(
                    l10n.appTitle,
                    style: theme.textTheme.headlineMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                      color: theme.colorScheme.primary,
                      letterSpacing: 1.5,
                    ),
                  ),
                  const SizedBox(height: 10),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 32),
                    child: Text(
                      _statusMessage(l10n, securityProvider),
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 16,
                        color: (isBlocked || _hasError)
                            ? theme.colorScheme.error
                            : theme.colorScheme.onSurfaceVariant,
                        fontWeight: (isBlocked || _hasError)
                            ? FontWeight.bold
                            : FontWeight.normal,
                      ),
                    ),
                  ),
                ],
              ),

              // PIN Indicator Dots
              AnimatedBuilder(
                animation: _shakeAnimation,
                builder: (context, child) {
                  return Transform.translate(
                    offset: Offset(_shakeAnimation.value * (1 - _shakeController.value), 0),
                    child: child,
                  );
                },
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: List.generate(4, (index) {
                    final isFilled = index < _inputPin.length;
                    return AnimatedContainer(
                      duration: const Duration(milliseconds: 150),
                      margin: const EdgeInsets.symmetric(horizontal: 12),
                      width: 18,
                      height: 18,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: _hasError
                            ? theme.colorScheme.error
                            : isFilled
                                ? theme.colorScheme.primary
                                : theme.colorScheme.primary.withValues(alpha: 0.2),
                        border: Border.all(
                          color: _hasError
                              ? theme.colorScheme.error
                              : isFilled
                                  ? theme.colorScheme.primary
                                  : theme.colorScheme.primary.withValues(alpha: 0.4),
                          width: 1.5,
                        ),
                      ),
                    );
                  }),
                ),
              ),

              // Keypad
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 32.0),
                child: Column(
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                      children: [
                        _buildKey('1', enabled: canType),
                        _buildKey('2', enabled: canType),
                        _buildKey('3', enabled: canType),
                      ],
                    ),
                    const SizedBox(height: 16),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                      children: [
                        _buildKey('4', enabled: canType),
                        _buildKey('5', enabled: canType),
                        _buildKey('6', enabled: canType),
                      ],
                    ),
                    const SizedBox(height: 16),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                      children: [
                        _buildKey('7', enabled: canType),
                        _buildKey('8', enabled: canType),
                        _buildKey('9', enabled: canType),
                      ],
                    ),
                    const SizedBox(height: 16),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                      children: [
                        // Biometrics button
                        (securityProvider.isBiometricEnabled && securityProvider.isBiometricsAvailable)
                            ? _buildIconButton(
                                Icons.fingerprint_rounded,
                                _triggerBiometrics,
                                color: theme.colorScheme.primary,
                                enabled: canType,
                              )
                            : const SizedBox(width: 70, height: 70),
                        _buildKey('0', enabled: canType),
                        _buildIconButton(
                          Icons.backspace_outlined,
                          _onDelete,
                          enabled: canType,
                        ),
                      ],
                    ),
                  ],
                ),
              ),

              // Fallback Forgot PIN Button
              TextButton(
                onPressed: _forgotPin,
                child: Text(
                  l10n.forgotPassword,
                  style: TextStyle(
                    color: theme.colorScheme.primary,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildKey(String digit, {bool enabled = true}) {
    final theme = Theme.of(context);
    return SizedBox(
      width: 75,
      height: 75,
      child: OutlinedButton(
        onPressed: enabled ? () => _onKeyPress(digit) : null,
        style: OutlinedButton.styleFrom(
          shape: const CircleBorder(),
          side: BorderSide(color: theme.colorScheme.outlineVariant.withValues(alpha: 0.5)),
          padding: EdgeInsets.zero,
          backgroundColor: theme.colorScheme.surface,
          elevation: 1,
        ),
        child: Text(
          digit,
          style: theme.textTheme.headlineMedium?.copyWith(
            fontWeight: FontWeight.w600,
            color: theme.colorScheme.onSurface,
          ),
        ),
      ),
    );
  }

  Widget _buildIconButton(
    IconData icon,
    VoidCallback onPressed, {
    Color? color,
    bool enabled = true,
  }) {
    final theme = Theme.of(context);
    return SizedBox(
      width: 75,
      height: 75,
      child: IconButton(
        onPressed: enabled ? onPressed : null,
        icon: Icon(
          icon,
          size: 28,
          color: color ?? theme.colorScheme.onSurfaceVariant,
        ),
        style: IconButton.styleFrom(
          shape: const CircleBorder(),
        ),
      ),
    );
  }
}
