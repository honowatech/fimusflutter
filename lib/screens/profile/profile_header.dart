import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:monitrack/l10n/app_localizations.dart';
import '../../providers/auth_provider.dart';
import '../../providers/profile_provider.dart';
import 'dialogs/profile_identity_dialog.dart';

/// En-tête du profil : bandeau photo + identité, et action d'édition.
///
/// N'écoute que le nom affiché (`context.select`) au lieu de tout
/// [ProfileProvider] : un changement de pays, de devise ou de type de profil
/// ne reconstruit plus le bandeau.
class ProfileSliverAppBar extends StatelessWidget {
  const ProfileSliverAppBar({super.key});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final theme = Theme.of(context);
    final fullName = context.select<ProfileProvider, String>(
      (provider) =>
          '${provider.profile.firstName} ${provider.profile.lastName}',
    );

    return SliverAppBar(
      pinned: true,
      expandedHeight: 180.0, // Reduced height (was ~230 previously)
      backgroundColor: theme.colorScheme.primary,
      foregroundColor: theme.colorScheme.onPrimary,
      elevation: 0,
      actions: [
        IconButton(
          icon: const Icon(Icons.edit),
          onPressed: () => showEditNameDialog(context),
          tooltip: l10n.editProfileInfo,
        ),
      ],
      flexibleSpace: FlexibleSpaceBar(
        centerTitle: true,
        title: Text(
          fullName,
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
                    backgroundImage: (photoUrl != null && photoUrl.isNotEmpty)
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
    );
  }
}

/// Barre d'onglets épinglée sous l'en-tête (Mon compte / Paramètres).
class ProfileTabBarSliver extends StatelessWidget {
  const ProfileTabBarSliver({super.key, required this.controller});

  final TabController controller;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final theme = Theme.of(context);

    return SliverPersistentHeader(
      pinned: true,
      delegate: ProfileSliverTabBarDelegate(
        TabBar(
          controller: controller,
          labelColor: theme.colorScheme.primary,
          unselectedLabelColor: Colors.grey,
          indicatorColor: theme.colorScheme.primary,
          indicatorSize: TabBarIndicatorSize.tab,
          tabs: [
            Tab(
              icon: const Icon(Icons.person_outline_rounded),
              text: l10n.myAccount,
            ),
            Tab(
              icon: const Icon(Icons.settings_outlined),
              text: l10n.settings,
            ),
          ],
        ),
      ),
    );
  }
}

class ProfileSliverTabBarDelegate extends SliverPersistentHeaderDelegate {
  final TabBar tabBar;

  ProfileSliverTabBarDelegate(this.tabBar);

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
  bool shouldRebuild(ProfileSliverTabBarDelegate oldDelegate) {
    return false;
  }
}
