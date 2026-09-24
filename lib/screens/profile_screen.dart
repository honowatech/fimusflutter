import 'package:flutter/material.dart';

import 'profile/profile_account_section.dart';
import 'profile/profile_dev_section.dart';
import 'profile/profile_header.dart';
import 'profile/profile_notifications_section.dart';
import 'profile/profile_operators_section.dart';
import 'profile/profile_preferences_section.dart';
import 'profile/profile_security_section.dart';
import 'profile/profile_type_section.dart';

/// Écran « Profil » : coquille d'assemblage des sections.
///
/// Le contenu est découpé dans `lib/screens/profile/` :
/// - en-tête et identité : `profile_header.dart` (+ `dialogs/profile_identity_dialog.dart`)
/// - compte, synchronisation, multicompte : `profile_account_section.dart`
/// - opérateurs : `profile_operators_section.dart`
/// - préférences (langue, pays, devise, apparence) : `profile_preferences_section.dart`
/// - type de profil : `profile_type_section.dart`
/// - notifications : `profile_notifications_section.dart`
/// - sécurité (PIN, biométrie) : `profile_security_section.dart`
/// - environnement de développement : `profile_dev_section.dart`
///
/// Chaque section écoute elle-même les providers dont elle dépend : plus
/// aucun `Provider.of` large en tête de `build`.
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: NestedScrollView(
        headerSliverBuilder: (context, innerBoxIsScrolled) {
          return [
            const ProfileSliverAppBar(),
            ProfileTabBarSliver(controller: _tabController),
          ];
        },
        body: TabBarView(
          controller: _tabController,
          children: [
            // Onglet « Mon compte »
            SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 16.0),
              child: Column(
                key: const ValueKey('mon_compte_tab'),
                children: const [
                  ProfileAccountSection(),
                  SizedBox(height: 16),
                  ProfileOperatorsSection(),
                  SizedBox(height: 30),
                ],
              ),
            ),
            // Onglet « Paramètres »
            SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 16.0),
              child: Column(
                key: const ValueKey('parametres_tab'),
                children: const [
                  ProfilePreferencesSection(),
                  SizedBox(height: 16),
                  ProfileTypeSection(),
                  SizedBox(height: 16),
                  ProfileNotificationsSection(),
                  SizedBox(height: 16),
                  ProfileSecuritySection(),
                  ProfileDevEnvironmentSection(),
                  SizedBox(height: 30),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
