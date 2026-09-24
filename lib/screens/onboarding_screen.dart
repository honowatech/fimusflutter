import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../l10n/app_localizations.dart';
import '../providers/locale_provider.dart';
import '../services/auth_service.dart';
import '../services/notification_permission_service.dart';
import '../services/notification_service.dart';
import '../widgets/searchable_country_dropdown.dart';
import 'login_screen.dart';
import '../utils/app_theme.dart';

class OnboardingScreen extends StatefulWidget {
  const OnboardingScreen({super.key});

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen> {
  final PageController _pageController = PageController();
  final _authService = AuthService();
  
  int _currentStep = 0;
  bool _isLoadingCountries = true;
  List<Map<String, dynamic>> _countries = [];
  int? _selectedCountryId;
  String _selectedProfileType = 'particulier';
  bool _isRequestingNotification = false;
  bool _notificationHandled = false;
  bool _notificationGranted = false;
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    _fetchCountries();
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  Future<void> _fetchCountries() async {
    try {
      final countries = await _authService.getCountries();
      setState(() {
        _countries = List<Map<String, dynamic>>.from(countries);
        _isLoadingCountries = false;
      });
    } catch (e) {
      // Détail technique gardé dans les logs, message générique à l'écran.
      debugPrint('OnboardingScreen: chargement des pays impossible : $e');
      setState(() => _isLoadingCountries = false);
      if (mounted) {
        final l10n = AppLocalizations.of(context)!;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(l10n.genericErrorRetry),
            // Orange d'origine conserve en clair, jeton `warning` en sombre.
            backgroundColor: Theme.of(context).colorScheme.tone(
                  light: Colors.orange,
                  dark: Theme.of(context).colorScheme.warning,
                ),
          ),
        );
      }
    }
  }

  void _nextPage() {
    if (_currentStep < 3) {
      _pageController.nextPage(
        duration: const Duration(milliseconds: 350),
        curve: Curves.easeInOut,
      );
    }
  }

  void _previousPage() {
    if (_currentStep > 0) {
      _pageController.previousPage(
        duration: const Duration(milliseconds: 350),
        curve: Curves.easeInOut,
      );
    }
  }

  Future<void> _requestNotificationPermission() async {
    setState(() => _isRequestingNotification = true);
    var granted = false;
    try {
      final settings = await NotificationService().requestPermission();
      granted = settings.authorizationStatus == AuthorizationStatus.authorized ||
          settings.authorizationStatus == AuthorizationStatus.provisional;
    } catch (e) {
      debugPrint("Error requesting notification permission in onboarding: $e");
    } finally {
      if (mounted) {
        context.read<NotificationPermissionService>().applyStatus(granted);
        setState(() {
          _isRequestingNotification = false;
          _notificationHandled = true;
          _notificationGranted = granted;
        });

        if (granted) {
          Future.delayed(const Duration(milliseconds: 800), () {
            if (mounted && _currentStep == 2) {
              _nextPage();
            }
          });
        }
      }
    }
  }

  Future<void> _finishOnboarding() async {
    if (_selectedCountryId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(AppLocalizations.of(context)!.fieldRequired)),
      );
      return;
    }

    setState(() => _isSaving = true);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('has_seen_onboarding', true);
    await prefs.setInt('selected_country_id', _selectedCountryId!);
    await prefs.setString('selected_profile_type', _selectedProfileType);

    if (mounted) {
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (_) => const LoginScreen()),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final l10n = AppLocalizations.of(context)!;
    final localeProvider = Provider.of<LocaleProvider>(context);

    return Scaffold(
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              theme.colorScheme.primary.withValues(alpha: 0.06),
              theme.colorScheme.surface,
            ],
          ),
        ),
        child: SafeArea(
          child: Column(
            children: [
              // Header avec Logo et Bouton Retour
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 12.0),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    _currentStep > 0
                        ? IconButton(
                            icon: const Icon(Icons.arrow_back_ios_new_rounded),
                            onPressed: _previousPage,
                            tooltip: l10n.back,
                          )
                        : const SizedBox(width: 48),
                    Image.asset(
                      'assets/images/logo.png',
                      height: 48,
                    ),
                    const SizedBox(width: 48),
                  ],
                ),
              ),

              // Barre d'indicateur de progression (4 ÉTAPES)
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 8.0),
                child: Column(
                  children: [
                    Row(
                      children: List.generate(4, (index) {
                        final isCompleted = index < _currentStep;
                        final isCurrent = index == _currentStep;
                        return Expanded(
                          child: AnimatedContainer(
                            duration: const Duration(milliseconds: 300),
                            height: 6,
                            margin: const EdgeInsets.symmetric(horizontal: 3),
                            decoration: BoxDecoration(
                              color: isCurrent
                                  ? theme.colorScheme.primary
                                  : isCompleted
                                      ? theme.colorScheme.primary.withValues(alpha: 0.4)
                                      : theme.colorScheme.surfaceContainerHighest,
                              borderRadius: BorderRadius.circular(4),
                            ),
                          ),
                        );
                      }),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      l10n.onboardingStepProgress(_currentStep + 1, 4),
                      style: theme.textTheme.labelMedium?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),

              // Contenu principal dans PageView
              Expanded(
                child: PageView(
                  controller: _pageController,
                  physics: const NeverScrollableScrollPhysics(),
                  onPageChanged: (page) => setState(() => _currentStep = page),
                  children: [
                    // PAGE 0: CHOIX DE LA LANGUE
                    _buildLanguageStep(context, theme, l10n, localeProvider),

                    // PAGE 1: SÉLECTION DU PAYS
                    _buildCountryStep(context, theme, l10n),

                    // PAGE 2: CONFIRMATION DÉDIÉE DES NOTIFICATIONS (Juste après le pays !)
                    _buildNotificationStep(context, theme, l10n),

                    // PAGE 3: CHOIX DU PROFIL & FINALISATION
                    _buildProfileStep(context, theme, l10n),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // --------------------------------------------------------------------------
  // PAGE 0 : Choix de la Langue
  // --------------------------------------------------------------------------
  Widget _buildLanguageStep(
    BuildContext context,
    ThemeData theme,
    AppLocalizations l10n,
    LocaleProvider localeProvider,
  ) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const SizedBox(height: 16),
          Text(
            l10n.onboardingWelcome,
            textAlign: TextAlign.center,
            style: theme.textTheme.headlineMedium?.copyWith(
              fontWeight: FontWeight.bold,
              color: theme.colorScheme.primary,
            ),
          ),
          const SizedBox(height: 12),
          Text(
            l10n.onboardingStep1,
            textAlign: TextAlign.center,
            style: theme.textTheme.titleMedium?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 40),
          Row(
            children: [
              Expanded(
                child: _OptionCard(
                  title: l10n.french,
                  subtitle: l10n.officialLanguage,
                  icon: Icons.language_rounded,
                  isSelected: localeProvider.locale.languageCode == 'fr',
                  onTap: () => localeProvider.setLocale(const Locale('fr')),
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: _OptionCard(
                  title: l10n.english,
                  subtitle: l10n.defaultLanguage,
                  icon: Icons.language_rounded,
                  isSelected: localeProvider.locale.languageCode == 'en',
                  onTap: () => localeProvider.setLocale(const Locale('en')),
                ),
              ),
            ],
          ),
          const SizedBox(height: 60),
          ElevatedButton(
            onPressed: _nextPage,
            style: ElevatedButton.styleFrom(
              padding: const EdgeInsets.symmetric(vertical: 16),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
              backgroundColor: theme.colorScheme.primary,
              foregroundColor: theme.colorScheme.onPrimary,
              elevation: 2,
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  l10n.onboardingContinue.toUpperCase(),
                  style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, letterSpacing: 1),
                ),
                const SizedBox(width: 8),
                const Icon(Icons.arrow_forward_rounded),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // --------------------------------------------------------------------------
  // PAGE 1 : Sélection du Pays
  // --------------------------------------------------------------------------
  Widget _buildCountryStep(
    BuildContext context,
    ThemeData theme,
    AppLocalizations l10n,
  ) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const SizedBox(height: 16),
          Text(
            l10n.onboardingStep2,
            textAlign: TextAlign.center,
            style: theme.textTheme.headlineSmall?.copyWith(
              fontWeight: FontWeight.bold,
              color: theme.colorScheme.primary,
            ),
          ),
          const SizedBox(height: 12),
          Text(
            l10n.onboardingCountryHint,
            textAlign: TextAlign.center,
            style: theme.textTheme.bodyMedium?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 40),
          _isLoadingCountries
              ? const Center(child: CircularProgressIndicator())
              : SearchableCountryDropdown<int>(
                  countries: _countries,
                  initialValue: _selectedCountryId,
                  labelBuilder: (country) => country['name'] as String? ?? '',
                  valueBuilder: (country) => country['id'] as int,
                  decoration: InputDecoration(
                    prefixIcon: const Icon(Icons.flag_outlined),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(14)),
                  ),
                  hint: l10n.country,
                  onChanged: (v) => setState(() => _selectedCountryId = v),
                ),
          const SizedBox(height: 60),
          ElevatedButton(
            onPressed: _selectedCountryId == null ? null : _nextPage,
            style: ElevatedButton.styleFrom(
              padding: const EdgeInsets.symmetric(vertical: 16),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
              backgroundColor: theme.colorScheme.primary,
              foregroundColor: theme.colorScheme.onPrimary,
              elevation: 2,
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  l10n.onboardingContinue.toUpperCase(),
                  style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, letterSpacing: 1),
                ),
                const SizedBox(width: 8),
                const Icon(Icons.arrow_forward_rounded),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // --------------------------------------------------------------------------
  // PAGE 2 : ÉCRAN DÉDIÉ CONFIRMATION DES NOTIFICATIONS (Juste après le Pays !)
  // Design soigné et UX optimisée pour favoriser la validation par l'utilisateur
  // --------------------------------------------------------------------------
  Widget _buildNotificationStep(
    BuildContext context,
    ThemeData theme,
    AppLocalizations l10n,
  ) {
    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 12.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Visual Hero avec Cloche animée
          Center(
            child: Stack(
              alignment: Alignment.center,
              children: [
                Container(
                  width: 110,
                  height: 110,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: theme.colorScheme.primary.withValues(alpha: 0.12),
                  ),
                ),
                Container(
                  width: 85,
                  height: 85,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [
                        theme.colorScheme.primary,
                        theme.colorScheme.primary.withValues(alpha: 0.8),
                      ],
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: theme.colorScheme.primary.withValues(alpha: 0.35),
                        blurRadius: 16,
                        offset: const Offset(0, 6),
                      ),
                    ],
                  ),
                  child: Icon(
                    Icons.notifications_active_rounded,
                    // Pose sur le degrade `primary`.
                    color: theme.colorScheme.onPrimary,
                    size: 44,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),

          // Titre principal clair & lisible
          Text(
            l10n.onboardingNotifHeader,
            textAlign: TextAlign.center,
            style: theme.textTheme.headlineSmall?.copyWith(
              fontWeight: FontWeight.bold,
              color: theme.colorScheme.onSurface,
            ),
          ),
          const SizedBox(height: 8),

          // Sous-titre expliquant la valeur ajoutée
          Text(
            l10n.onboardingNotifSub,
            textAlign: TextAlign.center,
            style: theme.textTheme.bodyMedium?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
              height: 1.4,
            ),
          ),
          const SizedBox(height: 24),

          // Avantages clés (Checklist de bénéfices UX)
          _BenefitTile(
            icon: Icons.alarm_on_rounded,
            iconColor: theme.colorScheme.tone(
              light: Colors.orange.shade700,
              dark: theme.colorScheme.warning,
            ),
            title: l10n.onboardingNotifBenefit1Title,
            description: l10n.onboardingNotifBenefit1Desc,
          ),
          const SizedBox(height: 12),
          _BenefitTile(
            icon: Icons.groups_rounded,
            iconColor: theme.colorScheme.tone(
              light: Colors.blue.shade700,
              dark: theme.colorScheme.info,
            ),
            title: l10n.onboardingNotifBenefit2Title,
            description: l10n.onboardingNotifBenefit2Desc,
          ),
          const SizedBox(height: 32),

          // Action principale (Autoriser) — le succès n'est affiché que si
          // le système a réellement accordé la permission.
          _notificationHandled && _notificationGranted
              ? Container(
                  padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 20),
                  // Cartouche de succes : verts d'origine en clair, jeton
                  // `success` en sombre.
                  decoration: BoxDecoration(
                    color: theme.colorScheme
                        .tone(
                          light: Colors.green,
                          dark: theme.colorScheme.success,
                        )
                        .withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(
                      color: theme.colorScheme.tone(
                        light: Colors.green.shade400,
                        dark: theme.colorScheme.success,
                      ),
                      width: 1.5,
                    ),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.check_circle_rounded,
                        color: theme.colorScheme.tone(
                          light: Colors.green,
                          dark: theme.colorScheme.success,
                        ),
                        size: 24,
                      ),
                      const SizedBox(width: 10),
                      Text(
                        l10n.onboardingNotificationsEnabled,
                        style: TextStyle(
                          color: theme.colorScheme.tone(
                            light: Colors.green,
                            dark: theme.colorScheme.success,
                          ),
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                        ),
                      ),
                    ],
                  ),
                )
              : _notificationHandled && !_notificationGranted
              ? Container(
                  padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 20),
                  // Cartouche d'avertissement : oranges d'origine en clair,
                  // famille `warning*` en sombre.
                  decoration: BoxDecoration(
                    color: theme.colorScheme
                        .tone(
                          light: Colors.orange,
                          dark: theme.colorScheme.warning,
                        )
                        .withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(
                      color: theme.colorScheme.tone(
                        light: Colors.orange.shade400,
                        dark: theme.colorScheme.warning,
                      ),
                      width: 1.5,
                    ),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.notifications_off_rounded,
                        // clair = Colors.orange.shade800
                        color: theme.colorScheme.warning,
                        size: 24,
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          l10n.onboardingNotificationsDenied,
                          style: TextStyle(
                            color: theme.colorScheme.tone(
                              light: Colors.orange.shade900,
                              dark: theme.colorScheme.warning,
                            ),
                            fontWeight: FontWeight.bold,
                            fontSize: 15,
                          ),
                        ),
                      ),
                    ],
                  ),
                )
              : ElevatedButton.icon(
                  onPressed: _isRequestingNotification ? null : _requestNotificationPermission,
                  icon: _isRequestingNotification
                      ? SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(
                            // Pose sur le bouton rempli en `primary`.
                            color: theme.colorScheme.onPrimary,
                            strokeWidth: 2.5,
                          ),
                        )
                      : const Icon(Icons.notifications_active_rounded, size: 22),
                  label: Text(
                    l10n.onboardingEnableNotifications,
                    style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, letterSpacing: 0.5),
                  ),
                  style: ElevatedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                    backgroundColor: theme.colorScheme.primary,
                    foregroundColor: theme.colorScheme.onPrimary,
                    elevation: 3,
                  ),
                ),
          const SizedBox(height: 12),

          // Option secondaire (Plus tard / Continuer)
          TextButton(
            onPressed: _nextPage,
            child: Text(
              _notificationHandled ? l10n.onboardingContinue : l10n.onboardingSkip,
              style: TextStyle(
                color: theme.colorScheme.onSurfaceVariant,
                fontWeight: FontWeight.w600,
                fontSize: 15,
              ),
            ),
          ),
        ],
      ),
    );
  }

  // --------------------------------------------------------------------------
  // PAGE 3 : Choix du Profil & Finalisation
  // --------------------------------------------------------------------------
  Widget _buildProfileStep(
    BuildContext context,
    ThemeData theme,
    AppLocalizations l10n,
  ) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const SizedBox(height: 16),
          Text(
            l10n.onboardingStep3,
            textAlign: TextAlign.center,
            style: theme.textTheme.headlineSmall?.copyWith(
              fontWeight: FontWeight.bold,
              color: theme.colorScheme.primary,
            ),
          ),
          const SizedBox(height: 12),
          Text(
            l10n.onboardingProfileTypeHint,
            textAlign: TextAlign.center,
            style: theme.textTheme.bodyMedium?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 24),
          Row(
            children: [
              Expanded(
                child: _OptionCard(
                  title: l10n.profileTypePersonal,
                  subtitle: l10n.personalManagement,
                  icon: Icons.person_outline_rounded,
                  isSelected: _selectedProfileType == 'particulier',
                  onTap: () => setState(() => _selectedProfileType = 'particulier'),
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: _OptionCard(
                  title: l10n.profileTypeSmallBusiness,
                  subtitle: l10n.profileTypeSmallBusinessDesc,
                  icon: Icons.storefront_outlined,
                  isSelected: _selectedProfileType == 'petit_commerce',
                  onTap: () => setState(() => _selectedProfileType = 'petit_commerce'),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              Expanded(
                child: _OptionCard(
                  title: l10n.profileTypeCompany,
                  subtitle: l10n.profileTypeCompanyDesc,
                  icon: Icons.business_outlined,
                  isSelected: _selectedProfileType == 'entreprise',
                  onTap: () => setState(() => _selectedProfileType = 'entreprise'),
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: _OptionCard(
                  title: l10n.profileTypeKiosk,
                  subtitle: l10n.profileTypeKioskDesc,
                  icon: Icons.point_of_sale_outlined,
                  isSelected: _selectedProfileType == 'kiosque',
                  onTap: () => setState(() => _selectedProfileType = 'kiosque'),
                ),
              ),
            ],
          ),
          const SizedBox(height: 36),
          ElevatedButton(
            onPressed: (_selectedCountryId == null || _isSaving) ? null : _finishOnboarding,
            style: ElevatedButton.styleFrom(
              padding: const EdgeInsets.symmetric(vertical: 16),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
              backgroundColor: theme.colorScheme.primary,
              foregroundColor: theme.colorScheme.onPrimary,
              elevation: 3,
            ),
            child: _isSaving
                ? SizedBox(
                    height: 24,
                    width: 24,
                    child: CircularProgressIndicator(
                      // Pose sur le bouton rempli en `primary`.
                      color: theme.colorScheme.onPrimary,
                      strokeWidth: 2,
                    ),
                  )
                : Text(
                    l10n.onboardingFinish.toUpperCase(),
                    style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, letterSpacing: 1),
                  ),
          ),
        ],
      ),
    );
  }
}

