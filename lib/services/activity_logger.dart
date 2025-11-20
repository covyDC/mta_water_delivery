import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class ActivityLogger {
  static final ActivityLogger _instance = ActivityLogger._internal();

  factory ActivityLogger() {
    return _instance;
  }

  ActivityLogger._internal();

  final _firestore = FirebaseFirestore.instance;
  final _auth = FirebaseAuth.instance;

  /// Log a login attempt
  Future<void> logLogin(String email, String role, bool success, String? errorMessage) async {
    try {
      await _firestore.collection('activityLogs').add({
        'type': 'login',
        'email': email,
        'role': role,
        'success': success,
        'errorMessage': errorMessage,
        'timestamp': FieldValue.serverTimestamp(),
        'platform': _getPlatformName(),
        'ipAddress': 'N/A', // In production, capture actual IP
      });
    } catch (e) {
      print('Error logging login attempt: $e');
    }
  }

  /// Log a user registration
  Future<void> logRegistration(String email, String role) async {
    try {
      await _firestore.collection('activityLogs').add({
        'type': 'registration',
        'email': email,
        'role': role,
        'timestamp': FieldValue.serverTimestamp(),
        'platform': _getPlatformName(),
      });
    } catch (e) {
      print('Error logging registration: $e');
    }
  }

  /// Log a user deletion
  Future<void> logUserDeletion(String userId, String role) async {
    try {
      final user = _auth.currentUser;
      await _firestore.collection('activityLogs').add({
        'type': 'user_deletion',
        'deletedUserId': userId,
        'deletedUserRole': role,
        'deletedBy': user?.uid,
        'timestamp': FieldValue.serverTimestamp(),
        'platform': _getPlatformName(),
      });
    } catch (e) {
      print('Error logging user deletion: $e');
    }
  }

  /// Log a role change
  Future<void> logRoleChange(String userId, String oldRole, String newRole) async {
    try {
      final user = _auth.currentUser;
      await _firestore.collection('activityLogs').add({
        'type': 'role_change',
        'userId': userId,
        'oldRole': oldRole,
        'newRole': newRole,
        'changedBy': user?.uid,
        'timestamp': FieldValue.serverTimestamp(),
        'platform': _getPlatformName(),
      });
    } catch (e) {
      print('Error logging role change: $e');
    }
  }

  /// Log a profile update
  Future<void> logProfileUpdate(String userId, String role, Map<String, dynamic> changes) async {
    try {
      await _firestore.collection('activityLogs').add({
        'type': 'profile_update',
        'userId': userId,
        'role': role,
        'changes': changes,
        'timestamp': FieldValue.serverTimestamp(),
        'platform': _getPlatformName(),
      });
    } catch (e) {
      print('Error logging profile update: $e');
    }
  }

  /// Log an order placement
  Future<void> logOrderPlacement(String customerId, String orderId, Map<String, dynamic> orderData) async {
    try {
      await _firestore.collection('activityLogs').add({
        'type': 'order_placed',
        'customerId': customerId,
        'orderId': orderId,
        'orderDetails': orderData,
        'timestamp': FieldValue.serverTimestamp(),
        'platform': _getPlatformName(),
      });
    } catch (e) {
      print('Error logging order placement: $e');
    }
  }

  /// Log a delivery assignment
  Future<void> logDeliveryAssignment(String deliveryId, String driverId) async {
    try {
      final user = _auth.currentUser;
      await _firestore.collection('activityLogs').add({
        'type': 'delivery_assigned',
        'deliveryId': deliveryId,
        'driverId': driverId,
        'assignedBy': user?.uid,
        'timestamp': FieldValue.serverTimestamp(),
        'platform': _getPlatformName(),
      });
    } catch (e) {
      print('Error logging delivery assignment: $e');
    }
  }

  /// Get activity logs for admin
  Future<List<Map<String, dynamic>>> getActivityLogs({int limit = 50}) async {
    try {
      final snapshot = await _firestore
          .collection('activityLogs')
          .orderBy('timestamp', descending: true)
          .limit(limit)
          .get();
      return snapshot.docs.map((doc) => doc.data()).toList();
    } catch (e) {
      print('Error fetching activity logs: $e');
      return [];
    }
  }

  /// Get activity logs by type
  Future<List<Map<String, dynamic>>> getActivityLogsByType(String type, {int limit = 50}) async {
    try {
      final snapshot = await _firestore
          .collection('activityLogs')
          .where('type', isEqualTo: type)
          .orderBy('timestamp', descending: true)
          .limit(limit)
          .get();
      return snapshot.docs.map((doc) => doc.data()).toList();
    } catch (e) {
      print('Error fetching activity logs by type: $e');
      return [];
    }
  }

  /// Get activity logs by user
  Future<List<Map<String, dynamic>>> getActivityLogsByUser(String userId, {int limit = 50}) async {
    try {
      final snapshot = await _firestore
          .collection('activityLogs')
          .where('userId', isEqualTo: userId)
          .orderBy('timestamp', descending: true)
          .limit(limit)
          .get();
      return snapshot.docs.map((doc) => doc.data()).toList();
    } catch (e) {
      print('Error fetching activity logs by user: $e');
      return [];
    }
  }

  String _getPlatformName() {
    // This would require flutter/foundation.dart kIsWeb constant
    // For now, return a generic platform identifier
    return 'mobile'; // In production, check kIsWeb and return 'web' or 'mobile'
  }
}
