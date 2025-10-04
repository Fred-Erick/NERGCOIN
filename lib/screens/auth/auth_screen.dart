import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/services.dart';
import '../../services/auth_service.dart';
import '../dashboard/dashboard_screen.dart';

class AuthScreen extends StatefulWidget {
  @override
  _AuthScreenState createState() => _AuthScreenState();
}

class _AuthScreenState extends State<AuthScreen> {
  final TextEditingController _fullNameController = TextEditingController();
  final TextEditingController _usernameController = TextEditingController();
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  final TextEditingController _confirmPasswordController = TextEditingController();
  final TextEditingController _referralCodeController = TextEditingController();

  bool _isLogin = true;
  bool _isPasswordVisible = false;
  bool _isConfirmPasswordVisible = false;
  bool _isLoading = false;
  String? _emailError;
  String? _passwordError;

  final AuthService _authService = AuthService();
  final RegExp _passwordRegex = RegExp(r'^(?=.*[a-z])(?=.*[A-Z])(?=.*\d)(?=.*[\W_]).{8,}$');

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: Center(
        child: SingleChildScrollView(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 25, vertical: 40),
            child: Column(
              children: [
                const Icon(Icons.account_circle, size: 80, color: Colors.amber),
                const SizedBox(height: 10),
                Text(
                  _isLogin ? "Welcome Back!" : "Join NergNet",
                  style: const TextStyle(
                      fontSize: 28,
                      fontWeight: FontWeight.bold,
                      color: Colors.amber
                  ),
                ),
                const SizedBox(height: 5),
                Text(
                  _isLogin ? "Login to continue" : "Create an account to start mining",
                  style: const TextStyle(color: Colors.grey),
                ),
                const SizedBox(height: 20),
                _buildAuthCard(),
                const SizedBox(height: 20),
                _buildAuthButton(),
                const SizedBox(height: 10),
                _buildToggleAuthButton(),
                const SizedBox(height: 20),
                _buildGoogleSignInButton(),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildAuthCard() {
    return Card(
      color: Colors.grey[900],
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
      elevation: 8,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 15),
        child: Column(
          children: [
            if (!_isLogin) ...[
              _buildTextField("Full Name", _fullNameController, Icons.person),
              const SizedBox(height: 15),
              _buildTextField("Username", _usernameController, Icons.alternate_email),
              const SizedBox(height: 15),
            ],
            _buildEmailField(),
            if (_emailError != null) ...[
              const SizedBox(height: 4),
              Text(_emailError!, style: const TextStyle(color: Colors.red, fontSize: 12)),
            ],
            const SizedBox(height: 15),
            _buildPasswordField("Password", _passwordController, Icons.lock, isConfirm: false),
            if (!_isLogin) ...[
              const SizedBox(height: 8),
              _buildPasswordRequirements(),
              const SizedBox(height: 15),
              _buildPasswordField("Confirm Password", _confirmPasswordController, Icons.lock_outline, isConfirm: true),
            ],
            if (_passwordError != null) ...[
              const SizedBox(height: 4),
              Text(_passwordError!, style: const TextStyle(color: Colors.red, fontSize: 12)),
            ],
            if (!_isLogin) _buildReferralField(),
          ],
        ),
      ),
    );
  }

  Widget _buildPasswordRequirements() {
    return const Padding(
      padding: EdgeInsets.symmetric(horizontal: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            "Password must contain:",
            style: TextStyle(color: Colors.grey, fontSize: 12),
          ),
          SizedBox(height: 4),
          Text(
            "• 8+ characters\n• 1 uppercase letter\n• 1 lowercase letter\n• 1 number\n• 1 special character",
            style: TextStyle(color: Colors.grey, fontSize: 12),
          ),
        ],
      ),
    );
  }

  Widget _buildAuthButton() {
    return _isLoading
        ? const CircularProgressIndicator(color: Colors.amber)
        : ElevatedButton(
      onPressed: _authenticate,
      style: ElevatedButton.styleFrom(
        backgroundColor: Colors.deepPurple,
        padding: const EdgeInsets.symmetric(vertical: 15, horizontal: 80),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      ),
      child: Text(
        _isLogin ? "Login" : "Sign Up",
        style: const TextStyle(color: Colors.white, fontSize: 16),
      ),
    );
  }

  Widget _buildToggleAuthButton() {
    return TextButton(
      onPressed: _toggleAuthMode,
      child: Text(
        _isLogin ? "Create Account" : "Login Instead",
        style: const TextStyle(color: Colors.deepPurpleAccent),
      ),
    );
  }

  Widget _buildGoogleSignInButton() {
    return ElevatedButton(
      onPressed: _isLoading ? null : _googleSignIn,
      style: ElevatedButton.styleFrom(
        backgroundColor: Colors.white,
        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 20),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Image.asset("assets/google_logo.png", height: 24),
          const SizedBox(width: 10),
          const Text(
            "Sign In with Google",
            style: TextStyle(color: Colors.black, fontSize: 16),
          ),
        ],
      ),
    );
  }

  Widget _buildTextField(String label, TextEditingController controller, IconData icon) {
    return TextField(
      controller: controller,
      decoration: InputDecoration(
        labelText: label,
        labelStyle: const TextStyle(color: Colors.grey),
        hintText: "Enter $label",
        hintStyle: const TextStyle(color: Colors.grey),
        filled: true,
        fillColor: Colors.grey[800],
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
        prefixIcon: Icon(icon, color: Colors.white70),
      ),
      style: const TextStyle(color: Colors.white),
    );
  }

  Widget _buildEmailField() {
    return TextField(
      controller: _emailController,
      decoration: InputDecoration(
        labelText: "Email",
        labelStyle: const TextStyle(color: Colors.grey),
        hintText: "Enter your email",
        hintStyle: const TextStyle(color: Colors.grey),
        filled: true,
        fillColor: Colors.grey[800],
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
        prefixIcon: const Icon(Icons.email, color: Colors.white70),
        suffixIcon: IconButton(
          icon: const Icon(Icons.check, size: 20),
          onPressed: _checkEmailExists,
          color: _isEmailValid ? Colors.green : Colors.grey,
        ),
      ),
      keyboardType: TextInputType.emailAddress,
      onChanged: (value) => setState(() => _emailError = null),
      style: const TextStyle(color: Colors.white),
    );
  }

  Widget _buildPasswordField(String label, TextEditingController controller, IconData icon, {required bool isConfirm}) {
    return TextField(
      controller: controller,
      obscureText: isConfirm ? !_isConfirmPasswordVisible : !_isPasswordVisible,
      decoration: InputDecoration(
        labelText: label,
        labelStyle: const TextStyle(color: Colors.grey),
        hintText: "Enter $label",
        hintStyle: const TextStyle(color: Colors.grey),
        filled: true,
        fillColor: Colors.grey[800],
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
        prefixIcon: Icon(icon, color: Colors.white70),
        suffixIcon: IconButton(
          icon: Icon(
            isConfirm
                ? (_isConfirmPasswordVisible ? Icons.visibility_off : Icons.visibility)
                : (_isPasswordVisible ? Icons.visibility_off : Icons.visibility),
            color: Colors.white70,
          ),
          onPressed: () => setState(() {
            if (isConfirm) {
              _isConfirmPasswordVisible = !_isConfirmPasswordVisible;
            } else {
              _isPasswordVisible = !_isPasswordVisible;
            }
          }),
        ),
      ),
      onChanged: (value) => setState(() => _passwordError = null),
      style: const TextStyle(color: Colors.white),
    );
  }

  Widget _buildReferralField() {
    return Column(
      children: [
        const SizedBox(height: 15),
        _buildTextField(
          "Referral Code (optional)",
          _referralCodeController,
          Icons.card_giftcard,
        ),
      ],
    );
  }

  bool get _isEmailValid {
    if (_emailController.text.isEmpty) return false;
    return RegExp(r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$').hasMatch(_emailController.text);
  }

  bool get _isPasswordValid {
    return _passwordRegex.hasMatch(_passwordController.text);
  }

  Future<void> _checkEmailExists() async {
    if (!_isEmailValid) {
      setState(() => _emailError = "Please enter a valid email address");
      return;
    }

    setState(() => _isLoading = true);
    try {
      final methods = await FirebaseAuth.instance
          .fetchSignInMethodsForEmail(_emailController.text.trim());

      if (methods.isNotEmpty && !_isLogin) {
        setState(() => _emailError = "An account already exists with this email");
      } else {
        setState(() => _emailError = null);
      }
    } on FirebaseAuthException catch (e) {
      setState(() => _emailError = "Error checking email: ${e.message}");
    } finally {
      setState(() => _isLoading = false);
    }
  }

  void _toggleAuthMode() {
    setState(() {
      _isLogin = !_isLogin;
      _emailError = null;
      _passwordError = null;
      _fullNameController.clear();
      _usernameController.clear();
      _emailController.clear();
      _passwordController.clear();
      _confirmPasswordController.clear();
      _referralCodeController.clear();
    });
  }

  Future<void> _authenticate() async {
    if (_isLoading) return;

    if (!_validateForm()) return;

    setState(() => _isLoading = true);

    try {
      if (_isLogin) {
        await _handleLogin();
      } else {
        await _handleSignUp();
      }
    } on FirebaseAuthException catch (e) {
      _handleAuthError(e);
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("❌ Error: ${e.toString()}")),
      );
    } finally {
      setState(() => _isLoading = false);
    }
  }

  bool _validateForm() {
    if (!_isEmailValid) {
      setState(() => _emailError = "Please enter a valid email address");
      return false;
    }

    if (_passwordController.text.isEmpty) {
      setState(() => _passwordError = "Please enter a password");
      return false;
    }

    if (!_isLogin) {
      if (_fullNameController.text.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("❌ Please enter your full name")),
        );
        return false;
      }

      if (_usernameController.text.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("❌ Please choose a username")),
        );
        return false;
      }

      if (!_isPasswordValid) {
        setState(() => _passwordError = "Password must meet requirements");
        return false;
      }

      if (_passwordController.text != _confirmPasswordController.text) {
        setState(() => _passwordError = "Passwords do not match");
        return false;
      }
    }
    return true;
  }

  Future<void> _handleLogin() async {
    final user = await _authService.signInWithEmail(
      _emailController.text.trim(),
      _passwordController.text.trim(),
    );

    if (user != null) {
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (context) => DashboardScreen()),
      );
    }
  }

  Future<void> _handleSignUp() async {
    final user = await _authService.signUpWithEmail(
      _emailController.text.trim(),
      _passwordController.text.trim(),
      username: _usernameController.text.trim(),
      referredBy: _referralCodeController.text.trim(),
    );

    if (user != null) {
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (context) => DashboardScreen()),
      );
    }
  }

  Future<void> _googleSignIn() async {
    setState(() => _isLoading = true);
    try {
      final user = await _authService.signInWithGoogle();
      if (user != null) {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (context) => DashboardScreen()),
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("❌ Google Sign-In Failed: ${e.toString()}")),
      );
    } finally {
      setState(() => _isLoading = false);
    }
  }

  void _handleAuthError(FirebaseAuthException e) {
    String errorMessage = "Authentication failed";
    switch (e.code) {
      case 'wrong-password':
        errorMessage = "Incorrect password";
        break;
      case 'user-not-found':
        errorMessage = "No account found with this email";
        break;
      case 'email-already-in-use':
        errorMessage = "Email already in use";
        break;
      case 'weak-password':
        errorMessage = "Password must meet requirements";
        break;
      default:
        errorMessage = e.message ?? errorMessage;
    }

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text("❌ $errorMessage")),
    );
  }
}