import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:mta_water_delivery/models/order.dart' as model;
import 'package:mta_water_delivery/services/firestore_service.dart';
import 'package:mta_water_delivery/screens/order_history.dart';
import 'dart:convert';
import 'package:flutter/services.dart' show rootBundle;

class CustomerDashboard extends StatefulWidget {
  const CustomerDashboard({super.key});

  @override
  State<CustomerDashboard> createState() => _CustomerDashboardState();
}

class _CustomerDashboardState extends State<CustomerDashboard> {
  final user = FirebaseAuth.instance.currentUser;
  int _selectedIndex = 0;
  List<String> _barangays = [];

  @override
  void initState() {
    super.initState();
    _loadLocationData().whenComplete(() => _checkProfileCompletion());
  }

  Future<void> _loadLocationData() async {
    try {
      final s = await rootBundle.loadString('assets/philippines_locations.json');
      final Map<String, dynamic> data = json.decode(s);
      _barangays = List<String>.from(data['barangays'] as List<dynamic>? ?? []);
    } catch (e) {
      _barangays = ['Barangay 1', 'Barangay 2', 'Barangay 3'];
    }
  }

  Future<void> _checkProfileCompletion() async {
    try {
      final doc = await FirebaseFirestore.instance.collection('customers').doc(user?.uid).get();
      final data = doc.data() ?? {};
      final fullName = data['fullName'] ?? '';
      final contactNumber = data['contactNumber'] ?? '';
      final address = data['address'] ?? '';

      if (fullName.isEmpty || contactNumber.isEmpty || address.isEmpty) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (!mounted) return;
          _showRequiredProfileDialog(context, fullName, contactNumber, address);
        });
      }
    } catch (_) {}
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Customer Dashboard'),
        backgroundColor: Colors.blueAccent,
        actions: [
          IconButton(
            icon: const Icon(Icons.logout),
            onPressed: () {
              FirebaseAuth.instance.signOut();
              Navigator.of(context).pushNamedAndRemoveUntil('/', (r) => false);
            },
          )
        ],
      ),
      body: _getBodyForIndex(_selectedIndex),
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _selectedIndex,
        onTap: (i) => setState(() => _selectedIndex = i),
        items: const [
          BottomNavigationBarItem(icon: Icon(Icons.local_shipping), label: 'Active'),
          BottomNavigationBarItem(icon: Icon(Icons.history), label: 'History'),
          BottomNavigationBarItem(icon: Icon(Icons.person), label: 'Profile'),
        ],
      ),
      floatingActionButton: _selectedIndex == 2
          ? FloatingActionButton.extended(
              onPressed: () => _orderGallons(context),
              icon: const Icon(Icons.add_shopping_cart),
              label: const Text('Place Order'),
            )
          : null,
    );
  }

  Widget _getBodyForIndex(int index) {
    switch (index) {
      case 0:
        return _deliveriesView();
      case 1:
        return _orderHistoryView();
      case 2:
        return _profileView();
      default:
        return _deliveriesView();
    }
  }

  Widget _deliveriesView() {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('deliveries')
          .where('customer_id', isEqualTo: user?.uid)
          .orderBy('timestamp', descending: true)
          .snapshots(),
      builder: (context, snap) {
        if (!snap.hasData) return const Center(child: CircularProgressIndicator());
        final docs = snap.data!.docs;
        if (docs.isEmpty) return const Center(child: Text('No deliveries yet'));
        return ListView.builder(
          padding: const EdgeInsets.all(16),
          itemCount: docs.length,
          itemBuilder: (ctx, i) => _buildDeliveryCard(docs[i]),
        );
      },
    );
  }

  Widget _orderHistoryView() {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('orders')
          .where('customer_id', isEqualTo: user?.uid)
          .orderBy('createdAt', descending: true)
          .snapshots(),
      builder: (context, snap) {
        if (!snap.hasData) return const Center(child: CircularProgressIndicator());
        final docs = snap.data!.docs;
        
        final orders = docs.map((doc) {
          final data = doc.data() as Map<String, dynamic>;
          return OrderHistory(
            orderId: doc.id,
            productType: data['productType'] ?? 'Water',
            quantity: data['quantity'] ?? 0,
            totalAmount: (data['totalAmount'] as num?)?.toDouble() ?? 0.0,
            address: data['address'] ?? '',
            status: data['status'] ?? 'pending',
            createdAt: (data['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
            estimatedDelivery: (data['estimatedDelivery'] as Timestamp?)?.toDate(),
          );
        }).toList();

        if (orders.isEmpty) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  Icons.shopping_bag_outlined,
                  size: 64,
                  color: Colors.grey.shade300,
                ),
                const SizedBox(height: 16),
                Text(
                  'No order history',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                const SizedBox(height: 8),
                Text(
                  'Your orders will appear here',
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ],
            ),
          );
        }

        return ListView.builder(
          padding: const EdgeInsets.all(16),
          itemCount: orders.length,
          itemBuilder: (ctx, i) {
            final order = orders[i];
            return OrderHistoryCard(
              order: order,
              onTap: () {
                // View order details
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text('Order #${order.orderId} details')),
                );
              },
            );
          },
        );
      },
    );
  }

  Widget _buildDeliveryCard(QueryDocumentSnapshot delivery) {
    final data = delivery.data() as Map<String, dynamic>;
    final status = data['status'] ?? 'unknown';
    final address = data['address'] ?? '';
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Status: $status', style: const TextStyle(fontWeight: FontWeight.bold)),
            const SizedBox(height: 6),
            Text('Address: $address'),
          ],
        ),
      ),
    );
  }

  Widget _profileView() {
    return StreamBuilder<DocumentSnapshot>(
      stream: FirebaseFirestore.instance.collection('customers').doc(user?.uid).snapshots(),
      builder: (context, snap) {
        if (!snap.hasData) return const Center(child: CircularProgressIndicator());
        final data = snap.data!.data() as Map<String, dynamic>? ?? {};
        final fullName = data['fullName'] ?? '';
        final contact = data['contactNumber'] ?? '';
        final address = data['address'] ?? '';

        return SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            const Text('My Profile', style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold)),
            const SizedBox(height: 16),
            _buildProfileCard('Full Name', fullName.isEmpty ? 'Not set' : fullName),
            const SizedBox(height: 12),
            _buildProfileCard('Contact Number', contact.isEmpty ? 'Not set' : contact),
            const SizedBox(height: 12),
            _buildProfileCard('Delivery Address', address.isEmpty ? 'Not set' : address),
            const SizedBox(height: 20),
            ElevatedButton.icon(
              onPressed: () => _showEditProfileDialog(context, fullName, contact, address),
              icon: const Icon(Icons.edit),
              label: const Text('Edit Profile'),
            ),
            const SizedBox(height: 12),
            ElevatedButton.icon(
              onPressed: () => _orderGallons(context),
              icon: const Icon(Icons.add_shopping_cart),
              label: const Text('Place Order'),
            ),
          ]),
        );
      },
    );
  }

  Widget _buildProfileCard(String label, String value) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(border: Border.all(color: Colors.grey), borderRadius: BorderRadius.circular(8)),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(label, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
        const SizedBox(height: 6),
        Text(value, style: const TextStyle(fontSize: 16)),
      ]),
    );
  }

  // Required profile dialog (first-time completion)
  void _showRequiredProfileDialog(BuildContext context, String fullName, String contactNumber, String address) {
    final firstNameCtrl = TextEditingController();
    final middleInitialCtrl = TextEditingController();
    final lastNameCtrl = TextEditingController();
    final suffixCtrl = TextEditingController();
    final contactCtrl = TextEditingController(text: contactNumber);
    final blkLotCtrl = TextEditingController();
    final streetCtrl = TextEditingController();
    String? selectedBarangay = _barangays.isNotEmpty ? _barangays.first : null;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (dialogCtx) {
        return PopScope(
          canPop: false,
          child: AlertDialog(
            title: const Text('Complete Your Profile'),
            content: SingleChildScrollView(
              child: StatefulBuilder(builder: (ctx, setState) {
                return Column(mainAxisSize: MainAxisSize.min, children: [
                  TextField(controller: firstNameCtrl, decoration: const InputDecoration(label: Text.rich(TextSpan(text: 'First Name ', children: [TextSpan(text: '*', style: TextStyle(color: Colors.red))])), border: OutlineInputBorder(), hintText: 'First name')),
                  const SizedBox(height: 8),
                  TextField(controller: middleInitialCtrl, decoration: const InputDecoration(label: Text.rich(TextSpan(text: 'Middle Initial ', children: [TextSpan(text: '*', style: TextStyle(color: Colors.red))])), border: OutlineInputBorder(), hintText: 'Middle initial')),
                  const SizedBox(height: 8),
                  TextField(controller: lastNameCtrl, decoration: const InputDecoration(label: Text.rich(TextSpan(text: 'Last Name ', children: [TextSpan(text: '*', style: TextStyle(color: Colors.red))])), border: OutlineInputBorder(), hintText: 'Last name')),
                  const SizedBox(height: 8),
                  TextField(controller: suffixCtrl, decoration: const InputDecoration(labelText: 'Suffix', border: OutlineInputBorder(), hintText: 'Suffix (optional)')),
                  const SizedBox(height: 8),
                  TextField(controller: contactCtrl, keyboardType: TextInputType.phone, decoration: const InputDecoration(label: Text.rich(TextSpan(text: 'Contact Number ', children: [TextSpan(text: '*', style: TextStyle(color: Colors.red))])), border: OutlineInputBorder(), hintText: 'Enter your phone number')),
                  const SizedBox(height: 8),
                  TextField(controller: blkLotCtrl, decoration: const InputDecoration(labelText: 'Blk / Lot / Unit', border: OutlineInputBorder(), hintText: 'Blk/Lot/Unit (optional)')),
                  const SizedBox(height: 8),
                  TextField(controller: streetCtrl, decoration: const InputDecoration(label: Text.rich(TextSpan(text: 'Street ', children: [TextSpan(text: '*', style: TextStyle(color: Colors.red))])), border: OutlineInputBorder(), hintText: 'Street name')),
                  const SizedBox(height: 8),
                  DropdownButtonFormField<String>(initialValue: selectedBarangay, items: _barangays.map((b) => DropdownMenuItem(value: b, child: Text(b))).toList(), onChanged: (v) => setState(() => selectedBarangay = v), decoration: const InputDecoration(label: Text.rich(TextSpan(text: 'Barangay ', children: [TextSpan(text: '*', style: TextStyle(color: Colors.red))])))),
                  const SizedBox(height: 6),
                  const Align(alignment: Alignment.centerLeft, child: Text('All address fields are required', style: TextStyle(fontSize: 12, color: Colors.redAccent))),
                ]);
              }),
            ),
            actions: [
              ElevatedButton(
                onPressed: () async {
                  if (firstNameCtrl.text.trim().isEmpty || middleInitialCtrl.text.trim().isEmpty || lastNameCtrl.text.trim().isEmpty || contactCtrl.text.trim().isEmpty || streetCtrl.text.trim().isEmpty || selectedBarangay == null) {
                    ScaffoldMessenger.of(dialogCtx).showSnackBar(const SnackBar(content: Text('Please fill all required fields')));
                    return;
                  }

                  final fullName = '${firstNameCtrl.text.trim()} ${middleInitialCtrl.text.trim()} ${lastNameCtrl.text.trim()}${suffixCtrl.text.trim().isNotEmpty ? ' ${suffixCtrl.text.trim()}' : ''}';
                  final combinedAddress = '${blkLotCtrl.text.trim().isNotEmpty ? '${blkLotCtrl.text.trim()}, ' : ''}${streetCtrl.text.trim()}, $selectedBarangay';

                  final navigator = Navigator.of(context);
                  final messenger = ScaffoldMessenger.of(context);

                  await FirebaseFirestore.instance.collection('customers').doc(user?.uid).set({
                    'fullName': fullName,
                    'contactNumber': contactCtrl.text.trim(),
                    'address': combinedAddress,
                    'email': user?.email,
                    'uid': user?.uid,
                    'updatedAt': FieldValue.serverTimestamp(),
                    'profileCompleted': true,
                  }, SetOptions(merge: true));

                  if (!mounted) return;
                  navigator.pop();
                  messenger.showSnackBar(const SnackBar(content: Text('Profile completed successfully')));
                },
                child: const Text('Complete Profile'),
              ),
            ],
          ),
        );
      },
    );
  }

  void _showEditProfileDialog(BuildContext context, String fullName, String contactNumber, String address) {
    final nameParts = fullName.split(' ');
    final firstNameCtrl = TextEditingController(text: nameParts.isNotEmpty ? nameParts[0] : '');
    final middleInitialCtrl = TextEditingController(text: nameParts.length > 1 ? nameParts[1] : '');
    final lastNameCtrl = TextEditingController(text: nameParts.length > 2 ? nameParts[2] : '');
    final suffixCtrl = TextEditingController(text: nameParts.length > 3 ? nameParts.sublist(3).join(' ') : '');
    final contactCtrl = TextEditingController(text: contactNumber);
    final blkLotCtrl = TextEditingController();
    final streetCtrl = TextEditingController(text: address);
    String? selectedBarangay = _barangays.isNotEmpty ? _barangays.first : null;

    showDialog(
      context: context,
      builder: (dialogCtx) {
        return AlertDialog(
          title: const Text('Edit Profile'),
          content: SingleChildScrollView(
            child: StatefulBuilder(builder: (ctx, setState) {
              return Column(mainAxisSize: MainAxisSize.min, children: [
                TextField(controller: firstNameCtrl, decoration: const InputDecoration(label: Text.rich(TextSpan(text: 'First Name ', children: [TextSpan(text: '*', style: TextStyle(color: Colors.red))])), border: OutlineInputBorder())),
                const SizedBox(height: 8),
                TextField(controller: middleInitialCtrl, decoration: const InputDecoration(label: Text.rich(TextSpan(text: 'Middle Initial ', children: [TextSpan(text: '*', style: TextStyle(color: Colors.red))])), border: OutlineInputBorder())),
                const SizedBox(height: 8),
                TextField(controller: lastNameCtrl, decoration: const InputDecoration(label: Text.rich(TextSpan(text: 'Last Name ', children: [TextSpan(text: '*', style: TextStyle(color: Colors.red))])), border: OutlineInputBorder())),
                const SizedBox(height: 8),
                TextField(controller: suffixCtrl, decoration: const InputDecoration(labelText: 'Suffix', border: OutlineInputBorder(), hintText: 'Suffix (optional)')),
                const SizedBox(height: 8),
                TextField(controller: contactCtrl, decoration: const InputDecoration(label: Text.rich(TextSpan(text: 'Contact Number ', children: [TextSpan(text: '*', style: TextStyle(color: Colors.red))])), border: OutlineInputBorder()), keyboardType: TextInputType.phone),
                const SizedBox(height: 8),
                TextField(controller: blkLotCtrl, decoration: const InputDecoration(labelText: 'Blk / Lot / Unit', border: OutlineInputBorder(), hintText: 'Blk/Lot/Unit (optional)')),
                const SizedBox(height: 8),
                TextField(controller: streetCtrl, decoration: const InputDecoration(label: Text.rich(TextSpan(text: 'Street ', children: [TextSpan(text: '*', style: TextStyle(color: Colors.red))])), border: OutlineInputBorder(), hintText: 'Street name')),
                const SizedBox(height: 8),
                DropdownButtonFormField<String>(initialValue: selectedBarangay, items: _barangays.map((b) => DropdownMenuItem(value: b, child: Text(b))).toList(), onChanged: (v) => setState(() => selectedBarangay = v), decoration: const InputDecoration(label: Text.rich(TextSpan(text: 'Barangay ', children: [TextSpan(text: '*', style: TextStyle(color: Colors.red))])))),
                const SizedBox(height: 6),
                const Align(alignment: Alignment.centerLeft, child: Text('All address fields are required', style: TextStyle(fontSize: 12, color: Colors.redAccent))),
              ]);
            }),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.of(dialogCtx).pop(), child: const Text('Cancel')),
            ElevatedButton(
              onPressed: () async {
                if (firstNameCtrl.text.trim().isEmpty || middleInitialCtrl.text.trim().isEmpty || lastNameCtrl.text.trim().isEmpty || contactCtrl.text.trim().isEmpty || streetCtrl.text.trim().isEmpty || selectedBarangay == null) {
                  ScaffoldMessenger.of(dialogCtx).showSnackBar(const SnackBar(content: Text('Please fill all required fields')));
                  return;
                }

                final fullName = '${firstNameCtrl.text.trim()} ${middleInitialCtrl.text.trim()} ${lastNameCtrl.text.trim()}${suffixCtrl.text.trim().isNotEmpty ? ' ${suffixCtrl.text.trim()}' : ''}';
                final combinedAddress = '${blkLotCtrl.text.trim().isNotEmpty ? '${blkLotCtrl.text.trim()}, ' : ''}${streetCtrl.text.trim()}, $selectedBarangay';

                final navigator = Navigator.of(context);
                final messenger = ScaffoldMessenger.of(context);

                await FirebaseFirestore.instance.collection('customers').doc(user?.uid).set({
                  'fullName': fullName,
                  'contactNumber': contactCtrl.text.trim(),
                  'address': combinedAddress,
                  'email': user?.email,
                  'uid': user?.uid,
                  'updatedAt': FieldValue.serverTimestamp(),
                }, SetOptions(merge: true));

                if (!mounted) return;
                navigator.pop();
                messenger.showSnackBar(const SnackBar(content: Text('Profile updated successfully')));
              },
              child: const Text('Save'),
            ),
          ],
        );
      },
    );
  }

  void _orderGallons(BuildContext context) {
    final qtyCtrl = TextEditingController(text: '1');
    String productType = 'gallon';
    String container = 'blue_round';
    String refillOption = 'with_container';
    String? customerAddress;

    FirebaseFirestore.instance.collection('customers').doc(user?.uid).get().then((doc) {
      if (doc.exists && mounted) customerAddress = doc['address'] as String?;
      if (mounted) setState(() {});
    });

    showDialog(
      context: context,
      builder: (dialogCtx) {
        return StatefulBuilder(builder: (ctx, setState) {
          return AlertDialog(
            title: const Text('Place Order'),
            content: SingleChildScrollView(
              child: Column(mainAxisSize: MainAxisSize.min, children: [
                DropdownButtonFormField<String>(initialValue: productType, items: const [DropdownMenuItem(value: 'gallon', child: Text('Gallon')), DropdownMenuItem(value: 'bottled', child: Text('Bottled Water'))], onChanged: (v) => setState(() => productType = v ?? 'gallon'), decoration: const InputDecoration(labelText: 'Product')),
                const SizedBox(height: 8),
                if (productType == 'gallon') ...[
                  DropdownButtonFormField<String>(initialValue: container, items: const [DropdownMenuItem(value: 'blue_round', child: Text('Blue container — Round')), DropdownMenuItem(value: 'blue_slim', child: Text('Blue container — Slim'))], onChanged: (v) => setState(() => container = v ?? 'blue_round'), decoration: const InputDecoration(labelText: 'Container Type')),
                  const SizedBox(height: 8),
                  DropdownButtonFormField<String>(initialValue: refillOption, items: const [DropdownMenuItem(value: 'with_container', child: Text('With container')), DropdownMenuItem(value: 'refill_only', child: Text('Refill only'))], onChanged: (v) => setState(() => refillOption = v ?? 'with_container'), decoration: const InputDecoration(labelText: 'Refill / Container')),
                  const SizedBox(height: 8),
                ],
                TextField(controller: qtyCtrl, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'Quantity')),
                const SizedBox(height: 12),
                const Align(alignment: Alignment.centerLeft, child: Text('Delivery Address (required):', style: TextStyle(fontWeight: FontWeight.bold))),
                const SizedBox(height: 8),
                Container(width: double.infinity, padding: const EdgeInsets.all(12), decoration: BoxDecoration(border: Border.all(color: Colors.grey), borderRadius: BorderRadius.circular(4)), child: Text(customerAddress ?? 'Loading address...', style: const TextStyle(fontSize: 13))),
              ]),
            ),
            actions: [
              TextButton(onPressed: () => Navigator.of(context).pop(), child: const Text('Cancel')),
              ElevatedButton(
                onPressed: () async {
                  final qty = int.tryParse(qtyCtrl.text) ?? 0;
                  if (qty <= 0) return;
                  if (customerAddress == null || customerAddress!.isEmpty) {
                    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Please complete your profile address first')));
                    return;
                  }

                  final order = model.Order(customerId: user?.uid ?? '', customerName: user?.displayName ?? user?.email, productType: productType, options: {'container': container, 'refill': refillOption}, quantity: qty, address: customerAddress, status: 'pending');
                  final navigator = Navigator.of(context);
                  final messenger = ScaffoldMessenger.of(context);
                  await FirestoreService.createOrder(order);
                  if (!mounted) return;
                  navigator.pop();
                  messenger.showSnackBar(const SnackBar(content: Text('Order submitted!')));
                },
                child: const Text('Submit Order'),
              ),
            ],
          );
        });
      },
    );
  }
}
