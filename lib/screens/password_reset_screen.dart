import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:monitrack/l10n/app_localizations.dart';

import '../services/auth_service.dart';
import '../utils/app_theme.dart';

/// Parcours « mot de passe oublié » en trois temps (sprint 7).
///
/// Le serveur n'envoie plus de mot de passe par e-mail : il envoie un code à
/// usage unique. Le parcours est donc :
///   1. adresse e-mail        → `POST /api/password/forgot`
///   2. code à 6 chiffres     → `POST /api/password/verify-code` (rend un jeton)
///   3. nouveau mot de passe  → `POST /api/password/reset`
///
/// Deux invariants portés par cet écran :
///
///  * **aucun message ne révèle si une adresse existe**. Le serveur répond
///    délibérément la même chose dans les deux cas ; l'écran ne fait donc
///    jamais varier ses textes selon l'adresse saisie, et tous les échecs de
///    l'étape 2 (code faux, périmé, déjà utilisé, quota épuisé, compte
///    inexistant) partagent un seul message ;
///  * **le succès de l'étape 3 déconnecte tout**, cet appareil compris : c'est
///    annoncé avant l'envoi, pas découvert après.
class PasswordResetScreen extends StatefulWidget {
  /// Adresse déjà saisie sur l'écran de connexion, reprise telle quelle pour
  /// éviter une double frappe.
  final String initialEmail;

  const PasswordResetScreen({super.key, this.initialEmail = ''});

  @override
  State<PasswordResetScreen> createState() => _PasswordResetScreenState();
}

/// Les trois temps du parcours.
enum _ResetStep { email, code, password }

/// Hauteur minimale des cibles tactiles (recommandation Material : 48 dp).
const double _minTouchTarget = 48.0;

class _PasswordResetScreenState extends State<PasswordResetScreen> {
  /// Délai local entre deux demandes de code. Le serveur limite déjà de son
  /// côté (429) ; ce garde-fou évite d'aller chercher son refus.
  static const Duration _resendCooldown = Duration(seconds: 60);

  final _emailFormKey = GlobalKey<FormState>();
  final _codeFormKey = GlobalKey<FormState>();
  final _passwordFormKey = GlobalKey<FormState>();

  late final TextEditingController _emailController;
  final _codeController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmController = TextEditingController();

  final _auth = AuthService();

  _ResetStep _step = _ResetStep.email;
  bool _isSubmitting = false;
  bool _obscurePassword = true;

  /// Longueur du code annoncée par le serveur (`code_length`) : l'interface s'y
  /// adapte au lieu de figer 6.
  int _codeLength = 6;

  /// Fin de validité du code (15 minutes côté serveur) et du jeton d'échange
  /// (10 minutes) : deux comptes à rebours distincts, tous deux affichés.
  DateTime? _codeExpiresAt;
  DateTime? _tokenExpiresAt;

  /// Prochaine demande de code autorisée : cooldown local, ou délai imposé par
  /// un 429 (`Retry-After`).
  DateTime? _resendAvailableAt;

  /// Fin du blocage imposé par un 429, distinct du cooldown d'envoi : le
  /// serveur limite séparément les demandes de code et les vérifications, donc
  /// un 429 sur la vérification doit geler le bouton « Valider » sans attendre
  /// la fin d'un cooldown d'envoi qui, lui, dure toujours une minute.
  DateTime? _throttledUntil;

  /// Jeton rendu par l'étape 2, seul sésame de l'étape 3.
  String? _resetToken;

  /// Message d'erreur et message neutre affichés en bandeau (jamais un texte
  /// venu du serveur : les libellés sont localisés ici).
  String? _errorMessage;
  String? _noticeMessage;

  /// Rafraîchit les comptes à rebours une fois par seconde, uniquement quand
  /// un compte à rebours est réellement affiché.
  Timer? _ticker;

  @override
  void initState() {
    super.initState();
    _emailController = TextEditingController(text: widget.initialEmail.trim());
  }

