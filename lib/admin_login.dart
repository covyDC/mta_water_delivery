import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';   // <-- IMPORTANT
import 'admin_dashboard.dart';
import 'staff_dashboard.dart';

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

  // Embedded admin credentials
  final String _adminUsername = 'admin';
  final String _adminPassword = '12345678';

  /// ============================
  /// Local Admin Login
  /// ============================
  Future<void> _loginAdmin() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _isLoading = true);

    await Future.delayed(const Duration(seconds: 1));

    if (_usernameController.text.trim() == _adminUsername &&
        _passwordController.text.trim() == _adminPassword) {
      if (!mounted) return;
      setState(() => _isLoading = false);

      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (_) => const AdminDashboardPage()),
      );
    } else {
      if (!mounted) return;
      setState(() => _isLoading = false);

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Invalid admin credentials')),
      );
    }
  }

  /// ============================
  /// Firestore Staff/Carrier Login (NOT FirebaseAuth)
  /// ============================
  Future<void> _loginStaff() async {
  if (!_formKey.currentState!.validate()) return;

  setState(() => _isLoading = true);

  try {
    final email = _usernameController.text.trim();
    final password = _passwordController.text.trim();

    // 🔍 Search for staff in Firestore
    final snapshot = await FirebaseFirestore.instance
        .collection('staff')
        .where('email', isEqualTo: email)
        .limit(1)
        .get();

    if (snapshot.docs.isEmpty) {
      throw Exception('No staff account found with that email');
    }

    final staff = snapshot.docs.first.data();

    // Add Firestore document ID (IMPORTANT)
    staff['id'] = snapshot.docs.first.id;

    // 🔐 Compare plain password
    if (staff['password'] != password) {
      throw Exception('Incorrect staff password');
    }

    if (!mounted) return;
    setState(() => _isLoading = false);

    // ✅ FIX: Pass staff map into dashboard
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(
        builder: (_) => StaffDashboardPage(staff: staff),
      ),
    );

  } catch (e) {
    if (!mounted) return;

    setState(() => _isLoading = false);

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
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Text(
                  'Admin & Staff Portal',
                  style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 24),

                // Username / Email
                TextFormField(
                  controller: _usernameController,
                  decoration: const InputDecoration(
                    labelText: 'Username or Email',
                    border: OutlineInputBorder(),
                    prefixIcon: Icon(Icons.person_outline),
                  ),
                  validator: (value) =>
                      value == null || value.isEmpty ? 'Enter username or email' : null,
                ),
                const SizedBox(height: 16),

                // Password
                TextFormField(
                  controller: _passwordController,
                  decoration: const InputDecoration(
                    labelText: 'Password',
                    border: OutlineInputBorder(),
                    prefixIcon: Icon(Icons.lock_outline),
                  ),
                  obscureText: true,
                  validator: (value) =>
                      value == null || value.isEmpty ? 'Enter password' : null,
                ),
                const SizedBox(height: 24),

                if (_isLoading)
                  const CircularProgressIndicator()
                else
                  Column(
                    children: [
                      // Admin Login Button
                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton.icon(
                          onPressed: _loginAdmin,
                          icon: const Icon(Icons.admin_panel_settings),
                          label: const Text('Login as Admin'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.black87,
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(vertical: 14),
                          ),
                        ),
                      ),
                      const SizedBox(height: 12),

                      // Staff Login Button
                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton.icon(
                          onPressed: _loginStaff,
                          icon: const Icon(Icons.badge_outlined),
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
