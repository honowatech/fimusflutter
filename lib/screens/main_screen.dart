import 'package:flutter/material.dart';
import 'package:monitrack/l10n/app_localizations.dart';
import 'home_screen.dart';
import 'profile_screen.dart';
import 'expense_screen.dart';
import 'ussd_screen.dart';
import 'debt_screen.dart';
import 'dart:async';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:provider/provider.dart';
import '../providers/auth_provider.dart';
import '../providers/notification_provider.dart';
import '../providers/notification_preferences_provider.dart';
import '../providers/profile_provider.dart';
import '../services/notification_permission_service.dart';
import '../services/notification_service.dart';
import '../services/alerts/local_alerts_hook.dart';
import 'notifications_screen.dart';
import 'products_screen.dart';
import 'staff_screen.dart';

class MainScreen extends StatefulWidget {
  static final GlobalKey<MainScreenState> globalKey = GlobalKey<MainScreenState>();

  MainScreen({Key? key}) : super(key: key ?? globalKey);

  static MainScreenState? of(BuildContext context) =>
      context.findAncestorStateOfType<MainScreenState>() ?? globalKey.currentState;

  @override
  State<MainScreen> createState() => MainScreenState();
}

class MainScreenState extends State<MainScreen> with WidgetsBindingObserver {
  int _selectedIndex = 0;
  late PageController _pageController;
  StreamSubscription<List<ConnectivityResult>>? _connectivitySubscription;

  @override
  void initState() {
    super.initState();
    _pageController = PageController(initialPage: _selectedIndex);
    WidgetsBinding.instance.addObserver(this);

    // Listen to connectivity changes to sync when connection is restored
    _connectivitySubscription = Connectivity().onConnectivityChanged.listen((List<ConnectivityResult> results) {
      if (!results.contains(ConnectivityResult.none)) {
        if (mounted) {
          context.read<AuthProvider>().syncNow(context);
        }
      }
    });

    WidgetsBinding.instance.addPostFrameCallback((_) async {
      NotificationService().syncFcmToken();
      if (mounted) {
        final permissionService = context.read<NotificationPermissionService>();
        try {
          // On se contente de relever l'état de la permission : la demande
          // elle-même est contextualisée (bandeau d'accueil et écran
          // Profil > Notifications). La relancer à chaque montage ne servait
          // à rien — le système ne réaffiche pas la boîte de dialogue une fois
          // la décision prise — et privait l'utilisateur de toute explication.
          await permissionService.checkPermission();
        } catch (e) {
          debugPrint('Error requesting notification permission: $e');
        }
      }
      if (mounted) {
        context.read<NotificationProvider>().fetch();
        context.read<NotificationPreferencesProvider>().fetchPreferences();
      }
      // Tap / action issus d'une notification (cold start, prefs, FCM).
      await NotificationService().consumePendingOnLaunch();
    });
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _connectivitySubscription?.cancel();
    _pageController.dispose();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    super.didChangeAppLifecycleState(state);
    if (state != AppLifecycleState.resumed) return;
    // Un bouton de notification (« Confirmer » / « Annuler ») appuyé pendant
    // que l'app était en tâche de fond est traité dans un isolat séparé, qui
    // ne peut que persister l'intention. On la relit à chaque reprise.
    // drain() ne fait rien tant que le verrou PIN n'est pas levé : si
    // _AuthGate réaffiche LockScreen, c'est LockScreen qui relancera le rejeu.
    NotificationService().consumePendingOnLaunch();
    // Rattrapage des alertes locales retenues pendant les heures calmes :
    // sans ce passage, une alerte différée n'apparaîtrait qu'à la prochaine
    // opération de l'utilisateur.
    runLocalAlerts(context);
  }

  void setSelectedIndex(int index) {
    setState(() {
      _selectedIndex = index;
    });
    if (_pageController.hasClients) {
      _pageController.animateToPage(
        index,
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOut,
      );
    }
  }

