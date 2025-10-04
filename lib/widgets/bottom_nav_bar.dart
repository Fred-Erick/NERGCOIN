import 'package:flutter/material.dart';

class BottomNavBar extends StatelessWidget {
  final int currentIndex;
  final Function(int)? onTap;

  const BottomNavBar({
    Key? key,
    required this.currentIndex,
    this.onTap,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return BottomNavigationBar(
      currentIndex: currentIndex,
      onTap: onTap ??
              (index) {
            // Default nav logic (can be customized)
            if (index == 0) {
              // Already on home
            } else if (index == 1) {
              // Navigate to Wallet (you can implement later)
            } else if (index == 2) {
              // Navigate to Profile
            }
          },
      backgroundColor: Colors.black,
      selectedItemColor: Colors.greenAccent,
      unselectedItemColor: Colors.white70,
      items: const [
        BottomNavigationBarItem(
          icon: Icon(Icons.dashboard),
          label: "Home",
        ),
        BottomNavigationBarItem(
          icon: Icon(Icons.account_balance_wallet),
          label: "Wallet",
        ),
        BottomNavigationBarItem(
          icon: Icon(Icons.person),
          label: "Profile",
        ),
      ],
    );
  }
}
