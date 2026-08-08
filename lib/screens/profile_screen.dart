import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:monitrack/l10n/app_localizations.dart';
import '../providers/ussd_provider.dart';
import '../providers/profile_provider.dart';
import '../providers/locale_provider.dart';
import '../providers/theme_provider.dart';
import '../providers/auth_provider.dart';
import '../providers/security_provider.dart';
import '../screens/login_screen.dart';
import 'add_operator_screen.dart';
import '../widgets/searchable_country_dropdown.dart';
import '../utils/countries_data.dart';
import 'contacts_screen.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  void _editName(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final profileProvider = Provider.of<ProfileProvider>(
      context,
      listen: false,
    );
    String firstName = profileProvider.profile.firstName;
    String lastName = profileProvider.profile.lastName;

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(l10n.editProfileInfo),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextFormField(
              initialValue: firstName,
              decoration: InputDecoration(labelText: l10n.firstName),
              onChanged: (val) => firstName = val,
            ),
            TextFormField(
              initialValue: lastName,
              decoration: InputDecoration(labelText: l10n.lastName),
              onChanged: (val) => lastName = val,
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text(l10n.cancel),
          ),
          TextButton(
            onPressed: () {
              profileProvider.updateProfile(
                profileProvider.profile.copyWith(
                  firstName: firstName.trim(),
                  lastName: lastName.trim(),
                ),
              );
              Navigator.pop(ctx);
            },
            child: Text(l10n.save),
          ),
        ],
      ),
    );
  }

  void _showSetPinDialog(BuildContext context) {
    final securityProvider = Provider.of<SecurityProvider>(
      context,
      listen: false,
    );
    final pinController = TextEditingController();
    final confirmController = TextEditingController();
    final formKey = GlobalKey<FormState>();

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Activer le verrouillage'),
        content: Form(
          key: formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text(
                'Définissez un code PIN à 4 chiffres pour sécuriser l\'accès.',
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: pinController,
                obscureText: true,
                keyboardType: TextInputType.number,
                maxLength: 4,
                decoration: const InputDecoration(
                  labelText: 'Nouveau code PIN',
                  prefixIcon: Icon(Icons.lock_outline),
                ),
                validator: (val) {
                  if (val == null ||
                      val.length != 4 ||
                      int.tryParse(val) == null) {
                    return 'Saisissez 4 chiffres';
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
                decoration: const InputDecoration(
                  labelText: 'Confirmer le code PIN',
                  prefixIcon: Icon(Icons.lock_outline),
                ),
                validator: (val) {
                  if (val != pinController.text) {
                    return 'Les codes ne correspondent pas';
                  }
                  return null;
                },
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Annuler'),
          ),
          TextButton(
            onPressed: () async {
              if (formKey.currentState!.validate()) {
                await securityProvider.enableAppLock(pinController.text);
                if (ctx.mounted) Navigator.pop(ctx);
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('✅ Verrouillage activé avec succès'),
                    ),
                  );
                }
              }
            },
            child: const Text('Activer'),
          ),
        ],
      ),
    );
  }

  void _showDisablePinDialog(BuildContext context) {
    final securityProvider = Provider.of<SecurityProvider>(
      context,
      listen: false,
    );
    final pinController = TextEditingController();
    final formKey = GlobalKey<FormState>();

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Désactiver le verrouillage'),
        content: Form(
          key: formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text(
                'Veuillez saisir votre code PIN actuel pour désactiver le verrouillage.',
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: pinController,
                obscureText: true,
                keyboardType: TextInputType.number,
                maxLength: 4,
                decoration: const InputDecoration(
                  labelText: 'Code PIN actuel',
                  prefixIcon: Icon(Icons.lock_outline),
                ),
                validator: (val) {
                  if (val == null || val.isEmpty) {
                    return 'Code PIN requis';
                  }
                  return null;
                },
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Annuler'),
          ),
          TextButton(
            onPressed: () async {
              if (formKey.currentState!.validate()) {
                final success = await securityProvider.disableAppLock(
                  pinController.text,
                );
                if (success) {
                  if (ctx.mounted) Navigator.pop(ctx);
                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('✅ Verrouillage désactivé')),
                    );
                  }
                } else {
                  ScaffoldMessenger.of(ctx).showSnackBar(
                    const SnackBar(
                      content: Text('❌ Code PIN incorrect'),
                      backgroundColor: Colors.red,
                    ),
                  );
                }
              }
            },
            child: const Text(
              'Désactiver',
              style: TextStyle(color: Colors.red),
            ),
          ),
        ],
      ),
    );
  }

  void _showChangePinDialog(BuildContext context) {
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
      builder: (ctx) => AlertDialog(
        title: const Text('Modifier le code PIN'),
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
                  decoration: const InputDecoration(
                    labelText: 'Code PIN actuel',
                    prefixIcon: Icon(Icons.lock_outline),
                  ),
                  validator: (val) {
                    if (val == null || val.length != 4) {
                      return 'Saisissez 4 chiffres';
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
                  decoration: const InputDecoration(
                    labelText: 'Nouveau code PIN',
                    prefixIcon: Icon(Icons.lock_outline),
                  ),
                  validator: (val) {
                    if (val == null ||
                        val.length != 4 ||
                        int.tryParse(val) == null) {
                      return 'Saisissez 4 chiffres';
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
                  decoration: const InputDecoration(
                    labelText: 'Confirmer le code PIN',
                    prefixIcon: Icon(Icons.lock_outline),
                  ),
                  validator: (val) {
                    if (val != newPinController.text) {
                      return 'Les codes ne correspondent pas';
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
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Annuler'),
          ),
          TextButton(
            onPressed: () async {
              if (formKey.currentState!.validate()) {
                final success = await securityProvider.changePin(
                  oldPinController.text,
                  newPinController.text,
                );
                if (success) {
                  if (ctx.mounted) Navigator.pop(ctx);
                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('✅ Code PIN modifié avec succès'),
                      ),
                    );
                  }
                } else {
                  ScaffoldMessenger.of(ctx).showSnackBar(
                    const SnackBar(
                      content: Text('❌ Code PIN actuel incorrect'),
                      backgroundColor: Colors.red,
                    ),
                  );
                }
              }
            },
            child: const Text('Modifier'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final ussdProvider = Provider.of<UssdProvider>(context);
    final profileProvider = Provider.of<ProfileProvider>(context);
    final profile = profileProvider.profile;
    final operators = ussdProvider.operators;
    final theme = Theme.of(context);

    return Scaffold(
      body: NestedScrollView(
        headerSliverBuilder: (context, innerBoxIsScrolled) {
          return [
            SliverAppBar(
              pinned: true,
              expandedHeight: 180.0, // Reduced height (was ~230 previously)
              backgroundColor: theme.colorScheme.primary,
              foregroundColor: theme.colorScheme.onPrimary,
              elevation: 0,
              actions: [
                IconButton(
                  icon: const Icon(Icons.edit),
                  onPressed: () => _editName(context),
                  tooltip: l10n.editProfileInfo,
                ),
              ],
              flexibleSpace: FlexibleSpaceBar(
                centerTitle: true,
                title: Text(
                  '${profile.firstName} ${profile.lastName}',
                  style: TextStyle(
                    color: theme.colorScheme.onPrimary,
                    fontWeight: FontWeight.bold,
                    fontSize: 18,
                  ),
                ),
                background: Container(
                  decoration: BoxDecoration(
                    color: theme.colorScheme.primary,
                    borderRadius: const BorderRadius.only(
                      bottomLeft: Radius.circular(30),
                      bottomRight: Radius.circular(30),
                    ),
                  ),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const SizedBox(height: 20),
                      Consumer<AuthProvider>(
                        builder: (context, authProvider, _) {
                          final photoUrl = authProvider.user?['photoUrl'];
                          return CircleAvatar(
                            radius: 35, // Reduced size
                            backgroundColor: theme.colorScheme.primaryContainer,
                            backgroundImage:
                                (photoUrl != null && photoUrl.isNotEmpty)
                                ? NetworkImage(photoUrl)
                                : null,
                            child: (photoUrl == null || photoUrl.isEmpty)
                                ? Icon(
                                    Icons.person,
                                    size: 40,
                                    color: theme.colorScheme.onPrimaryContainer,
                                  )
                                : null,
                          );
                        },
                      ),
                      const SizedBox(height: 40),
                    ],
                  ),
                ),
              ),
            ),
            SliverPersistentHeader(
              pinned: true,
              delegate: _SliverTabBarDelegate(
                TabBar(
                  controller: _tabController,
                  labelColor: theme.colorScheme.primary,
                  unselectedLabelColor: Colors.grey,
                  indicatorColor: theme.colorScheme.primary,
                  indicatorSize: TabBarIndicatorSize.tab,
                  tabs: [
                    Tab(
                      icon: const Icon(Icons.person_outline_rounded),
                      text: 'Mon Compte',
                    ),
                    Tab(
                      icon: const Icon(Icons.settings_outlined),
                      text: l10n.settings,
                    ),
                  ],
                ),
              ),
            ),
          ];
        },
        body: TabBarView(
          controller: _tabController,
          children: [
            SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 16.0),
              child: Column(
                key: const ValueKey('mon_compte_tab'),
                children: [
                  // Carte Compte & Synchronisation
                  Consumer<AuthProvider>(
                    builder: (context, authProvider, _) {
                      return _buildSectionCard(
                        theme: theme,
                        children: [
                          if (authProvider.isAuthenticated) ...[
                            ListTile(
                              leading: CircleAvatar(
                                backgroundColor:
                                    theme.colorScheme.primaryContainer,
                                child: Icon(
                                  Icons.person,
                                  color: theme.colorScheme.onPrimaryContainer,
                                ),
                              ),
                              title: Text(
                                authProvider.user?['name'] ?? 'Utilisateur',
                                style: const TextStyle(
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                              subtitle: Text(authProvider.user?['email'] ?? ''),
                            ),
                            const Divider(height: 1, indent: 16),
                            ListTile(
                              leading: Icon(
                                Icons.vpn_key_rounded,
                                color: theme.colorScheme.primary,
                              ),
                              title: const Text('Mon pseudo'),
                              subtitle: Text(
                                authProvider.userPseudo ?? 'Non défini',
                                style: const TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 16,
                                ),
                              ),
                              trailing: IconButton(
                                icon: const Icon(Icons.copy_rounded),
                                onPressed: () {
                                  final pseudo = authProvider.userPseudo;
                                  if (pseudo != null) {
                                    Clipboard.setData(
                                      ClipboardData(text: pseudo),
                                    );
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      const SnackBar(
                                        content: Text('Mon pseudo copié !'),
                                      ),
                                    );
                                  }
                                },
                              ),
                            ),
                            const Divider(height: 1, indent: 16),
                            ListTile(
                              leading: Icon(
                                Icons.people_alt_rounded,
                                color: theme.colorScheme.primary,
                              ),
                              title: const Text('Mes contacts'),
                              subtitle: const Text(
                                'Gérer vos contacts pour le partage de comptes et dettes',
                              ),
                              onTap: () {
                                Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (_) => const ContactsScreen(),
                                  ),
                                );
                              },
                            ),
                            const Divider(height: 1, indent: 16),
                            ListTile(
                              leading: authProvider.isSyncing
                                  ? SizedBox(
                                      width: 24,
                                      height: 24,
                                      child: CircularProgressIndicator(
                                        strokeWidth: 2,
                                        color: theme.colorScheme.primary,
                                      ),
                                    )
                                  : Icon(
                                      Icons.sync_rounded,
                                      color: theme.colorScheme.primary,
                                    ),
                              title: const Text('Synchroniser maintenant'),
                              subtitle: const Text(
                                'Pousse vos données locales vers le cloud',
                              ),
                              onTap: authProvider.isSyncing
                                  ? null
                                  : () async {
                                      final result = await authProvider.syncNow(
                                        context,
                                      );
                                      if (context.mounted) {
                                        ScaffoldMessenger.of(
                                          context,
                                        ).showSnackBar(
                                          SnackBar(
                                            content: Text(
                                              result.success
                                                  ? '✅ Sync terminée — ${result.pushed} envoyés, ${result.pulled} reçus'
                                                  : '❌ Erreur: ${result.error}',
                                            ),
                                            backgroundColor: result.success
                                                ? Colors.green
                                                : Colors.red,
                                          ),
                                        );
                                      }
                                    },
                            ),
                            const Divider(height: 1, indent: 16),
                            ListTile(
                              leading: const Icon(
                                Icons.logout_rounded,
                                color: Colors.red,
                              ),
                              title: const Text(
                                'Se déconnecter',
                                style: TextStyle(color: Colors.red),
                              ),
                              onTap: () async {
                                final confirm = await showDialog<bool>(
                                  context: context,
                                  builder: (_) => AlertDialog(
                                    title: const Text('Déconnexion'),
                                    content: const Text(
                                      'Êtes-vous sûr de vouloir vous déconnecter ? Vos données locales seront préservées.',
                                    ),
                                    actions: [
                                      TextButton(
                                        onPressed: () =>
                                            Navigator.pop(context, false),
                                        child: const Text('Annuler'),
                                      ),
                                      TextButton(
                                        onPressed: () =>
                                            Navigator.pop(context, true),
                                        child: const Text(
                                          'Déconnecter',
                                          style: TextStyle(color: Colors.red),
                                        ),
                                      ),
                                    ],
                                  ),
                                );
                                if (confirm == true && context.mounted) {
                                  await authProvider.logout();
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
                              },
                            ),
                            const Divider(height: 1, indent: 16),
                            ListTile(
                              leading: const Icon(
                                Icons.delete_forever_rounded,
                                color: Colors.red,
                              ),
                              title: Text(
                                l10n.deleteUserAccount,
                                style: const TextStyle(color: Colors.red),
                              ),
                              onTap: () async {
                                final confirm = await showDialog<bool>(
                                  context: context,
                                  builder: (_) => AlertDialog(
                                    title: Text(l10n.deleteUserAccountConfirm),
                                    content: Text(l10n.deleteUserAccountWarning),
                                    actions: [
                                      TextButton(
                                        onPressed: () =>
                                            Navigator.pop(context, false),
                                        child: Text(l10n.cancel),
                                      ),
                                      TextButton(
                                        onPressed: () =>
                                            Navigator.pop(context, true),
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
                                    await authProvider.deleteAccount();
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
                                    if (context.mounted) {
                                      Navigator.pop(context);
                                      ScaffoldMessenger.of(context).showSnackBar(
                                        SnackBar(
                                          content: Text('${l10n.errorOccurred}: ${e.toString()}'),
                                          backgroundColor: Colors.red,
                                        ),
                                      );
                                    }
                                  }
                                }
                              },
                            ),
                          ] else ...[
                            Padding(
                              padding: const EdgeInsets.all(16.0),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.stretch,
                                children: [
                                  const Text(
                                    'Connectez-vous pour synchroniser vos données dans le cloud.',
                                    style: TextStyle(
                                      fontStyle: FontStyle.italic,
                                    ),
                                  ),
                                  const SizedBox(height: 12),
                                  ElevatedButton.icon(
                                    onPressed: () {
                                      Navigator.push(
                                        context,
                                        MaterialPageRoute(
                                          builder: (_) => const LoginScreen(),
                                        ),
                                      );
                                    },
                                    icon: const Icon(Icons.login),
                                    label: const Text('Se connecter'),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ],
                      );
                    },
                  ),

                  const SizedBox(height: 16),

                  // Carte Opérateurs
                  _buildSectionCard(
                    title: l10n.myOperators,
                    icon: Icons.sim_card,
                    theme: theme,
                    action: OutlinedButton.icon(
                      onPressed: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => const AddOperatorScreen(),
                          ),
                        );
                      },
                      style: OutlinedButton.styleFrom(
                        foregroundColor: theme.colorScheme.primary,
                        side: BorderSide(
                          color: theme.colorScheme.primary.withValues(
                            alpha: 0.3,
                          ),
                        ),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 8,
                        ),
                      ),
                      icon: const Icon(Icons.add, size: 16),
                      label: Text(l10n.add),
                    ),
                    children: operators.isEmpty
                        ? [
                            Padding(
                              padding: const EdgeInsets.all(16.0),
                              child: Text(
                                l10n.noOperatorAvailable,
                                style: const TextStyle(
                                  fontStyle: FontStyle.italic,
                                ),
                              ),
                            ),
                          ]
                        : operators
                              .map(
                                (op) => Column(
                                  children: [
                                    ListTile(
                                      leading: CircleAvatar(
                                        backgroundColor:
                                            theme.colorScheme.primaryContainer,
                                        child: Icon(
                                          Icons.cell_tower,
                                          color: theme
                                              .colorScheme
                                              .onPrimaryContainer,
                                        ),
                                      ),
                                      title: Text(
                                        op.name,
                                        style: const TextStyle(
                                          fontWeight: FontWeight.w600,
                                        ),
                                      ),
                                      subtitle: Text(
                                        op.userPhoneNumber ??
                                            l10n.noNumberDefined,
                                      ),
                                      trailing: const Icon(
                                        Icons.chevron_right,
                                        color: Colors.grey,
                                      ),
                                      onTap: () {
                                        Navigator.push(
                                          context,
                                          MaterialPageRoute(
                                            builder: (_) =>
                                                AddOperatorScreen(operator: op),
                                          ),
                                        );
                                      },
                                    ),
                                    if (op != operators.last)
                                      const Divider(height: 1, indent: 70),
                                  ],
                                ),
                              )
                              .toList(),
                  ),

                  const SizedBox(height: 30),
                ],
              ),
            ),
            SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 16.0),
              child: Column(
                key: const ValueKey('parametres_tab'),
                children: [
                  // Carte Préférences
                  _buildSectionCard(
                    theme: theme,
                    children: [
                      Padding(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 8,
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                const Icon(
                                  Icons.language,
                                  size: 20,
                                  color: Colors.grey,
                                ),
                                const SizedBox(width: 8),
                                Text(
                                  l10n.appLanguage,
                                  style: const TextStyle(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 16,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 8),
                            Consumer<LocaleProvider>(
                              builder: (context, localeProvider, child) {
                                return Wrap(
                                  spacing: 8.0,
                                  children: [
                                    ChoiceChip(
                                      label: Text(l10n.french),
                                      selected:
                                          localeProvider.locale.languageCode ==
                                          'fr',
                                      onSelected: (selected) {
                                        if (selected)
                                          localeProvider.setLocale(
                                            const Locale('fr'),
                                          );
                                      },
                                    ),
                                    ChoiceChip(
                                      label: Text(l10n.english),
                                      selected:
                                          localeProvider.locale.languageCode ==
                                          'en',
                                      onSelected: (selected) {
                                        if (selected)
                                          localeProvider.setLocale(
                                            const Locale('en'),
                                          );
                                      },
                                    ),
                                  ],
                                );
                              },
                            ),
                          ],
                        ),
                      ),
                      const Divider(height: 1),
                      Padding(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 8,
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                const Icon(
                                  Icons.public,
                                  size: 20,
                                  color: Colors.grey,
                                ),
                                const SizedBox(width: 8),
                                Text(
                                  l10n.country,
                                  style: const TextStyle(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 16,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 8),
                            Consumer<ProfileProvider>(
                              builder: (context, profileProvider, child) {
                                final currentCountry =
                                    profileProvider.profile.country;
                                return SearchableCountryDropdown<String>(
                                  countries: CountriesData.countries,
                                  initialValue: currentCountry == 'Tous'
                                      ? null
                                      : currentCountry,
                                  labelBuilder: (c) => c['name'] ?? '',
                                  valueBuilder: (c) => c['name'] ?? '',
                                  decoration: InputDecoration(
                                    hintText: l10n.allCountries,
                                    border: const OutlineInputBorder(),
                                    isDense: true,
                                    contentPadding: const EdgeInsets.symmetric(
                                      horizontal: 12,
                                      vertical: 8,
                                    ),
                                  ),
                                  onChanged: (val) {
                                    profileProvider.updateProfile(
                                      profileProvider.profile.copyWith(
                                        country: val ?? 'Tous',
                                      ),
                                    );
                                  },
                                );
                              },
                            ),
                          ],
                        ),
                      ),
                      const Divider(height: 1),
                      Padding(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 8,
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                const Icon(
                                  Icons.monetization_on,
                                  size: 20,
                                  color: Colors.grey,
                                ),
                                const SizedBox(width: 8),
                                Text(
                                  l10n.currency,
                                  style: const TextStyle(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 16,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 8),
                            Consumer<ProfileProvider>(
                              builder: (context, profileProvider, child) {
                                final currentCurrency =
                                    profileProvider.profile.currency;
                                final currencies = [
                                  'CFA',
                                  '€',
                                  '\$',
                                  '£',
                                  'XOF',
                                  'GNF',
                                  'CDF',
                                ];
                                return Wrap(
                                  spacing: 8.0,
                                  runSpacing: 8.0,
                                  children: currencies.map((c) {
                                    return ChoiceChip(
                                      label: Text(c),
                                      selected: currentCurrency == c,
                                      onSelected: (selected) {
                                        if (selected) {
                                          profileProvider.updateProfile(
                                            profileProvider.profile.copyWith(
                                              currency: c,
                                            ),
                                          );
                                        }
                                      },
                                    );
                                  }).toList(),
                                );
                              },
                            ),
                          ],
                        ),
                      ),
                      const Divider(height: 1),
                      Padding(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 8,
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                const Icon(
                                  Icons.color_lens,
                                  size: 20,
                                  color: Colors.grey,
                                ),
                                const SizedBox(width: 8),
                                Text(
                                  l10n.themeColor,
                                  style: const TextStyle(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 16,
                                  ),
                                ),
                              ],
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
                                        themeProvider.primaryColor.toARGB32() ==
                                        c.toARGB32();
                                    return GestureDetector(
                                      onTap: () =>
                                          themeProvider.setPrimaryColor(c),
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
                      ),
                    ],
                  ),

                  const SizedBox(height: 16),

                  // Carte Sécurité
                  Consumer<SecurityProvider>(
                    builder: (context, securityProvider, _) {
                      return _buildSectionCard(
                        title: 'Sécurité d\'accès',
                        icon: Icons.security_rounded,
                        theme: theme,
                        children: [
                          ListTile(
                            leading: Icon(
                              Icons.lock_outline_rounded,
                              color: securityProvider.isAppLockEnabled
                                  ? theme.colorScheme.primary
                                  : Colors.grey,
                            ),
                            title: const Text('Verrouiller l\'application'),
                            subtitle: const Text(
                              'Sécuriser l\'accès avec un code PIN',
                            ),
                            trailing: Switch(
                              value: securityProvider.isAppLockEnabled,
                              onChanged: (value) {
                                if (value) {
                                  _showSetPinDialog(context);
                                } else {
                                  _showDisablePinDialog(context);
                                }
                              },
                            ),
                          ),
                          if (securityProvider.isAppLockEnabled) ...[
                            const Divider(height: 1, indent: 16),
                            ListTile(
                              leading: Icon(
                                Icons.pin_rounded,
                                color: theme.colorScheme.primary,
                              ),
                              title: const Text('Modifier le code PIN'),
                              subtitle: const Text(
                                'Changer votre code PIN à 4 chiffres',
                              ),
                              trailing: const Icon(Icons.chevron_right),
                              onTap: () => _showChangePinDialog(context),
                            ),
                            if (securityProvider.isBiometricsAvailable) ...[
                              const Divider(height: 1, indent: 16),
                              ListTile(
                                leading: Icon(
                                  Icons.fingerprint_rounded,
                                  color: securityProvider.isBiometricEnabled
                                      ? theme.colorScheme.primary
                                      : Colors.grey,
                                ),
                                title: const Text('Empreinte / Face ID'),
                                subtitle: const Text(
                                  'Déverrouiller avec la biométrie',
                                ),
                                trailing: Switch(
                                  value: securityProvider.isBiometricEnabled,
                                  onChanged: (value) async {
                                    await securityProvider.setBiometricEnabled(
                                      value,
                                    );
                                  },
                                ),
                              ),
                            ],
                          ],
                        ],
                      );
                    },
                  ),

                  const SizedBox(height: 30),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSectionCard({
    String? title,
    IconData? icon,
    required ThemeData theme,
    required List<Widget> children,
    Widget? action,
  }) {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (title != null && icon != null) ...[
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 12),
              child: Row(
                children: [
                  Icon(icon, color: theme.colorScheme.primary),
                  const SizedBox(width: 8),
                  Text(
                    title,
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: theme.colorScheme.primary,
                    ),
                  ),
                  if (action != null) ...[const Spacer(), action],
                ],
              ),
            ),
            const Divider(height: 1),
          ],
          ...children,
        ],
      ),
    );
  }
}

class _SliverTabBarDelegate extends SliverPersistentHeaderDelegate {
  final TabBar tabBar;

  _SliverTabBarDelegate(this.tabBar);

  @override
  double get minExtent => tabBar.preferredSize.height;
  @override
  double get maxExtent => tabBar.preferredSize.height;

  @override
  Widget build(
    BuildContext context,
    double shrinkOffset,
    bool overlapsContent,
  ) {
    return Container(
      color: Theme.of(context).scaffoldBackgroundColor,
      child: tabBar,
    );
  }

  @override
  bool shouldRebuild(_SliverTabBarDelegate oldDelegate) {
    return false;
  }
}
