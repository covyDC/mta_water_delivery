import 'package:flutter/material.dart';

class StaffDashboardPage extends StatelessWidget {
  const StaffDashboardPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Staff / Carrier Dashboard')),
      body: const Center(
        child: Text('Welcome, Staff/Carrier!', style: TextStyle(fontSize: 20)),
      ),
    );
  }
}
