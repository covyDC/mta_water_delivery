import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:mta_water_delivery/screens/dashboards/admin_dashboard.dart';
import 'package:mta_water_delivery/screens/dashboards/staff_dashboard.dart';
import 'package:mta_water_delivery/screens/dashboards/driver_dashboard.dart';

class AdminLoginPage extends StatefulWidget {
  const AdminLoginPage({super.key});

  @override
  State<AdminLoginPage> createState() => _AdminLoginPageState();
}

class _AdminLoginPageState extends State<AdminLoginPage> {
  final _formKey = GlobalKey<FormState>();
  final _usernameController = TextEditingController();
  final _passwordController = TextEditingController();

  bool _isLoading = false;
  bool _isStaffMode = false;
  bool _obscurePassword = true;

  final String _adminUsername = 'admin';
  final String _adminPassword = '12345678';

  Future<void> _loginAdmin() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);

    await Future.delayed(const Duration(milliseconds: 600));

    if (!mounted) return;

    if (_usernameController.text.trim() == _adminUsername &&
        _passwordController.text.trim() == _adminPassword) {

      setState(() => _isLoading = false);

      if (!mounted) return;
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (_) => const AdminDashboardPage()),
      );
    } else {
      setState(() => _isLoading = false);

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Invalid admin credentials')),
      );
    }
  }

  Future<void> _loginStaff() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);

    try {
      final email = _usernameController.text.trim();
      final password = _passwordController.text.trim();

      // Authenticate with Firebase Auth
      final userCredential = await FirebaseAuth.instance.signInWithEmailAndPassword(
        email: email,
        password: password,
      );

      if (!mounted) return;

      // Get staff details from Firestore
      final staffSnapshot = await FirebaseFirestore.instance
          .collection('staff')
          .doc(userCredential.user!.uid)
          .get();

      if (!staffSnapshot.exists) {
        throw Exception('Staff profile not found');
      }

      final staff = {'id': staffSnapshot.id, ...staffSnapshot.data() as Map<String, dynamic>};

      setState(() => _isLoading = false);

      if (!mounted) return;

      // Route based on role
      final role = staff['role'] ?? 'on-site staff';
      if (role == 'driver') {
        // Check if driver is accessing from mobile only
        if (kIsWeb) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Drivers can only access the app via mobile devices')),
          );
          return;
        }
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(
            builder: (_) => DriverDashboardPage(staff: staff),
          ),
        );
      } else {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(
            builder: (_) => StaffDashboardPage(staff: staff),
          ),
        );
      }

    } on FirebaseAuthException catch (e) {
      setState(() => _isLoading = false);

      if (!mounted) return;
      
      String errorMessage = 'Login failed';
      if (e.code == 'user-not-found') {
        errorMessage = 'No staff account found with that email';
      } else if (e.code == 'wrong-password') {
        errorMessage = 'Incorrect password';
      } else if (e.code == 'invalid-email') {
        errorMessage = 'Invalid email format';
      }

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(errorMessage)),
      );
    } catch (e) {
      setState(() => _isLoading = false);

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.toString())),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Admin / Staff Login'),
        backgroundColor: theme.colorScheme.inversePrimary,
      ),
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24.0),
          child: Form(
            key: _formKey,
            child: Column(
              children: [
                Text(
                  _isStaffMode ? 'Staff Login' : 'Admin Login',
                  style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 24),

                TextFormField(
                  controller: _usernameController,
                  decoration: InputDecoration(
                    labelText: _isStaffMode ? 'Email' : 'Admin Username',
                    border: const OutlineInputBorder(),
                    prefixIcon:
                        Icon(_isStaffMode ? Icons.email : Icons.person),
                  ),
                  validator: (value) =>
                      value == null || value.isEmpty
                          ? 'Please enter your ${_isStaffMode ? 'email' : 'username'}'
                          : null,
                ),
                const SizedBox(height: 16),

                TextFormField(
                  controller: _passwordController,
                  decoration: InputDecoration(
                    labelText: 'Password',
                    border: const OutlineInputBorder(),
                    prefixIcon: const Icon(Icons.lock),
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
                  validator: (value) =>
                      value == null || value.isEmpty ? 'Enter password' : null,
                ),
                const SizedBox(height: 24),

                if (_isLoading)
                  const CircularProgressIndicator()
                else
                  Column(
                    children: [
                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton.icon(
                          onPressed: () {
                            setState(() => _isStaffMode = false);
                            _loginAdmin();
                          },
                          icon: const Icon(Icons.admin_panel_settings),
                          label: const Text('Login as Admin'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.black,
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(vertical: 14),
                          ),
                        ),
                      ),
                      const SizedBox(height: 12),

                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton.icon(
                          onPressed: () {
                            setState(() => _isStaffMode = true);
                            _loginStaff();
                          },
                          icon: const Icon(Icons.badge),
                          label: const Text('Login as Staff / Carrier'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.blueAccent,
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(vertical: 14),
                          ),
                        ),
                      ),
                    ],
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
