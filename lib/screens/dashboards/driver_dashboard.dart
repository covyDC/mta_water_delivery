// driver_dashboard.dart
// Driver Dashboard for delivery personnel
// Features: Assigned deliveries, Completed deliveries, Notifications, Profile

import 'dart:io';
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
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Driver Dashboard (${staff['name'] ?? ''})'),
        actions: [
          IconButton(
            icon: const Icon(Icons.logout),
            onPressed: () => Navigator.pop(context),
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
      ),
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
      stream: _firestore
          .collection('deliveries')
          .where('assignedTo', isEqualTo: staff['id'])
          .where('status', whereIn: ['assigned', 'on_the_way'])
          .orderBy('scheduledAt', descending: false)
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
          return const Center(child: Text('No assigned deliveries.'));
        }

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
                    Text('Status: ${d['status'] ?? 'N/A'}'),
                  ],
                ),
                isThreeLine: true,
                trailing: PopupMenuButton<String>(
                  onSelected: (action) => _handleAssignedAction(action, doc.id, d),
                  itemBuilder: (_) => [
                    const PopupMenuItem(value: 'start', child: Text('Start Delivery')),
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
      case 'start':
        await _firestore.collection('deliveries').doc(id).update({'status': 'on_the_way'});
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

  Future<void> _captureProofPhoto(String id) async {
    try {
      final image = await _picker.pickImage(source: ImageSource.camera);
      if (image == null) return;

      // Upload image to Firebase Storage
      final file = File(image.path);
      final fileName = 'proofs/delivery_${id}_${DateTime.now().millisecondsSinceEpoch}.jpg';
      final ref = FirebaseStorage.instance.ref().child(fileName);
      await ref.putFile(file);
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
      stream: _firestore
          .collection('deliveries')
          .where('assignedTo', isEqualTo: staff['id'])
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
                title: Text(d['customerName'] ?? 'Unknown'),
                subtitle: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Address: ${d['address'] ?? '-'}'),
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
              Text('${details['customerName']}',
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

      final file = File(image.path);
      final ref = FirebaseStorage.instance
          .ref()
          .child('deliveries')
          .child(deliveryId)
          .child('proof_${DateTime.now().millisecondsSinceEpoch}.jpg');

      await ref.putFile(file);
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
}