// --------------------------------------------------------------------------
// Composant Carte d'Avantage UX (Benefits Checklist)
// --------------------------------------------------------------------------
class _BenefitTile extends StatelessWidget {
  final IconData icon;
  final Color iconColor;
  final String title;
  final String description;

  const _BenefitTile({
    required this.icon,
    required this.iconColor,
    required this.title,
    required this.description,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.all(14.0),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerLow,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: theme.colorScheme.outlineVariant.withValues(alpha: 0.5)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: iconColor.withValues(alpha: 0.12),
              shape: BoxShape.circle,
            ),
            child: Icon(icon, color: iconColor, size: 22),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: theme.textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: theme.colorScheme.onSurface,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  description,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                    height: 1.3,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// --------------------------------------------------------------------------
// Composant Carte d'Option Sélectionnable
// --------------------------------------------------------------------------
class _OptionCard extends StatelessWidget {
  final String title;
  final String? subtitle;
  final IconData icon;
  final bool isSelected;
  final VoidCallback onTap;

  const _OptionCard({
    required this.title,
    this.subtitle,
    required this.icon,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 14),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isSelected
                ? theme.colorScheme.primary
                : theme.colorScheme.outlineVariant,
            width: isSelected ? 2 : 1,
          ),
          color: isSelected ? theme.colorScheme.primary.withValues(alpha: 0.08) : theme.colorScheme.surface,
          boxShadow: isSelected
              ? [
                  BoxShadow(
                    color: theme.colorScheme.primary.withValues(alpha: 0.15),
                    blurRadius: 8,
                    offset: const Offset(0, 3),
                  )
                ]
              : null,
        ),
        child: Column(
          children: [
            Icon(
              icon,
              color: isSelected
                  ? theme.colorScheme.primary
                  : theme.colorScheme.onSurfaceVariant,
              size: 30,
            ),
            const SizedBox(height: 10),
            Text(
              title,
              textAlign: TextAlign.center,
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: isSelected ? FontWeight.bold : FontWeight.w600,
                color: isSelected ? theme.colorScheme.primary : theme.colorScheme.onSurface,
              ),
            ),
            if (subtitle != null) ...[
              const SizedBox(height: 4),
              Text(
                subtitle!,
                textAlign: TextAlign.center,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                  fontSize: 11,
                ),
              ),
            ]
          ],
        ),
      ),
    );
  }
}
