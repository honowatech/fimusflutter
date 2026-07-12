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
      UssdScreen(key: UssdScreen.globalKey),
      ExpenseScreen(),
      DebtScreen(),
      ProfileScreen(),
    ];

    return Scaffold(
      floatingActionButton: (_selectedIndex >= 1 && _selectedIndex <= 3)
          ? FloatingActionButton(
              onPressed: () {
                if (_selectedIndex == 1) {
                  UssdScreen.globalKey.currentState?.handleFabPress();
                } else if (_selectedIndex == 2) {
                  ExpenseScreen.globalKey.currentState?.handleFabPress();
                } else if (_selectedIndex == 3) {
                  DebtScreen.globalKey.currentState?.handleFabPress();
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
          const BottomNavigationBarItem(
            icon: Icon(Icons.home),
            label: 'Home',
          ),
          BottomNavigationBarItem(
            icon: const Icon(Icons.dialpad),
            label: l10n.ussdMenu,
          ),
          BottomNavigationBarItem(
            icon: const Icon(Icons.account_balance_wallet),
            label: l10n.expenses,
          ),
          BottomNavigationBarItem(
            icon: const Icon(Icons.compare_arrows),
            label: l10n.debtsAndReceivables,
          ),
          const BottomNavigationBarItem(
            icon: Icon(Icons.person),
            label: 'Profil',
          ),
        ],
        selectedItemColor: Theme.of(context).colorScheme.primary,
        unselectedItemColor: Colors.black,
        type: BottomNavigationBarType.fixed,
        showSelectedLabels: true,
        showUnselectedLabels: true,
      ),
    );
  }
}
