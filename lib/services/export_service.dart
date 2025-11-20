import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';

class ExportService {
  static final ExportService _instance = ExportService._internal();

  factory ExportService() {
    return _instance;
  }

  ExportService._internal();

  final _firestore = FirebaseFirestore.instance;

  /// Format timestamp to string
  String _formatTimestamp(dynamic timestamp, String format) {
    try {
      if (timestamp is Timestamp) {
        return DateFormat(format).format(timestamp.toDate());
      }
      return '';
    } catch (e) {
      return '';
    }
  }

  /// Export orders to CSV format
  Future<String> exportOrdersToCSV({
    DateTime? startDate,
    DateTime? endDate,
  }) async {
    try {
      Query query = _firestore.collection('orders');

      if (startDate != null && endDate != null) {
        query = query
            .where('createdAt', isGreaterThanOrEqualTo: startDate)
            .where('createdAt', isLessThanOrEqualTo: endDate);
      }

      final snapshot = await query.get();
      final orders = snapshot.docs;

      if (orders.isEmpty) {
        return 'Order ID,Customer ID,Product Type,Quantity,Total Amount,Status,Created Date,Delivery Date\n';
      }

      StringBuffer csv = StringBuffer();
      csv.writeln('Order ID,Customer ID,Product Type,Quantity,Total Amount,Status,Created Date,Delivery Date');

      for (var order in orders) {
        final data = order.data() as Map<String, dynamic>;
        final orderId = order.id;
        final customerId = data['customerId'] ?? '';
        final productType = data['productType'] ?? '';
        final quantity = data['quantity'] ?? 0;
        final totalAmount = data['totalAmount'] ?? 0.0;
        final status = data['status'] ?? 'pending';
        final createdAt = _formatTimestamp(data['createdAt'], 'yyyy-MM-dd HH:mm');
        final deliveryDate = _formatTimestamp(data['deliveryDate'], 'yyyy-MM-dd');

        csv.writeln('$orderId,$customerId,$productType,$quantity,$totalAmount,"$status",$createdAt,$deliveryDate');
      }

      return csv.toString();
    } catch (e) {
      print('Error exporting orders to CSV: $e');
      return '';
    }
  }

  /// Export deliveries to CSV format
  Future<String> exportDeliveriesToCSV({
    DateTime? startDate,
    DateTime? endDate,
  }) async {
    try {
      Query query = _firestore.collection('deliveries');

      if (startDate != null && endDate != null) {
        query = query
            .where('createdAt', isGreaterThanOrEqualTo: startDate)
            .where('createdAt', isLessThanOrEqualTo: endDate);
      }

      final snapshot = await query.get();
      final deliveries = snapshot.docs;

      if (deliveries.isEmpty) {
        return 'Delivery ID,Order ID,Driver ID,Status,Created Date,Delivered Date,Delivery Time (hours)\n';
      }

      StringBuffer csv = StringBuffer();
      csv.writeln('Delivery ID,Order ID,Driver ID,Status,Created Date,Delivered Date,Delivery Time (hours)');

      for (var delivery in deliveries) {
        final data = delivery.data() as Map<String, dynamic>;
        final deliveryId = delivery.id;
        final orderId = data['orderId'] ?? '';
        final driverId = data['driverId'] ?? '';
        final status = data['status'] ?? 'pending';
        final createdAt = _formatTimestamp(data['createdAt'], 'yyyy-MM-dd HH:mm');
        final deliveredDate = _formatTimestamp(data['deliveredAt'], 'yyyy-MM-dd HH:mm');

        // Calculate delivery time
        String deliveryTime = '';
        if (data['createdAt'] != null && data['deliveredAt'] != null) {
          try {
            final created = (data['createdAt'] as Timestamp).toDate();
            final delivered = (data['deliveredAt'] as Timestamp).toDate();
            final duration = delivered.difference(created);
            deliveryTime = (duration.inMinutes / 60).toStringAsFixed(2);
          } catch (e) {
            deliveryTime = '';
          }
        }

        csv.writeln('$deliveryId,$orderId,$driverId,"$status",$createdAt,$deliveredDate,$deliveryTime');
      }

      return csv.toString();
    } catch (e) {
      print('Error exporting deliveries to CSV: $e');
      return '';
    }
  }

