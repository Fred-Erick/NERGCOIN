import 'package:flutter/material.dart';

class BaseScaffold extends StatelessWidget {
  final Widget child;
  final int? currentIndex;  // Made nullable
  final BuildContext context;
  final bool showBottomNavBar;

  // Color scheme
  final Color _primaryColor = const Color(0xFF6C5CE7);
  final Color _secondaryColor = const Color(0xFF00B894);
  final Color _darkBackground = const Color(0xFF1E1E2D);
  final Color _navBarColor = const Color(0xFF0A0A2A);

  const BaseScaffold({
    Key? key,
    required this.child,
    this.currentIndex,  // Now optional
    required this.context,
    this.showBottomNavBar = true,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _darkBackground,
      appBar: AppBar(
        backgroundColor: _darkBackground,
        elevation: 0,
        title: Text(
          "NergNet",
          style: TextStyle(
            color: _secondaryColor,
            fontSize: 20,
            fontWeight: FontWeight.bold,
          ),
        ),
        actions: [
          IconButton(
            icon: Icon(Icons.notifications, color: Colors.white.withOpacity(0.8)),
            onPressed: () => Navigator.pushNamed(context, '/notifications'),
          ),
          IconButton(
            icon: Icon(Icons.settings, color: Colors.white.withOpacity(0.8)),
            onPressed: () => Navigator.pushNamed(context, '/settings'),
          ),
        ],
      ),
      body: SafeArea(child: child),
      bottomNavigationBar: showBottomNavBar ? _buildBottomNavBar() : null,
    );
  }

  Widget _buildBottomNavBar() {
    // Default to 0 if currentIndex is null
    final effectiveIndex = currentIndex ?? 0;

    return Container(
      decoration: BoxDecoration(
        color: _navBarColor,
        border: Border(
          top: BorderSide(
            color: Colors.white.withOpacity(0.1),
            width: 0.5,
          ),
        ),
      ),
      child: BottomNavigationBar(
        currentIndex: effectiveIndex.clamp(0, 3),  // Ensures index is always valid
        backgroundColor: Colors.transparent,
        elevation: 0,
        selectedItemColor: _primaryColor,
        unselectedItemColor: Colors.white60,
        type: BottomNavigationBarType.fixed,
        onTap: (index) {
          switch (index) {
            case 0:
              Navigator.pushNamed(context, '/dashboard');
              break;
            case 1:
              Navigator.pushNamed(context, '/wallet');
              break;
            case 2:
              Navigator.pushNamed(context, '/transactions');
              break;
            case 3:
              Navigator.pushNamed(context, '/community');
              break;
          }
        },
        items: const [
          BottomNavigationBarItem(
            icon: Icon(Icons.dashboard),
            label: "Dashboard",
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.account_balance_wallet),
            label: "Wallet",
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.swap_horiz_rounded),
            label: "Transactions",
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.people),
            label: "Community",
          ),
        ],
      ),
    );
  }
}