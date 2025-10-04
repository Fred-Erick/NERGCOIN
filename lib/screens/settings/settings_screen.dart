import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:package_info_plus/package_info_plus.dart';
import '../../base_scaffold.dart';
import '../auth/auth_screen.dart';
import '../../utils/constants.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({Key? key}) : super(key: key);

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  bool darkMode = true;
  bool notificationsOn = true;
  String appVersion = "";

  @override
  void initState() {
    super.initState();
    _loadSettings();
    _loadAppVersion();
  }

  Future<void> _loadAppVersion() async {
    final info = await PackageInfo.fromPlatform();
    setState(() => appVersion = info.version);
  }

  Future<void> _loadSettings() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      darkMode = prefs.getBool("isDarkMode") ?? true;
      notificationsOn = prefs.getBool("notificationsOn") ?? true;
    });
  }

  Future<void> _toggleSetting(String key, bool value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(key, value);
    setState(() {
      if (key == "isDarkMode") {
        darkMode = value;
        _showSnackBar("Restart app to apply theme changes");
      } else if (key == "notificationsOn") {
        notificationsOn = value;
      }
    });
  }

  void _showSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        behavior: SnackBarBehavior.floating,
        backgroundColor: const Color(0xFF6C5CE7),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      ),
    );
  }

  Future<void> _launchUrl(String url) async {
    final uri = Uri.parse(url);
    if (!await launchUrl(uri, mode: LaunchMode.externalApplication)) {
      _showSnackBar("Could not launch URL");
    }
  }

  void _confirmLogout() {
    showDialog(
      context: context,
      builder: (_) => Dialog(
        backgroundColor: const Color(0xFF2D2D44),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text("Confirm Logout",
                  style: TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold)),
              const SizedBox(height: 20),
              const Text("Are you sure you want to logout?",
                  style: TextStyle(color: Colors.white70, fontSize: 16)),
              const SizedBox(height: 30),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  TextButton(
                    onPressed: () => Navigator.pop(context),
                    child: const Text("Cancel", style: TextStyle(color: Color(0xFF00B894), fontSize: 16)),
                  ),
                  ElevatedButton(
                    onPressed: () async {
                      await FirebaseAuth.instance.signOut();
                      if (!mounted) return;
                      Navigator.of(context).pushAndRemoveUntil(
                        MaterialPageRoute(builder: (_) => AuthScreen()),
                            (route) => false,
                      );
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFFFF5252),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                    ),
                    child: const Text("Logout", style: TextStyle(fontSize: 16)),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSettingsCard(Widget child) {
    return Card(
      elevation: 0,
      color: const Color(0xFF2D2D44),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
      margin: const EdgeInsets.only(bottom: 16),
      child: child,
    );
  }

  Widget sectionTitle(String title) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Text(
        title,
        style: TextStyle(color: Colors.white.withOpacity(0.8), fontSize: 16, fontWeight: FontWeight.w500),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return BaseScaffold(
      context: context,
      showBottomNavBar: false,
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          const Text("Settings", style: TextStyle(color: Colors.white, fontSize: 24, fontWeight: FontWeight.bold)),
          const SizedBox(height: 20),

          sectionTitle("Appearance"),
          _buildSettingsCard(
            SwitchListTile(
              value: darkMode,
              onChanged: (value) => _toggleSetting("isDarkMode", value),
              title: const Text("Dark Mode", style: TextStyle(color: Colors.white)),
              secondary: const Icon(Icons.dark_mode, color: Color(0xFF6C5CE7)),
            ),
          ),

          sectionTitle("Notifications"),
          _buildSettingsCard(
            SwitchListTile(
              value: notificationsOn,
              onChanged: (value) => _toggleSetting("notificationsOn", value),
              title: const Text("Enable Notifications", style: TextStyle(color: Colors.white)),
              secondary: const Icon(Icons.notifications_active, color: Color(0xFF00B894)),
            ),
          ),

          sectionTitle("About"),
          _buildSettingsCard(
            Column(children: [
              ListTile(
                leading: const Icon(Icons.info_outline, color: Color(0xFF00B894)),
                title: const Text("App Version", style: TextStyle(color: Colors.white)),
                subtitle: Text("v$appVersion", style: const TextStyle(color: Colors.white70)),
              ),
              const Divider(height: 1, color: Color(0xFF1E1E2D)),
              ListTile(
                leading: const Icon(Icons.privacy_tip, color: Color(0xFF6C5CE7)),
                title: const Text("Privacy Policy", style: TextStyle(color: Colors.white)),
                onTap: () => _launchUrl(AppUrls.privacyPolicy),
              ),
              const Divider(height: 1, color: Color(0xFF1E1E2D)),
              ListTile(
                leading: const Icon(Icons.help_outline, color: Color(0xFFFD79A8)),
                title: const Text("Help & Support", style: TextStyle(color: Colors.white)),
                onTap: () => _launchUrl(AppUrls.helpAndSupport),
              ),
            ]),
          ),

          const SizedBox(height: 20),
          Center(
            child: ElevatedButton.icon(
              onPressed: _confirmLogout,
              icon: const Icon(Icons.logout),
              label: const Text("Logout"),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFFFF5252).withOpacity(0.2),
                foregroundColor: const Color(0xFFFF5252),
                padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                  side: BorderSide(color: const Color(0xFFFF5252).withOpacity(0.5)),
                ),
              ),
            ),
          ),
        ]),
      ),
    );
  }
}
