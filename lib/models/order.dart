import 'package:cloud_firestore/cloud_firestore.dart';

class Order {
  final String? id;
  final String customerId;
  final String? customerName;
  final String productType; // e.g. bottled, gallon
  final Map<String, dynamic> options; // variant, containerType, refill, etc
  final int quantity;
  final String? address;
  final String status; // pending, confirmed, assigned, completed
  final Timestamp? timestamp;

  Order({
    this.id,
    required this.customerId,
    this.customerName,
    required this.productType,
    required this.options,
    required this.quantity,
    this.address,
    required this.status,
    this.timestamp,
  });

  Map<String, dynamic> toMap() => {
      'customer_id': customerId,
      if (customerName != null) 'customer_name': customerName,
        'product_type': productType,
        'options': options,
        'quantity': quantity,
        'address': address,
        'status': status,
        'timestamp': FieldValue.serverTimestamp(),
      };

  factory Order.fromDoc(DocumentSnapshot doc) {
    final d = doc.data() as Map<String, dynamic>;
    return Order(
      id: doc.id,
      customerId: d['customer_id'] ?? '',
      customerName: d['customer_name'],
      productType: d['product_type'] ?? 'unknown',
      options: Map<String, dynamic>.from(d['options'] ?? {}),
      quantity: (d['quantity'] is int) ? d['quantity'] : int.tryParse('${d['quantity']}') ?? 0,
      address: d['address'],
      status: d['status'] ?? 'pending',
      timestamp: d['timestamp'] as Timestamp?,
    );
  }
}
