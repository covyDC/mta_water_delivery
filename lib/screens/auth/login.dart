import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
// ...existing code...
import 'package:google_sign_in/google_sign_in.dart';
import 'package:mta_water_delivery/screens/dashboards/customer_dashboard.dart';
// ...existing code...
import 'package:mta_water_delivery/screens/auth/register.dart';
import 'package:mta_water_delivery/screens/auth/admin_login.dart';
// ...existing code...
// ...existing code...
import 'package:mta_water_delivery/services/activity_logger.dart';

class LoginPage extends StatefulWidget {
  const LoginPage({super.key});

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();

  bool _isLoading = false;
  bool _obscurePassword = true;

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  /// Route user to customer dashboard only
  void _routeToCustomerDashboard(User user) {
    if (!mounted) return;
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(builder: (_) => const CustomerDashboard()),
    );
  }

  /// =========================
  /// Google Sign-In (Customer only)
  /// =========================
  Future<void> _signInWithGoogle() async {
    setState(() => _isLoading = true);
    final messenger = ScaffoldMessenger.of(context);
    try {
      final googleSignIn = GoogleSignIn(scopes: ['email']);
      final googleUser = await googleSignIn.signIn();
      if (googleUser == null) {
        setState(() => _isLoading = false);
        return;
      }
      final googleAuth = await googleUser.authentication;
      final credential = GoogleAuthProvider.credential(
        idToken: googleAuth.idToken,
        accessToken: googleAuth.accessToken,
      );
      final userCredential = await FirebaseAuth.instance.signInWithCredential(credential);
      // Disallow staff or driver accounts from signing in via the customer flow
      final uid = userCredential.user?.uid;
      if (uid != null && await _isStaffOrDriver(uid)) {
        // log and sign out to prevent access through the customer UI
        await FirebaseAuth.instance.signOut();
        if (!mounted) return;
        final activityLogger = ActivityLogger();
        await activityLogger.logLogin(userCredential.user?.email ?? '', 'customer', false, 'blocked-role');
        messenger.showSnackBar(const SnackBar(content: Text('Staff/Driver accounts cannot log in here. Use Admin / Staff / Driver Login instead.')));
        setState(() => _isLoading = false);
        return;
      }
      if (!mounted) return;
      setState(() => _isLoading = false);
      // Route to customer dashboard only
      _routeToCustomerDashboard(userCredential.user!);
    } catch (e) {
      if (!mounted) return;
      setState(() => _isLoading = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Google Sign-In failed: $e')),
      );
    }
  }

  /// =========================
  /// Email/Password Login (Customer only)
  /// =========================
  Future<void> _login() async {
    final messenger = ScaffoldMessenger.of(context);
    if (!_formKey.currentState!.validate()) return;
    setState(() => _isLoading = true);
    try {
      final userCredential = await FirebaseAuth.instance.signInWithEmailAndPassword(
        email: _emailController.text.trim(),
        password: _passwordController.text.trim(),
      );
      // Block staff/driver accounts from signing in with the customer form
      if (userCredential.user != null && await _isStaffOrDriver(userCredential.user!.uid)) {
        // sign out immediately and show a friendly message
        await FirebaseAuth.instance.signOut();
        final activityLogger = ActivityLogger();
        await activityLogger.logLogin(_emailController.text.trim(), 'customer', false, 'blocked-role');
        if (!mounted) return;
        setState(() => _isLoading = false);
        messenger.showSnackBar(const SnackBar(content: Text('Staff/Driver accounts cannot sign in here — use Admin / Staff / Driver Login.')));
        return;
      }
      if (!mounted) return;
      setState(() => _isLoading = false);
      // Log successful login
      final activityLogger = ActivityLogger();
      await activityLogger.logLogin(_emailController.text.trim(), 'customer', true, null);
      // Route to customer dashboard only
      _routeToCustomerDashboard(userCredential.user!);
    } on FirebaseAuthException catch (e) {
      if (!mounted) return;
      setState(() => _isLoading = false);
      final message = switch (e.code) {
        'user-not-found' => 'No user found with this email',
        'wrong-password' => 'Incorrect password',
        _ => e.message ?? 'Login failed',
      };
      // Log failed login
      final activityLogger = ActivityLogger();
      await activityLogger.logLogin(_emailController.text.trim(), 'customer', false, e.code);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(message)),
      );
    }
  }

  Future<bool> _isStaffOrDriver(String uid) async {
    try {
      final staffDoc = await FirebaseFirestore.instance.collection('staff').doc(uid).get();
      if (staffDoc.exists) return true;
    } catch (_) {}

    try {
      final driverDoc = await FirebaseFirestore.instance.collection('drivers').doc(uid).get();
      if (driverDoc.exists) return true;
    } catch (_) {}

    return false;
  }

  /// =========================
  /// UI
  /// =========================
  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(
        title: const Text('Login'),
        backgroundColor: theme.colorScheme.inversePrimary,
      ),
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24.0),
          child: Form(
            key: _formKey,
            child: AutofillGroup(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  // Email
                  TextFormField(
                    controller: _emailController,
                    decoration: const InputDecoration(
                      labelText: 'Email',
                      border: OutlineInputBorder(),
                      prefixIcon: Icon(Icons.email_outlined),
                    ),
                    autofillHints: const [AutofillHints.username],
                    keyboardType: TextInputType.emailAddress,
                    validator: (value) {
                      if (value == null || value.isEmpty) {
                        return 'Please enter your email';
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 16),

                  // Password
                  TextFormField(
                    controller: _passwordController,
                    decoration: InputDecoration(
                      labelText: 'Password',
                      border: const OutlineInputBorder(),
                      prefixIcon: const Icon(Icons.lock_outline),
                      suffixIcon: IconButton(
                        icon: Icon(
                          _obscurePassword ? Icons.visibility_off : Icons.visibility,
                        ),
                        onPressed: () {
                          setState(() {
                            _obscurePassword = !_obscurePassword;
                          });
                        },
                      ),
                    ),
                    obscureText: _obscurePassword,
                    autofillHints: const [AutofillHints.password],
                    validator: (value) {
                      if (value == null || value.isEmpty) {
                        return 'Please enter your password';
                      }
                      if (value.length < 4) {
                        return 'Password must be at least 4 characters';
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 24),

                  // Login Button
                  _isLoading
                      ? const CircularProgressIndicator()
                      : SizedBox(
                          width: double.infinity,
                          child: ElevatedButton(
                            onPressed: _login,
                            style: ElevatedButton.styleFrom(
                              padding: const EdgeInsets.symmetric(vertical: 14),
                            ),
                            child: const Text('Login'),
                          ),
                        ),
                  const SizedBox(height: 12),

                  // Register Button (➡ Goes to register.dart)
                  TextButton(
                    onPressed: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => const RegisterPage(),
                        ),
                      );
                    },
                    child: const Text("Don't have an account? Register"),
                  ),
                  const SizedBox(height: 12),

                  // Google Sign-In Button
                  if (!_isLoading)
                    ElevatedButton.icon(
                      icon: const Icon(Icons.login),
                      label: const Text('Sign in with Google'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.white,
                        foregroundColor: Colors.black87,
                        minimumSize: const Size(double.infinity, 50),
                        side: const BorderSide(color: Colors.black12),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      onPressed: _signInWithGoogle,
                    ),
                  const SizedBox(height: 12),

                  // Admin Login Button (➡ Goes to admin_login.dart)
                  ElevatedButton.icon(
                    icon: const Icon(Icons.admin_panel_settings),
                    label: const Text('Admin / Staff / Driver Login'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.black87,
                      foregroundColor: Colors.white,
                      minimumSize: const Size(double.infinity, 50),
                    ),
                    onPressed: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => const AdminLoginPage(),
                        ),
                      );
                    },
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