  @override
  void dispose() {
    _ticker?.cancel();
    _emailController.dispose();
    _codeController.dispose();
    _passwordController.dispose();
    _confirmController.dispose();
    super.dispose();
  }

  // ---------------------------------------------------------------------------
  // Comptes à rebours
  // ---------------------------------------------------------------------------

  void _startTicker() {
    _ticker ??= Timer.periodic(const Duration(seconds: 1), (_) {
      if (!mounted) return;
      // Un seul `setState` par seconde : les getters `_remaining…` relisent
      // les échéances, il n'y a pas d'état à recalculer ici.
      setState(() {});
      if (_remainingCode == null &&
          _remainingToken == null &&
          _remainingResend == null &&
          _remainingThrottle == null) {
        _ticker?.cancel();
        _ticker = null;
      }
    });
  }

  Duration? _remainingOf(DateTime? deadline) {
    if (deadline == null) return null;
    final left = deadline.difference(DateTime.now());
    return left.isNegative ? null : left;
  }

  Duration? get _remainingCode => _remainingOf(_codeExpiresAt);
  Duration? get _remainingToken => _remainingOf(_tokenExpiresAt);
  Duration? get _remainingResend => _remainingOf(_resendAvailableAt);
  Duration? get _remainingThrottle => _remainingOf(_throttledUntil);

  /// `mm:ss`, format lisible et indépendant de la langue.
  String _formatDuration(Duration d) {
    final minutes = d.inMinutes;
    final seconds = d.inSeconds % 60;
    return '$minutes:${seconds.toString().padLeft(2, '0')}';
  }

  // ---------------------------------------------------------------------------
  // Étape 1 — demande du code
  // ---------------------------------------------------------------------------

