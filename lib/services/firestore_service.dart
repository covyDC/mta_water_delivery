import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:mta_water_delivery/models/order.dart' as model;

class FirestoreService {
  static final FirebaseFirestore _db = FirebaseFirestore.instance;

  static Future<DocumentReference> createOrder(model.Order order) async {
    return await _db.collection('orders').add(order.toMap());
  }

  static Stream<QuerySnapshot> streamPendingOrders() {
    return _db.collection('orders').where('status', isEqualTo: 'pending').orderBy('timestamp', descending: false).snapshots();
  }

  /// Staff confirms an order: atomically check inventory, decrement, create a delivery and update order.
  /// Returns true if confirmation succeeded; throws an error when inventory is insufficient or transaction fails.
  static Future<bool> confirmOrder({required String orderId, required Map<String, dynamic> orderData, required String staffId}) async {
    final staffRef = _db.collection('staff').doc(staffId);
    final orderRef = _db.collection('orders').doc(orderId);

    return await _db.runTransaction<bool>((txn) async {
      final staffSnap = await txn.get(staffRef);
      if (!staffSnap.exists) {
        throw Exception('Staff record not found');
      }

      final staffData = staffSnap.data() ?? {};
      final inventory = (staffData['inventory'] is Map) ? Map<String, dynamic>.from(staffData['inventory']) : <String, dynamic>{};

      final productType = orderData['product_type'] ?? orderData['productType'] ?? 'gallon';
      final quantity = (orderData['quantity'] is int) ? orderData['quantity'] : int.tryParse('${orderData['quantity']}') ?? 0;

      // For gallons, check 'full' inventory
      if (productType == 'gallon') {
        final int available = (inventory['full'] is int) ? inventory['full'] : int.tryParse('${inventory['full'] ?? 0}') ?? 0;
        if (available < quantity) {
          throw Exception('Insufficient inventory: have $available, need $quantity');
        }
      }

      // Create delivery doc
      final deliveryRef = _db.collection('deliveries').doc();
      txn.set(deliveryRef, {
        'order_id': orderId,
        'customer_id': orderData['customer_id'],
        'customer_name': orderData['customer_name'] ?? '',
        'address': orderData['address'] ?? '',
        'phone': orderData['phone'] ?? '',
        'gallons': quantity,
        'product_type': productType,
        'options': orderData['options'] ?? {},
        'assignedTo': staffId,
        'status': 'assigned',
        'scheduledAt': FieldValue.serverTimestamp(),
        'timestamp': FieldValue.serverTimestamp(),
      });

      // Update order
      txn.update(orderRef, {'status': 'assigned', 'assignedTo': staffId, 'delivery_id': deliveryRef.id});

      // Decrement inventory for gallon orders
      if (productType == 'gallon' && quantity > 0) {
        txn.update(staffRef, {
          'inventory.full': FieldValue.increment(-quantity),
        });
      }

      return true;
    });
  }

  static Future<void> sendNotification({required String toStaffId, required String title, required String body}) async {
    await _db.collection('notifications').add({
      'toStaffId': toStaffId,
      'title': title,
      'body': body,
      'createdAt': FieldValue.serverTimestamp(),
    });
  }
}
