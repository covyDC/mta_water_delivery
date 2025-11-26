import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:mta_water_delivery/config/product_prices.dart';

class ReportsService {
  static final ReportsService _instance = ReportsService._internal();

  factory ReportsService() {
    return _instance;
  }

  ReportsService._internal();

  final _firestore = FirebaseFirestore.instance;

  /// Get orders statistics
  Future<Map<String, dynamic>> getOrdersStats({DateTime? startDate, DateTime? endDate}) async {
    try {
      Query query = _firestore.collection('orders');

      if (startDate != null) {
        query = query.where('timestamp', isGreaterThanOrEqualTo: startDate);
      }
      if (endDate != null) {
        query = query.where('timestamp', isLessThanOrEqualTo: endDate);
      }

      final allOrders = await query.get();
      final docs = allOrders.docs;

      int totalOrders = docs.length;
      int completedOrders = docs.where((d) => d['status'] == 'completed').length;
      int pendingOrders = docs.where((d) => d['status'] == 'pending').length;
      int cancelledOrders = docs.where((d) => d['status'] == 'cancelled').length;

      double totalRevenue = 0;
      for (var doc in docs) {
        final quantity = doc['quantity'] as int? ?? 0;
        final productType = doc['productType'] as String? ?? 'gallon';
        final options = (doc['options'] is Map) ? Map<String, dynamic>.from(doc['options']) : <String, dynamic>{};
        final price = doc['price'] as double? ?? ProductPrices.getPrice(productType, options);
        totalRevenue += (quantity * price).toDouble();
      }

      final avgOrderValue = totalOrders > 0 ? totalRevenue / totalOrders : 0.0;

      return {
        'totalOrders': totalOrders,
        'completedOrders': completedOrders,
        'pendingOrders': pendingOrders,
        'cancelledOrders': cancelledOrders,
        'totalRevenue': totalRevenue,
        'avgOrderValue': avgOrderValue,
        'completionRate': totalOrders > 0 ? (completedOrders / totalOrders * 100).toStringAsFixed(1) : '0.0',
      };
    } catch (e) {
      print('Error fetching orders stats: $e');
      return {};
    }
  }

  /// Get deliveries statistics
  Future<Map<String, dynamic>> getDeliveriesStats({DateTime? startDate, DateTime? endDate}) async {
    try {
      Query query = _firestore.collection('deliveries');

      if (startDate != null) {
        query = query.where('timestamp', isGreaterThanOrEqualTo: startDate);
      }
      if (endDate != null) {
        query = query.where('timestamp', isLessThanOrEqualTo: endDate);
      }

      final allDeliveries = await query.get();
      final docs = allDeliveries.docs;

      int totalDeliveries = docs.length;
      int completedDeliveries = docs.where((d) => d['status'] == 'delivered').length;
      int inProgressDeliveries = docs.where((d) => d['status'] == 'in_progress').length;
      int failedDeliveries = docs.where((d) => d['status'] == 'failed').length;

      // Calculate average delivery time
      double totalDeliveryTime = 0;
      int completedCount = 0;
      for (var doc in docs) {
        if (doc['status'] == 'delivered' && doc['deliveredAt'] != null && doc['createdAt'] != null) {
          final createdAt = (doc['createdAt'] as Timestamp).toDate();
          final deliveredAt = (doc['deliveredAt'] as Timestamp).toDate();
          totalDeliveryTime += deliveredAt.difference(createdAt).inHours.toDouble();
          completedCount++;
        }
      }
      final avgDeliveryTime = completedCount > 0 ? totalDeliveryTime / completedCount : 0.0;

      return {
        'totalDeliveries': totalDeliveries,
        'completedDeliveries': completedDeliveries,
        'inProgressDeliveries': inProgressDeliveries,
        'failedDeliveries': failedDeliveries,
        'avgDeliveryTime': avgDeliveryTime.toStringAsFixed(1),
        'deliveryRate': totalDeliveries > 0 ? (completedDeliveries / totalDeliveries * 100).toStringAsFixed(1) : '0.0',
      };
    } catch (e) {
      print('Error fetching deliveries stats: $e');
      return {};
    }
  }