  Future<void> _requestCode({bool resend = false}) async {
    final l10n = AppLocalizations.of(context)!;
    if (!resend && !(_emailFormKey.currentState?.validate() ?? false)) return;
    if (_remainingResend != null) return;

    setState(() {
      _isSubmitting = true;
      _errorMessage = null;
      _noticeMessage = null;
    });

    try {
      final result = await _auth.requestPasswordResetCode(
        _emailController.text.trim(),
      );
      if (!mounted) return;
      setState(() {
        _codeLength = result.codeLength;
        _codeExpiresAt = DateTime.now().add(result.expiresIn);
        _resendAvailableAt = DateTime.now().add(_resendCooldown);
        _throttledUntil = null;
        _step = _ResetStep.code;
        // Message volontairement conditionnel (« si un compte existe ») :
        // c'est la seule formulation qui ne renseigne pas un attaquant.
        _noticeMessage = l10n.passwordResetCodeSent;
        if (resend) _codeController.clear();
      });
      _startTicker();
    } on PasswordResetException catch (e) {
      _showResetError(e, l10n);
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  // ---------------------------------------------------------------------------
  // Étape 2 — vérification du code
  // ---------------------------------------------------------------------------

  Future<void> _verifyCode() async {
    final l10n = AppLocalizations.of(context)!;
    if (!(_codeFormKey.currentState?.validate() ?? false)) return;

    setState(() {
      _isSubmitting = true;
      _errorMessage = null;
      _noticeMessage = null;
    });

    try {
      final token = await _auth.verifyPasswordResetCode(
        email: _emailController.text.trim(),
        code: _codeController.text.trim(),
      );
      if (!mounted) return;
      setState(() {
        _resetToken = token.token;
        _tokenExpiresAt = DateTime.now().add(token.expiresIn);
        _codeExpiresAt =
            null; // le code est consommé, son décompte n'a plus de sens
        _step = _ResetStep.password;
      });
      _startTicker();
    } on PasswordResetException catch (e) {
      _showResetError(e, l10n);
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  // ---------------------------------------------------------------------------
  // Étape 3 — nouveau mot de passe
  // ---------------------------------------------------------------------------

  Future<void> _submitPassword() async {
    final l10n = AppLocalizations.of(context)!;
    if (!(_passwordFormKey.currentState?.validate() ?? false)) return;
    final token = _resetToken;
    if (token == null || token.isEmpty) {
      setState(() {
        _step = _ResetStep.email;
        _errorMessage = l10n.passwordResetTokenExpired;
      });
      return;
    }

    setState(() {
      _isSubmitting = true;
      _errorMessage = null;
      _noticeMessage = null;
    });

    try {
      await _auth.resetPasswordWithToken(
        resetToken: token,
        password: _passwordController.text,
      );
      if (!mounted) return;
      // Le serveur a révoqué toutes les sessions : l'écran de connexion
      // affiche le message et l'utilisateur se reconnecte.
      Navigator.of(context).pop(true);
    } on PasswordResetException catch (e) {
      _showResetError(e, l10n);
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  // ---------------------------------------------------------------------------
  // Traduction des erreurs du flux
  // ---------------------------------------------------------------------------

  /// Un seul endroit décide de ce que l'utilisateur lit, pour qu'aucun cas ne
  /// laisse filtrer l'existence d'un compte.
  void _showResetError(PasswordResetException error, AppLocalizations l10n) {
    if (!mounted) return;
    setState(() {
      switch (error) {
        case PasswordResetThrottledException(:final retryAfter):
          // 429 : on affiche le délai du serveur et on verrouille l'action
          // jusqu'à son terme, au lieu de laisser marteler.
          final until = DateTime.now().add(retryAfter);
          _throttledUntil = until;
          // Le cooldown d'envoi ne peut pas être plus court que le refus du
          // serveur.
          if (_resendAvailableAt == null ||
              _resendAvailableAt!.isBefore(until)) {
            _resendAvailableAt = until;
          }
          _errorMessage = l10n.passwordResetTooManyAttempts(
            _formatDuration(retryAfter),
          );
        case InvalidResetCodeException():
          // Code faux, périmé, déjà utilisé, quota épuisé ou adresse inconnue :
          // le serveur ne les distingue pas, l'interface non plus.
          _errorMessage = l10n.passwordResetCodeInvalid;
        case InvalidResetTokenException():
          // Le jeton d'échange a expiré : il faut repartir de l'adresse.
          _step = _ResetStep.email;
          _resetToken = null;
          _tokenExpiresAt = null;
          _codeController.clear();
          _passwordController.clear();
          _confirmController.clear();
          _errorMessage = l10n.passwordResetTokenExpired;
        case PasswordResetValidationException(:final concernsPassword):
          _errorMessage = concernsPassword
              ? l10n.passwordResetPasswordRejected
              : l10n.pleaseEnterValidEmail;
        case PasswordResetUnavailableException(:final details):
          debugPrint('PasswordResetScreen : appel indisponible ($details)');
          _errorMessage = l10n.passwordResetUnavailable;
      }
    });
    _startTicker();
  }

  /// Complexité exigée : 8 caractères, casse mixte, chiffres — exactement la
  /// règle serveur (`Password::min(8)->mixedCase()->numbers()`), commune à
  /// l'inscription. Le message de longueur est celui déjà utilisé par
  /// `register_screen.dart` (`min8Chars`) pour ne pas dire deux choses
  /// différentes de la même contrainte.
  String? _validateNewPassword(String? value, AppLocalizations l10n) {
    if (value == null || value.isEmpty) return l10n.required;
    if (value.length < 8) return l10n.min8Chars;
    final hasLower = RegExp(r'[a-z]').hasMatch(value);
    final hasUpper = RegExp(r'[A-Z]').hasMatch(value);
    if (!hasLower || !hasUpper) return l10n.passwordNeedsMixedCase;
    if (!RegExp(r'\d').hasMatch(value)) return l10n.passwordNeedsDigit;
    return null;
  }

  // ---------------------------------------------------------------------------
  // Interface
  // ---------------------------------------------------------------------------

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final l10n = AppLocalizations.of(context)!;

    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.passwordResetTitle),
        centerTitle: true,
        // Transparent volontaire : laisse voir le dégradé du Container, comme
        // sur les écrans de connexion et d'inscription.
        backgroundColor: Colors.transparent,
        elevation: 0,
      ),
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              theme.colorScheme.primary.withValues(alpha: 0.05),
              theme.colorScheme.surface,
            ],
          ),
        ),
        child: SafeArea(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _StepIndicator(step: _step),
                const SizedBox(height: 24),
                if (_noticeMessage != null) ...[
                  _Banner(
                    icon: Icons.mark_email_read_outlined,
                    message: _noticeMessage!,
                    background: theme.colorScheme.infoContainer,
                    foreground: theme.colorScheme.onInfoContainer,
                    border: theme.colorScheme.infoOutline,
                  ),
                  const SizedBox(height: 16),
                ],
                if (_errorMessage != null) ...[
                  _Banner(
                    icon: Icons.error_outline,
                    message: _errorMessage!,
                    background: theme.colorScheme.errorContainer,
                    foreground: theme.colorScheme.onErrorContainer,
                    border: theme.colorScheme.error.withValues(alpha: 0.4),
                  ),
                  const SizedBox(height: 16),
                ],
                switch (_step) {
                  _ResetStep.email => _buildEmailStep(theme, l10n),
                  _ResetStep.code => _buildCodeStep(theme, l10n),
                  _ResetStep.password => _buildPasswordStep(theme, l10n),
                },
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildEmailStep(ThemeData theme, AppLocalizations l10n) {
    final waiting = _remainingResend;
    return Form(
      key: _emailFormKey,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            l10n.passwordResetEmailInstruction(_codeLength),
            style: theme.textTheme.bodyMedium?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 24),
          TextFormField(
            controller: _emailController,
            keyboardType: TextInputType.emailAddress,
            textInputAction: TextInputAction.done,
            autofillHints: const [AutofillHints.email],
            enabled: !_isSubmitting,
            decoration: InputDecoration(
              labelText: l10n.email,
              prefixIcon: const Icon(Icons.email_outlined),
            ),
            validator: (v) {
              if (v == null || v.trim().isEmpty) return l10n.required;
              if (!v.contains('@')) return l10n.pleaseEnterValidEmail;
              return null;
            },
            onFieldSubmitted: (_) => _requestCode(),
          ),
          const SizedBox(height: 24),
          _PrimaryButton(
            label: waiting != null
                ? l10n.passwordResetResendIn(_formatDuration(waiting))
                : l10n.passwordResetSendCode,
            isLoading: _isSubmitting,
            onPressed: _isSubmitting || waiting != null
                ? null
                : () => _requestCode(),
          ),
        ],
      ),
    );
  }

  Widget _buildCodeStep(ThemeData theme, AppLocalizations l10n) {
    final codeLeft = _remainingCode;
    final resendLeft = _remainingResend;
    final throttleLeft = _remainingThrottle;
    return Form(
      key: _codeFormKey,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            l10n.passwordResetCodeInstruction(
              _codeLength,
              _emailController.text.trim(),
            ),
            style: theme.textTheme.bodyMedium?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 24),
          // Pas de wrapper `Semantics` autour du champ : `labelText` est déjà
          // annoncé par les lecteurs d'écran, et la consigne au-dessus donne le
          // nombre de chiffres attendu.
          TextFormField(
            controller: _codeController,
            // Clavier numérique et saisie chiffres uniquement : le code n'a
            // jamais de lettre, autant éviter le clavier alphabétique.
            keyboardType: TextInputType.number,
            inputFormatters: [
              FilteringTextInputFormatter.digitsOnly,
              LengthLimitingTextInputFormatter(_codeLength),
            ],
            autofillHints: const [AutofillHints.oneTimeCode],
            textInputAction: TextInputAction.done,
            textAlign: TextAlign.center,
            autofocus: true,
            enabled: !_isSubmitting,
            style: theme.textTheme.headlineSmall?.copyWith(
              letterSpacing: 8,
              fontWeight: FontWeight.w600,
            ),
            decoration: InputDecoration(
              labelText: l10n.passwordResetCodeLabel,
              counterText: '',
            ),
            validator: (v) {
              final value = v?.trim() ?? '';
              if (value.isEmpty) return l10n.required;
              if (value.length != _codeLength) {
                return l10n.passwordResetCodeIncomplete(_codeLength);
              }
              return null;
            },
            onFieldSubmitted: (_) => _verifyCode(),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Icon(
                codeLeft != null
                    ? Icons.timer_outlined
                    : Icons.timer_off_outlined,
                size: 18,
                color: codeLeft != null
                    ? theme.colorScheme.onSurfaceVariant
                    : theme.colorScheme.warning,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  codeLeft != null
                      ? l10n.passwordResetCodeValidFor(
                          _formatDuration(codeLeft),
                        )
                      : l10n.passwordResetCodeExpired,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: codeLeft != null
                        ? theme.colorScheme.onSurfaceVariant
                        : theme.colorScheme.warning,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 24),
          _PrimaryButton(
            label: throttleLeft != null
                ? l10n.passwordResetResendIn(_formatDuration(throttleLeft))
                : l10n.passwordResetVerifyCode,
            isLoading: _isSubmitting,
            onPressed: _isSubmitting || throttleLeft != null
                ? null
                : _verifyCode,
          ),
          const SizedBox(height: 8),
          _SecondaryButton(
            icon: Icons.refresh,
            label: resendLeft != null
                ? l10n.passwordResetResendIn(_formatDuration(resendLeft))
                : l10n.passwordResetResendCode,
            onPressed: _isSubmitting || resendLeft != null
                ? null
                : () => _requestCode(resend: true),
          ),
          _SecondaryButton(
            icon: Icons.edit_outlined,
            label: l10n.passwordResetChangeEmail,
            onPressed: _isSubmitting
                ? null
                : () => setState(() {
                    _step = _ResetStep.email;
                    _errorMessage = null;
                    _noticeMessage = null;
                    _codeController.clear();
                  }),
          ),
        ],
      ),
    );
  }

  Widget _buildPasswordStep(ThemeData theme, AppLocalizations l10n) {
    final tokenLeft = _remainingToken;
    return Form(
      key: _passwordFormKey,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            l10n.passwordResetRules,
            style: theme.textTheme.bodyMedium?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 24),
          TextFormField(
            controller: _passwordController,
            obscureText: _obscurePassword,
            autofillHints: const [AutofillHints.newPassword],
            enabled: !_isSubmitting,
            decoration: InputDecoration(
              labelText: l10n.passwordResetNewPassword,
              prefixIcon: const Icon(Icons.lock_outline),
              suffixIcon: IconButton(
                tooltip: l10n.passwordResetNewPassword,
                icon: Icon(
                  _obscurePassword ? Icons.visibility_off : Icons.visibility,
                ),
                onPressed: () =>
                    setState(() => _obscurePassword = !_obscurePassword),
              ),
            ),
            validator: (v) => _validateNewPassword(v, l10n),
          ),
          const SizedBox(height: 16),
          TextFormField(
            controller: _confirmController,
            obscureText: _obscurePassword,
            autofillHints: const [AutofillHints.newPassword],
            enabled: !_isSubmitting,
            textInputAction: TextInputAction.done,
            decoration: InputDecoration(
              labelText: l10n.confirmPassword,
              prefixIcon: const Icon(Icons.lock_reset_outlined),
            ),
            validator: (v) {
              if (v == null || v.isEmpty) return l10n.required;
              if (v != _passwordController.text) {
                return l10n.passwordsDoNotMatch;
              }
              return null;
            },
            onFieldSubmitted: (_) => _submitPassword(),
          ),
          const SizedBox(height: 16),
          _Banner(
            icon: Icons.logout,
            message: l10n.passwordResetSessionsWarning,
            background: theme.colorScheme.warningContainer,
            foreground: theme.colorScheme.onWarningContainer,
            border: theme.colorScheme.warningOutline,
          ),
          if (tokenLeft != null) ...[
            const SizedBox(height: 12),
            Text(
              l10n.passwordResetCodeValidFor(_formatDuration(tokenLeft)),
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ],
          const SizedBox(height: 24),
          _PrimaryButton(
            label: l10n.passwordResetSubmit,
            isLoading: _isSubmitting,
            onPressed: _isSubmitting || _remainingThrottle != null
                ? null
                : _submitPassword,
          ),
        ],
      ),
    );
  }
}