  void _onItemTapped(int index) {
    setSelectedIndex(index);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final profileProvider = Provider.of<ProfileProvider>(context);
    final profile = profileProvider.profile;

    final Widget specializedPage;
    final String specializedLabel;
    final IconData specializedIcon;

    if (profile.hasProducts) {
      specializedPage = ProductsScreen(key: ProductsScreen.globalKey);
      specializedLabel = l10n.navProducts;
      specializedIcon = Icons.storefront_rounded;
    } else if (profile.hasStaff) {
      specializedPage = StaffScreen(key: StaffScreen.globalKey);
      specializedLabel = l10n.navStaff;
      specializedIcon = Icons.badge_rounded;
    } else {
      specializedPage = UssdScreen(key: UssdScreen.globalKey);
      specializedLabel = l10n.ussdMenu;
      specializedIcon = Icons.dialpad;
    }

    final List<Widget> pages = [
      HomeScreen(),
      ExpenseScreen(),
      DebtScreen(),
      specializedPage,
      ProfileScreen(),
    ];

    return Scaffold(
      appBar: AppBar(
        backgroundColor: Theme.of(context).colorScheme.primary,
        foregroundColor: Theme.of(context).colorScheme.onPrimary,
        title: Text(
          _selectedIndex == 0
              ? l10n.home
              : _selectedIndex == 1
                  ? l10n.expenses
                  : _selectedIndex == 2
                      ? l10n.debtsAndReceivables
                      : _selectedIndex == 3
                          ? specializedLabel
                          : l10n.profile,
        ),
        actions: [
          Consumer<NotificationProvider>(
            builder: (context, notificationProvider, child) {
              return Stack(
                children: [
                  IconButton(
                    icon: const Icon(Icons.notifications),
                    onPressed: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(builder: (_) => const NotificationsScreen()),
                      );
                    },
                  ),
                  if (notificationProvider.unreadCount > 0)
                    Positioned(
                      right: 8,
                      top: 8,
                      child: Badge(
                        label: Text(
                          notificationProvider.unreadCount.toString(),
                          style: TextStyle(
                            color: Theme.of(context).colorScheme.onError,
                            fontSize: 10,
                          ),
                        ),
                        backgroundColor: Theme.of(context).colorScheme.error,
                      ),
                    ),
                ],
              );
            },
          ),
        ],
      ),
      floatingActionButton: (_selectedIndex >= 1 && _selectedIndex <= 3)
          ? FloatingActionButton(
              onPressed: () {
                if (_selectedIndex == 1) {
                  ExpenseScreen.globalKey.currentState?.handleFabPress();
                } else if (_selectedIndex == 2) {
                  DebtScreen.globalKey.currentState?.handleFabPress();
                } else if (_selectedIndex == 3) {
                  if (profile.hasProducts) {
                    ProductsScreen.globalKey.currentState?.handleFabPress();
                  } else if (profile.hasStaff) {
                    StaffScreen.globalKey.currentState?.handleFabPress();
                  } else {
                    UssdScreen.globalKey.currentState?.handleFabPress();
                  }
                }
              },
              child: Icon(Icons.add, color: Theme.of(context).colorScheme.primary, weight: 900, size: 28),
            )
          : null,
      body: PageView(
        controller: _pageController,
        onPageChanged: (index) {
          setState(() {
            _selectedIndex = index;
          });
        },
        children: pages,
      ),
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _selectedIndex.clamp(0, pages.length - 1),
        onTap: _onItemTapped,
        items: [
          BottomNavigationBarItem(
            icon: const Icon(Icons.home),
            label: l10n.home,
          ),
          BottomNavigationBarItem(
            icon: const Icon(Icons.account_balance_wallet),
            label: l10n.expenses,
          ),
          BottomNavigationBarItem(
            icon: const Icon(Icons.compare_arrows),
            label: l10n.debtsAndReceivables,
          ),
          BottomNavigationBarItem(
            icon: Icon(specializedIcon),
            label: specializedLabel,
          ),
          BottomNavigationBarItem(
            icon: const Icon(Icons.person),
            label: l10n.profile,
          ),
        ],
        selectedItemColor: Theme.of(context).colorScheme.primary,
        unselectedItemColor: Theme.of(context).colorScheme.onSurfaceVariant,
        type: BottomNavigationBarType.fixed,
        showSelectedLabels: true,
        showUnselectedLabels: true,
      ),
    );
  }
}