  /// Export staff performance to CSV
  Future<String> exportStaffPerformanceToCSV({
    DateTime? startDate,
    DateTime? endDate,
  }) async {
    try {
      final snapshot = await _firestore.collection('staff').get();
      final staffMembers = snapshot.docs;

      if (staffMembers.isEmpty) {
        return 'Staff ID,Name,Role,Total Deliveries,Completed Deliveries,Completion Rate (%),Avg Delivery Time (hours)\n';
      }

      StringBuffer csv = StringBuffer();
      csv.writeln('Staff ID,Name,Role,Total Deliveries,Completed Deliveries,Completion Rate (%),Avg Delivery Time (hours)');

      for (var staff in staffMembers) {
        final data = staff.data();
        final staffId = staff.id;
        final name = data['fullName'] ?? 'Unknown';
        final role = data['role'] ?? '';

        // Get delivery stats for this staff member
        Query deliveryQuery = _firestore
            .collection('deliveries')
            .where('driverId', isEqualTo: staffId);

        if (startDate != null && endDate != null) {
          deliveryQuery = deliveryQuery
              .where('createdAt', isGreaterThanOrEqualTo: startDate)
              .where('createdAt', isLessThanOrEqualTo: endDate);
        }

        final deliverySnapshot = await deliveryQuery.get();
        final deliveries = deliverySnapshot.docs;

        int totalDeliveries = deliveries.length;
        int completedDeliveries = 0;
        double totalDeliveryTime = 0;

        for (var delivery in deliveries) {
          final deliveryData = delivery.data() as Map<String, dynamic>;
          if (deliveryData['status'] == 'completed') {
            completedDeliveries++;
          }

          if (deliveryData['createdAt'] != null && deliveryData['deliveredAt'] != null) {
            try {
              final created = (deliveryData['createdAt'] as Timestamp).toDate();
              final delivered = (deliveryData['deliveredAt'] as Timestamp).toDate();
              final duration = delivered.difference(created);
              totalDeliveryTime += duration.inMinutes / 60;
            } catch (e) {
              // ignore
            }
          }
        }

        final completionRate = totalDeliveries > 0 ? (completedDeliveries / totalDeliveries) * 100 : 0;
        final avgDeliveryTime = totalDeliveries > 0 ? totalDeliveryTime / totalDeliveries : 0;

        csv.writeln('$staffId,"$name","$role",$totalDeliveries,$completedDeliveries,${completionRate.toStringAsFixed(2)},${avgDeliveryTime.toStringAsFixed(2)}');
      }

      return csv.toString();
    } catch (e) {
      print('Error exporting staff performance to CSV: $e');
      return '';
    }
  }

  /// Export customers to CSV
  Future<String> exportCustomersToCSV() async {
    try {
      final snapshot = await _firestore.collection('customers').get();
      final customers = snapshot.docs;

      if (customers.isEmpty) {
        return 'Customer ID,Name,Email,Contact,Address,Total Orders,Total Spent\n';
      }

      StringBuffer csv = StringBuffer();
      csv.writeln('Customer ID,Name,Email,Contact,Address,Total Orders,Total Spent');

      for (var customer in customers) {
        final data = customer.data();
        final customerId = customer.id;
        final name = data['fullName'] ?? 'Unknown';
        final email = data['email'] ?? '';
        final contact = data['contactNumber'] ?? '';
        final address = data['address'] ?? '';

        // Get order stats for this customer
        final orderSnapshot = await _firestore
            .collection('orders')
            .where('customerId', isEqualTo: customerId)
            .get();

        int totalOrders = orderSnapshot.docs.length;
        double totalSpent = 0;

        for (var order in orderSnapshot.docs) {
          final orderData = order.data();
          totalSpent += (orderData['totalAmount'] ?? 0.0) as double;
        }

        csv.writeln('$customerId,"$name","$email","$contact","$address",$totalOrders,${totalSpent.toStringAsFixed(2)}');
      }

      return csv.toString();
    } catch (e) {
      print('Error exporting customers to CSV: $e');
      return '';
    }
  }

