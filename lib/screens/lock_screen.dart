import 'package:flutter/material.dart';
import 'package:monitrack/l10n/app_localizations.dart';
import 'package:provider/provider.dart';
import '../providers/security_provider.dart';
import '../providers/auth_provider.dart';
import 'login_screen.dart';

class LockScreen extends StatefulWidget {
  const LockScreen({super.key});

  @override
  State<LockScreen> createState() => _LockScreenState();
}

class _LockScreenState extends State<LockScreen> with SingleTickerProviderStateMixin {
  String _inputPin = '';
  bool _hasError = false;
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

    // Auto-trigger biometrics on launch if enabled
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _triggerBiometrics();
    });
  }

  @override
  void dispose() {
    _shakeController.dispose();
    super.dispose();
  }

  Future<void> _triggerBiometrics() async {
    final securityProvider = Provider.of<SecurityProvider>(context, listen: false);
    if (securityProvider.isLockedOut) return;
    if (securityProvider.isBiometricEnabled && securityProvider.isBiometricsAvailable) {
      await securityProvider.authenticateWithBiometrics();
    }
  }

  void _onKeyPress(String digit) {
    final securityProvider = Provider.of<SecurityProvider>(context, listen: false);
    if (securityProvider.isLockedOut) return;

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
    if (securityProvider.isLockedOut) return;

    if (_inputPin.isNotEmpty) {
      setState(() {
        _hasError = false;
        _inputPin = _inputPin.substring(0, _inputPin.length - 1);
      });
    }
  }

  Future<void> _verifyPin() async {
    final securityProvider = Provider.of<SecurityProvider>(context, listen: false);
    final success = await securityProvider.authenticateWithPin(_inputPin);
    
    if (!success) {
      setState(() {
        _hasError = true;
      });
      _shakeController.forward(from: 0.0);
    }
  }

  void _forgotPin() {
    final l10n = AppLocalizations.of(context)!;
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(l10n.forgotPassword),
        content: const Text(
          'Pour des raisons de sécurité, si vous avez oublié votre code PIN, vous devez vous déconnecter et vous reconnecter. Vos données locales synchronisées seront préservées.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text(l10n.cancel),
          ),
          TextButton(
            onPressed: () async {
              Navigator.pop(ctx);
              final authProvider = Provider.of<AuthProvider>(context, listen: false);
              await authProvider.logout();
              if (mounted) {
                Navigator.pushAndRemoveUntil(
                  context,
                  MaterialPageRoute(builder: (_) => const LoginScreen()),
                  (route) => false,
                );
              }
            },
            child: Text(l10n.logout, style: TextStyle(color: Colors.red)),
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
                    'FIMUS',
                    style: theme.textTheme.headlineMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                      color: theme.colorScheme.primary,
                      letterSpacing: 1.5,
                    ),
                  ),
                  const SizedBox(height: 10),
                  Text(
                    securityProvider.isLockedOut
                        ? 'Trop de tentatives. Réessayez plus tard.'
                        : _hasError ? 'Code PIN incorrect' : 'Saisissez votre code PIN',
                    style: TextStyle(
                      fontSize: 16,
                      color: (securityProvider.isLockedOut || _hasError) ? theme.colorScheme.error : theme.colorScheme.onSurfaceVariant,
                      fontWeight: (securityProvider.isLockedOut || _hasError) ? FontWeight.bold : FontWeight.normal,
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
                        _buildKey('1'),
                        _buildKey('2'),
                        _buildKey('3'),
                      ],
                    ),
                    const SizedBox(height: 16),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                      children: [
                        _buildKey('4'),
                        _buildKey('5'),
                        _buildKey('6'),
                      ],
                    ),
                    const SizedBox(height: 16),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                      children: [
                        _buildKey('7'),
                        _buildKey('8'),
                        _buildKey('9'),
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
                              )
                            : const SizedBox(width: 70, height: 70),
                        _buildKey('0'),
                        _buildIconButton(
                          Icons.backspace_outlined,
                          _onDelete,
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

  Widget _buildKey(String digit) {
    final theme = Theme.of(context);
    return SizedBox(
      width: 75,
      height: 75,
      child: OutlinedButton(
        onPressed: () => _onKeyPress(digit),
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

  Widget _buildIconButton(IconData icon, VoidCallback onPressed, {Color? color}) {
    final theme = Theme.of(context);
    return SizedBox(
      width: 75,
      height: 75,
      child: IconButton(
        onPressed: onPressed,
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