  /// Get staff/driver performance
  Future<List<Map<String, dynamic>>> getStaffPerformance() async {
    try {
      final staffDocs = await _firestore.collection('staff').get();
      final List<Map<String, dynamic>> performance = [];

      for (var staffDoc in staffDocs.docs) {
        final staffId = staffDoc.id;
        final staffData = staffDoc.data();

        // Count deliveries assigned to this driver
        final deliveriesSnapshot = await _firestore
            .collection('deliveries')
            .where('driver_id', isEqualTo: staffId)
            .get();

        final totalDeliveries = deliveriesSnapshot.docs.length;
        final completedDeliveries = deliveriesSnapshot.docs.where((d) => d['status'] == 'delivered').length;

        performance.add({
          'name': staffData['name'] ?? 'Unknown',
          'role': staffData['role'] ?? 'Unknown',
          'totalDeliveries': totalDeliveries,
          'completedDeliveries': completedDeliveries,
          'completionRate': totalDeliveries > 0 ? (completedDeliveries / totalDeliveries * 100).toStringAsFixed(1) : '0.0',
        });
      }

      return performance;
    } catch (e) {
      print('Error fetching staff performance: $e');
      return [];
    }
  }

  /// Get top customers by orders
  Future<List<Map<String, dynamic>>> getTopCustomers({int limit = 10}) async {
    try {
      final ordersSnapshot = await _firestore.collection('orders').get();
      final Map<String, int> customerOrders = {};
      final Map<String, double> customerRevenue = {};

      for (var order in ordersSnapshot.docs) {
        final customerId = order['customer_id'] as String?;
        if (customerId != null) {
          customerOrders[customerId] = (customerOrders[customerId] ?? 0) + 1;
          final productType = order['productType'] as String? ?? 'gallon';
          final options = (order['options'] is Map) ? Map<String, dynamic>.from(order['options']) : <String, dynamic>{};
          final price = order['price'] as double? ?? ProductPrices.getPrice(productType, options);
          final quantity = order['quantity'] as int? ?? 1;
          customerRevenue[customerId] = (customerRevenue[customerId] ?? 0) + (quantity * price);
        }
      }

      // Get customer details and create list
      final List<Map<String, dynamic>> topCustomers = [];
      for (var entry in customerOrders.entries) {
        final customerDoc = await _firestore.collection('customers').doc(entry.key).get();
        if (customerDoc.exists) {
          final data = customerDoc.data() as Map<String, dynamic>;
          topCustomers.add({
            'name': data['fullName'] ?? 'Unknown',
            'orders': entry.value,
            'revenue': customerRevenue[entry.key] ?? 0.0,
          });
        }
      }

      topCustomers.sort((a, b) => (b['revenue'] as num).compareTo(a['revenue'] as num));
      return topCustomers.take(limit).toList();
    } catch (e) {
      print('Error fetching top customers: $e');
      return [];
    }
  }

  /// Get daily/weekly/monthly stats
  Future<Map<String, int>> getOrdersTimeSeriesStats(String period) async {
    try {
      final allOrders = await _firestore.collection('orders').get();
      final Map<String, int> stats = {};

      for (var order in allOrders.docs) {
        final timestamp = order['timestamp'] as Timestamp? ?? Timestamp.now();
        final date = timestamp.toDate();
        String key;

        if (period == 'daily') {
          key = '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
        } else if (period == 'weekly') {
          final weekNumber = (date.day / 7).ceil();
          key = '${date.year}-W$weekNumber';
        } else {
          // monthly
          key = '${date.year}-${date.month.toString().padLeft(2, '0')}';
        }

        stats[key] = (stats[key] ?? 0) + 1;
      }

      return stats;
    } catch (e) {
      print('Error fetching time series stats: $e');
      return {};
    }
  }
}