  /// Export all reports summary to CSV
  Future<String> exportReportsSummaryToCSV({
    DateTime? startDate,
    DateTime? endDate,
  }) async {
    try {
      StringBuffer csv = StringBuffer();

      // Summary section
      csv.writeln('=== MTA WATER DELIVERY REPORTS SUMMARY ===');
      csv.writeln('Generated Date,${_formatTimestamp(DateTime.now(), 'yyyy-MM-dd HH:mm')}');
      if (startDate != null && endDate != null) {
        final start = _formatTimestamp(startDate, 'yyyy-MM-dd');
        final end = _formatTimestamp(endDate, 'yyyy-MM-dd');
        csv.writeln('Report Period,"$start to $end"');
      }
      csv.writeln('');

      // Orders summary
      csv.writeln('=== ORDERS SUMMARY ===');
      Query orderQuery = _firestore.collection('orders');
      if (startDate != null && endDate != null) {
        orderQuery = orderQuery
            .where('createdAt', isGreaterThanOrEqualTo: startDate)
            .where('createdAt', isLessThanOrEqualTo: endDate);
      }
      final orderSnapshot = await orderQuery.get();
      int totalOrders = orderSnapshot.docs.length;
      int completedOrders = 0;
      int pendingOrders = 0;
      double totalRevenue = 0;

      for (var order in orderSnapshot.docs) {
        final data = order.data() as Map<String, dynamic>?;
        if (data?['status'] == 'completed') {
          completedOrders++;
        } else if (data?['status'] == 'pending') {
          pendingOrders++;
        }
        totalRevenue += (data?['totalAmount'] ?? 0.0) as double;
      }

      csv.writeln('Total Orders,$totalOrders');
      csv.writeln('Completed Orders,$completedOrders');
      csv.writeln('Pending Orders,$pendingOrders');
      csv.writeln('Total Revenue,₱${totalRevenue.toStringAsFixed(2)}');
      csv.writeln('Average Order Value,₱${(totalOrders > 0 ? totalRevenue / totalOrders : 0).toStringAsFixed(2)}');
      csv.writeln('');

      // Deliveries summary
      csv.writeln('=== DELIVERIES SUMMARY ===');
      Query deliveryQuery = _firestore.collection('deliveries');
      if (startDate != null && endDate != null) {
        deliveryQuery = deliveryQuery
            .where('createdAt', isGreaterThanOrEqualTo: startDate)
            .where('createdAt', isLessThanOrEqualTo: endDate);
      }
      final deliverySnapshot = await deliveryQuery.get();
      int totalDeliveries = deliverySnapshot.docs.length;
      int completedDeliveries = 0;
      int inProgressDeliveries = 0;

      for (var delivery in deliverySnapshot.docs) {
        final data = delivery.data() as Map<String, dynamic>?;
        if (data?['status'] == 'completed') {
          completedDeliveries++;
        } else if (data?['status'] == 'in_progress') {
          inProgressDeliveries++;
        }
      }

      csv.writeln('Total Deliveries,$totalDeliveries');
      csv.writeln('Completed Deliveries,$completedDeliveries');
      csv.writeln('In Progress Deliveries,$inProgressDeliveries');
      csv.writeln('Delivery Success Rate,${(totalDeliveries > 0 ? (completedDeliveries / totalDeliveries) * 100 : 0).toStringAsFixed(2)}%');
      csv.writeln('');

      return csv.toString();
    } catch (e) {
      print('Error exporting reports summary to CSV: $e');
      return '';
    }
  }

  /// Save export to file (returns filename)
  String generateFilename(String reportType) {
    final timestamp = DateFormat('yyyyMMdd_HHmmss').format(DateTime.now());
    return '${reportType}_export_$timestamp.csv';
  }
}
