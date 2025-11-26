import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:mta_water_delivery/services/firestore_service.dart';
import 'package:mta_water_delivery/screens/order_history.dart';
import 'package:mta_water_delivery/screens/payment/payment_processing.dart';
import 'package:mta_water_delivery/config/product_prices.dart';
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
  bool _profileCheckDone = false;
  final List<Map<String, dynamic>> _cartItems = [];

  @override
  void initState() {
    super.initState();
    _loadLocationData();
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
    if (_profileCheckDone) return;
    _profileCheckDone = true;
    try {
      final doc = await FirebaseFirestore.instance.collection('customers').doc(user?.uid).get();
      final data = doc.data() ?? {};
      final fullName = data['fullName'] ?? '';
      final contactNumber = data['contactNumber'] ?? '';
      final address = data['address'] ?? '';

      if (fullName.isEmpty || contactNumber.isEmpty || address.isEmpty) {
        if (!mounted) return;
        _showRequiredProfileDialog(context, fullName, contactNumber, address);
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
        type: BottomNavigationBarType.fixed,
        items: const [
          BottomNavigationBarItem(icon: Icon(Icons.local_shipping), label: 'Active'),
          BottomNavigationBarItem(icon: Icon(Icons.history), label: 'History'),
          BottomNavigationBarItem(icon: Icon(Icons.add_shopping_cart), label: 'Order'),
          BottomNavigationBarItem(icon: Icon(Icons.person), label: 'Profile'),
        ],
      ),
      floatingActionButton: null,
    );
  }

  Widget _getBodyForIndex(int index) {
    switch (index) {
      case 0:
        return _deliveriesView();
      case 1:
        return _orderHistoryView();
      case 2:
        return _placeOrderView();
      case 3:
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
            options: Map<String, dynamic>.from(data['options'] ?? {}),
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
    final productType = data['product_type'] ?? data['productType'] ?? '';
    final options = (data['options'] is Map) ? Map<String, dynamic>.from(data['options']) : <String, dynamic>{};
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
            if (productType.isNotEmpty) Text('Product: $productType${options.isNotEmpty ? ' • ${options['size'] ?? options['refill'] ?? options['container'] ?? ''}' : ''}'),
          ],
        ),
      ),
    );
  }

  Widget _profileView() {
    // Trigger profile check only when user views the profile tab
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _checkProfileCompletion();
    });

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

  Widget _placeOrderView() {
    return StreamBuilder<DocumentSnapshot>(
      stream: FirebaseFirestore.instance.collection('customers').doc(user?.uid).snapshots(),
      builder: (context, snap) {
        if (!snap.hasData) return const Center(child: CircularProgressIndicator());
        final data = snap.data!.data() as Map<String, dynamic>? ?? {};
        final customerAddress = data['address'] ?? '';
        final totalCost = _cartItems.fold<double>(0, (total, item) {
          final qty = item['quantity'] as int? ?? 0;
          final unit = item['unitPrice'] as double? ?? ProductPrices.getPrice(item['productType'] as String? ?? 'gallon', item['options'] as Map<String, dynamic>?);
          return total + (qty * unit);
        });

        return SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('Place Order', style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold)),
              const SizedBox(height: 20),
              const Text('Select Products', style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold)),
              const SizedBox(height: 8),
              Card(
                child: ListTile(
                  leading: const Icon(Icons.local_drink),
                  title: const Text('Gallon Water'),
                  subtitle: const Text('19L or 20L containers'),
                  trailing: const Icon(Icons.add_circle_outline),
                  onTap: () => _showAddProductDialog(context, 'gallon'),
                ),
              ),
              const SizedBox(height: 8),
              Card(
                child: ListTile(
                  leading: const Icon(Icons.water_drop),
                  title: const Text('Bottled Water'),
                  subtitle: const Text('350ml, 500ml, 1L, 1.5L or 5L bottles'),
                  trailing: const Icon(Icons.add_circle_outline),
                  onTap: () => _showAddProductDialog(context, 'bottled'),
                ),
              ),
              const SizedBox(height: 20),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text('Your Cart', style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold)),
                  Text('${_cartItems.length} item${_cartItems.length != 1 ? 's' : ''}', style: const TextStyle(fontSize: 12, color: Colors.grey)),
                ],
              ),
              const SizedBox(height: 8),
              if (_cartItems.isEmpty)
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(border: Border.all(color: Colors.grey, width: 0.5), borderRadius: BorderRadius.circular(8)),
                  child: const Center(child: Text('No items added yet. Select products above.', style: TextStyle(color: Colors.grey))),
                )
              else
                Column(
                  children: [
                    for (int i = 0; i < _cartItems.length; i++) _buildCartItemTile(i, _cartItems[i]),
                    const SizedBox(height: 12),
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(color: Colors.blue.shade50, borderRadius: BorderRadius.circular(8)),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text('Order Total', style: TextStyle(fontWeight: FontWeight.bold)),
                          const SizedBox(height: 4),
                          Text('₱${totalCost.toStringAsFixed(2)}', style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.blue)),
                        ],
                      ),
                    ),
                  ],
                ),
              const SizedBox(height: 20),
              const Text('Delivery Address', style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold)),
              const SizedBox(height: 8),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(border: Border.all(color: Colors.grey), borderRadius: BorderRadius.circular(8)),
                child: Text(customerAddress.isEmpty ? 'Please complete your profile' : customerAddress, style: const TextStyle(fontSize: 13)),
              ),
              const SizedBox(height: 20),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: _cartItems.isEmpty || customerAddress.isEmpty ? null : () => _proceedToPayment(context, customerAddress, totalCost),
                  style: ElevatedButton.styleFrom(padding: const EdgeInsets.symmetric(vertical: 12)),
                  child: const Text('Proceed to Payment'),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildCartItemTile(int index, Map<String, dynamic> item) {
    final productType = item['productType'] as String;
    final qty = item['quantity'] as int;
            final unitPrice = item['unitPrice'] as double? ?? ProductPrices.getPrice(productType, item['options'] as Map<String, dynamic>?);
    final subtotal = qty * unitPrice;
    final options = item['options'] as Map<String, dynamic>? ?? {};

    final displayText = productType == 'gallon'
      ? 'Gallon (${options['container'] ?? 'blue_round'} - ${options['refill'] ?? 'with_container'}): $qty × ₱${unitPrice.toStringAsFixed(2)}'
      : 'Bottled Water${options['size'] != null ? ' (${options['size']})' : ''}: $qty × ₱${unitPrice.toStringAsFixed(2)}';

    return Card(
      margin: const EdgeInsets.symmetric(vertical: 4),
      child: ListTile(
        title: Text(displayText),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('₱${subtotal.toStringAsFixed(2)}', style: const TextStyle(fontWeight: FontWeight.bold)),
            PopupMenuButton<String>(
              onSelected: (action) {
                if (action == 'edit') {
                  _showEditProductDialog(context, index);
                } else if (action == 'delete') {
                  setState(() => _cartItems.removeAt(index));
                }
              },
              itemBuilder: (_) => [
                const PopupMenuItem(value: 'edit', child: Text('Edit')),
                const PopupMenuItem(value: 'delete', child: Text('Remove')),
              ],
            ),
          ],
        ),
      ),
    );
  }

  void _showAddProductDialog(BuildContext context, String productType) {
    final qtyCtrl = TextEditingController(text: '1');
    String container = 'blue_round';
    String refillOption = 'with_container';

    showDialog(
      context: context,
      builder: (dialogCtx) {
        // bottleSize persisted across rebuilds of the StatefulBuilder
        String bottleSize = '500ml';

        return StatefulBuilder(builder: (ctx, setState) {
            // compute unit price synchronously using ProductPrices and current options
            final double unitPrice = (productType == 'gallon')
              ? ProductPrices.getPrice('gallon', {'refill': refillOption})
              : ProductPrices.getPrice('bottled', {'size': bottleSize});
              return AlertDialog(
                title: Text('Add ${productType == 'gallon' ? 'Gallon' : 'Bottled'} to Cart'),
                content: SingleChildScrollView(
                  child: Column(mainAxisSize: MainAxisSize.min, children: [
                    if (productType == 'gallon') ...[
                      DropdownButtonFormField<String>(
                        initialValue: container,
                        items: const [
                          DropdownMenuItem(value: 'blue_round', child: Text('Blue container — Round')),
                          DropdownMenuItem(value: 'blue_slim', child: Text('Blue container — Slim'))
                        ],
                        onChanged: (v) => setState(() => container = v ?? 'blue_round'),
                        decoration: const InputDecoration(labelText: 'Container Type'),
                      ),
                      const SizedBox(height: 8),
                      DropdownButtonFormField<String>(
                        initialValue: refillOption,
                        items: const [
                          DropdownMenuItem(value: 'with_container', child: Text('With container')),
                          DropdownMenuItem(value: 'refill_only', child: Text('Refill only'))
                        ],
                        onChanged: (v) => setState(() => refillOption = v ?? 'with_container'),
                        decoration: const InputDecoration(labelText: 'Refill / Container'),
                      ),
                      const SizedBox(height: 8),
                    ],
                    if (productType == 'bottled') ...[
                      const SizedBox(height: 8),
                      DropdownButtonFormField<String>(
                        initialValue: bottleSize,
                        items: const [
                          DropdownMenuItem(value: '350ml', child: Text('350 ml')),
                          DropdownMenuItem(value: '500ml', child: Text('500 ml')),
                          DropdownMenuItem(value: '1l', child: Text('1 L')),
                          DropdownMenuItem(value: '1.5l', child: Text('1.5 L')),
                          DropdownMenuItem(value: '5l', child: Text('5 L')),
                        ],
                        onChanged: (v) => setState(() => bottleSize = v ?? '500ml'),
                        decoration: const InputDecoration(labelText: 'Bottle Size'),
                      ),
                      const SizedBox(height: 8),
                    ],
                    TextField(
                      controller: qtyCtrl,
                      keyboardType: TextInputType.number,
                      decoration: const InputDecoration(labelText: 'Quantity'),
                    ),
                    const SizedBox(height: 12),
                    // Display fixed price (read-only)
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(color: Colors.grey[200], borderRadius: BorderRadius.circular(4)),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text('Unit Price: ', style: TextStyle(fontWeight: FontWeight.bold)),
                          Text('₱${unitPrice.toStringAsFixed(2)}',
                            style: const TextStyle(fontWeight: FontWeight.w500)),
                        ],
                      ),
                    ),
                  ]),
                ),
                actions: [
                  TextButton(onPressed: () => Navigator.of(dialogCtx).pop(), child: const Text('Cancel')),
                  ElevatedButton(
                    onPressed: () {
                            final qty = int.tryParse(qtyCtrl.text) ?? 0;
                            if (qty <= 0) return;
                            this.setState(() {
                              _cartItems.add({
                                'productType': productType,
                                'quantity': qty,
                                  'unitPrice': unitPrice,
                                  'options': productType == 'gallon'
                                      ? {'container': container, 'refill': refillOption}
                                      : {'size': bottleSize},
                              });
                            });

                            Navigator.of(dialogCtx).pop();
                          }
                        ,
                    child: const Text('Add to Cart'),
                  ),
                ],
              );
            });
      },
    );
  }

  // NOTE: product prices are computed synchronously via ProductPrices.getPrice

  void _showEditProductDialog(BuildContext context, int index) {
    final item = _cartItems[index];
    final qtyCtrl = TextEditingController(text: '${item['quantity']}');
    String container = item['options']?['container'] ?? 'blue_round';
    String refillOption = item['options']?['refill'] ?? 'with_container';
    final productType = item['productType'] as String;
    String bottleSize = item['options']?['size'] ?? '500ml';

    showDialog(
      context: context,
      builder: (dialogCtx) {
        return StatefulBuilder(builder: (ctx, setState) {
          final double currentUnitPrice = productType == 'gallon'
              ? ProductPrices.getPrice('gallon', {'refill': refillOption})
              : ProductPrices.getPrice('bottled', {'size': bottleSize});

          return AlertDialog(
            title: const Text('Edit Item'),
            content: SingleChildScrollView(
              child: Column(mainAxisSize: MainAxisSize.min, children: [
                if (productType == 'gallon') ...[
                  DropdownButtonFormField<String>(
                    initialValue: container,
                    items: const [
                      DropdownMenuItem(value: 'blue_round', child: Text('Blue container — Round')),
                      DropdownMenuItem(value: 'blue_slim', child: Text('Blue container — Slim'))
                    ],
                    onChanged: (v) => setState(() => container = v ?? 'blue_round'),
                    decoration: const InputDecoration(labelText: 'Container Type'),
                  ),
                  const SizedBox(height: 8),
                  DropdownButtonFormField<String>(
                    initialValue: refillOption,
                    items: const [
                      DropdownMenuItem(value: 'with_container', child: Text('With container')),
                      DropdownMenuItem(value: 'refill_only', child: Text('Refill only'))
                    ],
                    onChanged: (v) => setState(() => refillOption = v ?? 'with_container'),
                    decoration: const InputDecoration(labelText: 'Refill / Container'),
                  ),
                  const SizedBox(height: 8),
                ],
                if (productType == 'bottled') ...[
                  const SizedBox(height: 8),
                  DropdownButtonFormField<String>(
                    initialValue: bottleSize,
                    items: const [
                      DropdownMenuItem(value: '350ml', child: Text('350 ml')),
                      DropdownMenuItem(value: '500ml', child: Text('500 ml')),
                      DropdownMenuItem(value: '1l', child: Text('1 L')),
                      DropdownMenuItem(value: '1.5l', child: Text('1.5 L')),
                      DropdownMenuItem(value: '5l', child: Text('5 L')),
                    ],
                    onChanged: (v) => setState(() => bottleSize = v ?? '500ml'),
                    decoration: const InputDecoration(labelText: 'Bottle Size'),
                  ),
                  const SizedBox(height: 8),
                ],
                TextField(
                  controller: qtyCtrl,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(labelText: 'Quantity'),
                ),
                const SizedBox(height: 12),
                // Display fixed price (read-only)
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(color: Colors.grey[200], borderRadius: BorderRadius.circular(4)),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text('Unit Price: ', style: TextStyle(fontWeight: FontWeight.bold)),
                      Text('₱${currentUnitPrice.toStringAsFixed(2)}'),
                    ],
                  ),
                ),
              ]),
            ),
            actions: [
              TextButton(onPressed: () => Navigator.of(dialogCtx).pop(), child: const Text('Cancel')),
              ElevatedButton(
                  onPressed: () {
                  final qty = int.tryParse(qtyCtrl.text) ?? 0;
                  if (qty <= 0) return;

                  setState(() {
                    _cartItems[index] = {
                      'productType': productType,
                      'quantity': qty,
                      'unitPrice': currentUnitPrice,
                      'options': productType == 'gallon' ? {'container': container, 'refill': refillOption} : {'size': bottleSize},
                    };
                  });

                  Navigator.of(dialogCtx).pop();
                  this.setState(() {});
                },
                child: const Text('Update'),
              ),
            ],
          );
        });
      },
    );
  }

  Future<void> _proceedToPayment(BuildContext context, String customerAddress, double totalCost) async {
    String? selectedMethod = 'GCash';
    final navigatorContext = context; // Capture context before async operation

    await showDialog(
      context: context,
      builder: (payCtx) {
        return StatefulBuilder(builder: (ctx, setState) {
          return AlertDialog(
            title: const Text('Select Payment Method'),
            content: Column(mainAxisSize: MainAxisSize.min, children: [
              // ignore: deprecated_member_use
              RadioListTile<String>(
                value: 'GCash',
                // ignore: deprecated_member_use
                groupValue: selectedMethod,
                title: const Text('GCash (Online)'),
                // ignore: deprecated_member_use
                onChanged: (v) => setState(() => selectedMethod = v),
              ),
              // ignore: deprecated_member_use
              RadioListTile<String>(
                value: 'PayPal',
                // ignore: deprecated_member_use
                groupValue: selectedMethod,
                title: const Text('PayPal (Online)'),
                // ignore: deprecated_member_use
                onChanged: (v) => setState(() => selectedMethod = v),
              ),
              // ignore: deprecated_member_use
              RadioListTile<String>(
                value: 'COD',
                // ignore: deprecated_member_use
                groupValue: selectedMethod,
                title: const Text('Cash on Delivery (COD)'),
                // ignore: deprecated_member_use
                onChanged: (v) => setState(() => selectedMethod = v),
              ),
            ]),
            actions: [
              TextButton(onPressed: () => Navigator.of(payCtx).pop(), child: const Text('Cancel')),
              ElevatedButton(
                onPressed: () async {
                  if (selectedMethod == null) return;
                  Navigator.of(payCtx).pop();

                  final messenger = ScaffoldMessenger.of(navigatorContext);

                  // Create a single multi-item order containing all cart items
                  // Resolve a reliable customer name: prefer the customer's
                  // saved profile fullName when available. Fall back to the
                  // Firebase user displayName or email as a last resort.
                  String resolvedName = user?.displayName ?? '';
                  try {
                    final custSnap = await FirebaseFirestore.instance.collection('customers').doc(user?.uid).get();
                    if (custSnap.exists) {
                      final raw = custSnap.data() ?? {};
                      final cand = raw['fullName'] ?? raw['name'];
                      if (cand != null && cand.toString().trim().isNotEmpty) resolvedName = cand.toString();
                    }
                  } catch (_) {}

                  final orderMap = {
                    'customer_id': user?.uid ?? '',
                    'customer_name': resolvedName.isNotEmpty ? resolvedName : (user?.displayName ?? user?.email),
                    'items': _cartItems.map((it) => Map<String, dynamic>.from(it)).toList(),
                    'totalAmount': totalCost,
                    'address': customerAddress,
                    'status': 'pending',
                    'paymentType': selectedMethod,
                  };

                  await FirestoreService.createOrderFromMap(orderMap);

                  if (!mounted) return;

                  if (selectedMethod == 'COD') {
                    messenger.showSnackBar(const SnackBar(content: Text('Orders placed (COD). Processing.')));
                    setState(() => _cartItems.clear());
                  } else {
                    // ignore: use_build_context_synchronously
                    final paid = await Navigator.of(navigatorContext).push<bool>(
                      MaterialPageRoute(builder: (_) => PaymentProcessingPage(amount: totalCost, paymentMethod: selectedMethod!)),
                    );
                    if (!mounted) return;
                    if (paid == true) {
                      messenger.showSnackBar(const SnackBar(content: Text('Payment successful')));
                      setState(() => _cartItems.clear());
                    } else {
                      messenger.showSnackBar(const SnackBar(content: Text('Payment not completed')));
                    }
                  }
                },
                child: const Text('Proceed'),
              ),
            ],
          );
        });
      },
    );
  }
}
