import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:mta_water_delivery/screens/dashboards/customer_dashboard.dart';
import 'package:mta_water_delivery/screens/dashboards/driver_dashboard.dart';
import 'package:mta_water_delivery/screens/dashboards/staff_dashboard.dart';
import 'package:mta_water_delivery/screens/dashboards/admin_dashboard.dart';
import 'package:mta_water_delivery/screens/auth/register.dart';
import 'package:mta_water_delivery/screens/auth/admin_login.dart';
import 'package:mta_water_delivery/services/user_auth_service.dart';
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

  /// Route user to appropriate dashboard based on role
  Future<void> _routeToRoleDashboard(User user) async {
    try {
      final userService = UserAuthService();
      
      // Get user role
      final role = await userService.getUserRole(user.uid);
      
      // Default to customer if role not found (backwards compatibility)
      final finalRole = role ?? UserRole.customer;

      // Check platform access
      final canAccess = await userService.canAccessPlatform(user.uid, finalRole);
      if (!canAccess) {
        await FirebaseAuth.instance.signOut();
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('${finalRole.name} users cannot access this platform')),
        );
        return;
      }

      if (!mounted) return;

      // Route to appropriate dashboard
      final dashboard = switch (finalRole) {
        UserRole.customer => const CustomerDashboard(),
        UserRole.driver => const DriverDashboardPage(staff: {}),
        UserRole.staff => const StaffDashboardPage(staff: {}),
        UserRole.admin => const AdminDashboardPage(),
      };

      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (_) => dashboard),
      );
    } catch (e) {
      // Fallback: route to customer dashboard if anything fails
      if (!mounted) return;
      print('Error in role-based routing: $e');
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (_) => const CustomerDashboard()),
      );
    }
  }

  /// =========================
  /// Google Sign-In
  /// =========================
  Future<void> _signInWithGoogle() async {
    setState(() => _isLoading = true);

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

      if (!mounted) return;
      setState(() => _isLoading = false);

      // Route based on user role
      await _routeToRoleDashboard(userCredential.user!);
    } catch (e) {
      if (!mounted) return;
      setState(() => _isLoading = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Google Sign-In failed: $e')),
      );
    }
  }

  /// =========================
  /// Email/Password Login
  /// =========================
  Future<void> _login() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);

    try {
      final userCredential = await FirebaseAuth.instance.signInWithEmailAndPassword(
        email: _emailController.text.trim(),
        password: _passwordController.text.trim(),
      );

      if (!mounted) return;
      setState(() => _isLoading = false);

      // Log successful login
      final userService = UserAuthService();
      final role = await userService.getUserRole(userCredential.user!.uid);
      final activityLogger = ActivityLogger();
      await activityLogger.logLogin(_emailController.text.trim(), role?.name ?? 'customer', true, null);

      // Route based on user role
      await _routeToRoleDashboard(userCredential.user!);
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
      await activityLogger.logLogin(_emailController.text.trim(), 'unknown', false, e.code);

      if (!mounted) return;
      // ignore: use_build_context_synchronously
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(message)),
      );
    }
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
                    label: const Text('Admin Login'),
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
