import 'package:cloud_firestore/cloud_firestore.dart';

class EmailNotificationService {
  static final EmailNotificationService _instance = EmailNotificationService._internal();

  factory EmailNotificationService() {
    return _instance;
  }

  EmailNotificationService._internal();

  final _firestore = FirebaseFirestore.instance;

  /// Send order confirmation email
  Future<void> sendOrderConfirmationEmail({
    required String customerEmail,
    required String customerName,
    required String orderId,
    required Map<String, dynamic> orderDetails,
  }) async {
    try {
      await _firestore.collection('emailQueue').add({
        'type': 'order_confirmation',
        'recipientEmail': customerEmail,
        'recipientName': customerName,
        'orderId': orderId,
        'orderDetails': orderDetails,
        'status': 'pending',
        'createdAt': FieldValue.serverTimestamp(),
        'template': 'order_confirmation',
      });
    } catch (e) {
      print('Error queueing order confirmation email: $e');
    }
  }

  /// Send delivery status update email
  Future<void> sendDeliveryStatusEmail({
    required String customerEmail,
    required String customerName,
    required String deliveryId,
    required String status,
    required String estimatedTime,
  }) async {
    try {
      await _firestore.collection('emailQueue').add({
        'type': 'delivery_status',
        'recipientEmail': customerEmail,
        'recipientName': customerName,
        'deliveryId': deliveryId,
        'status': status,
        'estimatedTime': estimatedTime,
        'emailStatus': 'pending',
        'createdAt': FieldValue.serverTimestamp(),
        'template': 'delivery_status',
      });
    } catch (e) {
      print('Error queueing delivery status email: $e');
    }
  }

  /// Send delivery completed email
  Future<void> sendDeliveryCompletedEmail({
    required String customerEmail,
    required String customerName,
    required String deliveryId,
    required String address,
  }) async {
    try {
      await _firestore.collection('emailQueue').add({
        'type': 'delivery_completed',
        'recipientEmail': customerEmail,
        'recipientName': customerName,
        'deliveryId': deliveryId,
        'deliveryAddress': address,
        'status': 'pending',
        'createdAt': FieldValue.serverTimestamp(),
        'template': 'delivery_completed',
      });
    } catch (e) {
      print('Error queueing delivery completed email: $e');
    }
  }

  /// Send admin alert email
  Future<void> sendAdminAlertEmail({
    required String adminEmail,
    required String alertType,
    required Map<String, dynamic> alertData,
  }) async {
    try {
      await _firestore.collection('emailQueue').add({
        'type': 'admin_alert',
        'recipientEmail': adminEmail,
        'alertType': alertType,
        'alertData': alertData,
        'status': 'pending',
        'createdAt': FieldValue.serverTimestamp(),
        'template': 'admin_alert',
      });
    } catch (e) {
      print('Error queueing admin alert email: $e');
    }
  }

  /// Send driver assignment notification
  Future<void> sendDriverAssignmentEmail({
    required String driverEmail,
    required String driverName,
    required String deliveryId,
    required String customerAddress,
  }) async {
    try {
      await _firestore.collection('emailQueue').add({
        'type': 'driver_assignment',
        'recipientEmail': driverEmail,
        'recipientName': driverName,
        'deliveryId': deliveryId,
        'customerAddress': customerAddress,
        'status': 'pending',
        'createdAt': FieldValue.serverTimestamp(),
        'template': 'driver_assignment',
      });
    } catch (e) {
      print('Error queueing driver assignment email: $e');
    }
  }

  /// Send weekly staff report email
  Future<void> sendWeeklyReportEmail({
    required String staffEmail,
    required String staffName,
    required Map<String, dynamic> reportData,
  }) async {
    try {
      await _firestore.collection('emailQueue').add({
        'type': 'weekly_report',
        'recipientEmail': staffEmail,
        'recipientName': staffName,
        'reportData': reportData,
        'status': 'pending',
        'createdAt': FieldValue.serverTimestamp(),
        'template': 'weekly_report',
      });
    } catch (e) {
      print('Error queueing weekly report email: $e');
    }
  }

  /// Get email queue status
  Future<Map<String, int>> getEmailQueueStatus() async {
    try {
      final pending = await _firestore.collection('emailQueue').where('status', isEqualTo: 'pending').count().get();
      final sent = await _firestore.collection('emailQueue').where('status', isEqualTo: 'sent').count().get();
      final failed = await _firestore.collection('emailQueue').where('status', isEqualTo: 'failed').count().get();

      return {
        'pending': pending.count ?? 0,
        'sent': sent.count ?? 0,
        'failed': failed.count ?? 0,
      };
    } catch (e) {
      print('Error fetching email queue status: $e');
      return {'pending': 0, 'sent': 0, 'failed': 0};
    }
  }

  /// Retry failed emails
  Future<void> retryFailedEmails() async {
    try {
      final failedEmails = await _firestore
          .collection('emailQueue')
          .where('status', isEqualTo: 'failed')
          .limit(10)
          .get();

      for (var doc in failedEmails.docs) {
        await _firestore.collection('emailQueue').doc(doc.id).update({
          'status': 'pending',
          'retryCount': (doc['retryCount'] ?? 0) + 1,
        });
      }
    } catch (e) {
      print('Error retrying failed emails: $e');
    }
  }
}
