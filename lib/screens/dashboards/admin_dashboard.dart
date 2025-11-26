import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:mta_water_delivery/services/reports_service.dart';
// ignore_for_file: use_build_context_synchronously
import 'package:mta_water_delivery/config/product_prices.dart';
import '../auth/register_staff.dart';

class AdminDashboardPage extends StatefulWidget {
  const AdminDashboardPage({super.key});

  @override
  State<AdminDashboardPage> createState() => _AdminDashboardPageState();
}

class _AdminDashboardPageState extends State<AdminDashboardPage> {
  int _selectedIndex = 0;
  final _firestore = FirebaseFirestore.instance;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Admin Dashboard'),
        backgroundColor: Colors.black87,
        actions: [
          IconButton(
            icon: const Icon(Icons.logout),
            onPressed: () {
              FirebaseAuth.instance.signOut();
              Navigator.of(context).pushNamedAndRemoveUntil('/', (r) => false);
            },
            tooltip: 'Logout',
          ),
        ],
      ),
      body: Row(
        children: [
          NavigationRail(
            selectedIndex: _selectedIndex,
            onDestinationSelected: (index) => setState(() => _selectedIndex = index),
            labelType: NavigationRailLabelType.all,
            destinations: const [
              NavigationRailDestination(
                icon: Icon(Icons.dashboard),
                selectedIcon: Icon(Icons.dashboard),
                label: Text('Dashboard'),
              ),
              NavigationRailDestination(
                icon: Icon(Icons.people_outline),
                selectedIcon: Icon(Icons.people),
                label: Text('Customers'),
              ),
              NavigationRailDestination(
                icon: Icon(Icons.badge_outlined),
                selectedIcon: Icon(Icons.badge),
                label: Text('Staff'),
              ),
              NavigationRailDestination(
                icon: Icon(Icons.local_shipping_outlined),
                selectedIcon: Icon(Icons.local_shipping),
                label: Text('Drivers'),
              ),
              NavigationRailDestination(
                icon: Icon(Icons.assessment_outlined),
                selectedIcon: Icon(Icons.assessment),
                label: Text('Reports'),
              ),
                  // Products management removed — product prices are fixed app-wide
            ],
          ),
          const VerticalDivider(width: 1),
          Expanded(
            child: _buildPage(),
          ),
        ],
      ),
    );
  }

  Widget _buildPage() {
    switch (_selectedIndex) {
      case 0:
        return _dashboardPage();
      case 1:
        return _customersPage();
      case 2:
        return _staffPage();
      case 3:
        return _driversPage();
      case 4:
        return _reportsPage();
      case 5:
        return _productsPage();
      default:
        return const Center(child: Text('Unknown page'));
    }
  }

  Widget _dashboardPage() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Welcome, Admin!', style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold)),
          const SizedBox(height: 32),
          const Text('Quick Actions', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: _actionCard(
                  title: 'Register Staff',
                  icon: Icons.person_add,
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(builder: (_) => const RegisterStaffPage()),
                    );
                  },
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: _actionCard(
                  title: 'View Orders',
                  icon: Icons.shopping_cart,
                  onTap: () => setState(() => _selectedIndex = 1),
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: _actionCard(
                  title: 'Manage Inventory',
                  icon: Icons.inventory_2,
                  onTap: () => ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Inventory management feature coming soon')),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 32),
          const Text('System Status', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
          const SizedBox(height: 16),
          _systemStatsCard(),
        ],
      ),
    );
  }

  Widget _actionCard({required String title, required IconData icon, required VoidCallback onTap}) {
    return Card(
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, size: 40, color: Colors.blueAccent),
              const SizedBox(height: 8),
              Text(title, textAlign: TextAlign.center, style: const TextStyle(fontWeight: FontWeight.bold)),
            ],
          ),
        ),
      ),
    );
  }

  Widget _systemStatsCard() {
    return FutureBuilder<List<int>>(
      future: _getSystemStats(),
      builder: (context, snapshot) {
        if (!snapshot.hasData) return const CircularProgressIndicator();
        final stats = snapshot.data!;
        return Row(
          children: [
            Expanded(
              child: Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    children: [
                      const Text('Customers', style: TextStyle(fontWeight: FontWeight.bold)),
                      Text('${stats[0]}', style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: Colors.blue)),
                    ],
                  ),
                ),
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    children: [
                      const Text('Staff', style: TextStyle(fontWeight: FontWeight.bold)),
                      Text('${stats[1]}', style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: Colors.green)),
                    ],
                  ),
                ),
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    children: [
                      const Text('Drivers', style: TextStyle(fontWeight: FontWeight.bold)),
                      Text('${stats[2]}', style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: Colors.orange)),
                    ],
                  ),
                ),
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _customersPage() {
    return StreamBuilder<QuerySnapshot>(
      stream: _firestore.collection('customers').snapshots(),
      builder: (context, snapshot) {
        if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());
        final customers = snapshot.data!.docs;
        return ListView(
          padding: const EdgeInsets.all(16),
          children: [
            const Text('Registered Customers', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
            const SizedBox(height: 16),
            if (customers.isEmpty)
              const Center(child: Text('No customers registered'))
            else
              ...customers.map((doc) => _customerTile(doc)),
          ],
        );
      },
    );
  }

  Widget _customerTile(QueryDocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: ListTile(
        leading: const Icon(Icons.person, color: Colors.blue),
        title: Text(data['fullName'] ?? 'Unknown'),
        subtitle: Text(data['email'] ?? data['contactNumber'] ?? 'No contact'),
        trailing: PopupMenuButton(
          itemBuilder: (context) => [
            PopupMenuItem(
              child: const Text('View Details'),
              onTap: () => _showCustomerDetails(context, doc.id, data),
            ),
            PopupMenuItem(
              child: const Text('Delete'),
              onTap: () => _deleteUser(doc.id, 'customer'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _staffPage() {
    return StreamBuilder<QuerySnapshot>(
      stream: _firestore.collection('staff').where('role', isEqualTo: 'on-site staff').snapshots(),
      builder: (context, snapshot) {
        if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());
        final staff = snapshot.data!.docs;
        return ListView(
          padding: const EdgeInsets.all(16),
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text('On-Site Staff', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
                ElevatedButton.icon(
                  onPressed: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(builder: (_) => const RegisterStaffPage()),
                    );
                  },
                  icon: const Icon(Icons.add),
                  label: const Text('Add Staff'),
                ),
              ],
            ),
            const SizedBox(height: 16),
            if (staff.isEmpty)
              const Center(child: Text('No staff members registered'))
            else
              ...staff.map((doc) => _staffTile(doc)),
          ],
        );
      },
    );
  }

  Widget _staffTile(QueryDocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: ListTile(
        leading: const Icon(Icons.badge, color: Colors.green),
        title: Text(data['name'] ?? 'Unknown'),
        subtitle: Text(data['email'] ?? 'No email'),
        trailing: PopupMenuButton(
          itemBuilder: (context) => [
            PopupMenuItem(
              child: const Text('Edit'),
              onTap: () => ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Edit feature coming soon')),
              ),
            ),
            PopupMenuItem(
              child: const Text('Delete'),
              onTap: () => _deleteUser(doc.id, 'staff'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _driversPage() {
    return StreamBuilder<QuerySnapshot>(
      stream: _firestore.collection('staff').where('role', isEqualTo: 'driver').snapshots(),
      builder: (context, snapshot) {
        if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());
        final drivers = snapshot.data!.docs;
        return ListView(
          padding: const EdgeInsets.all(16),
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text('Drivers', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
                ElevatedButton.icon(
                  onPressed: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(builder: (_) => const RegisterStaffPage()),
                    );
                  },
                  icon: const Icon(Icons.add),
                  label: const Text('Add Driver'),
                ),
              ],
            ),
            const SizedBox(height: 16),
            if (drivers.isEmpty)
              const Center(child: Text('No drivers registered'))
            else
              ...drivers.map((doc) => _driverTile(doc)),
          ],
        );
      },
    );
  }

  Widget _driverTile(QueryDocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: ListTile(
        leading: const Icon(Icons.local_shipping, color: Colors.orange),
        title: Text(data['name'] ?? 'Unknown'),
        subtitle: Text(data['email'] ?? 'No email'),
        trailing: PopupMenuButton(
          itemBuilder: (context) => [
            PopupMenuItem(
              child: const Text('View Details'),
              onTap: () => ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('View details feature coming soon')),
              ),
            ),
            PopupMenuItem(
              child: const Text('Delete'),
              onTap: () => _deleteUser(doc.id, 'driver'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _reportsPage() {
    final reportsService = ReportsService();
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Reports & Analytics', style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold)),
          const SizedBox(height: 32),
          
          // Orders Stats Section
          const Text('Orders Statistics', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
          const SizedBox(height: 16),
          FutureBuilder<Map<String, dynamic>>(
            future: reportsService.getOrdersStats(),
            builder: (context, snapshot) {
              if (!snapshot.hasData) return const CircularProgressIndicator();
              final stats = snapshot.data!;
              return Row(
                children: [
                  _statCard('Total Orders', '${stats['totalOrders'] ?? 0}', Colors.blue),
                  const SizedBox(width: 16),
                  _statCard('Completed', '${stats['completedOrders'] ?? 0}', Colors.green),
                  const SizedBox(width: 16),
                  _statCard('Pending', '${stats['pendingOrders'] ?? 0}', Colors.orange),
                  const SizedBox(width: 16),
                  _statCard('Revenue', '\$${(stats['totalRevenue'] ?? 0).toStringAsFixed(2)}', Colors.purple),
                ],
              );
            },
          ),
          const SizedBox(height: 32),

          // Deliveries Stats Section
          const Text('Deliveries Statistics', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
          const SizedBox(height: 16),
          FutureBuilder<Map<String, dynamic>>(
            future: reportsService.getDeliveriesStats(),
            builder: (context, snapshot) {
              if (!snapshot.hasData) return const CircularProgressIndicator();
              final stats = snapshot.data!;
              return Row(
                children: [
                  _statCard('Total', '${stats['totalDeliveries'] ?? 0}', Colors.blueAccent),
                  const SizedBox(width: 16),
                  _statCard('Completed', '${stats['completedDeliveries'] ?? 0}', Colors.green),
                  const SizedBox(width: 16),
                  _statCard('In Progress', '${stats['inProgressDeliveries'] ?? 0}', Colors.amber),
                  const SizedBox(width: 16),
                  _statCard('Avg Time', '${stats['avgDeliveryTime'] ?? 0}h', Colors.teal),
                ],
              );
            },
          ),
          const SizedBox(height: 32),

          // Staff Performance Section
          const Text('Staff Performance', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
          const SizedBox(height: 16),
          FutureBuilder<List<Map<String, dynamic>>>(
            future: reportsService.getStaffPerformance(),
            builder: (context, snapshot) {
              if (!snapshot.hasData) return const CircularProgressIndicator();
              final staffData = snapshot.data!;
              if (staffData.isEmpty) return const Text('No staff data available');
              return DataTable(
                columns: const [
                  DataColumn(label: Text('Name')),
                  DataColumn(label: Text('Role')),
                  DataColumn(label: Text('Deliveries')),
                  DataColumn(label: Text('Completed')),
                  DataColumn(label: Text('Rate')),
                ],
                rows: staffData.map((staff) => DataRow(cells: [
                  DataCell(Text(staff['name'] ?? 'Unknown')),
                  DataCell(Text(staff['role'] ?? 'Unknown')),
                  DataCell(Text('${staff['totalDeliveries'] ?? 0}')),
                  DataCell(Text('${staff['completedDeliveries'] ?? 0}')),
                  DataCell(Text('${staff['completionRate'] ?? 0}%')),
                ])).toList(),
              );
            },
          ),
          const SizedBox(height: 32),

          // Top Customers Section
          const Text('Top Customers', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
          const SizedBox(height: 16),
          FutureBuilder<List<Map<String, dynamic>>>(
            future: reportsService.getTopCustomers(),
            builder: (context, snapshot) {
              if (!snapshot.hasData) return const CircularProgressIndicator();
              final customers = snapshot.data!;
              if (customers.isEmpty) return const Text('No customer data available');
              return DataTable(
                columns: const [
                  DataColumn(label: Text('Customer')),
                  DataColumn(label: Text('Orders')),
                  DataColumn(label: Text('Revenue')),
                ],
                rows: customers.map((customer) => DataRow(cells: [
                  DataCell(Text(customer['name'] ?? 'Unknown')),
                  DataCell(Text('${customer['orders'] ?? 0}')),
                  DataCell(Text('\$${(customer['revenue'] ?? 0).toStringAsFixed(2)}')),
                ])).toList(),
              );
            },
          ),
        ],
      ),
    );
  }

  // ----- Products management removed -----
  // Product management UI has been removed. Product prices are fixed app-wide
  // and can be changed in `lib/config/product_prices.dart`.
  Widget _productsPage() {
    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Product pricing (fixed)', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
          const SizedBox(height: 12),
          Card(
            child: ListTile(
              leading: const Icon(Icons.water_drop),
              title: const Text('Gallon (5L)'),
              subtitle: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text('Refill only: ₱${ProductPrices.gallonPricing()['refill_only']!.toStringAsFixed(2)}'),
                Text('With new container: ₱${ProductPrices.gallonPricing()['with_container']!.toStringAsFixed(2)}'),
              ]),
            ),
          ),
          const SizedBox(height: 8),
          Card(
            child: ListTile(
              leading: const Icon(Icons.local_drink),
              title: const Text('Bottled Water'),
              subtitle: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                for (final e in ProductPrices.allBottledPrices().entries)
                  Text('${e.key.toUpperCase()} : ₱${e.value.toStringAsFixed(2)}'),
              ]),
            ),
          ),
          const SizedBox(height: 12),
          const Text('Product management (create/update/delete) has been removed and prices are fixed in the app config.'),
          const SizedBox(height: 8),
          const Text('To change pricing, update `lib/config/product_prices.dart` and redeploy the app.'),
        ],
      ),
    );
  }



  // Product management helper dialogs removed — product management is disabled
  // and product prices are fixed in `lib/config/product_prices.dart`.

  Widget _statCard(String label, String value, Color color) {
    return Expanded(
      child: Card(
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(8),
            color: color.withValues(alpha: 0.1),
            border: Border.all(color: color.withValues(alpha: 0.3)),
          ),
          child: Column(
            children: [
              Text(label, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
              const SizedBox(height: 8),
              Text(value, style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: color)),
            ],
          ),
        ),
      ),
    );
  }

  void _showCustomerDetails(BuildContext context, String customerId, Map<String, dynamic> data) {
    showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Customer Details'),
        content: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              _detailRow('Name:', data['fullName'] ?? 'N/A'),
              _detailRow('Email:', data['email'] ?? 'N/A'),
              _detailRow('Contact:', data['contactNumber'] ?? 'N/A'),
              _detailRow('Address:', data['address'] ?? 'N/A'),
            ],
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(dialogContext), child: const Text('Close')),
        ],
      ),
    );
  }

  Widget _detailRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
          Text(value, style: const TextStyle(fontSize: 14)),
        ],
      ),
    );
  }

  void _deleteUser(String userId, String userType) {
    showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Confirm Delete'),
        content: Text('Are you sure you want to delete this $userType?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(dialogContext), child: const Text('Cancel')),
          TextButton(
            onPressed: () async {
              Navigator.pop(dialogContext);
              try {
                if (userType == 'customer') {
                  await _firestore.collection('customers').doc(userId).delete();
                } else {
                  await _firestore.collection('staff').doc(userId).delete();
                }
                await _firestore.collection('users').doc(userId).delete();
                if (!mounted) return;
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text('$userType deleted successfully')),
                );
              } catch (e) {
                if (!mounted) return;
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text('Error deleting $userType: $e')),
                );
              }
            },
            child: const Text('Delete', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
  }

  Future<List<int>> _getSystemStats() async {
    final customersCount = await _firestore.collection('customers').count().get();
    final staffSnapshot = await _firestore.collection('staff').where('role', isEqualTo: 'on-site staff').count().get();
    final driversSnapshot = await _firestore.collection('staff').where('role', isEqualTo: 'driver').count().get();
    return [customersCount.count ?? 0, staffSnapshot.count ?? 0, driversSnapshot.count ?? 0];
  }
}
