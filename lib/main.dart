import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:nergnet/services/transaction_service.dart';
import 'package:nergnet/services/wallet_service.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'screens/auth/auth_screen.dart';
import 'theme_provider.dart';
import 'services/mining_service.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'screens/wallet/wallet_screen.dart';
import 'screens/dashboard/dashboard_screen.dart';
import 'screens/community/community_screen.dart';
import 'screens/transactions/transaction_history_screen.dart';
import 'screens/settings/settings_screen.dart';
import 'screens/notifications/notifications_screen.dart';
import 'package:workmanager/workmanager.dart'; // Import WorkManager

// This is the top-level function that WorkManager will call
// It must be a static or top-level function
// The actual implementation is in mining_service.dart
// We just need to ensure it's accessible here.
// For simplicity, we'll assume callbackDispatcher is already defined in mining_service.dart
// and imported with 'package:nergnet/services/mining_service.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await Firebase.initializeApp(
    options: FirebaseOptions(
      apiKey: "AIzaSyA-a7uSkzvbF_7H9dK3YJkDo1gDIBtnvtY",
      authDomain: "nergnet-adb04.firebaseapp.com",
      projectId: "nergnet-adb04",
      storageBucket: "nergnet-adb04.appspot.com",
      messagingSenderId: "704065450568",
      appId: "1:704065450568:web:4f7dc4254c93ef163b9e7d",
      measurementId: "G-EWKZB6PTWP",
      databaseURL: "https://nergnet-adb04-default-rtdb.firebaseio.com",
    ),
  );

  // Initialize WorkManager
  Workmanager().initialize(
    callbackDispatcher, // The top-level function defined in mining_service.dart
    isInDebugMode: true, // Set to false for production
  );

  SharedPreferences prefs = await SharedPreferences.getInstance();
  bool isDarkMode = prefs.getBool("isDarkMode") ?? false;

  runApp(MyApp(isDarkMode: isDarkMode));
}

class MyApp extends StatelessWidget {
  final bool isDarkMode;

  const MyApp({super.key, required this.isDarkMode});

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        Provider<FirebaseAuth>(create: (_) => FirebaseAuth.instance),
        ChangeNotifierProvider(create: (_) => ThemeProvider(isDarkMode)),
        ChangeNotifierProvider(create: (_) => MiningService()),
        StreamProvider<User?>(
          create: (context) => FirebaseAuth.instance.authStateChanges(),
          initialData: FirebaseAuth.instance.currentUser,
        ),
        ProxyProvider<User?, WalletService>(
          update: (_, user, __) => WalletService(user?.uid),
        ),
        Provider(create: (_) => TransactionService()),
      ],
      child: Consumer<ThemeProvider>(
        builder: (context, themeProvider, child) {
          return MaterialApp(
            debugShowCheckedModeBanner: false,
            theme: ThemeData.light(),
            darkTheme: ThemeData.dark(),
            themeMode: themeProvider.themeMode,
            home: AuthScreen(),
            routes: {
              '/dashboard': (_) => DashboardScreen(),
              '/wallet': (context) => const WalletScreen(),
              '/community': (context) => const CommunityScreen(),
              '/transactions': (context) => const TransactionHistoryScreen(),
              '/settings': (context) => const SettingsScreen(),
              '/notifications': (context) => const NotificationsScreen(),
            },
          );
        },
      ),
    );
  }
}