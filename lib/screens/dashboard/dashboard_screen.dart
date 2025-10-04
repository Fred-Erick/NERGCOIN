import 'dart:async';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../base_scaffold.dart';
import '../../services/mining_service.dart';
import '../../services/wallet_service.dart';

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({Key? key}) : super(key: key);

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen>
    with SingleTickerProviderStateMixin {
  late AnimationController _coinController;
  late Animation<double> _pulseAnimation;

  // Color scheme
  final Color _primaryColor = const Color(0xFF6C5CE7);
  final Color _secondaryColor = const Color(0xFF00B894);
  final Color _accentColor = const Color(0xFFFD79A8);
  final Color _darkBackground = const Color(0xFF1E1E2D);
  final Color _lightBackground = const Color(0xFF2D2D44);
  final Color _successColor = const Color(0xFF00E676);
  final Color _errorColor = const Color(0xFFFF5252);
  final Color _referralColor = const Color(0xFFFFA500);

  @override
  void initState() {
    super.initState();
    _coinController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 3),
    );
    _pulseAnimation = Tween<double>(begin: 1.0, end: 1.1).animate(
      CurvedAnimation(parent: _coinController, curve: Curves.easeInOut),
    );
    _precacheImages();
  }

  void _precacheImages() {
    final user = FirebaseAuth.instance.currentUser;
    if (user?.photoURL != null) {
      precacheImage(NetworkImage(user!.photoURL!), context);
    }
  }

  @override
  void dispose() {
    _coinController.dispose();
    super.dispose();
  }



  @override
  Widget build(BuildContext context) {
    final currentUser = Provider.of<User?>(context);
    final userId = currentUser?.uid;

    if (userId == null) {
      return BaseScaffold(
        context: context,
        currentIndex: 0,
        child: const Center(child: CircularProgressIndicator()),
      );
    }

    // Change listen: false to listen: true for MiningService
    final miningService = Provider.of<MiningService>(context, listen: true);
    final walletService = Provider.of<WalletService>(context, listen: false);

    return BaseScaffold(
      context: context,
      currentIndex: 0,
      child: RefreshIndicator(
        onRefresh: _refreshData,
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          child: StreamBuilder<DocumentSnapshot>(
            stream: miningService.miningSessionStream(userId).handleError((e) {
              debugPrint("Mining stream error: $e");
              return Stream.empty();
            }),
            builder: (context, miningSnapshot) {
              // Process snapshot data first
              final miningData = miningSnapshot.hasData && miningSnapshot.data!.exists
                  ? miningSnapshot.data!.data() as Map<String, dynamic>
                  : null;

              // Use the current state from miningService for UI rendering
              final isMining = miningService.isMining(userId);
              final currentMinedAmount = miningService.currentMinedAmount(userId);
              final lastMinedTime = miningService.lastMinedTime(userId);
              final lastError = miningService.lastError(userId);

              // Control animation based on mining status and remaining time
              if (isMining) {
                if (!_coinController.isAnimating) {
                  _coinController.repeat();
                }
              } else {
                if (_coinController.isAnimating) {
                  _coinController.stop();
                  _coinController.reset();
                }
              }

              // Schedule state updates after build
              WidgetsBinding.instance.addPostFrameCallback((_) {
                if (miningData != null) {
                  miningService.updateMiningStateFromFirestore(userId, miningData);
                } else if (miningSnapshot.connectionState == ConnectionState.active &&
                    !miningSnapshot.hasData) {
                  if (miningService.isMining(userId)) {
                    miningService.stopMining(userId);
                  }
                }
              });

              return Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  children: [
                    _buildUserHeader(userId),
                    const SizedBox(height: 20),
                    _buildNeonMiningCard(
                        userId,
                        miningService,
                        isMining,
                        currentMinedAmount,
                        lastMinedTime,
                        lastError
                    ),
                    const SizedBox(height: 25),
                    _buildStatsRow(),
                    const SizedBox(height: 20),
                    _buildReferralSection(),
                  ],
                ),
              );
            },
          ),
        ),
      ),
    );
  }

  Future<void> _refreshData() async {
    final walletService = Provider.of<WalletService>(context, listen: false);
    await walletService.refreshWallet();
  }

  Widget _buildNeonMiningCard(
      String userId,
      MiningService miningService,
      bool isMining,
      double currentMinedAmount,
      DateTime? lastMinedTime,
      String? lastError
      ) {
    final bool buttonDisabled = isMining ||
        (lastMinedTime != null && DateTime.now().isBefore(lastMinedTime.add(const Duration(minutes: 5))));

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [_darkBackground, _lightBackground],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: isMining
                ? _successColor.withOpacity(0.3)
                : _primaryColor.withOpacity(0.3),
            blurRadius: 20,
            spreadRadius: 2,
          ),
        ],
      ),
      child: Column(
        children: [
          Text("Mining Status", style: _headerTextStyle()),
          const SizedBox(height: 10),
          Text(
            isMining
                ? "Active: Come Back After 24h"
                : lastMinedTime == null
                ? "Ready to mine 0.05 NERG"
                : "Next mining in ${_getCooldownText(lastMinedTime)}",
            style: TextStyle(
              color: isMining ? _successColor : Colors.white70,
              fontSize: 16,
            ),
          ),
          const SizedBox(height: 16),
          AnimatedBuilder(
            animation: _coinController,
            builder: (_, __) {
              return ScaleTransition(
                scale: isMining
                    ? _pulseAnimation
                    : const AlwaysStoppedAnimation(1.0),
                child: Transform.rotate(
                  angle: isMining ? _coinController.value * 2 * pi : 0,
                  child: Container(
                    width: 80,
                    height: 80,
                    decoration: BoxDecoration(
                      color: _secondaryColor,
                      shape: BoxShape.circle,
                      boxShadow: [
                        BoxShadow(
                          color: _secondaryColor.withOpacity(0.5),
                          blurRadius: 15,
                          spreadRadius: 3,
                        ),
                      ],
                    ),
                    child: const Center(
                      child: Text(
                        "NERG",
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          color: Colors.black,
                          fontSize: 16,
                        ),
                      ),
                    ),
                  ),
                ),
              );
            },
          ),
          const SizedBox(height: 20),
          ElevatedButton(
            onPressed: buttonDisabled ? null : () => miningService.startDailyMining(),
            style: ElevatedButton.styleFrom(
              backgroundColor: buttonDisabled ? Colors.grey : _primaryColor,
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(30),
              ),
              elevation: 12,
            ),
            child: Text(
              isMining ? "MINING..." : "START MINING",
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.bold,
                fontSize: 16,
              ),
            ),
          ),
          if (lastError != null)
            Padding(
              padding: const EdgeInsets.only(top: 10),
              child: Text(
                lastError,
                style: TextStyle(color: _errorColor),
                textAlign: TextAlign.center,
              ),
            ),
        ],
      ),
    );
  }

  String _getCooldownText(DateTime lastMined) {
    final nextMineTime = lastMined.add(const Duration(minutes: 5));
    final remaining = nextMineTime.difference(DateTime.now());
    if (remaining.isNegative) return "Ready to mine";
    return "${remaining.inMinutes}m ${remaining.inSeconds.remainder(60)}s";
  }

  Widget _buildUserHeader(String userId) {
    final walletService = Provider.of<WalletService>(context);
    final miningService = Provider.of<MiningService>(context);
    final currentUser = Provider.of<User?>(context);
    final displayName = currentUser?.displayName ??
        currentUser?.email?.split('@').first ?? "User";

    return StreamBuilder<DocumentSnapshot>(
      stream: walletService.walletStream().handleError((e) {
        debugPrint("Wallet stream error: $e");
        return Stream.empty();
      }),
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return _buildErrorWidget("Failed to load wallet data");
        }

        final data = snapshot.data?.data() as Map<String, dynamic>? ?? {};
        final balance = (data['balance'] ?? 0.0).toDouble();
        final bonusBalance = (data['bonusBalance'] ?? 0.0).toDouble();
        final address = data['address']?.toString() ?? 'Loading...';

        return Row(
          children: [
            _buildUserAvatar(currentUser),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text("Welcome, $displayName", style: _headerTextStyle()),
                  Text("Balance: ${balance.toStringAsFixed(8)} NERG",
                      style: _subheaderTextStyle()),
                  Text("Bonus: ${bonusBalance.toStringAsFixed(8)} NERG",
                      style: _bonusTextStyle()),
                  Text(
                    miningService.isMining(userId) ? "Mining in progress..." : address,
                    style: _addressTextStyle(miningService, userId),
                  ),
                ],
              ),
            ),
          ],
        );
      },
    );
  }
  Widget _buildUserAvatar(User? user) {
    return Container(
      padding: const EdgeInsets.all(2),
      decoration: BoxDecoration(
        gradient: LinearGradient(colors: [_primaryColor, _accentColor]),
        shape: BoxShape.circle,
      ),
      child: CircleAvatar(
        radius: 30,
        backgroundColor: _darkBackground,
        child: user?.photoURL != null
            ? ClipOval(
          child: Image.network(
            user!.photoURL!,
            fit: BoxFit.cover,
            errorBuilder: (_, __, ___) =>
            const Icon(Icons.person, size: 30, color: Colors.white),
          ),
        )
            : const Icon(Icons.person, size: 30, color: Colors.white),
      ),
    );
  }

  Widget _buildStatsRow() {
    final walletService = Provider.of<WalletService>(context);

    return StreamBuilder<DocumentSnapshot>(
      stream: walletService.walletStream().handleError((e) {
        debugPrint("Wallet stream error: $e");
        return Stream.empty();
      }),
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return _buildErrorWidget("Failed to load wallet stats");
        }

        if (!snapshot.hasData || !snapshot.data!.exists) {
          return _buildDefaultStatsRow();
        }

        final data = snapshot.data!.data() as Map<String, dynamic>;
        return Row(
          children: [
            _buildStatCard(
                "Referrals",
                (data['referralCount'] ?? 0).toString(),
                Icons.people
            ),
            const SizedBox(width: 10),
            _buildStatCard(
                "Bonus",
                (data['bonusBalance'] ?? 0.0).toStringAsFixed(5),
                Icons.card_giftcard
            ),
            const SizedBox(width: 10),
            _buildStatCard(
                "Balance",
                (data['balance'] ?? 0.0).toStringAsFixed(5),
                Icons.account_balance_wallet
            ),
          ],
        );
      },
    );
  }

  Widget _buildReferralSection() {
    final walletService = Provider.of<WalletService>(context);
    final currentUser = Provider.of<User?>(context);

    return StreamBuilder<DocumentSnapshot>(
      stream: walletService.walletStream().handleError((e) {
        debugPrint("Wallet stream error: $e");
        return Stream.empty();
      }),
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return _buildErrorWidget("Failed to load referral data");
        }

        final data = snapshot.data?.data() as Map<String, dynamic>? ?? {};
        final referralCount = data['referralCount'] ?? 0;
        final bonusBalance = (data['bonusBalance'] ?? 0.0).toDouble();

        return Column(
          children: [
            Text("Referral Program", style: _sectionHeaderStyle()),
            const SizedBox(height: 10),
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: _lightBackground,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: _referralColor.withOpacity(0.3)),
              ),
              child: Column(
                children: [
                  Text("Your Referral Code:", style: _sectionSubheaderStyle()),
                  const SizedBox(height: 8),
                  _buildReferralCodeCard(currentUser),
                  const SizedBox(height: 12),
                  _buildReferralStats(referralCount, bonusBalance),
                  if (bonusBalance > 0) _buildTransferBonusButton(),
                  const SizedBox(height: 8),
                  Text(
                    "Earn 0.05 NERG for each friend who signs up with your code",
                    textAlign: TextAlign.center,
                    style: _sectionFooterStyle(),
                  ),
                ],
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _buildDefaultStatsRow() {
    return Row(
      children: [
        _buildStatCard("Referrals", "0", Icons.people),
        const SizedBox(width: 10),
        _buildStatCard("Bonus", "0.00000", Icons.card_giftcard),
        const SizedBox(width: 10),
        _buildStatCard("Balance", "0.00000", Icons.account_balance_wallet),
      ],
    );
  }

  Widget _buildStatCard(String label, String value, IconData icon) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: _lightBackground,
          borderRadius: BorderRadius.circular(15),
          boxShadow: [
            BoxShadow(
              color: _primaryColor.withOpacity(0.2),
              blurRadius: 10,
            ),
          ],
        ),
        child: Column(
          children: [
            Icon(icon, color: _secondaryColor),
            const SizedBox(height: 8),
            Text(
              value,
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.bold,
                fontSize: 16,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              label,
              style: const TextStyle(
                color: Colors.white60,
                fontSize: 12,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildReferralCodeCard(User? currentUser) {
    return GestureDetector(
      onTap: () {
        if (currentUser?.uid != null) {
          Clipboard.setData(ClipboardData(text: currentUser!.uid));
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text("Referral code copied!")),
          );
        }
      },
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 12),
        decoration: BoxDecoration(
          color: _darkBackground,
          borderRadius: BorderRadius.circular(8),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              currentUser?.uid ?? "Not available",
              style: TextStyle(
                color: _referralColor,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(width: 8),
            Icon(Icons.copy, size: 16, color: _referralColor),
          ],
        ),
      ),
    );
  }

  Widget _buildReferralStats(int referralCount, double bonusBalance) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
      children: [
        Column(
          children: [
            Text("Referrals", style: _sectionSubheaderStyle()),
            Text(
              referralCount.toString(),
              style: TextStyle(
                color: _referralColor,
                fontSize: 20,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
        Column(
          children: [
            Text("Bonus", style: _sectionSubheaderStyle()),
            Text(
              "${bonusBalance.toStringAsFixed(5)} NERG",
              style: TextStyle(
                color: _referralColor,
                fontSize: 20,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildTransferBonusButton() {
    final walletService = Provider.of<WalletService>(context);

    return ElevatedButton(
      onPressed: () async {
        try {
          await walletService.transferBonusToMainBalance();
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text("Bonus transferred successfully!")),
          );
        } catch (e) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text("Transfer failed: ${e.toString()}")),
          );
        }
      },
      style: ElevatedButton.styleFrom(
        backgroundColor: _referralColor,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
      ),
      child: const Text(
        "TRANSFER BONUS",
        style: TextStyle(
          color: Colors.black,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }

  Widget _buildErrorWidget(String message) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: _errorColor.withOpacity(0.1),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        children: [
          Icon(Icons.error, color: _errorColor),
          const SizedBox(width: 8),
          Text(message, style: TextStyle(color: _errorColor)),
        ],
      ),
    );
  }

  // Text style methods
  TextStyle _headerTextStyle() => const TextStyle(
    fontSize: 18,
    color: Colors.white,
    fontWeight: FontWeight.bold,
  );

  TextStyle _subheaderTextStyle() => TextStyle(
    fontSize: 14,
    color: Colors.white.withOpacity(0.7),
  );

  TextStyle _bonusTextStyle() => TextStyle(
    fontSize: 14,
    color: _referralColor.withOpacity(0.9),
  );

  TextStyle _addressTextStyle(MiningService miningService, String userId) => TextStyle(
    fontSize: 12,
    color: miningService.isMining(userId) ? _secondaryColor : Colors.white70,
  );

  TextStyle _sectionHeaderStyle() => const TextStyle(
    color: Colors.white,
    fontSize: 18,
    fontWeight: FontWeight.bold,
  );

  TextStyle _sectionSubheaderStyle() => TextStyle(
    color: Colors.white70,
    fontSize: 14,
  );

  TextStyle _sectionFooterStyle() => TextStyle(
    color: Colors.white70,
    fontSize: 12,
  );
}