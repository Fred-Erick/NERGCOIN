import 'package:flutter/material.dart';

class AppColors {
  static const backgroundDark = Color(0xFF2D2D44);
  static const cardDark = Color(0xFF2D2D44);
  static const dividerDark = Color(0xFF1E1E2D);
  static const accentPurple = Color(0xFF6C5CE7);
  static const accentGreen = Color(0xFF00B894);
  static const accentPink = Color(0xFFFD79A8);
  static const errorRed = Color(0xFFFF5252);
}

class AppStrings {
  static const settingsTitle = "Settings";
  static const appearance = "Appearance";
  static const notifications = "Notifications";
  static const security = "Security";
  static const language = "Language";
  static const about = "About";
  static const darkMode = "Dark Mode";
  static const enableNotifications = "Enable Notifications";
  static const biometricAuth = "Biometric Authentication";
  static const appLanguage = "App Language";
  static const appVersion = "App Version";
  static const privacyPolicy = "Privacy Policy";
  static const helpSupport = "Help & Support";
  static const logout = "Logout";
  static const confirmLogout = "Confirm Logout";
  static const logoutPrompt = "Are you sure you want to logout?";
  static const cancel = "Cancel";
  static const couldNotLaunch = "Could not launch URL";
  static const themeRestartHint = "Restart app to apply theme changes";

  static const List<String> supportedLanguages = [
    "English", "French", "Spanish", "German", "Japanese"
  ];
}

class AppUrls {
  static const privacyPolicy = 'https://nergnet-adb04.web.app/privacy.html';
  static const helpAndSupport = 'https://nergnet-adb04.web.app/support.html';
}

class PrefKeys {
  static const isDarkMode = "isDarkMode";
  static const notificationsOn = "notificationsOn";
  static const biometricAuth = "biometricAuth";
  static const language = "language";
}
