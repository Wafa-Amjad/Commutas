import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';

import 'dart:ui' as ui;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:dio/dio.dart';
import 'dart:math' as math;
import '../theme.dart';
import 'services/wallet_service.dart';
import 'services/notification_service.dart';

class HomeScreen extends StatefulWidget {
  final String studentName;
  final String studentRegNo;
  final String? password;
  final String? avatarPath;
  final String avatarType;

  const HomeScreen({
    super.key,
    required this.studentName,
    required this.studentRegNo,
    this.password,
    this.avatarPath,
    this.avatarType = 'emoji',
  });

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> with WidgetsBindingObserver, TickerProviderStateMixin {
  final WalletService _walletService = WalletService();
  double _walletBalance = 0.0;
  bool _isLoadingBalance = true;
  String? _accessToken;
  late final AnimationController _busAnimationController;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _loadTokenAndBalance();
    _busAnimationController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 4),
    )..repeat();
  }

  @override
  void dispose() {
    _busAnimationController.dispose();
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _checkPendingTransactions();
    }
  }

  Future<void> _checkPendingTransactions() async {
    if (_accessToken == null) return;
    final changed = await _walletService.checkPendingTransactions(_accessToken!, context);
    if (changed && mounted) {
      _fetchBalance();
    }
  }

  Future<void> _loadTokenAndBalance() async {
    final prefs = await SharedPreferences.getInstance();
    _accessToken = prefs.getString('session_token');
    if (_accessToken != null) {
      await _fetchBalance();
      // Proactively check status upon dashboard load in case a payment succeeded offline
      _checkPendingTransactions();
      
      // Auto-register device token for push notifications
      NotificationService().autoRegisterToken(_accessToken!);
    } else {
      if (mounted) {
        setState(() => _isLoadingBalance = false);
      }
    }
  }

  Future<void> _fetchBalance() async {
    if (_accessToken == null) return;
    final balance = await _walletService.fetchWalletBalance(token: _accessToken!);
    if (mounted) {
      setState(() {
        _walletBalance = balance;
        _isLoadingBalance = false;
      });
    }
  }

  void _showAddFundsSheet() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => _AddFundsSheet(
        studentRegNo: widget.studentRegNo,
        walletService: _walletService,
        onPaymentInitiated: () {
          // Refresh balance after returning from checkout
          _fetchBalance();
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: CommutasColors.backgroundGray,
      appBar: _buildAppBar(),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            _buildCombinedHeaderWalletCard(),
            const SizedBox(height: 16),
            _buildNfcPaymentCard(),
            _buildRoadDivider(),
            _buildQuickActions(),
            _buildRoadDivider(),
            _buildUpcomingBusCard(),
            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }

  PreferredSizeWidget _buildAppBar() {
    return AppBar(
      backgroundColor: Colors.white,
      elevation: 0,
      automaticallyImplyLeading: false,
      titleSpacing: 20,
      title: Row(
        children: [
          Image.asset(
            'assets/logo_theme_cropped.png',
            height: 24,
            errorBuilder: (_, __, ___) => const Icon(Icons.bus_alert, color: CommutasColors.emeraldGreen, size: 20),
          ),
          const SizedBox(width: 8),
          Text(
            'COMMUTAS',
            style: CommutasTextStyles.labelBold.copyWith(fontSize: 14, letterSpacing: 1),
          ),
        ],
      ),
      actions: [
        IconButton(
          icon: const Icon(Icons.notifications_outlined, color: CommutasColors.primaryNavy),
          onPressed: () {
            // Notification action placeholder
          },
        ),
        const SizedBox(width: 8),
      ],
    );
  }

  String _formatStudentName(String name) {
    final parts = name.trim().split(RegExp(r'\s+'));
    if (parts.isEmpty) return '';
    if (parts.length == 1) return parts[0];
    final firstName = parts[0];
    final lastPart = parts[parts.length - 1];
    if (lastPart.isEmpty) return firstName;
    return '$firstName ${lastPart[0]}.';
  }

  String _getGreeting() {
    final hour = DateTime.now().hour;
    if (hour < 12) return 'Good Morning';
    if (hour < 17) return 'Good Afternoon';
    return 'Good Evening';
  }

  String _getGreetingEmoji() {
    final hour = DateTime.now().hour;
    if (hour < 12) return ' ☀️';
    if (hour < 17) return ' 🌤️';
    return ' 🌙';
  }

  Widget _buildCombinedHeaderWalletCard() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(24),
      decoration: const BoxDecoration(
        color: CommutasColors.primaryNavy,
        borderRadius: BorderRadius.zero,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Expanded(
                child: Row(
                  children: [
                    Flexible(
                      child: Text.rich(
                        TextSpan(
                          children: [
                            TextSpan(
                              text: '${_getGreeting()}, ',
                              style: GoogleFonts.inter(
                                color: Colors.white70,
                                fontSize: 16,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                            TextSpan(
                              text: _formatStudentName(widget.studentName),
                              style: GoogleFonts.inter(
                                color: Colors.white,
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    Text(
                      _getGreetingEmoji(),
                      style: const TextStyle(fontSize: 16),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              const Icon(
                Icons.account_balance_wallet_outlined,
                color: CommutasColors.emeraldGreen,
                size: 32,
              ),
            ],
          ),
          const SizedBox(height: 24),
          Text(
            'Wallet Balance',
            style: CommutasTextStyles.bodySmall.copyWith(
              color: Colors.white60,
              fontSize: 12,
            ),
          ),
          const SizedBox(height: 8),
          RichText(
            text: TextSpan(
              children: [
                TextSpan(
                  text: 'Rs. ',
                  style: CommutasTextStyles.heading1.copyWith(
                    color: CommutasColors.emeraldGreen,
                    fontSize: 28,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                TextSpan(
                  text: _isLoadingBalance ? 'Loading...' : _walletBalance.toStringAsFixed(2),
                  style: CommutasTextStyles.heading1.copyWith(
                    color: Colors.white,
                    fontSize: 28,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),
          Row(
            children: [
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: _showAddFundsSheet,
                  icon: const Icon(Icons.add, size: 18, color: CommutasColors.emeraldGreen),
                  label: Text(
                    'Add Funds',
                    style: CommutasTextStyles.labelBold.copyWith(
                      color: CommutasColors.emeraldGreen,
                      fontSize: 14,
                    ),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.white,
                    foregroundColor: CommutasColors.emeraldGreen,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: const RoundedRectangleBorder(borderRadius: BorderRadius.zero),
                    elevation: 0,
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: OutlinedButton(
                  onPressed: () {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Please select the Wallet tab at the bottom to view your full history.')),
                    );
                  },
                  style: OutlinedButton.styleFrom(
                    foregroundColor: Colors.white,
                    side: const BorderSide(color: Colors.white, width: 1.5),
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: const RoundedRectangleBorder(borderRadius: BorderRadius.zero),
                  ),
                  child: Text(
                    'View Wallet',
                    style: CommutasTextStyles.labelBold.copyWith(
                      color: Colors.white,
                      fontSize: 14,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildNfcPaymentCard() {
    return Container(
      height: 140,
      decoration: CommutasShapes.cardDecoration,
      clipBehavior: Clip.hardEdge,
      child: Stack(
        children: [
          // 1. 3D Background animation stretching across the entire card
          Positioned.fill(
            child: AnimatedBuilder(
              animation: _busAnimationController,
              builder: (context, _) {
                return CustomPaint(
                  painter: _ThreeDBackgroundPainter(animationValue: _busAnimationController.value),
                );
              },
            ),
          ),
          
          // 2. Hand-drawn bus translating across the entire card width
          Positioned.fill(
            child: AnimatedBuilder(
              animation: _busAnimationController,
              builder: (context, _) {
                return LayoutBuilder(
                  builder: (context, constraints) {
                    final double busWidth = 100;
                    final double busHeight = 60;
                    
                    final double totalDistance = constraints.maxWidth + busWidth;
                    final double leftPos = constraints.maxWidth - (_busAnimationController.value * totalDistance);
                    final double topPos = constraints.maxHeight * 0.42;
                    
                    return Stack(
                      children: [
                        Positioned(
                          left: leftPos,
                          top: topPos,
                          width: busWidth,
                          height: busHeight,
                          child: CustomPaint(
                            painter: TopUpBusPainter(animationValue: _busAnimationController.value),
                          ),
                        ),
                      ],
                    );
                  },
                );
              },
            ),
          ),
          
          // 3. Foreground Text & Content
          Positioned.fill(
            child: Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    Colors.white.withOpacity(0.92),
                    Colors.white.withOpacity(0.40),
                  ],
                  begin: Alignment.centerLeft,
                  end: Alignment.centerRight,
                ),
              ),
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          'Tap To Pay',
                          style: CommutasTextStyles.heading2.copyWith(color: CommutasColors.primaryNavy),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'Hold your phone\nnear the reader',
                          style: CommutasTextStyles.bodySmall.copyWith(
                            color: CommutasColors.navyInk.withOpacity(0.75),
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                        const SizedBox(height: 8),
                        const Icon(
                          Icons.contactless,
                          color: CommutasColors.emeraldGreen,
                          size: 28,
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildQuickActions() {
    final List<Map<String, dynamic>> items = [
      {'icon': Icons.add_card_rounded, 'label': 'Top Up', 'action': _showAddFundsSheet},
      {
        'icon': Icons.receipt_long_rounded,
        'label': 'Transactions',
        'action': () {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Please select the Wallet tab at the bottom to view transactions.')),
          );
        }
      },
      {
        'icon': Icons.directions_bus_rounded,
        'label': 'My Trips',
        'action': () {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('My Trips is currently under development.')),
          );
        }
      },
      {
        'icon': Icons.credit_card_rounded,
        'label': 'Bus Passes',
        'action': () {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Bus Passes is currently under development.')),
          );
        }
      },
      {
        'icon': Icons.map_rounded,
        'label': 'Routes',
        'action': () {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Please select the Schedule tab at the bottom to view routes.')),
          );
        }
      },
      {
        'icon': Icons.support_agent_rounded,
        'label': 'Support',
        'action': () {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Support is currently under development.')),
          );
        }
      },
      {
        'icon': Icons.campaign_rounded,
        'label': 'Announcements',
        'action': () {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Announcements is currently under development.')),
          );
        }
      },
      {
        'icon': Icons.more_horiz_rounded,
        'label': 'More',
        'action': () {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('More options are currently under development.')),
          );
        }
      },
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(left: 4, bottom: 12),
          child: Text(
            'Quick Actions',
            style: CommutasTextStyles.heading2.copyWith(fontSize: 16),
          ),
        ),
        SizedBox(
          height: 90,
          child: ListView.builder(
            scrollDirection: Axis.horizontal,
            itemCount: items.length,
            itemBuilder: (context, index) {
              final item = items[index];
              return Padding(
                padding: EdgeInsets.only(
                  left: index == 0 ? 0 : 8,
                  right: index == items.length - 1 ? 0 : 8,
                ),
                child: GestureDetector(
                  onTap: item['action'] as VoidCallback,
                  child: Container(
                    width: 90,
                    decoration: CommutasShapes.cardDecoration,
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          item['icon'] as IconData,
                          color: CommutasColors.primaryNavy,
                          size: 24,
                        ),
                        const SizedBox(height: 8),
                        Text(
                          item['label'] as String,
                          style: CommutasTextStyles.labelBold.copyWith(fontSize: 10, fontWeight: FontWeight.w600),
                          textAlign: TextAlign.center,
                        ),
                      ],
                    ),
                  ),
                ),
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _buildUpcomingBusCard() {
    final now = DateTime.now();
    final hour = now.hour;
    final minute = now.minute;
    final double timeInDouble = hour + minute / 60.0;

    String nextTripRoute;
    String nextTripPath;
    String nextTripTime;
    String leavesInText;
    int seatsLeft = 28;
    int totalSeats = 50;

    if (timeInDouble < 8.0) {
      nextTripRoute = 'Route 01';
      nextTripPath = 'Main Campus → Dhamtor Campus';
      nextTripTime = '8:00 AM';
      final diffMin = (8 * 60) - (hour * 60 + minute);
      leavesInText = 'Leaves in $diffMin min';
    } else if (timeInDouble < 13.5) {
      nextTripRoute = 'Route 01';
      nextTripPath = 'Dhamtor Campus → Main Campus';
      nextTripTime = '1:30 PM';
      final diffMin = (13.5 * 60).toInt() - (hour * 60 + minute);
      if (diffMin > 60) {
        final diffHours = diffMin ~/ 60;
        final remainingMins = diffMin % 60;
        leavesInText = 'Leaves in ${diffHours}h ${remainingMins}m';
      } else {
        leavesInText = 'Leaves in $diffMin min';
      }
    } else if (timeInDouble < 16.5) {
      nextTripRoute = 'Route 02';
      nextTripPath = 'Dhamtor Campus → Main Campus';
      nextTripTime = '4:30 PM';
      final diffMin = (16.5 * 60).toInt() - (hour * 60 + minute);
      if (diffMin > 60) {
        final diffHours = diffMin ~/ 60;
        final remainingMins = diffMin % 60;
        leavesInText = 'Leaves in ${diffHours}h ${remainingMins}m';
      } else {
        leavesInText = 'Leaves in $diffMin min';
      }
    } else {
      nextTripRoute = 'Route 01';
      nextTripPath = 'Main Campus → Dhamtor Campus';
      nextTripTime = '8:00 AM';
      final diffMin = ((24 + 8) * 60) - (hour * 60 + minute);
      final diffHours = diffMin ~/ 60;
      final remainingMins = diffMin % 60;
      leavesInText = 'Leaves in ${diffHours}h ${remainingMins}m (Tomorrow)';
    }

    final double occupancyRatio = seatsLeft / totalSeats;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(left: 4, bottom: 12),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Upcoming Bus',
                style: CommutasTextStyles.heading2.copyWith(fontSize: 16),
              ),
              Text(
                leavesInText,
                style: CommutasTextStyles.labelBold.copyWith(
                  color: CommutasColors.emeraldGreen,
                  fontSize: 12,
                ),
              ),
            ],
          ),
        ),
        Container(
          padding: const EdgeInsets.all(16),
          decoration: CommutasShapes.cardDecoration,
          child: Column(
            children: [
              Row(
                children: [
                  Container(
                    width: 44,
                    height: 44,
                    decoration: BoxDecoration(
                      color: CommutasColors.backgroundGray,
                      border: Border.all(color: CommutasColors.lineBorder, width: 1),
                      borderRadius: BorderRadius.zero,
                    ),
                    child: const Icon(
                      Icons.directions_bus_outlined,
                      color: CommutasColors.primaryNavy,
                      size: 22,
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          nextTripRoute,
                          style: CommutasTextStyles.labelBold.copyWith(fontSize: 16),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          nextTripPath,
                          style: CommutasTextStyles.bodySmall,
                        ),
                      ],
                    ),
                  ),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text(
                        nextTripTime,
                        style: CommutasTextStyles.labelBold.copyWith(fontSize: 14),
                      ),
                      const SizedBox(height: 4),
                      const Text(
                        'Scheduled',
                        style: TextStyle(
                          fontSize: 10,
                          color: CommutasColors.slateMuted,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
              const SizedBox(height: 16),
              const Divider(height: 1, color: CommutasColors.lineBorder),
              const SizedBox(height: 16),
              Row(
                children: [
                  const Icon(
                    Icons.people_outline,
                    color: CommutasColors.slateMuted,
                    size: 16,
                  ),
                  const SizedBox(width: 6),
                  Text(
                    '$seatsLeft / $totalSeats seats left',
                    style: CommutasTextStyles.bodySmall.copyWith(
                      color: CommutasColors.slateMuted,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: ClipRRect(
                      borderRadius: BorderRadius.zero,
                      child: LinearProgressIndicator(
                        value: occupancyRatio,
                        backgroundColor: CommutasColors.lineBorder,
                        valueColor: const AlwaysStoppedAnimation<Color>(
                          CommutasColors.emeraldGreen,
                        ),
                        minHeight: 6,
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  const Icon(
                    Icons.chevron_right,
                    color: CommutasColors.slateMuted,
                    size: 20,
                  ),
                ],
              ),
            ],
          ),
        ),
      ],
    );
  }



  Widget _buildRoadDivider() {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 12),
      child: SizedBox(
        height: 12,
        width: double.infinity,
        child: const CustomPaint(
          painter: _RoadDividerPainter(),
        ),
      ),
    );
  }
}

// ──────────────────────────────────────────────────────────
// Add Funds Bottom Sheet
// ──────────────────────────────────────────────────────────
class _AddFundsSheet extends StatefulWidget {
  final String studentRegNo;
  final WalletService walletService;
  final VoidCallback onPaymentInitiated;

  const _AddFundsSheet({
    required this.studentRegNo,
    required this.walletService,
    required this.onPaymentInitiated,
  });

  @override
  State<_AddFundsSheet> createState() => _AddFundsSheetState();
}

class _AddFundsSheetState extends State<_AddFundsSheet> with TickerProviderStateMixin {
  final TextEditingController _amountController = TextEditingController();
  bool _isProcessing = false;
  String? _error;
  late final AnimationController _busController;

  final List<int> _quickAmounts = [100, 200, 500, 1000];
  int? _selectedAmount;

  @override
  void initState() {
    super.initState();
    _busController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 3),
    );
  }

  @override
  void dispose() {
    _amountController.dispose();
    _busController.dispose();
    super.dispose();
  }

  void _selectQuickAmount(int amount) {
    _amountController.text = amount.toString();
    setState(() {
      _error = null;
      _selectedAmount = amount;
    });
  }

  Future<void> _initiatePayment() async {
    final amountText = _amountController.text.trim();
    if (amountText.isEmpty) {
      setState(() => _error = 'Enter an amount');
      return;
    }

    final amount = double.tryParse(amountText);
    if (amount == null || amount < 10) {
      setState(() => _error = 'Minimum top-up amount is Rs. 10');
      return;
    }
    if (amount > 10000) {
      setState(() => _error = 'Maximum top-up amount is Rs. 10,000');
      return;
    }

    setState(() {
      _isProcessing = true;
      _error = null;
    });
    _busController.repeat();

    try {
      final response = await widget.walletService.initiateTopUp(
        regNo: widget.studentRegNo,
        amount: amount,
      );

      if (response != null && response['checkout_url'] != null) {
        final url = Uri.parse(response['checkout_url']);
        bool launched = false;
        try {
          launched = await launchUrl(url, mode: LaunchMode.externalApplication);
        } catch (e) {
          debugPrint('launchUrl externalApplication error: $e');
        }

        if (!launched) {
          try {
            launched = await launchUrl(url, mode: LaunchMode.platformDefault);
          } catch (e) {
            debugPrint('launchUrl platformDefault error: $e');
          }
        }

        if (launched) {
          // Track this transaction ID for status updates in background/app resume
          if (response['transaction_id'] != null) {
            await widget.walletService.trackPendingTransaction(
              response['transaction_id'].toString(),
              amount,
            );
          }
          widget.onPaymentInitiated();
          if (mounted) Navigator.pop(context);
        } else {
          setState(() {
            _isProcessing = false;
            _error = 'Could not open payment browser. Direct checkout URL: ${response['checkout_url']}';
          });
          _busController.stop();
        }
      } else {
        setState(() {
          _isProcessing = false;
          _error = 'Failed to initialize payment. Try again.';
        });
        _busController.stop();
      }
    } on DioException catch (e) {
      final detail = e.response?.data?['detail'];
      setState(() {
        _isProcessing = false;
        _error = detail?.toString() ?? 'Payment initiation failed. Check your connection.';
      });
      _busController.stop();
    } catch (e) {
      setState(() {
        _isProcessing = false;
        _error = 'An unexpected error occurred.';
      });
      _busController.stop();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        border: Border(top: BorderSide(color: CommutasColors.lineBorder, width: 1)),
      ),
      padding: EdgeInsets.only(
        left: 24,
        right: 24,
        top: 24,
        bottom: MediaQuery.of(context).viewInsets.bottom + 24,
      ),
      child: _isProcessing ? _buildProcessingView() : _buildFormView(),
    );
  }

  Widget _buildFormView() {
    return SingleChildScrollView(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Header
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'ADD FUNDS',
                style: CommutasTextStyles.labelBold.copyWith(fontSize: 13, letterSpacing: 1.5),
              ),
              GestureDetector(
                onTap: () => Navigator.pop(context),
                child: const Icon(Icons.close, color: CommutasColors.slateMuted, size: 20),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            'Top up your transit wallet via Safepay',
            style: CommutasTextStyles.bodySmall,
          ),
          const SizedBox(height: 24),

          // Amount Input
          TextField(
            controller: _amountController,
            keyboardType: TextInputType.number,
            inputFormatters: [
              FilteringTextInputFormatter.digitsOnly,
            ],
            style: CommutasTextStyles.heading1.copyWith(fontSize: 28),
            decoration: InputDecoration(
              prefixText: 'Rs. ',
              prefixStyle: CommutasTextStyles.heading1.copyWith(fontSize: 28, color: CommutasColors.slateMuted),
              hintText: '0',
              hintStyle: CommutasTextStyles.heading1.copyWith(fontSize: 28, color: CommutasColors.lineBorder),
              border: CommutasShapes.inputBorder,
              enabledBorder: CommutasShapes.inputBorder,
              focusedBorder: CommutasShapes.inputFocusBorder,
              errorBorder: CommutasShapes.inputErrorBorder,
              contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
            ),
            onChanged: (val) {
              final parsed = int.tryParse(val);
              
              if (parsed != null && parsed > 10000) {
                _amountController.text = '10000';
                _amountController.selection = TextSelection.fromPosition(
                  TextPosition(offset: _amountController.text.length),
                );
                setState(() {
                  _error = 'Maximum limit is Rs. 10,000';
                  _selectedAmount = 10000;
                });
                return;
              }
              
              setState(() {
                _error = null;
                if (parsed != null && _quickAmounts.contains(parsed)) {
                  _selectedAmount = parsed;
                } else {
                  _selectedAmount = null;
                }
              });
            },
          ),
          const SizedBox(height: 16),

          // Quick Select Buttons
          Row(
            children: _quickAmounts.map((amount) {
              return Expanded(
                child: Padding(
                  padding: EdgeInsets.only(right: amount != _quickAmounts.last ? 8.0 : 0),
                  child: OutlinedButton(
                    onPressed: () => _selectQuickAmount(amount),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: _selectedAmount == amount ? Colors.white : CommutasColors.primaryNavy,
                      backgroundColor: _selectedAmount == amount ? CommutasColors.emeraldGreen : Colors.transparent,
                      side: BorderSide(
                        color: _selectedAmount == amount ? CommutasColors.emeraldGreen : CommutasColors.lineBorder,
                      ),
                      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.zero),
                      padding: const EdgeInsets.symmetric(vertical: 12),
                    ),
                    child: Text('Rs. $amount', style: CommutasTextStyles.labelBold.copyWith(fontSize: 11)),
                  ),
                ),
              );
            }).toList(),
          ),
          const SizedBox(height: 24),

          // Error message
          if (_error != null) ...[
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: CommutasColors.danger.withOpacity(0.08),
                border: Border.all(color: CommutasColors.danger.withOpacity(0.3)),
                borderRadius: BorderRadius.zero,
              ),
              child: Row(
                children: [
                  const Icon(Icons.error_outline, color: CommutasColors.danger, size: 16),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      _error!,
                      style: CommutasTextStyles.bodySmall.copyWith(color: CommutasColors.danger),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
          ],

          // Proceed Button
          SizedBox(
            height: 48,
            child: TextButton(
              style: TextButton.styleFrom(
                backgroundColor: (_selectedAmount != null || (_amountController.text.isNotEmpty && double.tryParse(_amountController.text) != null && double.parse(_amountController.text) >= 10 && double.parse(_amountController.text) <= 10000))
                    ? CommutasColors.emeraldGreen
                    : CommutasColors.primaryNavy,
                shape: const RoundedRectangleBorder(borderRadius: BorderRadius.zero),
                padding: EdgeInsets.zero,
              ),
              onPressed: _initiatePayment,
              child: Text(
                'PROCEED TO PAYMENT',
                style: CommutasTextStyles.buttonLabel,
              ),
            ),
          ),
          const SizedBox(height: 12),
          Center(
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.lock_outline, size: 12, color: CommutasColors.slateMuted),
                const SizedBox(width: 4),
                Text(
                  'Secured by Safepay',
                  style: CommutasTextStyles.bodySmall.copyWith(fontSize: 10),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildProcessingView() {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        const SizedBox(height: 24),
        // Animated bouncing bus
        SizedBox(
          width: 120,
          height: 80,
          child: AnimatedBuilder(
            animation: _busController,
            builder: (context, child) {
              return CustomPaint(
                painter: TopUpBusPainter(animationValue: _busController.value),
              );
            },
          ),
        ),
        const SizedBox(height: 24),
        Text(
          'INITIALIZING PAYMENT',
          style: CommutasTextStyles.labelBold.copyWith(letterSpacing: 1.5),
        ),
        const SizedBox(height: 8),
        Text(
          'Connecting to Safepay gateway...',
          style: CommutasTextStyles.bodySmall,
        ),
        const SizedBox(height: 24),
        // Linear progress indicator
        Container(
          height: 3,
          color: CommutasColors.cobaltTint,
          child: const LinearProgressIndicator(
            backgroundColor: Color(0xFFEEF0FC),
            valueColor: AlwaysStoppedAnimation<Color>(CommutasColors.accentCobalt),
          ),
        ),
        const SizedBox(height: 24),
      ],
    );
  }
}

// ──────────────────────────────────────────────────────────
// Sketchy bouncing bus painter for the top-up loading state
// ──────────────────────────────────────────────────────────
class TopUpBusPainter extends CustomPainter {
  final double animationValue;

  TopUpBusPainter({required this.animationValue});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = CommutasColors.navyInk
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.0
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;

    final bounce = math.sin(animationValue * 2 * math.pi) * 2.0;

    final double top = 10.0 + bounce;
    final double bottom = size.height - 20.0 + bounce;
    final double left = 10.0;
    final double right = size.width - 10.0;

    // ──────────────────────────────────────────────────────────
    // Filled Details (so outlines are layered on top)
    // ──────────────────────────────────────────────────────────
    
    // 1. Solid white fill for the entire body so the bus is opaque and pops over the 3D grid
    final bodyBasePaint = Paint()
      ..color = Colors.white
      ..style = PaintingStyle.fill;
    canvas.drawRect(Rect.fromLTRB(left, top, right, bottom), bodyBasePaint);

    // 2. Light green/mint tint fill overlay for the bus body itself
    final fillPaint = Paint()
      ..color = CommutasColors.emeraldGreen.withOpacity(0.12)
      ..style = PaintingStyle.fill;
    canvas.drawRect(Rect.fromLTRB(left, top, right, bottom), fillPaint);

    // 3. Bright emerald green stripe on the side of the bus body
    final stripePaint = Paint()
      ..color = CommutasColors.emeraldGreen
      ..style = PaintingStyle.fill;
    canvas.drawRect(Rect.fromLTRB(left + 2, bottom - 14, right - 2, bottom - 8), stripePaint);

    // 4. Mint tint window fills
    final windowFillPaint = Paint()
      ..color = const Color(0xFFE8F5E9)
      ..style = PaintingStyle.fill;
    // Front windshield fill
    canvas.drawRect(Rect.fromLTRB(left + 8, top + 6, left + 24, top + 18), windowFillPaint);
    // Passenger windows fill
    for (int i = 0; i < 3; i++) {
      final double wx = left + 32.0 + i * 20.0;
      canvas.drawRect(Rect.fromLTWH(wx, top + 6, 14, 12), windowFillPaint);
    }

    // 5. Glowing Headlight Cone (Orange/Yellow Gradient)
    final lightConePaint = Paint()
      ..shader = ui.Gradient.linear(
        Offset(left, bottom - 10),
        Offset(left - 30, bottom - 10),
        [
          Colors.orangeAccent.withOpacity(0.45),
          Colors.orangeAccent.withOpacity(0.0),
        ],
      )
      ..style = PaintingStyle.fill;
    final lightPath = Path()
      ..moveTo(left, bottom - 10)
      ..lineTo(left - 30, bottom - 22)
      ..lineTo(left - 30, bottom + 2)
      ..close();
    canvas.drawPath(lightPath, lightConePaint);

    // ──────────────────────────────────────────────────────────
    // Outlines (on top of the fills)
    // ──────────────────────────────────────────────────────────

    // Body
    canvas.drawLine(Offset(left, top), Offset(right, top), paint);
    canvas.drawLine(Offset(right, top), Offset(right, bottom), paint);
    canvas.drawLine(Offset(left, bottom), Offset(right, bottom), paint);
    canvas.drawLine(Offset(left, top), Offset(left, bottom), paint);

    // Front windshield
    canvas.drawLine(Offset(left + 8, top + 6), Offset(left + 24, top + 6), paint);
    canvas.drawLine(Offset(left + 24, top + 6), Offset(left + 24, top + 18), paint);
    canvas.drawLine(Offset(left + 8, top + 18), Offset(left + 24, top + 18), paint);
    canvas.drawLine(Offset(left + 8, top + 6), Offset(left + 8, top + 18), paint);

    // Windows
    for (int i = 0; i < 3; i++) {
      final double wx = left + 32.0 + i * 20.0;
      canvas.drawRect(Rect.fromLTWH(wx, top + 6, 14, 12), paint);
    }

    // Headlights
    canvas.drawLine(Offset(left, bottom - 10), Offset(left - 4, bottom - 10), paint);
    final rayPaint = Paint()
      ..color = Colors.orangeAccent
      ..strokeWidth = 1.5;
    canvas.drawLine(Offset(left - 4, bottom - 10), Offset(left - 20, bottom - 14), rayPaint);
    canvas.drawLine(Offset(left - 4, bottom - 10), Offset(left - 20, bottom - 6), rayPaint);

    // Bumper
    canvas.drawLine(Offset(left - 4, bottom - 2), Offset(left + 4, bottom - 2), paint);
    canvas.drawLine(Offset(right - 4, bottom - 2), Offset(right + 4, bottom - 2), paint);

    // Wheels
    final double wheelRadius = 8.0;
    final double leftWheelX = left + 20.0;
    final double rightWheelX = right - 20.0;
    final double wheelY = bottom + 8.0 - bounce;

    // Wheel 1 (Front)
    final wheelFill = Paint()
      ..color = CommutasColors.primaryNavy
      ..style = PaintingStyle.fill;
    canvas.drawCircle(Offset(leftWheelX, wheelY), wheelRadius - 1.0, wheelFill);
    canvas.drawCircle(Offset(leftWheelX, wheelY), wheelRadius, paint);
    
    final angle = animationValue * 2 * math.pi;
    final spokePaint = Paint()
      ..color = Colors.white
      ..strokeWidth = 1.2;
    canvas.drawLine(
      Offset(leftWheelX, wheelY),
      Offset(leftWheelX + wheelRadius * math.cos(angle), wheelY + wheelRadius * math.sin(angle)),
      spokePaint,
    );
    canvas.drawLine(
      Offset(leftWheelX, wheelY),
      Offset(leftWheelX + wheelRadius * math.cos(angle + math.pi), wheelY + wheelRadius * math.sin(angle + math.pi)),
      spokePaint,
    );

    // Wheel 2 (Rear)
    canvas.drawCircle(Offset(rightWheelX, wheelY), wheelRadius - 1.0, wheelFill);
    canvas.drawCircle(Offset(rightWheelX, wheelY), wheelRadius, paint);
    canvas.drawLine(
      Offset(rightWheelX, wheelY),
      Offset(rightWheelX + wheelRadius * math.cos(angle), wheelY + wheelRadius * math.sin(angle)),
      spokePaint,
    );
    canvas.drawLine(
      Offset(rightWheelX, wheelY),
      Offset(rightWheelX + wheelRadius * math.cos(angle + math.pi), wheelY + wheelRadius * math.sin(angle + math.pi)),
      spokePaint,
    );

    // ──────────────────────────────────────────────────────────
    // Exhaust puffs trailing behind the bus (right/rear side)
    // ──────────────────────────────────────────────────────────
    final smokePaint = Paint()
      ..color = CommutasColors.slateMuted.withOpacity(0.25)
      ..style = PaintingStyle.fill;
    final smokeOutline = Paint()
      ..color = CommutasColors.slateMuted.withOpacity(0.45)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 0.8;

    final double exhaustX = right + 2;
    final double exhaustY = bottom - 4 + bounce;

    // Puff 1
    final double p1X = exhaustX + 8.0 + math.sin(animationValue * 3 * math.pi) * 2.0;
    final double p1Y = exhaustY - 4.0 - (animationValue * 10.0);
    final double p1R = 4.0 + (animationValue * 3.0);
    canvas.drawCircle(Offset(p1X, p1Y), p1R, smokePaint);
    canvas.drawCircle(Offset(p1X, p1Y), p1R, smokeOutline);

    // Puff 2
    final double p2Val = (animationValue + 0.5) % 1.0;
    final double p2X = exhaustX + 16.0 + math.cos(p2Val * 2 * math.pi) * 3.0;
    final double p2Y = exhaustY - 8.0 - (p2Val * 14.0);
    final double p2R = 3.5 + (p2Val * 4.0);
    canvas.drawCircle(Offset(p2X, p2Y), p2R, smokePaint);
    canvas.drawCircle(Offset(p2X, p2Y), p2R, smokeOutline);

    // Puff 3 (fading)
    final double p3Val = (animationValue + 0.25) % 1.0;
    final double p3X = exhaustX + 22.0 + math.sin(p3Val * 4 * math.pi) * 2.5;
    final double p3Y = exhaustY - 12.0 - (p3Val * 16.0);
    final double p3R = 3.0 + (p3Val * 5.0);
    final fadedSmoke = Paint()
      ..color = CommutasColors.slateMuted.withOpacity(0.12 * (1.0 - p3Val))
      ..style = PaintingStyle.fill;
    canvas.drawCircle(Offset(p3X, p3Y), p3R, fadedSmoke);
  }

  @override
  bool shouldRepaint(covariant TopUpBusPainter oldDelegate) {
    return oldDelegate.animationValue != animationValue;
  }
}

// ──────────────────────────────────────────────────────────
// 3D Perspective Road Grid Background Painter
// ──────────────────────────────────────────────────────────
class _ThreeDBackgroundPainter extends CustomPainter {
  final double animationValue;

  _ThreeDBackgroundPainter({required this.animationValue});

  @override
  void paint(Canvas canvas, Size size) {
    final double horizonY = size.height * 0.45;
    final double centerX = size.width / 2;

    // 1. Horizon glow (Green neon sky reflection)
    final glowPaint = Paint()
      ..shader = ui.Gradient.linear(
        Offset(0, horizonY - 25),
        Offset(0, horizonY + 15),
        [
          CommutasColors.emeraldGreen.withOpacity(0.0),
          CommutasColors.emeraldGreen.withOpacity(0.24),
          CommutasColors.emeraldGreen.withOpacity(0.0),
        ],
        const [0.0, 0.5, 1.0],
      );
    canvas.drawRect(Rect.fromLTWH(0, horizonY - 25, size.width, 40), glowPaint);

    final paint = Paint()
      ..color = CommutasColors.emeraldGreen.withOpacity(0.26)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.2
      ..strokeCap = StrokeCap.round;

    // Horizon line
    canvas.drawLine(Offset(0, horizonY), Offset(size.width, horizonY), paint);

    // Radiating perspective lines from horizon center to boundaries
    const int linesCount = 8;
    for (int i = 0; i <= linesCount; i++) {
      final double ratio = i / linesCount;
      final double targetX = ratio * size.width;
      canvas.drawLine(
        Offset(centerX, horizonY),
        Offset(targetX, size.height),
        paint,
      );
    }

    // Moving horizontal grid lines (perspective speed)
    const int gridLines = 5;
    for (int i = 0; i < gridLines; i++) {
      final double progress = (i + animationValue) / gridLines;
      final double ratio = progress % 1.0;
      final double y = horizonY + (size.height - horizonY) * math.pow(ratio, 1.8);
      
      final double widthRatio = ratio;
      final double leftX = centerX - (centerX * widthRatio);
      final double rightX = centerX + ((size.width - centerX) * widthRatio);
      
      canvas.drawLine(Offset(leftX, y), Offset(rightX, y), paint);
    }
  }

  @override
  bool shouldRepaint(covariant _ThreeDBackgroundPainter oldDelegate) {
    return oldDelegate.animationValue != animationValue;
  }
}

// ──────────────────────────────────────────────────────────
// Tiny hand-drawn bus icon for the Upcoming Bus card
// ──────────────────────────────────────────────────────────


// ──────────────────────────────────────────────────────────
// Hand-drawn sketchy dashed road center-line divider
// ──────────────────────────────────────────────────────────
class _RoadDividerPainter extends CustomPainter {
  const _RoadDividerPainter();

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = CommutasColors.lineBorder
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.8
      ..strokeCap = StrokeCap.round;

    final double y = size.height / 2;
    const double dashWidth = 14.0;
    const double gapWidth = 10.0;
    double x = 0;

    while (x < size.width) {
      // Slight vertical wobble for hand-drawn feel
      final double wobble = math.sin(x * 0.3) * 0.8;
      canvas.drawLine(
        Offset(x, y + wobble),
        Offset(math.min(x + dashWidth, size.width), y - wobble),
        paint,
      );
      x += dashWidth + gapWidth;
    }
  }

  @override
  bool shouldRepaint(covariant _RoadDividerPainter oldDelegate) => false;
}
