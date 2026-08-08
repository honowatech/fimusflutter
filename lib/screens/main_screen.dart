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
import '../services/notification_permission_service.dart';
import '../services/notification_service.dart';
import 'notifications_screen.dart';

class MainScreen extends StatefulWidget {
  const MainScreen({super.key});

  static MainScreenState? of(BuildContext context) =>
      context.findAncestorStateOfType<MainScreenState>();

  @override
  State<MainScreen> createState() => MainScreenState();
}

class MainScreenState extends State<MainScreen> {
  int _selectedIndex = 0;
  late PageController _pageController;
  StreamSubscription<List<ConnectivityResult>>? _connectivitySubscription;

  @override
  void initState() {
    super.initState();
    _pageController = PageController(initialPage: _selectedIndex);

    // Listen to connectivity changes to sync when connection is restored
    _connectivitySubscription = Connectivity().onConnectivityChanged.listen((List<ConnectivityResult> results) {
      if (!results.contains(ConnectivityResult.none)) {
        if (mounted) {
          context.read<AuthProvider>().syncNow(context);
        }
      }
    });

    WidgetsBinding.instance.addPostFrameCallback((_) {
      NotificationService().syncFcmToken();
      if (mounted) {
        context.read<NotificationPermissionService>().checkPermission();
        context.read<NotificationProvider>().fetch();
        context.read<NotificationPreferencesProvider>().fetchPreferences();
      }
      if (NotificationService.pendingNotificationData != null) {
        final data = NotificationService.pendingNotificationData!;
        NotificationService.pendingNotificationData = null;
        NotificationService().handleNotificationData(data);
      }
    });
  }

  @override
  void dispose() {
    _connectivitySubscription?.cancel();
    _pageController.dispose();
    super.dispose();
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
    final List<Widget> pages = [
      HomeScreen(),
      ExpenseScreen(),
      DebtScreen(),
      UssdScreen(key: UssdScreen.globalKey),
      ProfileScreen(),
    ];

    return Scaffold(
      appBar: AppBar(
        backgroundColor: Theme.of(context).colorScheme.primary,
        foregroundColor: Colors.white,
        title: Text(
          _selectedIndex == 0
              ? l10n.home
              : _selectedIndex == 1
                  ? l10n.expenses
                  : _selectedIndex == 2
                      ? l10n.debtsAndReceivables
                      : _selectedIndex == 3
                          ? l10n.ussdMenu
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
                          style: const TextStyle(color: Colors.white, fontSize: 10),
                        ),
                        backgroundColor: Colors.red,
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
                  UssdScreen.globalKey.currentState?.handleFabPress();
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
            icon: const Icon(Icons.dialpad),
            label: l10n.ussdMenu,
          ),
          BottomNavigationBarItem(
            icon: const Icon(Icons.person),
            label: l10n.profile,
          ),
        ],
        selectedItemColor: Theme.of(context).colorScheme.primary,
        unselectedItemColor: Colors.grey.shade600,
        type: BottomNavigationBarType.fixed,
        showSelectedLabels: true,
        showUnselectedLabels: true,
      ),
    );
  }
}
