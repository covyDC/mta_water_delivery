import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:mta_water_delivery/models/order.dart' as model;

class FirestoreService {
  static final FirebaseFirestore _db = FirebaseFirestore.instance;

  static Future<DocumentReference> createOrder(model.Order order) async {
    return await _db.collection('orders').add(order.toMap());
  }

  /// Create an order directly from a map. This is used for multi-item orders
  /// (when a customer checks out multiple cart items) and preserves the
  /// 'items' array and other order-level metadata.
  static Future<DocumentReference> createOrderFromMap(Map<String, dynamic> orderData) async {
    final data = Map<String, dynamic>.from(orderData);
    data['timestamp'] = FieldValue.serverTimestamp();
    return await _db.collection('orders').add(data);
  }

  static Stream<QuerySnapshot> streamPendingOrders() {
    return _db.collection('orders').where('status', isEqualTo: 'pending').orderBy('timestamp', descending: false).snapshots();
  }

  /// Staff confirms an order: atomically check inventory, decrement, create a delivery and update order.
  /// Returns true if confirmation succeeded; throws an error when inventory is insufficient or transaction fails.
  /// confirmOrder: staff member confirms the pending order. Optionally a
  /// driver id may be provided to assign the created delivery documents to
  /// a particular driver. When provided, order.assignedTo will be set to the
  /// driver's id and order.assignedBy will store the staff who performed the
  /// confirmation.
  static Future<bool> confirmOrder({required String orderId, required Map<String, dynamic> orderData, required String staffId, String? assignedDriverId, String? assignedDriverName}) async {
    final staffRef = _db.collection('staff').doc(staffId);
    final orderRef = _db.collection('orders').doc(orderId);

    final result = await _db.runTransaction<bool>((txn) async {
      final staffSnap = await txn.get(staffRef);
      if (!staffSnap.exists) {
        throw Exception('Staff record not found');
      }

      final staffData = staffSnap.data() ?? {};
      final inventory = (staffData['inventory'] is Map) ? Map<String, dynamic>.from(staffData['inventory']) : <String, dynamic>{};

      // Determine whether this order contains multiple items (cart) or a single product
      final bool hasItems = orderData['items'] is List && (orderData['items'] as List).isNotEmpty;

      // Build required quantities per SKU so we can validate and decrement atomically
      final Map<String, int> requiredPerSku = {};

          final assignTo = assignedDriverId ?? staffId;
          final assignedBy = staffId;
          final assignedName = assignedDriverName;

          if (hasItems) {
        final items = List<Map<String, dynamic>>.from(orderData['items']);
        for (final it in items) {
          final ptype = it['productType'] ?? it['product_type'] ?? 'gallon';
          final qty = (it['quantity'] is int) ? it['quantity'] as int : int.tryParse('${it['quantity']}') ?? 0;

          String skuKey = 'full';
          if (ptype == 'gallon') {
            final refillOpt = (it['options'] is Map) ? (it['options']['refill'] ?? it['refill']) : it['refill'];
            final refillStr = refillOpt?.toString().toLowerCase();
            if (refillStr == 'with_container' || refillStr == 'withcontainer' || refillStr == 'new_container') {
              skuKey = 'gallon_with_container';
            } else if (refillStr == 'refill_only' || refillStr == 'refill') {
              skuKey = 'gallon_refill';
            } else {
              skuKey = 'full';
            }
          } else if (ptype == 'bottled') {
            final size = (it['options'] is Map) ? (it['options']['size'] ?? it['size']) : (it['size'] ?? '500ml');
            skuKey = (size ?? '500ml').toString().replaceAll('.', '_');
          }

          requiredPerSku[skuKey] = (requiredPerSku[skuKey] ?? 0) + qty;
        }

        // Validate that we have enough inventory for every SKU required
        for (final entry in requiredPerSku.entries) {
          final k = entry.key;
          final need = entry.value;
          int avail = 0;
          if (inventory.containsKey(k) && inventory[k] is int) {
            avail = inventory[k] as int;
          } else if (k != 'full' && inventory.containsKey('full') && inventory['full'] is int) {
            // fall back to full if SKU not present
            avail = inventory['full'] as int;
          } else {
            avail = 0;
          }
          if (avail < need) {
            throw Exception('Insufficient inventory: have $avail ($k), need $need');
          }
        }
      } else {
        final productType = orderData['product_type'] ?? orderData['productType'] ?? 'gallon';
        final quantity = (orderData['quantity'] is int) ? orderData['quantity'] : int.tryParse('${orderData['quantity']}') ?? 0;

        String skuKey = 'full';
        if (productType == 'gallon') {
          final refillOpt = (orderData['options'] is Map) ? (orderData['options']['refill'] ?? orderData['refill']) : orderData['refill'];
          final refillStr = refillOpt?.toString().toLowerCase();
          if (refillStr == 'with_container' || refillStr == 'withcontainer' || refillStr == 'new_container') {
            skuKey = 'gallon_with_container';
          } else if (refillStr == 'refill_only' || refillStr == 'refill') {
            skuKey = 'gallon_refill';
          } else {
            skuKey = 'full';
          }
        } else if (productType == 'bottled') {
          final size = (orderData['options'] is Map) ? (orderData['options']['size'] ?? orderData['size']) : (orderData['size'] ?? '500ml');
          skuKey = (size ?? '500ml').toString().replaceAll('.', '_');
        }

        requiredPerSku[skuKey] = (requiredPerSku[skuKey] ?? 0) + quantity as int;
      }

      // Try resolving a canonical customer record (if available) so we can
      // prefer a full customer name over an email when copying data into
      // delivery documents. We read it once inside the transaction so that
      // deliveries created in this run will consistently contain the
      // customer's full name when the customers collection has that data.
      Map<String, dynamic>? customerRecord;
      final customerId = orderData['customer_id'] ?? orderData['customerId'];
      if (customerId != null) {
        try {
          final csRef = _db.collection('customers').doc(customerId.toString());
          final csSnap = await txn.get(csRef);
            if (csSnap.exists) {
              final raw = csSnap.data();
              if (raw is Map<String, dynamic>) customerRecord = Map<String, dynamic>.from(raw);
            }
        } catch (_) {}
      }

      // Helper to determine the best customer name to copy into deliveries.
        String resolvedCustomerName(Map<String, dynamic> od) {
        var name = (od['customer_name'] ?? od['customerName'] ?? '').toString().trim();
        // Avoid treating an email address as a name — prefer customer's record
        // fullName/name when available.
          bool looksLikeEmail(String s) => s.contains('@') && s.contains('.');
        if ((name.isEmpty || looksLikeEmail(name)) && customerRecord != null) {
            final cand = customerRecord['fullName'] ?? customerRecord['name'];
            if (cand != null) name = cand.toString().trim();
        }
        return name;
      }

      // Create delivery documents for each item when this is a multi-item order,
      // otherwise create a single delivery for the single-product order.
      final List<String> createdDeliveryIds = [];

      if (hasItems) {
        final items = List<Map<String, dynamic>>.from(orderData['items']);
        for (final it in items) {
          final ptype = it['productType'] ?? it['product_type'] ?? 'gallon';
          final qty = (it['quantity'] is int) ? it['quantity'] as int : int.tryParse('${it['quantity']}') ?? 0;
          final opts = (it['options'] is Map) ? Map<String, dynamic>.from(it['options']) : <String, dynamic>{};

          final docRef = _db.collection('deliveries').doc();
            txn.set(docRef, {
            'order_id': orderId,
            'customer_id': orderData['customer_id'],
            // Ensure we try to store the resolved full customer name, not an
            // email that might have been saved in the order's customer_name
            // field.
              'customer_name': resolvedCustomerName(orderData),
            'address': orderData['address'] ?? '',
            'phone': orderData['phone'] ?? '',
            // copy order-level metadata so drivers can view it from deliveries
            if (orderData['paymentType'] != null) 'paymentType': orderData['paymentType'],
            if (orderData['payment_type'] != null) 'paymentType': orderData['payment_type'],
            if (orderData['totalAmount'] != null) 'totalAmount': orderData['totalAmount'],
            if (orderData['total_amount'] != null) 'totalAmount': orderData['total_amount'],
            if (orderData['email'] != null) 'customer_email': orderData['email'],
            if (orderData['customer_email'] != null) 'customer_email': orderData['customer_email'],
            if (orderData['notes'] != null) 'notes': orderData['notes'],
            // store quantity in a neutral field 'quantity' and keep 'gallons' for backward compatibility
            'quantity': qty,
            'gallons': ptype == 'gallon' ? qty : null,
            'product_type': ptype,
            'options': opts,
            'assignedTo': assignTo,
            // keep compatibility with security rules that reference 'driver_id'
            'driver_id': assignTo,
            if (assignedName != null) 'assignedToName': assignedName,
            'assignedBy': assignedBy,
            'status': 'assigned',
            'scheduledAt': FieldValue.serverTimestamp(),
            'timestamp': FieldValue.serverTimestamp(),
          });

          createdDeliveryIds.add(docRef.id);
        }

        // Update order to assigned and attach delivery ids. We store both
        // assignedTo (driver) and assignedBy (staff who confirmed) so the
        // assignment is auditable.
        final orderUpdate = {'status': 'assigned', 'assignedTo': assignTo, 'driver_id': assignTo, 'assignedBy': assignedBy, 'delivery_ids': createdDeliveryIds};
        if (assignedName != null) orderUpdate['assignedToName'] = assignedName;
        txn.update(orderRef, orderUpdate);

        // Decrement inventory per requiredPerSku
        for (final entry in requiredPerSku.entries) {
          final keyToUse = entry.key.replaceAll('.', '_');
          final deduct = entry.value;
          if (deduct > 0) txn.update(staffRef, {'inventory.$keyToUse': FieldValue.increment(-deduct)});
        }
      } else {
        // single item order: build single delivery and decrement SKU
        final productType = orderData['product_type'] ?? orderData['productType'] ?? 'gallon';
        final quantity = (orderData['quantity'] is int) ? orderData['quantity'] : int.tryParse('${orderData['quantity']}') ?? 0;
        final opts = (orderData['options'] is Map) ? Map<String, dynamic>.from(orderData['options']) : <String, dynamic>{};

        final deliveryRef = _db.collection('deliveries').doc();
        txn.set(deliveryRef, {
          'order_id': orderId,
          'customer_id': orderData['customer_id'],
          'customer_name': resolvedCustomerName(orderData),
          'address': orderData['address'] ?? '',
          'phone': orderData['phone'] ?? '',
          if (orderData['paymentType'] != null) 'paymentType': orderData['paymentType'],
          if (orderData['payment_type'] != null) 'paymentType': orderData['payment_type'],
          if (orderData['totalAmount'] != null) 'totalAmount': orderData['totalAmount'],
          if (orderData['total_amount'] != null) 'totalAmount': orderData['total_amount'],
          if (orderData['email'] != null) 'customer_email': orderData['email'],
          if (orderData['customer_email'] != null) 'customer_email': orderData['customer_email'],
          if (orderData['notes'] != null) 'notes': orderData['notes'],
          'quantity': quantity,
          'gallons': productType == 'gallon' ? quantity : null,
          'product_type': productType,
          'options': opts,
          'assignedTo': assignTo,
          'driver_id': assignTo,
          if (assignedName != null) 'assignedToName': assignedName,
          'assignedBy': assignedBy,
          'status': 'assigned',
          'scheduledAt': FieldValue.serverTimestamp(),
          'timestamp': FieldValue.serverTimestamp(),
        });

        final singleOrderUpdate = {'status': 'assigned', 'assignedTo': assignTo, 'assignedBy': assignedBy, 'delivery_id': deliveryRef.id};
        if (assignedName != null) singleOrderUpdate['assignedToName'] = assignedName;
        txn.update(orderRef, singleOrderUpdate);

        // decrement inventory per sku in requiredPerSku (single entry expected)
        for (final entry in requiredPerSku.entries) {
          final keyToUse = entry.key.replaceAll('.', '_');
          final deduct = entry.value;
          if (deduct > 0) txn.update(staffRef, {'inventory.$keyToUse': FieldValue.increment(-deduct)});
        }
      }

      return true;
    });
    // No assignment notification: drivers will rely on Firestore (deliveries/orders)
    // to pick up assignments from their Assigned tab (Auth + Firestore only).

    return result;
  }

  /// Send a notification record to Firestore. Either [toStaffId] or
  /// [toDriverId] (or both) may be provided. We write both 'createdAt' and
  /// 'timestamp' server timestamps and set both 'body' and 'message' to be
  /// tolerant of consumers that use different field names.
  static Future<void> sendNotification({String? toStaffId, String? toDriverId, required String title, required String body, String type = 'info'}) async {
    final payload = <String, dynamic>{
      if (toStaffId != null) 'toStaffId': toStaffId,
      if (toDriverId != null) 'driverId': toDriverId,
      'title': title,
      'body': body,
      'message': body,
      'type': type,
      'createdAt': FieldValue.serverTimestamp(),
      'timestamp': FieldValue.serverTimestamp(),
    };

    await _db.collection('notifications').add(payload);
  }
  

  
}
