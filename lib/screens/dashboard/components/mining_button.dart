import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:firebase_auth/firebase_auth.dart'; // Import FirebaseAuth
import '../../../services/mining_service.dart';

class MiningButton extends StatelessWidget {
  final VoidCallback onStartMining;

  const MiningButton({
    Key? key,
    required this.onStartMining,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final miningService = Provider.of<MiningService>(context);
    final currentUser = Provider.of<User?>(context); // Get current user
    final userId = currentUser?.uid; // Get userId

    // Handle case where userId is null
    if (userId == null) {
      return const SizedBox.shrink(); // Or a loading indicator/error message
    }

    final isMining = miningService.isMining(userId); // Pass userId

    // Only show the button if not mining
    return Visibility(
      visible: !isMining,
      child: ElevatedButton(
        onPressed: onStartMining,
        style: ElevatedButton.styleFrom(
          backgroundColor: Colors.greenAccent,
          padding: const EdgeInsets.symmetric(vertical: 16),
        ),
        child: const Text(
          "START MINING",
          style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
        ),
      ),
    );
  }
}