/// Fil d'Ariane des trois étapes : un repère de progression, pas un contrôle
/// (on ne saute pas une étape en tapant dessus).
class _StepIndicator extends StatelessWidget {
  final _ResetStep step;

  const _StepIndicator({required this.step});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final l10n = AppLocalizations.of(context)!;
    final labels = [
      l10n.passwordResetStepEmail,
      l10n.passwordResetStepCode,
      l10n.passwordResetStepPassword,
    ];
    final current = _ResetStep.values.indexOf(step);

    return Row(
      children: [
        for (var i = 0; i < labels.length; i++) ...[
          if (i > 0)
            Expanded(
              child: Container(
                height: 2,
                color: i <= current
                    ? theme.colorScheme.primary
                    : theme.colorScheme.outlineVariant,
              ),
            ),
          Column(
            children: [
              Container(
                width: 28,
                height: 28,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: i <= current
                      ? theme.colorScheme.primary
                      : theme.colorScheme.surfaceContainerHighest,
                ),
                child: i < current
                    ? Icon(
                        Icons.check,
                        size: 16,
                        color: theme.colorScheme.onPrimary,
                      )
                    : Text(
                        '${i + 1}',
                        style: theme.textTheme.labelMedium?.copyWith(
                          color: i <= current
                              ? theme.colorScheme.onPrimary
                              : theme.colorScheme.onSurfaceVariant,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
              ),
              const SizedBox(height: 4),
              Text(
                labels[i],
                style: theme.textTheme.labelSmall?.copyWith(
                  color: i == current
                      ? theme.colorScheme.primary
                      : theme.colorScheme.onSurfaceVariant,
                  fontWeight: i == current
                      ? FontWeight.bold
                      : FontWeight.normal,
                ),
              ),
            ],
          ),
        ],
      ],
    );
  }
}

