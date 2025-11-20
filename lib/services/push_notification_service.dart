import 'package:cloud_firestore/cloud_firestore.dart';

class PushNotificationService {
  static final PushNotificationService _instance = PushNotificationService._internal();

  factory PushNotificationService() {
    return _instance;
  }

  PushNotificationService._internal();

  final _firestore = FirebaseFirestore.instance;

  /// Save FCM token for user
  Future<void> saveFCMToken(String userId, String fcmToken) async {
    try {
      await _firestore.collection('users').doc(userId).update({
        'fcmToken': fcmToken,
        'fcmTokenUpdatedAt': FieldValue.serverTimestamp(),
      });
    } catch (e) {
      print('Error saving FCM token: $e');
    }
  }

  /// Send order placed notification
  Future<void> sendOrderPlacedNotification({
    required String customerId,
    required String orderId,
    required String productType,
  }) async {
    try {
      await _firestore.collection('notifications').add({
        'type': 'order_placed',
        'userId': customerId,
        'orderId': orderId,
        'title': 'Order Placed',
        'body': 'Your order for $productType has been placed successfully',
        'read': false,
        'createdAt': FieldValue.serverTimestamp(),
      });
    } catch (e) {
      print('Error creating order placed notification: $e');
    }
  }

  /// Send delivery assigned notification
  Future<void> sendDeliveryAssignedNotification({
    required String driverId,
    required String deliveryId,
    required String customerName,
  }) async {
    try {
      await _firestore.collection('notifications').add({
        'type': 'delivery_assigned',
        'userId': driverId,
        'deliveryId': deliveryId,
        'title': 'New Delivery',
        'body': 'You have been assigned a delivery for $customerName',
        'read': false,
        'createdAt': FieldValue.serverTimestamp(),
      });
    } catch (e) {
      print('Error creating delivery assigned notification: $e');
    }
  }

  /// Send delivery in progress notification
  Future<void> sendDeliveryInProgressNotification({
    required String customerId,
    required String deliveryId,
  }) async {
    try {
      await _firestore.collection('notifications').add({
        'type': 'delivery_in_progress',
        'userId': customerId,
        'deliveryId': deliveryId,
        'title': 'Your Order is On the Way',
        'body': 'Your delivery is currently in progress and will arrive soon',
        'read': false,
        'createdAt': FieldValue.serverTimestamp(),
      });
    } catch (e) {
      print('Error creating delivery in progress notification: $e');
    }
  }

  /// Send delivery completed notification
  Future<void> sendDeliveryCompletedNotification({
    required String customerId,
    required String deliveryId,
  }) async {
    try {
      await _firestore.collection('notifications').add({
        'type': 'delivery_completed',
        'userId': customerId,
        'deliveryId': deliveryId,
        'title': 'Delivery Complete',
        'body': 'Your delivery has been completed',
        'read': false,
        'createdAt': FieldValue.serverTimestamp(),
      });
    } catch (e) {
      print('Error creating delivery completed notification: $e');
    }
  }

  /// Get notifications for user
  Future<List<Map<String, dynamic>>> getUserNotifications(String userId) async {
    try {
      final snapshot = await _firestore
          .collection('notifications')
          .where('userId', isEqualTo: userId)
          .orderBy('createdAt', descending: true)
          .limit(50)
          .get();
      return snapshot.docs.map((doc) => {'id': doc.id, ...doc.data()}).toList();
    } catch (e) {
      print('Error fetching user notifications: $e');
      return [];
    }
  }

  /// Mark notification as read
  Future<void> markNotificationAsRead(String notificationId) async {
    try {
      await _firestore.collection('notifications').doc(notificationId).update({
        'read': true,
        'readAt': FieldValue.serverTimestamp(),
      });
    } catch (e) {
      print('Error marking notification as read: $e');
    }
  }

  /// Mark all notifications as read for user
  Future<void> markAllNotificationsAsRead(String userId) async {
    try {
      final unreadNotifications = await _firestore
          .collection('notifications')
          .where('userId', isEqualTo: userId)
          .where('read', isEqualTo: false)
          .get();

      for (var doc in unreadNotifications.docs) {
        await _firestore.collection('notifications').doc(doc.id).update({
          'read': true,
          'readAt': FieldValue.serverTimestamp(),
        });
      }
    } catch (e) {
      print('Error marking all notifications as read: $e');
    }
  }

  /// Delete notification
  Future<void> deleteNotification(String notificationId) async {
    try {
      await _firestore.collection('notifications').doc(notificationId).delete();
    } catch (e) {
      print('Error deleting notification: $e');
    }
  }

  /// Get unread notification count
  Future<int> getUnreadNotificationCount(String userId) async {
    try {
      final count = await _firestore
          .collection('notifications')
          .where('userId', isEqualTo: userId)
          .where('read', isEqualTo: false)
          .count()
          .get();
      return count.count ?? 0;
    } catch (e) {
      print('Error fetching unread notification count: $e');
      return 0;
    }
  }

  /// Stream notifications for real-time updates
  Stream<List<Map<String, dynamic>>> streamUserNotifications(String userId) {
    return _firestore
        .collection('notifications')
        .where('userId', isEqualTo: userId)
        .orderBy('createdAt', descending: true)
        .limit(50)
        .snapshots()
        .map((snapshot) => snapshot.docs.map((doc) => {'id': doc.id, ...doc.data()}).toList());
  }
}
