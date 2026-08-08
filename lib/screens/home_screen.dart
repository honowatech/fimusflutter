import 'dart:async';
import 'package:flutter/material.dart';
import 'package:monitrack/l10n/app_localizations.dart';
import 'main_screen.dart';
import 'expense_screen.dart';
import 'add_expense_screen.dart';
import 'add_debt_operation_screen.dart';
import 'debt_screen.dart';
import 'package:provider/provider.dart';
import '../models/announcement.dart';
import '../services/announcement_service.dart';
import '../utils/api_config.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import '../widgets/add_account_bottom_sheet.dart';
import '../services/notification_permission_service.dart';

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});


  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final theme = Theme.of(context);

    return Scaffold(
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Consumer<NotificationPermissionService>(
              builder: (context, permService, child) {
                if (permService.isGranted) return const SizedBox.shrink();
                return Container(
                  margin: const EdgeInsets.only(bottom: 16),
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.orange.shade50,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.orange.shade300),
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.warning_amber_rounded, color: Colors.orange.shade800),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          "Activez les notifications pour ne rien manquer.",
                          style: TextStyle(color: Colors.orange.shade900),
                        ),
                      ),
                      TextButton(
                        onPressed: () => permService.requestPermission(),
                        child: const Text('Activer'),
                      ),
                    ],
                  ),
                );
              },
            ),
            // Accès Direct
            Text(
              l10n.recentOperations,
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: _buildActionCard(
                    context,
                    title: l10n.addIncomeAction,
                    icon: Icons.attach_money_rounded,
                    iconColor: const Color(0xFF00C853),
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => const AddExpenseScreen(isIncome: true),
                        ),
                      );
                    },
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: _buildActionCard(
                    context,
                    title: l10n.addBorrowAction,
                    icon: Icons.download_rounded,
                    iconColor: const Color(0xFFFF9100),
                    onTap: () async {
                      final result = await Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => const AddDebtOperationScreen(initialIsIncome: true),
                        ),
                      );
                      if (result == true) {
                        MainScreen.of(context)?.setSelectedIndex(2);
                        DebtScreen.globalKey.currentState?.switchToHistoryTab();
                      }
                    },
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: _buildActionCard(
                    context,
                    title: l10n.addAccountAction,
                    icon: Icons.account_balance_wallet_rounded,
                    iconColor: const Color(0xFF00B0FF),
                    onTap: () {
                      AddAccountBottomSheet.show(context, onSuccess: () {
                        // Redirect to Accounts tab
                        MainScreen.of(context)?.setSelectedIndex(1); // 1 is ExpenseScreen
                        ExpenseScreen.navigateToTab(2); // 2 is Accounts tab
                      });
                    },
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: _buildActionCard(
                    context,
                    title: l10n.ussdMenu,
                    icon: Icons.dialpad_rounded,
                    iconColor: const Color(0xFF7C4DFF),
                    onTap: () {
                      MainScreen.of(context)?.setSelectedIndex(3);
                    },
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: _buildActionCard(
                    context,
                    title: l10n.addExpenseAction,
                    icon: Icons.money_off_rounded,
                    iconColor: const Color(0xFFFF5274),
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => const AddExpenseScreen(isIncome: false),
                        ),
                      );
                    },
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: _buildActionCard(
                    context,
                    title: l10n.addLendAction,
                    icon: Icons.upload_rounded,
                    iconColor: const Color(0xFF651FFF),
                    onTap: () async {
                      final result = await Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => const AddDebtOperationScreen(initialIsIncome: false),
                        ),
                      );
                      if (result == true) {
                        MainScreen.of(context)?.setSelectedIndex(2);
                        DebtScreen.globalKey.currentState?.switchToHistoryTab();
                      }
                    },
                  ),
                ),
              ],
            ),
            
            const SizedBox(height: 32),
            
            // Annonces
            Text(
              'Annonces',
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            const AnnouncementCarousel(),
          ],
        ),
      ),
    );
  }

  Widget _buildActionCard(
    BuildContext context, {
    required String title,
    required IconData icon,
    required Color iconColor,
    required VoidCallback onTap,
  }) {
    final theme = Theme.of(context);
    return Container(
      decoration: BoxDecoration(
        color: iconColor,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 12,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(20),
        child: Container(
          margin: const EdgeInsets.only(bottom: 4), // Bottom border effect
          decoration: BoxDecoration(
            color: theme.colorScheme.surface,
            borderRadius: const BorderRadius.only(
              topLeft: Radius.circular(20),
              topRight: Radius.circular(20),
              bottomLeft: Radius.circular(16),
              bottomRight: Radius.circular(16),
            ),
          ),
          child: Material(
            color: Colors.transparent,
            child: InkWell(
              onTap: onTap,
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 14.0, horizontal: 6.0),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Icon Container
                    Container(
                      width: 42,
                      height: 42,
                      decoration: BoxDecoration(
                        color: iconColor.withValues(alpha: 0.12),
                        shape: BoxShape.circle,
                      ),
                      child: Icon(
                        icon,
                        color: iconColor,
                        size: 20,
                      ),
                    ),
                    const SizedBox(height: 10),
                    // Title
                    Text(
                      title,
                      textAlign: TextAlign.center,
                      style: theme.textTheme.bodyMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                        fontSize: 13.44,
                        color: theme.colorScheme.onSurface,
                      ),
                    ),
                    const SizedBox(height: 10),
                    // Arrow button
                    Container(
                      width: 24,
                      height: 24,
                      decoration: BoxDecoration(
                        color: iconColor.withValues(alpha: 0.1),
                        shape: BoxShape.circle,
                      ),
                      child: Icon(
                        Icons.arrow_forward_rounded,
                        color: iconColor,
                        size: 12,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class AnnouncementCarousel extends StatefulWidget {
  const AnnouncementCarousel({super.key});

  @override
  State<AnnouncementCarousel> createState() => _AnnouncementCarouselState();
}

class _AnnouncementCarouselState extends State<AnnouncementCarousel> {
  final PageController _pageController = PageController();
  int _currentPage = 0;
  Timer? _timer;
  Timer? _refreshTimer;
  StreamSubscription<List<ConnectivityResult>>? _connectivitySubscription;

  AnnouncementConfig? _config;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadInitialData();

    // Listen for connectivity changes
    _connectivitySubscription = Connectivity().onConnectivityChanged.listen((List<ConnectivityResult> results) {
      if (!results.contains(ConnectivityResult.none)) {
        _fetchAnnouncementConfig(isRefresh: true);
      }
    });

    // Refresh periodically (e.g. every 5 minutes)
    _refreshTimer = Timer.periodic(const Duration(minutes: 5), (_) {
      _fetchAnnouncementConfig(isRefresh: true);
    });
  }

  Future<void> _loadInitialData() async {
    final cached = await AnnouncementService().getCachedAnnouncementConfig();
    if (mounted && cached != null) {
      setState(() {
        _config = cached;
        _isLoading = false;
      });
      _startTimer();
    }
    _fetchAnnouncementConfig(isRefresh: cached != null);
  }

  Future<void> _fetchAnnouncementConfig({bool isRefresh = false}) async {
    try {
      final config = await AnnouncementService().getAnnouncementConfig();
      if (mounted) {
        setState(() {
          _config = config;
          _isLoading = false;
        });
        _startTimer();
      }
    } catch (e) {
      if (mounted && !isRefresh) {
        setState(() {
          _isLoading = false;
        });
      }
      debugPrint('Error fetching announcements: $e');
      // If error, start timer with default slides count (3)
      if (!isRefresh && _config == null) {
        _startTimer();
      }
    }
  }

  void _startTimer() {
    _timer?.cancel();
    final slidesCount = _config?.slides.length ?? 3; // Fallback to 3 if config is null
    if (slidesCount <= 1) return;

    final durationSeconds = _config?.slideDuration ?? 4; // Fallback to 4 if config is null
    _timer = Timer.periodic(Duration(seconds: durationSeconds), (timer) {
      if (_pageController.hasClients) {
        int nextPage = _currentPage + 1;
        if (nextPage >= slidesCount) {
          nextPage = 0;
        }
        _pageController.animateToPage(
          nextPage,
          duration: const Duration(milliseconds: 350),
          curve: Curves.easeInOut,
        );
      }
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    _refreshTimer?.cancel();
    _connectivitySubscription?.cancel();
    _pageController.dispose();
    super.dispose();
  }

  List<Color> _getFallbackGradient(int index) {
    switch (index % 3) {
      case 0:
        return [Colors.deepPurple, Colors.purpleAccent];
      case 1:
        return [Colors.orange, Colors.deepOrange];
      case 2:
      default:
        return [Colors.teal, Colors.green];
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    if (_isLoading) {
      return const SizedBox(
        height: 220,
        child: Center(
          child: CircularProgressIndicator(),
        ),
      );
    }

    final List<AnnouncementSlide> slides = _config?.slides ?? [
      AnnouncementSlide(
        text: 'Configurez vos codes USSD préférés pour exécuter vos transactions en un seul clic !',
      ),
      AnnouncementSlide(
        text: 'Vous pouvez désormais ajouter ou supprimer vos opérateurs USSD personnalisés en toute simplicité.',
      ),
      AnnouncementSlide(
        text: 'Suivi de budget : Suivez vos dépenses quotidiennes et maîtrisez votre budget grâce à nos rapports détaillés.',
      ),
    ];

    if (slides.isEmpty) {
      return const SizedBox.shrink(); // Hide the carousel if no slides configured
    }

    return Column(
      children: [
        SizedBox(
          height: 220,
          child: PageView.builder(
            controller: _pageController,
            onPageChanged: (int page) {
              setState(() {
                _currentPage = page;
              });
            },
            itemCount: slides.length,
            itemBuilder: (context, index) {
              final slide = slides[index];
              return Card(
                clipBehavior: Clip.antiAlias,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
                elevation: 4,
                margin: const EdgeInsets.symmetric(horizontal: 4, vertical: 8),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Expanded(
                      child: (slide.imagePath != null && slide.imagePath!.isNotEmpty)
                          ? Image.network(
                              '${ApiConfig.storageUrl}/${slide.imagePath}',
                              fit: BoxFit.cover,
                              errorBuilder: (context, error, stackTrace) => Container(
                                decoration: BoxDecoration(
                                  gradient: LinearGradient(
                                    colors: _getFallbackGradient(index),
                                    begin: Alignment.topLeft,
                                    end: Alignment.bottomRight,
                                  ),
                                ),
                                child: const Center(
                                  child: Icon(
                                    Icons.campaign_outlined,
                                    size: 48,
                                    color: Colors.white,
                                  ),
                                ),
                              ),
                            )
                          : Container(
                              decoration: BoxDecoration(
                                gradient: LinearGradient(
                                  colors: _getFallbackGradient(index),
                                  begin: Alignment.topLeft,
                                  end: Alignment.bottomRight,
                                ),
                              ),
                              child: const Center(
                                child: Icon(
                                  Icons.campaign_outlined,
                                  size: 48,
                                  color: Colors.white,
                                ),
                              ),
                            ),
                    ),
                    Padding(
                      padding: const EdgeInsets.all(12.0),
                      child: Text(
                        slide.text,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: theme.textTheme.bodyMedium?.copyWith(
                          color: Colors.grey[800],
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ],
                ),
              );
            },
          ),
        ),
        const SizedBox(height: 8),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: List.generate(
            slides.length,
            (index) => AnimatedContainer(
              duration: const Duration(milliseconds: 300),
              margin: const EdgeInsets.symmetric(horizontal: 4),
              width: _currentPage == index ? 24 : 8,
              height: 8,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(4),
                color: _currentPage == index
                    ? theme.colorScheme.primary
                    : theme.colorScheme.primary.withValues(alpha: 0.3),
              ),
            ),
          ),
        ),
      ],
    );
  }
}
