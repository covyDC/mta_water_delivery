// staff_dashboard_fixed.dart
// Full Staff/Carrier Dashboard integrated with Cloud Firestore + Firebase Storage
// Fixed to avoid using BuildContext across async gaps and to properly guard with `mounted`.

import 'dart:io';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:mta_water_delivery/services/firestore_service.dart';
import 'package:mta_water_delivery/widgets/driver_selection_dialog.dart';

class StaffDashboardPage extends StatefulWidget {
  final Map<String, dynamic> staff;

  const StaffDashboardPage({super.key, required this.staff});

  @override
  State<StaffDashboardPage> createState() => _StaffDashboardPageState();
}

class _StaffDashboardPageState extends State<StaffDashboardPage> {
  int _selectedIndex = 0;
  late final Map<String, dynamic> staff;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final ImagePicker _picker = ImagePicker();

  @override
  void initState() {
    super.initState();
    staff = widget.staff;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('On-Site Staff Dashboard (${staff['name'] ?? ''})'),
        actions: [
          IconButton(
            icon: const Icon(Icons.logout),
            onPressed: () => Navigator.of(context).pop(),
            tooltip: 'Logout',
          ),
        ],
      ),
      body: LayoutBuilder(builder: (ctx, constraints) {
        final useRail = constraints.maxWidth >= 700;
        if (useRail) {
          return Row(
            children: [
              NavigationRail(
                selectedIndex: _selectedIndex,
                onDestinationSelected: (index) => setState(() => _selectedIndex = index),
                labelType: NavigationRailLabelType.all,
                destinations: const [
                  NavigationRailDestination(
                    icon: Icon(Icons.shopping_cart_outlined),
                    selectedIcon: Icon(Icons.shopping_cart),
                    label: Text('Orders'),
                  ),
                  NavigationRailDestination(
                    icon: Icon(Icons.inventory_2_outlined),
                    selectedIcon: Icon(Icons.inventory_2),
                    label: Text('Inventory'),
                  ),
                  NavigationRailDestination(
                    icon: Icon(Icons.local_shipping_outlined),
                    selectedIcon: Icon(Icons.local_shipping),
                    label: Text('Assign'),
                  ),
                  NavigationRailDestination(
                    icon: Icon(Icons.list_alt_outlined),
                    selectedIcon: Icon(Icons.list_alt),
                    label: Text('Activity'),
                  ),
                  NavigationRailDestination(
                    icon: Icon(Icons.notifications_outlined),
                    selectedIcon: Icon(Icons.notifications),
                    label: Text('Notifications'),
                  ),
                  NavigationRailDestination(
                    icon: Icon(Icons.person_outline),
                    selectedIcon: Icon(Icons.person),
                    label: Text('Profile'),
                  ),
                ],
              ),
              const VerticalDivider(width: 1),
              Expanded(child: _buildPage()),
            ],
          );
        }

        return Column(
          children: [
            Expanded(child: _buildPage()),
            SafeArea(
              child: BottomNavigationBar(
                currentIndex: _selectedIndex,
                onTap: (idx) => setState(() => _selectedIndex = idx),
                type: BottomNavigationBarType.fixed,
                items: const [
                  BottomNavigationBarItem(icon: Icon(Icons.shopping_cart_outlined), label: 'Orders'),
                  BottomNavigationBarItem(icon: Icon(Icons.inventory_2_outlined), label: 'Inventory'),
                  BottomNavigationBarItem(icon: Icon(Icons.local_shipping_outlined), label: 'Assign'),
                  BottomNavigationBarItem(icon: Icon(Icons.list_alt_outlined), label: 'Activity'),
                  BottomNavigationBarItem(icon: Icon(Icons.notifications_outlined), label: 'Notifications'),
                  BottomNavigationBarItem(icon: Icon(Icons.person_outline), label: 'Profile'),
                ],
              ),
            ),
          ],
        );
      }),
    );
  }

  Widget _buildPage() {
    switch (_selectedIndex) {
      case 0:
        return _notificationsPage(); // Orders/Notifications for confirmation
      case 1:
        return _inventoryPage();
      case 2:
        return _assignedDeliveriesPage(); // Assignment page
      case 3:
        return _activityPage();
      case 4:
        return _completedDeliveriesPage(); // Notifications repurposed
      case 5:
        return _profilePage();
      default:
        return _assignedDeliveriesPage();
    }
  }

  // ------------------- Assigned Deliveries -------------------
  Widget _assignedDeliveriesPage() {
    // deliveries collection schema (example):
    // deliveries/{deliveryId} { assignedTo: staffId, status: 'assigned'|'on_the_way'|'completed'|'failed', customerName, address, phone, gallons, paymentType, notes, invoice }

    return StreamBuilder<QuerySnapshot>(
      stream: _firestore
          .collection('deliveries')
          .where('assignedTo', isEqualTo: staff['id'])
          .where('status', whereIn: ['assigned', 'on_the_way'])
          .orderBy('scheduledAt', descending: false)
          .snapshots(),
      builder: (context, snapshot) {
        if (snapshot.hasError) return Center(child: Text('Error: ${snapshot.error}'));
        if (snapshot.connectionState == ConnectionState.waiting) return const Center(child: CircularProgressIndicator());

        final docs = snapshot.data?.docs ?? [];
        if (docs.isEmpty) return const Center(child: Text('No assigned deliveries.'));

        return ListView.builder(
          padding: const EdgeInsets.all(16),
          itemCount: docs.length,
            itemBuilder: (context, index) {
            final doc = docs[index];
            final d = doc.data() as Map<String, dynamic>;

            final customerName = d['customerName'] ?? d['customer_name'] ?? 'Unknown';
            final customerPhone = d['phone'] ?? d['contact'] ?? '';
            final customerEmail = d['email'] ?? '';
            final customerAddress = d['address'] ?? '';

            final productType = d['product_type'] ?? d['productType'] ?? 'Order';
            final qty = d['gallons']?.toString() ?? d['quantity']?.toString() ?? '-';
            final opts = d['options'] is Map ? (d['options'] as Map).entries.map((e) => '${e.key}:${e.value}').join(', ') : '';

            return Card(
              elevation: 2,
              margin: const EdgeInsets.symmetric(vertical: 8),
              child: ExpansionTile(
                leading: const Icon(Icons.local_shipping),
                title: Text(customerName),
                subtitle: Text('$productType • Qty: $qty'),
                childrenPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                children: [
                  if (customerEmail.isNotEmpty) Row(children: [const Icon(Icons.email, size: 16), const SizedBox(width: 8), Expanded(child: Text(customerEmail))]),
                  if (customerPhone.isNotEmpty) Row(children: [const Icon(Icons.phone, size: 16), const SizedBox(width: 8), Expanded(child: Text(customerPhone))]),
                  if (customerAddress.isNotEmpty) Row(children: [const Icon(Icons.location_on, size: 16), const SizedBox(width: 8), Expanded(child: Text(customerAddress))]),
                  const SizedBox(height: 6),
                  Text('Gallons: ${_formatGallons(d['gallons'])} • Payment: ${d['paymentType'] ?? 'N/A'}'),
                  if (opts.isNotEmpty) Padding(padding: const EdgeInsets.only(top: 6), child: Text('Options: $opts', style: const TextStyle(fontSize: 12, color: Colors.grey))),
                  const Divider(),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      PopupMenuButton<String>(
                        onSelected: (action) => _handleAssignedAction(action, doc.id, d),
                        itemBuilder: (_) => [
                          const PopupMenuItem(value: 'accept', child: Text('Accept')),
                          const PopupMenuItem(value: 'start', child: Text('Start / Navigate')),
                          const PopupMenuItem(value: 'deliver', child: Text('Mark Delivered')),
                          const PopupMenuItem(value: 'fail', child: Text('Mark Failed')),
                        ],
                      ),
                      const SizedBox(width: 8),
                      ElevatedButton(onPressed: () => _openDeliveryDetails(doc.id, d), child: const Text('Details')),
                    ],
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  String _formatGallons(dynamic gallons) {
    if (gallons == null) return '-';
    if (gallons is Map) {
      final parts = gallons.entries.map((e) => '${e.key}: ${e.value}').join(', ');
      return parts;
    }
    return gallons.toString();
  }

  Future<void> _handleAssignedAction(String action, String id, Map d) async {
    switch (action) {
      case 'accept':
        await _firestore.collection('deliveries').doc(id).update({'status': 'on_the_way'});
        await _logActivity('Accepted delivery $id');
        break;
      case 'start':
        await _openMapForAddress(d['address']);
        await _firestore.collection('deliveries').doc(id).update({'status': 'on_the_way'});
        await _logActivity('Started delivery $id');
        break;
      case 'deliver':
        await _markAsDelivered(id);
        break;
      case 'fail':
        await _firestore.collection('deliveries').doc(id).update({'status': 'failed'});
        await _logActivity('Marked failed $id');
        break;
    }
  }

  Future<void> _markAsDelivered(String id) async {
    await _firestore.collection('deliveries').doc(id).update({
      'status': 'completed',
      'deliveredAt': FieldValue.serverTimestamp(),
    });
    await _logActivity('Delivered $id');
  }

  Future<void> _openMapForAddress(String? address) async {
    if (address == null) return;
    final query = Uri.encodeComponent(address);
    final url = Uri.parse('https://www.google.com/maps/search/?api=1&query=$query');
    if (await canLaunchUrl(url)) await launchUrl(url);
  }

  // ------------------- Completed Deliveries -------------------
  Widget _completedDeliveriesPage() {
    return StreamBuilder<QuerySnapshot>(
      stream: _firestore
          .collection('deliveries')
          .where('assignedTo', isEqualTo: staff['id'])
          .where('status', isEqualTo: 'completed')
          .orderBy('deliveredAt', descending: true)
          .snapshots(),
      builder: (context, snapshot) {
        if (snapshot.hasError) return Center(child: Text('Error: ${snapshot.error}'));
        if (snapshot.connectionState == ConnectionState.waiting) return const Center(child: CircularProgressIndicator());

        final docs = snapshot.data?.docs ?? [];
        if (docs.isEmpty) return const Center(child: Text('No completed deliveries yet.'));

        return ListView.builder(
          padding: const EdgeInsets.all(16),
          itemCount: docs.length,
          itemBuilder: (context, index) {
            final d = docs[index].data() as Map<String, dynamic>;
            return Card(
              elevation: 1,
              margin: const EdgeInsets.symmetric(vertical: 6),
              child: ListTile(
                leading: const Icon(Icons.check_circle),
                title: Text(d['customerName'] ?? 'Unknown'),
                subtitle: Text('Delivered: ${d['address'] ?? '-'}'),
                onTap: () => _openDeliveryDetails(docs[index].id, d),
              ),
            );
          },
        );
      },
    );
  }

  // ------------------- Inventory Page -------------------
  Widget _inventoryPage() {
    // We'll read/update a staff subcollection `vehicle_inventory` or a field on staff doc
    final staffDoc = _firestore.collection('staff').doc(staff['id']);

    return StreamBuilder<DocumentSnapshot>(
      stream: staffDoc.snapshots(),
      builder: (context, snapshot) {
        if (snapshot.hasError) return Center(child: Text('Error: ${snapshot.error}'));
        if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());

        final data = snapshot.data!.data() as Map<String, dynamic>? ?? {};
        final inventory = data['inventory'] as Map<String, dynamic>? ?? {};

        return Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('Inventory Tracker', style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
              const SizedBox(height: 12),
              // Show main counts
              Text('Full gallons loaded: ${inventory['full'] ?? 0}'),
              Text('Empty gallons collected: ${inventory['empty'] ?? 0}'),
              Text('Refill gallons returned: ${inventory['refillReturned'] ?? 0}'),
              const SizedBox(height: 12),
              const Text('Gallon product SKUs', style: TextStyle(fontWeight: FontWeight.bold)),
              const SizedBox(height: 6),
              Text('Gallon — refill only: ${inventory['gallon_refill'] ?? 0}'),
              Text('Gallon — with new container: ${inventory['gallon_with_container'] ?? 0}'),
              const SizedBox(height: 12),
              const Text('Bottled product SKUs', style: TextStyle(fontWeight: FontWeight.bold)),
              const SizedBox(height: 6),
              Text('350ml bottles: ${inventory['350ml'] ?? 0}'),
              Text('500ml bottles: ${inventory['500ml'] ?? 0}'),
              Text('1L bottles: ${inventory['1l'] ?? 0}'),
              Text('1.5L bottles: ${inventory['1_5l'] ?? 0}'),
              Text('5L bottles: ${inventory['5l'] ?? 0}'),
              const SizedBox(height: 12),
              ElevatedButton(
                onPressed: () async => _showEditInventoryDialog(inventory),
                child: const Text('Update Inventory'),
              ),
              const SizedBox(height: 20),
              const Text('Quick actions', style: TextStyle(fontWeight: FontWeight.bold)),
              Wrap(spacing: 8, children: [
                ElevatedButton.icon(
                  onPressed: () => _incrementInventoryField('full', 1),
                  icon: const Icon(Icons.add),
                  label: const Text('+1 Full'),
                ),
                ElevatedButton.icon(
                  onPressed: () => _incrementInventoryField('empty', 1),
                  icon: const Icon(Icons.remove),
                  label: const Text('+1 Empty'),
                ),
                // quick increments for new SKUs
                ElevatedButton.icon(onPressed: () => _incrementInventoryField('gallon_refill', 1), icon: const Icon(Icons.add), label: const Text('+1 Gallon (Refill)')),
                ElevatedButton.icon(onPressed: () => _incrementInventoryField('gallon_with_container', 1), icon: const Icon(Icons.add), label: const Text('+1 Gallon (With container)')),
                ElevatedButton.icon(onPressed: () => _incrementInventoryField('500ml', 1), icon: const Icon(Icons.add), label: const Text('+1 500ml')),
                ElevatedButton.icon(onPressed: () => _incrementInventoryField('1_5l', 1), icon: const Icon(Icons.add), label: const Text('+1 1.5L')),
                ElevatedButton.icon(onPressed: () => _incrementInventoryField('5l', 1), icon: const Icon(Icons.add), label: const Text('+1 5L')),
              ])
            ],
          ),
        );
      },
    );
  }

  Future<void> _showEditInventoryDialog(Map<String, dynamic> inventory) async {
    final fullCtrl = TextEditingController(text: (inventory['full'] ?? 0).toString());
    final emptyCtrl = TextEditingController(text: (inventory['empty'] ?? 0).toString());
    final refillCtrl = TextEditingController(text: (inventory['refillReturned'] ?? 0).toString());
    final gallonRefillCtrl = TextEditingController(text: (inventory['gallon_refill'] ?? 0).toString());
    final gallonWithContainerCtrl = TextEditingController(text: (inventory['gallon_with_container'] ?? 0).toString());
    final b350Ctrl = TextEditingController(text: (inventory['350ml'] ?? 0).toString());
    final b500Ctrl = TextEditingController(text: (inventory['500ml'] ?? 0).toString());
    final b1lCtrl = TextEditingController(text: (inventory['1l'] ?? 0).toString());
    final b1_5lCtrl = TextEditingController(text: (inventory['1_5l'] ?? 0).toString());
    final b5lCtrl = TextEditingController(text: (inventory['5l'] ?? 0).toString());

    // capture the widget context _before_ opening dialog
    final widgetContext = context;

    await showDialog<void>(
      context: widgetContext,
      builder: (dialogCtx) {
        // use dialogCtx (local) inside builder
        return AlertDialog(
          title: const Text('Edit Inventory'),
          content: SingleChildScrollView(
            child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(controller: fullCtrl, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'Full')),
              TextField(controller: emptyCtrl, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'Empty')),
              TextField(controller: refillCtrl, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'Refill Returned')),
              const SizedBox(height: 8),
              const Text('Gallon SKUs', style: TextStyle(fontWeight: FontWeight.bold)),
              TextField(controller: gallonRefillCtrl, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'Gallon — Refill only')),
              TextField(controller: gallonWithContainerCtrl, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'Gallon — With new container')),
              const SizedBox(height: 8),
              const Text('Bottled SKUs', style: TextStyle(fontWeight: FontWeight.bold)),
              TextField(controller: b350Ctrl, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: '350ml')),
              TextField(controller: b500Ctrl, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: '500ml')),
              TextField(controller: b1lCtrl, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: '1L')),
              TextField(controller: b1_5lCtrl, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: '1.5L')),
              TextField(controller: b5lCtrl, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: '5L')),
            ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogCtx).pop(),
              child: const Text('Cancel'),
            ),

            ElevatedButton(
              onPressed: () async {
                // capture anything needed BEFORE awaiting (navigator & doc ref)
                final nav = Navigator.of(dialogCtx);
                final staffDoc = _firestore.collection('staff').doc(staff['id']);

                await staffDoc.set({
                  'inventory': {
                    'full': int.tryParse(fullCtrl.text) ?? 0,
                    'empty': int.tryParse(emptyCtrl.text) ?? 0,
                    'refillReturned': int.tryParse(refillCtrl.text) ?? 0,
                    'gallon_refill': int.tryParse(gallonRefillCtrl.text) ?? 0,
                    'gallon_with_container': int.tryParse(gallonWithContainerCtrl.text) ?? 0,
                    '350ml': int.tryParse(b350Ctrl.text) ?? 0,
                    '500ml': int.tryParse(b500Ctrl.text) ?? 0,
                    '1l': int.tryParse(b1lCtrl.text) ?? 0,
                    '1_5l': int.tryParse(b1_5lCtrl.text) ?? 0,
                    '5l': int.tryParse(b5lCtrl.text) ?? 0,
                  }
                }, SetOptions(merge: true));

                if (!mounted) return; // guard widget state

                await _logActivity('Updated inventory');

                if (!mounted) return;

                // use the navigator captured earlier (no async gap on navigator)
                nav.pop();
              },
              child: const Text('Save'),
            ),
          ],
        );
      },
    );

    // controllers cleaned up by GC when out of scope; if you prefer explicit dispose,
    // you could keep them as fields and dispose in dispose().
  }

  Future<void> _incrementInventoryField(String key, int delta) async {
    final staffDoc = _firestore.collection('staff').doc(staff['id']);
    await staffDoc.set({
      'inventory': {key: FieldValue.increment(delta)}
    }, SetOptions(merge: true));
    await _logActivity('Inventory $key incremented by $delta');
  }

  // ------------------- Activity Page -------------------
  Widget _activityPage() {
    final col = _firestore.collection('activity_logs').doc(staff['id']).collection('logs').orderBy('timestamp', descending: true);

    return StreamBuilder<QuerySnapshot>(
      stream: col.snapshots(),
      builder: (context, snapshot) {
        if (snapshot.hasError) return Center(child: Text('Error: ${snapshot.error}'));
        if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());

        final docs = snapshot.data!.docs;
        if (docs.isEmpty) return const Center(child: Text('No activity yet.'));

        return ListView.builder(
          padding: const EdgeInsets.all(16),
          itemCount: docs.length,
          itemBuilder: (context, index) {
            final d = docs[index].data() as Map<String, dynamic>;
            return ListTile(
              leading: const Icon(Icons.history),
              title: Text(d['action'] ?? '-'),
              subtitle: Text(d['timestamp'] != null ? (d['timestamp'] as Timestamp).toDate().toString() : '-'),
            );
          },
        );
      },
    );
  }

  Future<void> _logActivity(String action) async {
    final ref = _firestore.collection('activity_logs').doc(staff['id']).collection('logs');
    await ref.add({
      'action': action,
      'timestamp': FieldValue.serverTimestamp(),
    });
  }

  // ------------------- Notifications Page -------------------
  Widget _notificationsPage() {
    // We'll show pending orders first so staff can confirm availability, then regular notifications
    return Column(
      children: [
        Expanded(
          flex: 1,
          child: StreamBuilder<QuerySnapshot>(
            stream: FirestoreService.streamPendingOrders(),
            builder: (context, snapshot) {
              if (snapshot.hasError) return Center(child: Text('Orders error: ${snapshot.error}'));
              if (snapshot.connectionState == ConnectionState.waiting) return const Center(child: CircularProgressIndicator());

              final docs = snapshot.data?.docs ?? [];
              if (docs.isEmpty) return const Center(child: Text('No pending orders.'));

              return ListView.builder(
                padding: const EdgeInsets.all(12),
                itemCount: docs.length,
                itemBuilder: (context, index) {
                  final d = docs[index].data() as Map<String, dynamic>;
                  final id = docs[index].id;

                  // We'll try to resolve a customer document for the order so
                  // that staff sees the customer's full name (not an email).
                  return FutureBuilder<DocumentSnapshot?>(
                    future: _lookupCustomerForOrder(d),
                    builder: (ctx, customerSnap) {
                      final customer = customerSnap.data?.data() as Map<String, dynamic>?;

                      // prefer a proper full-name (customer record), avoid showing
                      // email-like strings as the 'name'
                      final rawName = (d['customer_name'] ?? '')?.toString() ?? '';
                      bool looksLikeEmail(String s) => s.contains('@') && s.contains('.');
                      String customerName = '';
                      if (customer != null) {
                        customerName = (customer['fullName'] ?? customer['name'] ?? '').toString();
                      }
                      if (customerName.isEmpty) {
                        // If order has a name that isn't an email use it
                        if (rawName.isNotEmpty && !looksLikeEmail(rawName)) customerName = rawName;
                      }
                      if (customerName.isEmpty) customerName = 'Unknown';
                      final customerEmail = (customer?['email'] ?? d['customer_email'] ?? d['email'])?.toString() ?? '';
                      final customerPhone = (customer?['contactNumber'] ?? d['phone'] ?? d['contact'])?.toString() ?? '';
                      final customerAddress = (d['address'] ?? customer?['address'])?.toString() ?? '';

                      // Render order details (product / quantity / options) as a small section
                      final productType = d['product_type'] ?? d['productType'] ?? 'Order';
                      final qty = d['quantity']?.toString() ?? '-';
                      final options = d['options'] is Map ? (d['options'] as Map).entries.map((e) => '${e.key}:${e.value}').join(', ') : '';

                      return Card(
                        margin: const EdgeInsets.symmetric(vertical: 6),
                        child: ExpansionTile(
                          leading: const Icon(Icons.shopping_bag),
                          title: Text(customerName),
                          subtitle: Text('$productType • Qty: $qty'),
                          childrenPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                          children: [
                            if (customerEmail.isNotEmpty) Padding(
                              padding: const EdgeInsets.only(bottom: 6),
                              child: Row(children: [const Icon(Icons.email, size: 16), const SizedBox(width: 8), Expanded(child: Text(customerEmail))]),
                            ),
                            if (customerPhone.isNotEmpty) Padding(
                              padding: const EdgeInsets.only(bottom: 6),
                              child: Row(children: [const Icon(Icons.phone, size: 16), const SizedBox(width: 8), Expanded(child: Text(customerPhone))]),
                            ),
                            if (customerAddress.isNotEmpty) Padding(
                              padding: const EdgeInsets.only(bottom: 6),
                              child: Row(children: [const Icon(Icons.location_on, size: 16), const SizedBox(width: 8), Expanded(child: Text(customerAddress))]),
                            ),
                            const Divider(),
                            // If there's an 'items' list, show detailed itemized view, otherwise fall back to product_type/quantity/options
                            if (d['items'] is List && (d['items'] as List).isNotEmpty) ...[
                              const Text('Items:', style: TextStyle(fontWeight: FontWeight.bold)),
                              const SizedBox(height: 6),
                              ...((d['items'] as List).map((it) {
                                final item = it is Map ? Map<String, dynamic>.from(it) : <String, dynamic>{};
                                final name = item['name'] ?? item['product_type'] ?? item['productType'] ?? 'Product';
                                final q = item['quantity']?.toString() ?? '-';
                                final opts = (item['options'] is Map) ? (item['options'] as Map).entries.map((e) => '${e.key}:${e.value}').join(', ') : '';
                                return Padding(
                                  padding: const EdgeInsets.only(bottom: 6),
                                  child: Row(children: [Expanded(child: Text('$name • Qty: $q')), if (opts.isNotEmpty) Text(opts, style: const TextStyle(fontSize: 12, color: Colors.grey))]),
                                );
                              }).toList())
                            ] else ...[
                              Row(children: [Expanded(child: Text('Product: $productType')), Text('Qty: $qty')]),
                              if (options.isNotEmpty) Padding(padding: const EdgeInsets.only(top: 6), child: Text('Options: $options', style: const TextStyle(fontSize: 12, color: Colors.grey))),
                            ],
                            const SizedBox(height: 8),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.end,
                              children: [
                                ElevatedButton(
                                  onPressed: () => _showPreConfirmDialog(id, d),
                                  child: const Text('Confirm'),
                                ),
                              ],
                            ),
                          ],
                        ),
                      );
                    },
                  );
                },
              );
            },
          ),
        ),
        const Divider(height: 1),

        Expanded(
          flex: 1,
          child: StreamBuilder<QuerySnapshot>(
            stream: _firestore.collection('notifications').where('toStaffId', isEqualTo: staff['id']).orderBy('createdAt', descending: true).snapshots(),
            builder: (context, snapshot) {
              if (snapshot.hasError) return Center(child: Text('Error: ${snapshot.error}'));
              if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());

              final docs = snapshot.data!.docs;
              if (docs.isEmpty) return const Center(child: Text('No notifications.'));

              return ListView.builder(
                padding: const EdgeInsets.all(16),
                itemCount: docs.length,
                itemBuilder: (context, index) {
                  final d = docs[index].data() as Map<String, dynamic>;
                  return ListTile(
                    leading: const Icon(Icons.notifications),
                    title: Text(d['title'] ?? '-'),
                    subtitle: Text(d['body'] ?? '-'),
                    trailing: Text(d['createdAt'] != null ? (d['createdAt'] as Timestamp).toDate().toLocal().toString().split('.')[0] : ''),
                  );
                },
              );
            },
          ),
        ),
      ],
    );
  }

  // ------------------- Profile Page -------------------
  Widget _profilePage() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.person, size: 80),
          const SizedBox(height: 15),
          Text(staff['name'] ?? 'Unknown Staff', style: const TextStyle(fontSize: 22)),
          const SizedBox(height: 6),
          Text(staff['email'] ?? 'No email', style: const TextStyle(fontSize: 16)),
          const SizedBox(height: 6),
          Text('Role: ${staff['role'] ?? 'carrier'}', style: const TextStyle(fontSize: 16)),
          const SizedBox(height: 12),
          ElevatedButton(onPressed: () => _changeStatusDialog(), child: const Text('Change Status')),
        ],
      ),
    );
  }

  Future<void> _changeStatusDialog() async {
    final statuses = ['Active', 'On Break', 'End of Shift'];

    // capture widget context before opening dialog
    final widgetContext = context;

    await showDialog<void>(
      context: widgetContext,
      builder: (dialogCtx) => SimpleDialog(
        title: const Text('Change Status'),
        children: statuses
            .map((s) => SimpleDialogOption(
                  onPressed: () async {
                    // capture navigator BEFORE awaiting
                    final nav = Navigator.of(dialogCtx);
                    await _firestore.collection('staff').doc(staff['id']).set({'status': s}, SetOptions(merge: true));

                    if (!mounted) return;

                    await _logActivity('Changed status to $s');

                    if (!mounted) return;

                    nav.pop();
                  },
                  child: Text(s),
                ))
            .toList(),
      ),
    );
  }

  // ------------------- Delivery Details Modal -------------------
  void _openDeliveryDetails(String deliveryId, Map delivery) {
    // capture widget context to open modal
    final widgetContext = context;

    showModalBottomSheet(
      context: widgetContext,
      isScrollControlled: true,
      builder: (sheetCtx) {
        // use sheetCtx for any navigation/pop originating inside the sheet
        return Padding(
          padding: EdgeInsets.only(bottom: MediaQuery.of(sheetCtx).viewInsets.bottom),
          child: SingleChildScrollView(
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(delivery['customerName'] ?? '-', style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 8),
                  Text('Address: ${delivery['address'] ?? '-'}'),
                  Text('Phone: ${delivery['phone'] ?? '-'}'),
                  Text('Gallons: ${_formatGallons(delivery['gallons'])}'),
                  Text('Payment: ${delivery['paymentType'] ?? 'N/A'}'),
                  if (delivery['assignedToName'] != null || delivery['assignedTo'] != null)
                    Padding(
                      padding: const EdgeInsets.only(top: 6.0),
                      child: Text('Assigned to: ${delivery['assignedToName'] ?? delivery['assignedTo'] ?? '-'}', style: const TextStyle(fontWeight: FontWeight.w600)),
                    ),
                  const SizedBox(height: 12),

                  Wrap(spacing: 8, children: [
                    ElevatedButton.icon(
                      onPressed: () => _openPhone(delivery['phone']),
                      icon: const Icon(Icons.call),
                      label: const Text('Call'),
                    ),
                    ElevatedButton.icon(
                      onPressed: () => _openMapForAddress(delivery['address']),
                      icon: const Icon(Icons.map),
                      label: const Text('Navigate'),
                    ),
                    ElevatedButton.icon(
                      onPressed: () => _uploadProof(deliveryId),
                      icon: const Icon(Icons.camera_alt),
                      label: const Text('Upload Proof'),
                    ),
                  ]),

                  const SizedBox(height: 12),

                  Row(children: [
                    Expanded(
                      child: ElevatedButton(
                        onPressed: () async {
                          final nav = Navigator.of(sheetCtx);
                          await _markAsDelivered(deliveryId);
                          if (!mounted) return;
                          nav.pop();
                        },
                        child: const Text('Mark as Delivered'),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: ElevatedButton(
                        style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
                        onPressed: () async {
                          final nav = Navigator.of(sheetCtx);
                          await _firestore.collection('deliveries').doc(deliveryId).update({'status': 'failed'});
                          if (!mounted) return;
                          await _logActivity('Marked failed $deliveryId');
                          if (!mounted) return;
                          nav.pop();
                        },
                        child: const Text('Mark Failed'),
                      ),
                    ),
                  ])
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Future<void> _showPreConfirmDialog(String orderId, Map<String, dynamic> orderData) async {
    final staffRef = _firestore.collection('staff').doc(staff['id']);
    final staffSnap = await staffRef.get();
    final staffData = staffSnap.data() ?? {};
    final inventory = (staffData['inventory'] is Map)
        ? Map<String, dynamic>.from(staffData['inventory'])
        : <String, dynamic>{};

    // If the order contains multiple cart items, compute required quantities per SKU
    final bool hasItems = orderData['items'] is List && (orderData['items'] as List).isNotEmpty;

    Map<String, int> requiredPerSku = {};
    if (hasItems) {
      final items = List<Map<String, dynamic>>.from(orderData['items']);
      for (final it in items) {
        final ptype = it['productType'] ?? it['product_type'] ?? 'gallon';
        final qty = (it['quantity'] is int) ? it['quantity'] as int : int.tryParse('${it['quantity']}') ?? 0;

        String sku = 'full';
        if (ptype == 'gallon') {
          final refillOpt = (it['options'] is Map) ? (it['options']['refill'] ?? it['refill']) : it['refill'];
          final refillStr = refillOpt?.toString().toLowerCase();
          if (refillStr == 'with_container' || refillStr == 'withcontainer' || refillStr == 'new_container') {
            sku = 'gallon_with_container';
          } else if (refillStr == 'refill_only' || refillStr == 'refill') {
            sku = 'gallon_refill';
          }
        } else if (ptype == 'bottled') {
          final size = (it['options'] is Map) ? (it['options']['size'] ?? it['size']) : (it['size'] ?? '500ml');
          sku = (size ?? '500ml').toString().replaceAll('.', '_');
        }

        requiredPerSku[sku] = (requiredPerSku[sku] ?? 0) + qty;
      }
    }

    // compute availability per SKU for display & validation
    final Map<String, int> availablePerSku = {};
    if (requiredPerSku.isNotEmpty) {
      for (final k in requiredPerSku.keys) {
        if (inventory.containsKey(k) && inventory[k] is int) {
          availablePerSku[k] = inventory[k] as int;
        } else if (k != 'full' && inventory.containsKey('full') && inventory['full'] is int) {
          availablePerSku[k] = inventory['full'] as int;
        } else {
          availablePerSku[k] = 0;
        }
      }
    }

    bool canConfirm = true;
    if (requiredPerSku.isNotEmpty) {
      for (final e in requiredPerSku.entries) {
        final need = e.value;
        final have = availablePerSku[e.key] ?? 0;
        if (have < need) {
          canConfirm = false;
          break;
        }
      }
    }
    // fallback for single-item orders
    final int available = (inventory['full'] is int) ? inventory['full'] as int : int.tryParse('${inventory['full'] ?? 0}') ?? 0;
    final int qty = (orderData['quantity'] is int) ? orderData['quantity'] as int : int.tryParse('${orderData['quantity']}') ?? 0;
    final int remaining = available - qty;

    if (!mounted) return;

    await showDialog<void>(
      context: context,
      builder: (dialogCtx) {
        return AlertDialog(
          title: const Text('Confirm Order'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // customer contact info
                Text(orderData['customerName'] ?? orderData['customer_name'] ?? '', style: const TextStyle(fontWeight: FontWeight.bold)),
                const SizedBox(height: 4),
                if ((orderData['email'] ?? '') != '') Row(children: [const Icon(Icons.email, size: 16), const SizedBox(width: 8), Expanded(child: Text(orderData['email'] ?? ''))]),
                if ((orderData['phone'] ?? orderData['contact'] ?? '') != '') Row(children: [const Icon(Icons.phone, size: 16), const SizedBox(width: 8), Expanded(child: Text(orderData['phone'] ?? orderData['contact'] ?? ''))]),
                if ((orderData['address'] ?? '') != '') Row(children: [const Icon(Icons.location_on, size: 16), const SizedBox(width: 8), Expanded(child: Text(orderData['address'] ?? ''))]),
                const SizedBox(height: 8),

                // order summary
                Text('Product: ${orderData['product_type'] ?? orderData['productType'] ?? ''}'),
                const SizedBox(height: 6),
                Text('Quantity: $qty'),
                const SizedBox(height: 8),

                // optional itemized breakdown
                if (orderData['items'] is List && (orderData['items'] as List).isNotEmpty) ...[
                  const Divider(),
                  const Text('Items:', style: TextStyle(fontWeight: FontWeight.bold)),
                  const SizedBox(height: 6),
                  ...((orderData['items'] as List).map((it) {
                    if (it is Map<String, dynamic>) {
                      final name = it['name'] ?? it['title'] ?? it['product'] ?? '';
                      final q = it['quantity']?.toString() ?? it['qty']?.toString() ?? '';
                      final p = it['price']?.toString() ?? '';
                      return Padding(
                        padding: const EdgeInsets.symmetric(vertical: 2),
                        child: Text('- $name ${q.isNotEmpty ? 'x$q' : ''}${p.isNotEmpty ? ' @ $p' : ''}'),
                      );
                    }
                    return Padding(padding: const EdgeInsets.symmetric(vertical: 2), child: Text('- ${it.toString()}'));
                  }).toList()),
                  const SizedBox(height: 8),
                ],

                if (requiredPerSku.isNotEmpty) ...[
                  const Divider(),
                  const Text('Inventory check:', style: TextStyle(fontWeight: FontWeight.bold)),
                  const SizedBox(height: 6),
                  ...requiredPerSku.entries.map((e) {
                    final key = e.key;
                    final need = e.value;
                    final have = availablePerSku[key] ?? 0;
                    final rem = have - need;
                    return Padding(
                      padding: const EdgeInsets.symmetric(vertical: 2),
                      child: Text('$key — need: $need • available: $have • remaining: $rem', style: TextStyle(color: rem < 0 ? Colors.red : Colors.black)),
                    );
                  }),
                  if (!canConfirm) ...[const SizedBox(height: 8), const Text('Insufficient inventory to confirm this order.', style: TextStyle(color: Colors.red))],
                ] else ...[
                  Text('Available full gallons: $available'),
                  Text('Remaining after confirm: $remaining'),
                  if (!canConfirm) ...[const SizedBox(height: 8), const Text('Insufficient inventory to confirm this order.', style: TextStyle(color: Colors.red))],
                ],
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogCtx).pop(),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: canConfirm
                  ? () async {
                      // instead of immediately assigning to staff, present a
                      // driver selection so staff can choose an online driver
                      // to take this delivery.
                      final messenger = ScaffoldMessenger.of(context);
                      final nav = Navigator.of(dialogCtx);
                      try {
                        final assignedDriverId = await _showDriverSelectionDialog();
                        if (!mounted) return;
                        if (assignedDriverId == null) {
                          // no driver chosen; user cancelled or none available
                          messenger.showSnackBar(const SnackBar(content: Text('No driver selected — assignment cancelled')));
                          return;
                        }

                        // Resolve the driver's display name (try staff then drivers collection)
                        String? assignedDriverName;

                        String? _resolveName(Map<String, dynamic>? data) {
                          if (data == null) return null;
                          final cand = (data['name'] ?? data['fullName'] ?? data['displayName'])?.toString();
                          if (cand != null && cand.trim().isNotEmpty) return cand.trim();

                          // Try split fields
                          final first = (data['firstName'] ?? data['first_name'] ?? data['givenName'])?.toString().trim() ?? '';
                          final last = (data['lastName'] ?? data['last_name'] ?? data['familyName'])?.toString().trim() ?? '';
                          final combined = ('$first ${last}'.trim());
                          if (combined.isNotEmpty) return combined;

                          return null;
                        }
                        try {
                          final staffSnap = await FirebaseFirestore.instance.collection('staff').doc(assignedDriverId).get();
                            if (staffSnap.exists) {
                              final sd = staffSnap.data() as Map<String, dynamic>?;
                              assignedDriverName = _resolveName(sd);
                            }
                        } catch (_) {}

                        if (assignedDriverName == null) {
                          try {
                            final driverSnap = await FirebaseFirestore.instance.collection('drivers').doc(assignedDriverId).get();
                            if (driverSnap.exists) {
                              final dd = driverSnap.data() as Map<String, dynamic>?;
                              assignedDriverName = _resolveName(dd);
                            }
                          } catch (_) {}
                        }

                        // Use the currently authenticated user as the executor for confirmation.
                        // Many permission checks and security rules align to request.auth.uid so
                        // using the actual auth uid avoids mismatches (for example when the
                        // `staff` variable came from a stale value). If the signed-in user
                        // doesn't have a staff profile, create a small one (safe, minimal)
                        // so security rules that rely on the record exist will pass.
                        final currentUser = FirebaseAuth.instance.currentUser;
                        final executorId = currentUser?.uid ?? staff['id'];

                        Future<void> ensureStaffProfileFor(String uid) async {
                          try {
                            final ref = FirebaseFirestore.instance.collection('staff').doc(uid);
                            final snap = await ref.get();
                            if (!snap.exists) {
                              await ref.set({
                                'name': currentUser?.displayName ?? currentUser?.email ?? 'Staff ${uid.substring(0, 6)}',
                                'email': currentUser?.email ?? '',
                                'role': 'staff',
                                'status': 'online',
                                'inventory': {'full': 0},
                                'createdAt': FieldValue.serverTimestamp(),
                              });
                            }
                          } catch (_) {
                            // Non-fatal — we'll detect permission errors when confirming and
                            // show clearer guidance to the user.
                          }
                        }

                        await ensureStaffProfileFor(executorId);

                        // Ensure the driver has a profile so they can read assigned deliveries.
                          try {
                            final drvRef = FirebaseFirestore.instance.collection('drivers').doc(assignedDriverId);
                            final drvSnap = await drvRef.get();
                            if (!drvSnap.exists) {
                              await drvRef.set({
                                'name': assignedDriverName ?? 'Driver ${assignedDriverId.substring(0, 6)}',
                                'status': 'online',
                                'createdAt': FieldValue.serverTimestamp(),
                              });
                            }

                            // Also ensure there's a staff document with role == 'driver'
                            // so that the driver can sign in through the Staff/Admin
                            // login flow (some environments expect drivers in `staff/`).
                            final staffRef = FirebaseFirestore.instance.collection('staff').doc(assignedDriverId);
                            final staffSnap = await staffRef.get();
                            if (!staffSnap.exists) {
                              await staffRef.set({
                                'name': assignedDriverName ?? 'Driver ${assignedDriverId.substring(0, 6)}',
                                'email': '',
                                'role': 'driver',
                                'status': 'online',
                                'inventory': {'full': 0},
                                'createdAt': FieldValue.serverTimestamp(),
                              });
                            }
                          } catch (_) {
                            // non-fatal — continue and let confirmOrder create deliveries
                            // even if creating a drivers doc fails.
                          }
                        

                        bool ok = false;
                        try {
                          ok = await FirestoreService.confirmOrder(orderId: orderId, orderData: orderData, staffId: executorId, assignedDriverId: assignedDriverId, assignedDriverName: assignedDriverName);
                        } catch (e) {
                          // If confirm failed due to permission problems, try ensuring the
                          // executor profile exists (in case creation was blocked earlier)
                          // then retry once. If it still fails we'll bubble the error out.
                          final errStr = e.toString().toLowerCase();
                          if (errStr.contains('permission-denied') || errStr.contains('missing or insufficient')) {
                            await ensureStaffProfileFor(executorId);
                            ok = await FirestoreService.confirmOrder(orderId: orderId, orderData: orderData, staffId: executorId, assignedDriverId: assignedDriverId, assignedDriverName: assignedDriverName);
                          } else {
                            rethrow;
                          }
                        }
                        if (!mounted) return;
                        // Close the confirm dialog if visible but avoid double pop
                        await nav.maybePop();

                        if (ok) {
                          final assignedLabel = assignedDriverName ?? assignedDriverId;
                          messenger.showSnackBar(SnackBar(content: Text('Order confirmed and assigned to $assignedLabel')));
                          // Log activity but don't let a logging failure revert the success
                          try {
                            await _logActivity('Confirmed order $orderId and assigned to $assignedLabel');
                          } catch (e) {
                            debugPrint('Failed to log activity after confirm: $e');
                          }
                        }
                      } catch (e) {
                        if (!mounted) return;
                        await nav.maybePop();
                        messenger.showSnackBar(SnackBar(content: Text('Cannot confirm: ${e.toString()}')));
                      }
                    }
                  : null,
              child: const Text('Confirm & Assign'),
            ),
          ],
        );
      },
    );
  }

  /// Try to find a customer doc for this order using customer_id (preferred)
  /// or the email fields if customer_id is missing. Returns null when no
  /// customer record could be located.
  Future<DocumentSnapshot?> _lookupCustomerForOrder(Map<String, dynamic> orderData) async {
    final customerId = orderData['customer_id'] ?? orderData['customerId'];
    if (customerId != null) {
      try {
        final snap = await _firestore.collection('customers').doc(customerId.toString()).get();
        if (snap.exists) return snap;
      } catch (_) {}
    }

    final email = orderData['customer_email'] ?? orderData['email'] ?? orderData['customerEmail'];
    if (email != null && email.toString().isNotEmpty) {
      try {
        final q = await _firestore.collection('customers').where('email', isEqualTo: email.toString()).limit(1).get();
        if (q.docs.isNotEmpty) return q.docs.first;
      } catch (_) {}
    }

    return null;
  }

  /// Shows a dialog with currently online drivers and allows staff to pick
  /// one. Returns the selected driver's staff document id, or null if none
  /// selected / cancelled.
  Future<String?> _showDriverSelectionDialog() async {
    final widgetContext = context;

    return showDialog<String?>(
      context: widgetContext,
      builder: (dialogCtx) {
        return AlertDialog(
          title: const Text('Assign to Driver'),
          content: SizedBox(
            width: double.maxFinite,
            child: FutureBuilder<List<QuerySnapshot>>(
              // Fetch drivers from both the 'staff' collection (some systems store
              // drivers there) and the 'drivers' collection (legacy / separate).
              future: Future.wait([
                _firestore.collection('staff').where('role', isEqualTo: 'driver').where('status', isEqualTo: 'online').get(),
                _firestore.collection('drivers').where('status', isEqualTo: 'online').get(),
              ]),
                builder: (ctx, snap) {
                if (snap.hasError) return const Text('Failed to load drivers');
                if (!snap.hasData) return const SizedBox(height: 120, child: Center(child: CircularProgressIndicator()));

                // snap.data will be List<QuerySnapshot>
                final results = snap.data!;
                final staffDocs = results.isNotEmpty ? (results[0].docs) : <QueryDocumentSnapshot>[];
                final driverDocs = results.length > 1 ? results[1].docs : <QueryDocumentSnapshot>[];

                // Merge both result sets into a single drivers list and dedupe by id
                final temp = <Map<String, dynamic>>[];
                final seen = <String>{};

                for (final d in staffDocs) {
                  final m = d.data() as Map<String, dynamic>;
                  final id = d.id;
                  if (seen.contains(id)) continue;
                  seen.add(id);
                  temp.add({'id': id, ...m});
                }
                for (final d in driverDocs) {
                  final m = d.data() as Map<String, dynamic>;
                  final id = d.id;
                  if (seen.contains(id)) continue;
                  seen.add(id);
                  temp.add({'id': id, ...m});
                }

                return DriverSelectionDialog(drivers: temp);
              },
            ),
          ),
        );
      },
    );
  }

  Future<void> _openPhone(String? phone) async {
    if (phone == null) return;
    final uri = Uri.parse('tel:$phone');
    if (await canLaunchUrl(uri)) await launchUrl(uri);
  }

  // ------------------- Upload proof / payment receipts -------------------
  Future<void> _uploadProof(String deliveryId) async {
    // This function does not use BuildContext, so no context capturing is needed here.
    final picked = await _picker.pickImage(
      source: ImageSource.camera,
      imageQuality: 70,
    );

    if (!mounted) return; // after async gap #1

    if (picked == null) return;
    final file = File(picked.path);

    final storageRef = FirebaseStorage.instance
        .ref()
        .child('delivery_proofs/$deliveryId/${DateTime.now().millisecondsSinceEpoch}.jpg');

    final uploadTask = storageRef.putFile(file);

    final snapshot = await uploadTask.whenComplete(() {});

    if (!mounted) return; // after async gap #2

    final url = await snapshot.ref.getDownloadURL();

    await _firestore.collection('deliveries').doc(deliveryId).set(
      {'proofUrl': url},
      SetOptions(merge: true),
    );

    if (!mounted) return; // after async gap #3
    await _logActivity('Uploaded proof for $deliveryId');
  }
}
