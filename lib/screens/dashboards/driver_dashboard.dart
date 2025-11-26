// driver_dashboard.dart
// Driver Dashboard for delivery personnel
// Features: Assigned deliveries, Completed deliveries, Notifications, Profile

// Avoid importing dart:io to keep this file web-compatible. Use XFile.readAsBytes()
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:mta_water_delivery/widgets/signature_pad.dart';

class DriverDashboardPage extends StatefulWidget {
  final Map<String, dynamic> staff;

  const DriverDashboardPage({super.key, required this.staff});

  @override
  State<DriverDashboardPage> createState() => _DriverDashboardPageState();
}

class _DriverDashboardPageState extends State<DriverDashboardPage> {
  int _selectedIndex = 0;
  late final Map<String, dynamic> staff;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final ImagePicker _picker = ImagePicker();

  @override
  void initState() {
    super.initState();
    staff = widget.staff;
    // Mark driver online when opening the dashboard so staff assignment queries
    // can discover this driver. Fire-and-forget update to keep UI responsive.
    _setDriverStatus('online');
  }

  Future<void> _setDriverStatus(String val) async {
    try {
      // Try updating the canonical 'drivers' collection first. If the
      // authenticated driver is not allowed to write there, fall back to
      // updating their 'staff' document if available.
      await _firestore.collection('drivers').doc(staff['id']).set({'status': val}, SetOptions(merge: true));
      return;
    } catch (e) {
      debugPrint('Failed to update drivers collection: $e — attempting staff fallback');
    }

    try {
      await _firestore.collection('staff').doc(staff['id']).set({'status': val}, SetOptions(merge: true));
    } catch (e) {
      debugPrint('Failed to update staff collection fallback: $e');
      rethrow; // let callers decide whether to swallow or propagate
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Driver Dashboard (${staff['name'] ?? ''})'),
        actions: [
            IconButton(
            icon: const Icon(Icons.logout),
            onPressed: () async {
              // mark offline before leaving
              final nav = Navigator.of(context);
              await _setDriverStatus('offline');
              if (!mounted) return;
              nav.pop();
            },
            tooltip: 'Logout',
          ),
        ],
      ),
      body: LayoutBuilder(builder: (ctx, constraints) {
        // Use NavigationRail on wide screens and BottomNavigationBar on narrow (mobile)
        final bool useRail = constraints.maxWidth >= 700;
        if (useRail) {
          return Row(
            children: [
              NavigationRail(
                selectedIndex: _selectedIndex,
                onDestinationSelected: (index) => setState(() => _selectedIndex = index),
                labelType: NavigationRailLabelType.all,
                destinations: const [
                  NavigationRailDestination(
                    icon: Icon(Icons.local_shipping_outlined),
                    selectedIcon: Icon(Icons.local_shipping),
                    label: Text('Assigned'),
                  ),
                  NavigationRailDestination(
                    icon: Icon(Icons.check_circle_outline),
                    selectedIcon: Icon(Icons.check_circle),
                    label: Text('Completed'),
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

        // Mobile layout (narrow): main content with BottomNavigationBar
        return Column(
          children: [
            Expanded(child: _buildPage()),
            SafeArea(
              child: BottomNavigationBar(
                currentIndex: _selectedIndex,
                onTap: (idx) => setState(() => _selectedIndex = idx),
                type: BottomNavigationBarType.fixed,
                items: const [
                  BottomNavigationBarItem(icon: Icon(Icons.local_shipping_outlined), label: 'Assigned'),
                  BottomNavigationBarItem(icon: Icon(Icons.check_circle_outline), label: 'Completed'),
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
        return _assignedDeliveriesPage();
      case 1:
        return _completedDeliveriesPage();
      case 2:
        return _notificationsPage();
      case 3:
        return _profilePage();
      default:
        return _assignedDeliveriesPage();
    }
  }

  // ------------------- Assigned Deliveries -------------------
  Widget _assignedDeliveriesPage() {
    return StreamBuilder<QuerySnapshot>(
          // Query by `driver_id` only and do status filtering client-side to
          // avoid composite index requirements. Firestore returns an error when
          // a query mixes whereIn + orderBy on another field unless a composite
          // index is created. Fetching by driver_id and ordering by scheduledAt
          // is supported with single-field indexes and keeps the UI responsive.
          stream: _firestore
            .collection('deliveries')
            .where('driver_id', isEqualTo: staff['id'])
            .snapshots(),
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return Center(child: Text('Error: ${snapshot.error}'));
        }
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }

        final docs = snapshot.data?.docs ?? [];
        // Filter statuses client-side (avoid whereIn to prevent index errors)
        final filteredDocs = docs.where((doc) {
          final d = doc.data() as Map<String, dynamic>;
          final status = (d['status'] ?? '').toString().toLowerCase();
          return status == 'assigned' || status == 'on_delivery' || status == 'on_the_way';
        }).toList();

        // Sort client-side by scheduledAt (oldest first). Avoid server-side
        // orderBy to prevent composite index requirements on the query.
        DateTime extractScheduled(QueryDocumentSnapshot doc) {
          final d = doc.data() as Map<String, dynamic>;
          final v = d['scheduledAt'];
          if (v is Timestamp) return v.toDate();
          if (v is DateTime) return v;
          return DateTime.fromMillisecondsSinceEpoch(0);
        }

        filteredDocs.sort((a, b) => extractScheduled(a).compareTo(extractScheduled(b)));

        if (filteredDocs.isEmpty) {
          return const Center(child: Text('No assigned deliveries.'));
        }

        // Group deliveries by order_id (if present) so drivers see items from
        // the same order grouped together instead of separate list items.
        final Map<String, List<QueryDocumentSnapshot>> grouped = {};
        for (final doc in filteredDocs) {
          final d = doc.data() as Map<String, dynamic>;
          final orderId = (d['order_id'] ?? d['orderId'])?.toString() ?? doc.id;
          grouped.putIfAbsent(orderId, () => []).add(doc);
        }

        final groups = grouped.entries.toList();

        return ListView.builder(
          padding: const EdgeInsets.all(16),
          itemCount: groups.length,
          itemBuilder: (context, index) {
            final orderId = groups[index].key;
            final groupDocs = groups[index].value;
            // Merge deliveries in this group to build a robust header. Some
            // older systems may not copy order/customer fields into every
            // delivery, so prefer the first non-empty value from any item.
            final headerData = <String, dynamic>{};
            for (final doc in groupDocs) {
              final d = doc.data() as Map<String, dynamic>;
              headerData['customerName'] ??= (d['customer_name'] ?? d['customerName'] ?? d['customer'] ?? '').toString().trim();
              headerData['address'] ??= (d['address'] ?? d['addr'] ?? '').toString().trim();
              headerData['phone'] ??= (d['phone'] ?? d['contact'] ?? d['phoneNumber'] ?? '').toString().trim();
              headerData['customer_email'] ??= (d['customer_email'] ?? d['email'] ?? '').toString().trim();
              headerData['paymentType'] ??= (d['paymentType'] ?? d['payment_type'] ?? '').toString().trim();
              headerData['totalAmount'] ??= (d['totalAmount'] ?? d['total_amount'] ?? '').toString().trim();
              headerData['notes'] ??= (d['notes'] ?? '').toString().trim();
              headerData['scheduledAt'] ??= d['scheduledAt'];
              headerData['timestamp'] ??= d['timestamp'];
            }

            // Build a resilient future that tries orders/{orderId}, then
            // queries orders by delivery id fields so we can find the order
            // even when its id wasn't stored in the delivery.
            final Future<DocumentSnapshot> orderFuture = (() async {
              final docSnap = await _firestore.collection('orders').doc(orderId).get();
              if (docSnap.exists) return docSnap;
              try {
                final q = await _firestore.collection('orders').where('delivery_ids', arrayContains: groupDocs.first.id).limit(1).get();
                if (q.docs.isNotEmpty) return q.docs.first;
              } catch (_) {}
              try {
                final q2 = await _firestore.collection('orders').where('delivery_id', isEqualTo: groupDocs.first.id).limit(1).get();
                if (q2.docs.isNotEmpty) return q2.docs.first;
              } catch (_) {}
              return docSnap;
            })();

            return Card(
              elevation: 2,
              margin: const EdgeInsets.symmetric(vertical: 8),
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        const Icon(Icons.local_shipping),
                        const SizedBox(width: 8),
                        // Use merged header name first; fall back to orders/customers
                        // lookup when not available.
                        Builder(builder: (ctx) {
                          final rawName = (headerData['customerName'] ?? '').toString().trim();
                          bool looksLikeEmail(String s) => s.contains('@') && s.contains('.');
                          final nameVal = (rawName.isNotEmpty && !looksLikeEmail(rawName)) ? rawName : '';
                          if (nameVal.isNotEmpty) return Expanded(child: Text(nameVal, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)));
                          return Expanded(
                            child: FutureBuilder<DocumentSnapshot>(
                              future: orderFuture,
                              builder: (nCtx, orderSnap) {
                                if (orderSnap.hasError) return const Text('Unknown', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold));
                                if (!orderSnap.hasData) return const Text('Unknown', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold));
                                final orderD = orderSnap.data!.data() as Map<String, dynamic>? ?? {};
                                final orderName = (orderD['customer_name'] ?? orderD['customerName'] ?? orderD['customer'] ?? '').toString().trim();
                                if (orderName.isNotEmpty) return Text(orderName, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold));
                                if (orderD['customer_id'] != null) {
                                  return FutureBuilder<DocumentSnapshot>(
                                    future: _firestore.collection('customers').doc(orderD['customer_id']).get(),
                                    builder: (cCtx, custSnap) {
                                      if (custSnap.hasError) return const Text('Unknown', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold));
                                      if (!custSnap.hasData) return const Text('Unknown', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold));
                                      final cust = custSnap.data!.data() as Map<String, dynamic>? ?? {};
                                      final custName = (cust['fullName'] ?? cust['name'] ?? '').toString().trim();
                                      return Text(custName.isNotEmpty ? custName : 'Unknown', style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold));
                                    },
                                  );
                                }
                                return const Text('Unknown', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold));
                              },
                            ),
                          );
                        }),
                        Text('Order: ${orderId.substring(0, orderId.length > 8 ? 8 : orderId.length)}', style: const TextStyle(fontSize: 12, color: Colors.grey)),
                        const SizedBox(width: 8),
                        // Button to open full order details in a dialog so drivers can
                        // always inspect the full order/customer record even if the
                        // delivery doc lacks the fields.
                        TextButton(
                          onPressed: () => _showOrderDetailsDialog(orderId, groupDocs),
                          child: const Text('View order', style: TextStyle(fontSize: 12)),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Text('Address: ${headerData['address'] ?? '-'}'),
                    const SizedBox(height: 8),
                    // Contact details (phone, email). If missing we'll attempt
                    // to fetch more info from the order document below.
                    if ((headerData['phone'] ?? '').toString().isNotEmpty) ...[
                      Row(children: [const Icon(Icons.phone, size: 16), const SizedBox(width: 8), Expanded(child: Text(headerData['phone'].toString()))]),
                      const SizedBox(height: 8),
                    ],
                    if ((headerData['customer_email'] ?? headerData['email'] ?? '').toString().isNotEmpty) ...[
                      Row(children: [const Icon(Icons.email, size: 16), const SizedBox(width: 8), Expanded(child: Text((headerData['customer_email'] ?? headerData['email']).toString()))]),
                      const SizedBox(height: 8),
                    ],

                    // Order metadata
                    if ((headerData['paymentType'] ?? headerData['payment_type'] ?? '').toString().isNotEmpty) ...[
                      Row(children: [const Icon(Icons.payment, size: 16), const SizedBox(width: 8), Expanded(child: Text('Payment: ${(headerData['paymentType'] ?? headerData['payment_type']).toString()}'))]),
                      const SizedBox(height: 8),
                    ],
                    if ((headerData['totalAmount'] ?? headerData['total_amount'] ?? '').toString().isNotEmpty) ...[
                      Row(children: [const Icon(Icons.attach_money, size: 16), const SizedBox(width: 8), Expanded(child: Text('Total: ${(headerData['totalAmount'] ?? headerData['total_amount']).toString()}'))]),
                      const SizedBox(height: 8),
                    ],
                    if ((headerData['notes'] ?? '').toString().isNotEmpty) ...[
                      Row(children: [const Icon(Icons.notes, size: 16), const SizedBox(width: 8), Expanded(child: Text(headerData['notes'].toString()))]),
                      const SizedBox(height: 8),
                    ],
                    // Show scheduled time / order timestamp when available
                    if (headerData['scheduledAt'] != null) ...[
                      Row(children: [const Icon(Icons.schedule, size: 16), const SizedBox(width: 8), Expanded(child: Text('Scheduled: ${_formatDateTime(headerData['scheduledAt'])}'))]),
                      const SizedBox(height: 8),
                    ],
                    if (headerData['timestamp'] != null) ...[
                      Row(children: [const Icon(Icons.access_time, size: 16), const SizedBox(width: 8), Expanded(child: Text('Ordered: ${_formatDateTime(headerData['timestamp'])}'))]),
                      const SizedBox(height: 8),
                    ],

                    // If we don't have contact info in the delivery header, try
                    // to load it from the 'orders' document (or the customers
                    // record). This gives a better chance to show phone/email
                    // when orders were created without copying contact fields
                    // into the delivery document.
                    if ((headerData['phone'] ?? '').toString().isEmpty || (headerData['customer_email'] ?? headerData['email'] ?? '').toString().isEmpty)
                      FutureBuilder<DocumentSnapshot>(
                        future: _firestore.collection('orders').doc(orderId).get(),
                        builder: (ctx, orderSnap) {
                          if (orderSnap.hasError) return const SizedBox.shrink();
                          if (!orderSnap.hasData) return const SizedBox.shrink();

                          final orderD = orderSnap.data!.data() as Map<String, dynamic>? ?? {};
                          // Use any missing fields from orderD: phone, email, address
                          final String phone = (headerData['phone'] ?? orderD['phone'] ?? orderD['contact'] ?? '')?.toString() ?? '';
                          final String email = (headerData['customer_email'] ?? headerData['email'] ?? orderD['customer_email'] ?? orderD['email'])?.toString() ?? '';

                          if (phone.isEmpty && (orderD['customer_id'] != null)) {
                            // If still empty, try looking up the customer doc
                            return FutureBuilder<DocumentSnapshot>(
                              future: _firestore.collection('customers').doc(orderD['customer_id']).get(),
                              builder: (c2, custSnap) {
                                if (custSnap.hasError) return const SizedBox.shrink();
                                if (!custSnap.hasData) return const SizedBox.shrink();
                                final cust = custSnap.data!.data() as Map<String, dynamic>? ?? {};
                                final String custPhone = phone.isNotEmpty ? phone : (cust['contactNumber'] ?? cust['phone'] ?? '')?.toString() ?? '';
                                final String custEmail = email.isNotEmpty ? email : (cust['email'] ?? '')?.toString() ?? '';
                                return Column(
                                  children: [
                                    if (custPhone.isNotEmpty) Row(children: [const Icon(Icons.phone, size: 16), const SizedBox(width: 8), Expanded(child: Text(custPhone))]),
                                    if (custEmail.isNotEmpty) Row(children: [const Icon(Icons.email, size: 16), const SizedBox(width: 8), Expanded(child: Text(custEmail))]),
                                  ],
                                );
                              },
                            );
                          }

                          // We have phone/email from order or header
                          return Column(
                            children: [
                              if (phone.isNotEmpty) Row(children: [const Icon(Icons.phone, size: 16), const SizedBox(width: 8), Expanded(child: Text(phone))]),
                              if (email.isNotEmpty) Row(children: [const Icon(Icons.email, size: 16), const SizedBox(width: 8), Expanded(child: Text(email))]),
                            ],
                          );
                        },
                      ),

                    // Itemized view for deliveries that belong to this order
                    Column(
                      children: groupDocs.map((doc) {
                        final d = doc.data() as Map<String, dynamic>;
                        final title = (d['product_type'] ?? d['productType']) ?? 'Product';
                        final opts = (d['options'] is Map) ? (d['options'] as Map).entries.map((e) => '${e.key}:${e.value}').join(', ') : '';
                        final qty = d['quantity']?.toString() ?? d['gallons']?.toString() ?? '-';

                        return ListTile(
                          contentPadding: EdgeInsets.zero,
                          title: Text('$title • Qty: $qty'),
                          subtitle: opts.isNotEmpty ? Text(opts, style: const TextStyle(fontSize: 12, color: Colors.grey)) : null,
                          trailing: PopupMenuButton<String>(
                            onSelected: (action) => _handleAssignedAction(action, doc.id, d),
                            itemBuilder: (_) => [
                              const PopupMenuItem(value: 'start', child: Text('Start Delivery')),
                              const PopupMenuItem(value: 'deliver', child: Text('Mark Delivered')),
                              const PopupMenuItem(value: 'fail', child: Text('Mark Failed')),
                            ],
                          ),
                          onTap: () => _openDeliveryDetails(doc.id, d),
                        );
                      }).toList(),
                    ),
                  ],
                ),
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

  String _formatDateTime(dynamic value) {
    if (value == null) return '-';
    DateTime dt;
    if (value is Timestamp) {
      dt = value.toDate();
    } else if (value is DateTime) {
      dt = value;
    } else if (value is int) {
      dt = DateTime.fromMillisecondsSinceEpoch(value);
    } else if (value is String) {
      // try parse
      try {
        dt = DateTime.parse(value);
      } catch (_) {
        return value.toString();
      }
    } else {
      return value.toString();
    }

    return dt.toLocal().toString().split('.').first;
  }

  Future<void> _handleAssignedAction(String action, String id, Map d) async {
    switch (action) {
      case 'start':
        await _firestore.collection('deliveries').doc(id).update({'status': 'on_delivery'});
        await _logActivity('Started delivery $id');
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Delivery marked as on the way')),
        );
        break;
      case 'deliver':
        await _markAsDelivered(id);
        break;
      case 'fail':
        await _firestore.collection('deliveries').doc(id).update({'status': 'failed'});
        await _logActivity('Marked failed $id');
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Delivery marked as failed')),
        );
        break;
    }
  }

  Future<void> _markAsDelivered(String id) async {
    // Show proof of delivery dialog with signature and camera options
    if (!mounted) return;
    
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Proof of Delivery'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('Capture proof of delivery:'),
            const SizedBox(height: 16),
            ElevatedButton.icon(
              onPressed: () async {
                Navigator.pop(ctx);
                await _captureProofPhoto(id);
              },
              icon: const Icon(Icons.camera_alt),
              label: const Text('Take Photo'),
            ),
            const SizedBox(height: 12),
            ElevatedButton.icon(
              onPressed: () {
                Navigator.pop(ctx);
                _showSignatureDialog(id);
              },
              icon: const Icon(Icons.edit),
              label: const Text('Get Signature'),
            ),
            const SizedBox(height: 12),
            OutlinedButton(
              onPressed: () {
                Navigator.pop(ctx);
                _completeDelivery(id, null, null);
              },
              child: const Text('Skip (No Proof)'),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _showOrderDetailsDialog(String orderId, List<QueryDocumentSnapshot> groupDocs) async {
    // Use the robust order lookup (try orderId, or search by delivery ids)
    DocumentSnapshot? orderSnap;
    try {
      final o = await _firestore.collection('orders').doc(orderId).get();
      if (o.exists) orderSnap = o;
    } catch (_) {}

    if (orderSnap == null) {
      try {
        final q = await _firestore.collection('orders').where('delivery_ids', arrayContains: groupDocs.first.id).limit(1).get();
        if (q.docs.isNotEmpty) orderSnap = q.docs.first;
      } catch (_) {}
    }

    if (orderSnap == null) {
      try {
        final q2 = await _firestore.collection('orders').where('delivery_id', isEqualTo: groupDocs.first.id).limit(1).get();
        if (q2.docs.isNotEmpty) orderSnap = q2.docs.first;
      } catch (_) {}
    }

    // If still missing, show message
    if (orderSnap == null || !orderSnap.exists) {
      if (!mounted) return;
      showDialog(context: context, builder: (ctx) => AlertDialog(title: const Text('Order details'), content: const Text('Order document not found or not visible.'), actions: [TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Close'))]));
      return;
    }

    final orderData = orderSnap.data() as Map<String, dynamic>;

    // Fetch customer doc if referenced
    Map<String, dynamic>? customerData;
    if (orderData['customer_id'] != null) {
      try {
        final cs = await _firestore.collection('customers').doc(orderData['customer_id']).get();
        if (cs.exists) customerData = cs.data() as Map<String, dynamic>;
      } catch (_) {}
    }

    if (!mounted) return;
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Order details'),
        content: SizedBox(
          width: double.maxFinite,
          child: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Order ID: $orderId'),
                const SizedBox(height: 8),
                Text('Customer: ${orderData['customer_name'] ?? orderData['customerName'] ?? customerData?['fullName'] ?? customerData?['name'] ?? '-'}'),
                if ((customerData?['contactNumber'] ?? orderData['phone'] ?? orderData['contact']) != null) Text('Phone: ${(customerData?['contactNumber'] ?? orderData['phone'] ?? orderData['contact']).toString()}'),
                if ((customerData?['email'] ?? orderData['customer_email'] ?? orderData['email']) != null) Text('Email: ${(customerData?['email'] ?? orderData['customer_email'] ?? orderData['email']).toString()}'),
                const Divider(),
                Text('Address: ${orderData['address'] ?? '-'}'),
                const SizedBox(height: 8),
                Text('Payment: ${orderData['paymentType'] ?? orderData['payment_type'] ?? '-'}'),
                if (orderData['totalAmount'] != null) Text('Total: ${orderData['totalAmount']}'),
                if (orderData['notes'] != null) Text('Notes: ${orderData['notes']}'),
                const SizedBox(height: 12),
                const Text('Items:', style: TextStyle(fontWeight: FontWeight.bold)),
                if (orderData['items'] is List)
                  ...((orderData['items'] as List).map((it) => Padding(padding: const EdgeInsets.only(top: 6), child: Text('- ${it['product_name'] ?? it['productName'] ?? it['product_type'] ?? ''} x ${it['quantity'] ?? ''}'))).toList()),
              ],
            ),
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Close')),
        ],
      ),
    );
  }

  Future<void> _captureProofPhoto(String id) async {
    try {
      final image = await _picker.pickImage(source: ImageSource.camera);
      if (image == null) return;

      // Upload image to Firebase Storage using bytes so it works on web and mobile
      final bytes = await image.readAsBytes();
      final fileName = 'proofs/delivery_${id}_${DateTime.now().millisecondsSinceEpoch}.jpg';
      final ref = FirebaseStorage.instance.ref().child(fileName);
      await ref.putData(bytes);
      final photoUrl = await ref.getDownloadURL();

      await _completeDelivery(id, photoUrl, null);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error: $e')),
      );
    }
  }

  void _showSignatureDialog(String id) {
    showDialog(
      context: context,
      builder: (ctx) => SignatureDialog(
        customerName: 'Customer',
        onSignatureCaptured: (signature) async {
          // Upload signature to Firebase Storage
          try {
            final fileName = 'signatures/delivery_${id}_${DateTime.now().millisecondsSinceEpoch}.png';
            final ref = FirebaseStorage.instance.ref().child(fileName);
            await ref.putData(signature);
            final signatureUrl = await ref.getDownloadURL();
            
            await _completeDelivery(id, null, signatureUrl);
          } catch (e) {
            if (!mounted) return;
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text('Error saving signature: $e')),
            );
          }
        },
      ),
    );
  }

  Future<void> _completeDelivery(String id, String? photoUrl, String? signatureUrl) async {
    try {
      final update = {
        'status': 'completed',
        'deliveredAt': FieldValue.serverTimestamp(),
      };
      
      if (photoUrl != null) {
        update['proofPhoto'] = photoUrl;
      }
      if (signatureUrl != null) {
        update['proofSignature'] = signatureUrl;
      }

      await _firestore.collection('deliveries').doc(id).update(update);
      await _logActivity('Delivered $id with proof');
      
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Delivery completed with proof')),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error: $e')),
      );
    }
  }

  // ------------------- Completed Deliveries -------------------
  Widget _completedDeliveriesPage() {
    return StreamBuilder<QuerySnapshot>(
        // Also query completed deliveries by driver_id for the same reason above.
        stream: _firestore
          .collection('deliveries')
          .where('driver_id', isEqualTo: staff['id'])
          .where('status', isEqualTo: 'completed')
          .orderBy('deliveredAt', descending: true)
          .snapshots(),
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return Center(child: Text('Error: ${snapshot.error}'));
        }
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }

        final docs = snapshot.data?.docs ?? [];
        if (docs.isEmpty) {
          return const Center(child: Text('No completed deliveries.'));
        }

        return ListView.builder(
          padding: const EdgeInsets.all(16),
          itemCount: docs.length,
          itemBuilder: (context, index) {
            final doc = docs[index];
            final d = doc.data() as Map<String, dynamic>;

            return Card(
              elevation: 1,
              margin: const EdgeInsets.symmetric(vertical: 8),
              color: Colors.green.shade50,
              child: ListTile(
                leading: const Icon(Icons.check_circle, color: Colors.green),
                title: Text(() {
                  final raw = (d['customerName'] ?? d['customer_name'] ?? '').toString();
                  bool looksLikeEmail(String s) => s.contains('@') && s.contains('.');
                  if (raw.isNotEmpty && !looksLikeEmail(raw)) return raw;
                  return 'Unknown';
                }()),
                subtitle: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Address: ${d['address'] ?? '-'}'),
                    if ((d['product_type'] ?? d['productType']) != null)
                      Text('Product: ${d['product_type'] ?? d['productType']}${(d['options'] is Map && (d['options'] as Map).isNotEmpty) ? ' • ${(d['options'] as Map)['size'] ?? (d['options'] as Map)['refill'] ?? (d['options'] as Map)['container'] ?? ''}' : ''}'),
                    Text('Gallons: ${_formatGallons(d['gallons'])}'),
                    if (d['deliveredAt'] != null)
                      Text(
                        'Delivered: ${(d['deliveredAt'] as Timestamp).toDate().toString().split('.')[0]}',
                      ),
                  ],
                ),
                isThreeLine: true,
                onTap: () => _openDeliveryDetails(doc.id, d),
              ),
            );
          },
        );
      },
    );
  }

  // ------------------- Notifications -------------------
  Widget _notificationsPage() {
    return StreamBuilder<QuerySnapshot>(
      stream: _firestore
          .collection('notifications')
          .where('driverId', isEqualTo: staff['id'])
          .orderBy('timestamp', descending: true)
          .snapshots(),
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return Center(child: Text('Error: ${snapshot.error}'));
        }
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }

        final docs = snapshot.data?.docs ?? [];
        if (docs.isEmpty) {
          return const Center(child: Text('No notifications yet.'));
        }

        return ListView.builder(
          padding: const EdgeInsets.all(16),
          itemCount: docs.length,
          itemBuilder: (context, index) {
            final doc = docs[index];
            final notification = doc.data() as Map<String, dynamic>;

            return Card(
              elevation: 2,
              margin: const EdgeInsets.symmetric(vertical: 8),
              child: ListTile(
                leading: Icon(
                  notification['type'] == 'assignment' ? Icons.assignment : Icons.info,
                  color: notification['type'] == 'assignment' ? Colors.orange : Colors.blue,
                ),
                title: Text(notification['title'] ?? 'Notification'),
                subtitle: Text(notification['message'] ?? ''),
                trailing: notification['timestamp'] != null
                    ? Text(
                        (notification['timestamp'] as Timestamp).toDate().toString().split('.')[0],
                        style: const TextStyle(fontSize: 12),
                      )
                    : null,
              ),
            );
          },
        );
      },
    );
  }

  // ------------------- Delivery Details -------------------
  Future<void> _openDeliveryDetails(String deliveryId, Map details) async {
    showModalBottomSheet(
      context: context,
      builder: (_) => Container(
        padding: const EdgeInsets.all(16),
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(() {
                final raw = (details['customerName'] ?? details['customer_name'] ?? '')?.toString() ?? '';
                bool looksLikeEmail(String s) => s.contains('@') && s.contains('.');
                if (raw.isNotEmpty && !looksLikeEmail(raw)) return raw;
                return 'Unknown';
              }(),
                  style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
              const SizedBox(height: 12),
              Text('Address: ${details['address'] ?? '-'}'),
              Text('Phone: ${details['phone'] ?? '-'}'),
              Text('Gallons: ${_formatGallons(details['gallons'])}'),
              Text('Payment Type: ${details['paymentType'] ?? 'N/A'}'),
              if (details['notes'] != null) Text('Notes: ${details['notes']}'),
              const SizedBox(height: 16),
              if (details['proofUrl'] != null)
                Column(
                  children: [
                    const Text('Delivery Proof:',
                        style: TextStyle(fontWeight: FontWeight.bold)),
                    const SizedBox(height: 8),
                    Image.network(
                      details['proofUrl'],
                      height: 200,
                      fit: BoxFit.cover,
                    ),
                    const SizedBox(height: 16),
                  ],
                ),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceAround,
                children: [
                  ElevatedButton.icon(
                    onPressed: () => _makeCall(details['phone']),
                    icon: const Icon(Icons.phone),
                    label: const Text('Call'),
                  ),
                  ElevatedButton.icon(
                    onPressed: () => _openMaps(details['address']),
                    icon: const Icon(Icons.navigation),
                    label: const Text('Navigate'),
                  ),
                  if (details['status'] == 'on_the_way')
                    ElevatedButton.icon(
                      onPressed: () => _uploadProof(deliveryId),
                      icon: const Icon(Icons.camera_alt),
                      label: const Text('Upload Proof'),
                    ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _makeCall(String? phone) async {
    if (phone == null || phone.isEmpty) return;
    final uri = Uri(scheme: 'tel', path: phone);
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri);
    }
  }

  Future<void> _openMaps(String? address) async {
    if (address == null || address.isEmpty) return;
    final uri = Uri.https(
      'www.google.com',
      '/maps/search/',
      {'query': address},
    );
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    }
  }

  Future<void> _uploadProof(String deliveryId) async {
    try {
      final image = await _picker.pickImage(source: ImageSource.camera);
      if (image == null) return;

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Uploading proof photo...')),
      );

        // Use bytes instead of dart:io File so this runs on web as well
        final bytes = await image.readAsBytes();
      final ref = FirebaseStorage.instance
          .ref()
          .child('deliveries')
          .child(deliveryId)
          .child('proof_${DateTime.now().millisecondsSinceEpoch}.jpg');

        await ref.putData(bytes);
      final url = await ref.getDownloadURL();

      await _firestore.collection('deliveries').doc(deliveryId).update({
        'proofUrl': url,
      });

      await _logActivity('Uploaded proof for delivery $deliveryId');

      if (!mounted) return;
      Navigator.pop(context);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Proof uploaded successfully!')),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to upload proof: $e')),
      );
    }
  }

  // ------------------- Profile Page -------------------
  Widget _profilePage() {
    return Center(
      child: Card(
        margin: const EdgeInsets.all(24),
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Driver Profile',
                style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 24),
              _buildProfileField('Name', staff['name'] ?? 'Not set'),
              _buildProfileField('Email', staff['email'] ?? 'Not set'),
              _buildProfileField('Status', staff['status'] ?? 'Not set'),
              const SizedBox(height: 8),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: () => _changeStatusDialog(),
                  icon: const Icon(Icons.sync_alt),
                  label: const Text('Change Status'),
                ),
              ),
              const SizedBox(height: 24),
              if (staff['createdAt'] != null)
                _buildProfileField(
                  'Joined',
                  (staff['createdAt'] as Timestamp).toDate().toString().split('.')[0],
                ),
              const SizedBox(height: 24),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: () => Navigator.pop(context),
                  icon: const Icon(Icons.logout),
                  label: const Text('Logout'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.red,
                    foregroundColor: Colors.white,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildProfileField(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        children: [
          SizedBox(
            width: 100,
            child: Text(
              label,
              style: const TextStyle(fontWeight: FontWeight.w600),
            ),
          ),
          Expanded(
            child: Text(value),
          ),
        ],
      ),
    );
  }

  // ------------------- Activity Logging -------------------
  Future<void> _logActivity(String message) async {
    try {
      await _firestore
          .collection('staff')
          .doc(staff['id'])
          .collection('activity_logs')
          .add({
        'message': message,
        'timestamp': FieldValue.serverTimestamp(),
      });
    } catch (e) {
      debugPrint('Error logging activity: $e');
    }
  }

  Future<void> _changeStatusDialog() async {
    // Use canonical driver statuses, show friendly labels
    final statuses = [
      {'label': 'Online', 'value': 'online'},
      {'label': 'On Delivery', 'value': 'on_delivery'},
      {'label': 'On Break', 'value': 'break'},
      {'label': 'Offline', 'value': 'offline'},
    ];

    // capture widget context
    final widgetContext = context;

    await showDialog<void>(
      context: widgetContext,
      builder: (dialogCtx) => SimpleDialog(
        title: const Text('Change Status'),
        children: statuses
            .map((s) => SimpleDialogOption(
                    onPressed: () async {
                    final nav = Navigator.of(dialogCtx);
                    final val = s['value'] as String;

                    try {
                      // Attempt to set driver status using the helper which will
                      // try drivers then staff as fallback.
                      await _setDriverStatus(val);
                      if (!mounted) return;
                      await _logActivity('Changed status to $val');
                    } catch (e) {
                      if (!mounted) return;
                      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Failed to change status: $e')));
                      // do not update state or pop if we failed
                      return;
                    }

                    if (!mounted) return;
                    nav.pop();
                    setState(() => staff['status'] = val);
                  },
                  child: Text(s['label'] as String),
                ))
            .toList(),
      ),
    );
  }
}
