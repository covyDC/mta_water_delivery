import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class RegisterStaffPage extends StatefulWidget {
  const RegisterStaffPage({super.key});

  @override
  State<RegisterStaffPage> createState() => _RegisterStaffPageState();
}

class _RegisterStaffPageState extends State<RegisterStaffPage> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _nameController = TextEditingController();

  bool _isLoading = false;
  String _selectedRole = 'on-site staff'; // Default role

  Future<void> _registerStaff() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _isLoading = true);

    try {
      // Convert display role to system role
      final systemRole = _selectedRole == 'on-site staff' ? 'staff' : 'driver';
      final email = _emailController.text.trim();
      final password = _passwordController.text.trim();
      final name = _nameController.text.trim();

      // 1️⃣ Create Firebase Auth user
      final userCredential = await FirebaseAuth.instance.createUserWithEmailAndPassword(
        email: email,
        password: password,
      );
      final uid = userCredential.user!.uid;

      // 2️⃣ Save to Firestore users collection with role
      await FirebaseFirestore.instance.collection('users').doc(uid).set({
        'uid': uid,
        'email': email,
        'role': systemRole, // 'staff' or 'driver'
        'name': name,
        'createdAt': FieldValue.serverTimestamp(),
      });

      // 3️⃣ Save to Firestore staff collection
      await FirebaseFirestore.instance.collection('staff').doc(uid).set({
        'name': name,
        'email': email,
        'role': _selectedRole, // 'on-site staff' or 'driver' (display name)
        'status': 'online',
        'inventory': {
          'full': 0,
          'empty': 0,
          'refillReturned': 0,
        },
        'createdAt': FieldValue.serverTimestamp(),
      });

      if (!mounted) return;
      
      // Show success dialog
      showDialog(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Registration Successful'),
          content: Text('$name has been registered as $systemRole'),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.pop(context); // Close dialog
                Navigator.pop(context); // Return to admin page
              },
              child: const Text('OK'),
            ),
          ],
        ),
      );
    } on FirebaseAuthException catch (e) {
      if (!mounted) return;
      String errorMessage = 'Failed to register staff';
      if (e.code == 'weak-password') {
        errorMessage = 'Password is too weak';
      } else if (e.code == 'email-already-in-use') {
        errorMessage = 'Email is already registered';
      } else if (e.code == 'invalid-email') {
        errorMessage = 'Invalid email address';
      } else if (e.code == 'operation-not-allowed') {
        errorMessage = 'Email/Password registration is disabled';
      }
      
      showDialog(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Registration Failed'),
          content: Text(errorMessage),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('OK'),
            ),
          ],
        ),
      );
    } on FirebaseException catch (e) {
      if (!mounted) return;
      
      // Print detailed error for debugging
      print('🔥 Firestore Error: ${e.code} - ${e.message}');
      
      String errorMessage = 'Database error: ${e.message}';
      if (e.code == 'permission-denied') {
        errorMessage = 'Permission denied. Check Firestore rules or admin status.';
      }
      
      showDialog(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Registration Failed'),
          content: Text(errorMessage),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('OK'),
            ),
          ],
        ),
      );
    } catch (e) {
      if (!mounted) return;
      
      showDialog(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Registration Failed'),
          content: Text('An error occurred: $e'),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('OK'),
            ),
          ],
        ),
      );
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Register Staff / Carrier')),
      body: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Form(
          key: _formKey,
          child: SingleChildScrollView(
            child: Column(
              children: [
                const Text(
                  'Add New Staff / Carrier',
                  style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 24),

                TextFormField(
                  controller: _nameController,
                  decoration: const InputDecoration(
                    labelText: 'Full Name',
                    border: OutlineInputBorder(),
                    prefixIcon: Icon(Icons.person_outline),
                  ),
                  validator: (value) =>
                      value == null || value.isEmpty ? 'Enter name' : null,
                ),
                const SizedBox(height: 16),

                TextFormField(
                  controller: _emailController,
                  decoration: const InputDecoration(
                    labelText: 'Staff Email',
                    border: OutlineInputBorder(),
                    prefixIcon: Icon(Icons.email_outlined),
                  ),
                  validator: (value) =>
                      value == null || value.isEmpty ? 'Enter email' : null,
                ),
                const SizedBox(height: 16),

                TextFormField(
                  controller: _passwordController,
                  decoration: const InputDecoration(
                    labelText: 'Password',
                    border: OutlineInputBorder(),
                    prefixIcon: Icon(Icons.lock_outline),
                  ),
                  obscureText: true,
                  validator: (value) => value == null || value.length < 6
                      ? 'Password must be at least 6 characters'
                      : null,
                ),
                const SizedBox(height: 16),

                DropdownButtonFormField<String>(
                  initialValue: _selectedRole,
                  decoration: const InputDecoration(
                    labelText: 'Staff Role',
                    border: OutlineInputBorder(),
                    prefixIcon: Icon(Icons.badge_outlined),
                  ),
                  items: const [
                    DropdownMenuItem(
                      value: 'on-site staff',
                      child: Text('On-Site Staff'),
                    ),
                    DropdownMenuItem(
                      value: 'driver',
                      child: Text('Driver'),
                    ),
                  ],
                  onChanged: (value) {
                    if (value != null) {
                      setState(() => _selectedRole = value);
                    }
                  },
                ),

                const SizedBox(height: 24),

                _isLoading
                    ? const CircularProgressIndicator()
                    : ElevatedButton.icon(
                        onPressed: _registerStaff,
                        icon: const Icon(Icons.person_add),
                        label: const Text('Register Staff'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.green,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(
                            vertical: 14,
                            horizontal: 32,
                          ),
                        ),
                      ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
