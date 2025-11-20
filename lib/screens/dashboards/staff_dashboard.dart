// staff_dashboard_fixed.dart
// Full Staff/Carrier Dashboard integrated with Cloud Firestore + Firebase Storage
// Fixed to avoid using BuildContext across async gaps and to properly guard with `mounted`.

import 'dart:io';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:mta_water_delivery/services/firestore_service.dart';

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
      body: Row(
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
      ),
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

            return Card(
              elevation: 2,
              margin: const EdgeInsets.symmetric(vertical: 8),
              child: ListTile(
                leading: const Icon(Icons.local_shipping),
                title: Text(d['customerName'] ?? 'Unknown'),
                subtitle: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Address: ${d['address'] ?? '-'}'),
                    Text('Gallons: ${_formatGallons(d['gallons'])}'),
                    Text('Payment: ${d['paymentType'] ?? 'N/A'}'),
                  ],
                ),
                isThreeLine: true,
                trailing: PopupMenuButton<String>(
                  onSelected: (action) => _handleAssignedAction(action, doc.id, d),
                  itemBuilder: (_) => [
                    const PopupMenuItem(value: 'accept', child: Text('Accept')),
                    const PopupMenuItem(value: 'start', child: Text('Start / Navigate')),
                    const PopupMenuItem(value: 'deliver', child: Text('Mark Delivered')),
                    const PopupMenuItem(value: 'fail', child: Text('Mark Failed')),
                  ],
                ),
                onTap: () => _openDeliveryDetails(doc.id, d),
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
              Text('Full gallons loaded: ${inventory['full'] ?? 0}'),
              Text('Empty gallons collected: ${inventory['empty'] ?? 0}'),
              Text('Refill gallons returned: ${inventory['refillReturned'] ?? 0}'),
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

    // capture the widget context _before_ opening dialog
    final widgetContext = context;

    await showDialog<void>(
      context: widgetContext,
      builder: (dialogCtx) {
        // use dialogCtx (local) inside builder
        return AlertDialog(
          title: const Text('Edit Inventory'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(controller: fullCtrl, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'Full')),
              TextField(controller: emptyCtrl, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'Empty')),
              TextField(controller: refillCtrl, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'Refill Returned')),
            ],
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
                  return Card(
                    margin: const EdgeInsets.symmetric(vertical: 6),
                    child: ListTile(
                      leading: const Icon(Icons.shopping_bag),
                      title: Text(d['product_type'] ?? 'Order'),
                      subtitle: Text('Qty: ${d['quantity'] ?? '-'} • ${d['customer_name'] ?? ''}\n${d['address'] ?? ''}'),
                      isThreeLine: true,
                      trailing: ElevatedButton(
                        onPressed: () => _showPreConfirmDialog(id, d),
                        child: const Text('Confirm'),
                      ),
                    ),
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

    final int available = (inventory['full'] is int)
        ? inventory['full'] as int
        : int.tryParse('${inventory['full'] ?? 0}') ?? 0;

    final int qty = (orderData['quantity'] is int)
        ? orderData['quantity'] as int
        : int.tryParse('${orderData['quantity']}') ?? 0;

    final int remaining = available - qty;
    final bool canConfirm = available >= qty;

    if (!mounted) return;

    await showDialog<void>(
      context: context,
      builder: (dialogCtx) {
        return AlertDialog(
          title: const Text('Confirm Order'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Product: ${orderData['product_type'] ?? orderData['productType'] ?? ''}'),
              const SizedBox(height: 6),
              Text('Quantity: $qty'),
              const SizedBox(height: 8),
              Text('Available full gallons: $available'),
              Text('Remaining after confirm: $remaining'),
              if (!canConfirm) ...[const SizedBox(height: 8), const Text('Insufficient inventory to confirm this order.', style: TextStyle(color: Colors.red))],
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogCtx).pop(),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: canConfirm
                  ? () async {
                      final messenger = ScaffoldMessenger.of(context);
                      final nav = Navigator.of(dialogCtx);
                      try {
                        final ok = await FirestoreService.confirmOrder(orderId: orderId, orderData: orderData, staffId: staff['id']);
                        if (!mounted) return;
                        nav.pop();
                        if (ok) {
                          messenger.showSnackBar(const SnackBar(content: Text('Order confirmed and assigned')));
                          await _logActivity('Confirmed order $orderId');
                        }
                      } catch (e) {
                        if (!mounted) return;
                        nav.pop();
                        messenger.showSnackBar(SnackBar(content: Text('Cannot confirm: ${e.toString()}')));
                      }
                    }
                  : null,
              child: const Text('Confirm'),
            ),
          ],
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