/// Bandeau d'information, d'avertissement ou d'erreur. Les couleurs viennent
/// des jetons sémantiques d'`app_theme.dart` : lisibles en clair comme en
/// sombre.
class _Banner extends StatelessWidget {
  final IconData icon;
  final String message;
  final Color background;
  final Color foreground;
  final Color border;

  const _Banner({
    required this.icon,
    required this.message,
    required this.background,
    required this.foreground,
    required this.border,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: border),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 20, color: foreground),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              message,
              style: theme.textTheme.bodySmall?.copyWith(color: foreground),
            ),
          ),
        ],
      ),
    );
  }
}

/// Bouton d'action principal : hauteur fixée à 52 dp (au-delà des 48 dp
/// recommandés) et indicateur de chargement à la place du libellé.
class _PrimaryButton extends StatelessWidget {
  final String label;
  final bool isLoading;
  final VoidCallback? onPressed;

  const _PrimaryButton({
    required this.label,
    required this.isLoading,
    this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return ElevatedButton(
      onPressed: onPressed,
      style: ElevatedButton.styleFrom(
        minimumSize: const Size.fromHeight(52),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        backgroundColor: theme.colorScheme.primary,
        foregroundColor: theme.colorScheme.onPrimary,
      ),
      child: isLoading
          ? SizedBox(
              height: 24,
              width: 24,
              child: CircularProgressIndicator(
                // Posé sur le bouton rempli en `primary`.
                color: theme.colorScheme.onPrimary,
                strokeWidth: 2,
              ),
            )
          : Text(
              label,
              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
    );
  }
}

/// Action secondaire (renvoyer un code, changer d'adresse), avec la même
/// contrainte de cible tactile que le bouton principal.
class _SecondaryButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback? onPressed;

  const _SecondaryButton({
    required this.icon,
    required this.label,
    this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    return TextButton.icon(
      onPressed: onPressed,
      icon: Icon(icon, size: 20),
      label: Text(label),
      style: TextButton.styleFrom(
        minimumSize: const Size.fromHeight(_minTouchTarget),
      ),
    );
  }
}
