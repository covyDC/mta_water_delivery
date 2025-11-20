import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';

enum UserRole { customer, driver, staff, admin }

enum PlatformType { web, mobile }

class UserAuthService {
  static final UserAuthService _instance = UserAuthService._internal();

  factory UserAuthService() {
    return _instance;
  }

  UserAuthService._internal();

  final _firestore = FirebaseFirestore.instance;
  final _auth = FirebaseAuth.instance;

  /// Detect current platform (web or mobile)
  PlatformType get currentPlatform {
    if (kIsWeb) {
      return PlatformType.web;
    } else {
      return PlatformType.mobile;
    }
  }

  /// Get user role from Firestore
  Future<UserRole?> getUserRole(String uid) async {
    try {
      final doc = await _firestore.collection('users').doc(uid).get();
      final data = doc.data();
      if (data == null) return null;

      final roleString = data['role'] as String?;
      return _stringToRole(roleString);
    } catch (e) {
      print('Error fetching user role: $e');
      return null;
    }
  }

  /// Check if user has access based on role and platform
  Future<bool> canAccessPlatform(String uid, UserRole role) async {
    final platform = currentPlatform;

    switch (role) {
      case UserRole.customer:
        // Customer can access web and mobile
        return true;
      case UserRole.driver:
        // Driver can only access mobile
        return platform == PlatformType.mobile;
      case UserRole.staff:
        // Staff can access web and mobile
        return true;
      case UserRole.admin:
        // Admin can access web and mobile
        return true;
    }
  }

  /// Determine dashboard route based on role
  String getDashboardRoute(UserRole role) {
    switch (role) {
      case UserRole.customer:
        return '/customer-dashboard';
      case UserRole.driver:
        return '/driver-dashboard';
      case UserRole.staff:
        return '/staff-dashboard';
      case UserRole.admin:
        return '/admin-dashboard';
    }
  }

  /// Get dashboard display name
  String getDashboardName(UserRole role) {
    switch (role) {
      case UserRole.customer:
        return 'Customer Dashboard';
      case UserRole.driver:
        return 'Driver Dashboard';
      case UserRole.staff:
        return 'Staff Dashboard';
      case UserRole.admin:
        return 'Admin Dashboard';
    }
  }

  /// Validate user account (check if profile is complete)
  Future<bool> isProfileComplete(String uid) async {
    try {
      final roleDoc = await _firestore.collection('users').doc(uid).get();
      final roleData = roleDoc.data();
      if (roleData == null) return false;

      final role = _stringToRole(roleData['role'] as String?);
      if (role == null) return false;

      // Different roles have different profile requirements
      switch (role) {
        case UserRole.customer:
          final customerDoc = await _firestore.collection('customers').doc(uid).get();
          final customerData = customerDoc.data();
          if (customerData == null) return false;
          return (customerData['fullName'] as String?)?.isNotEmpty == true &&
              (customerData['contactNumber'] as String?)?.isNotEmpty == true &&
              (customerData['address'] as String?)?.isNotEmpty == true;

        case UserRole.driver:
          final driverDoc = await _firestore.collection('drivers').doc(uid).get();
          final driverData = driverDoc.data();
          if (driverData == null) return false;
          return (driverData['fullName'] as String?)?.isNotEmpty == true &&
              (driverData['contactNumber'] as String?)?.isNotEmpty == true &&
              (driverData['vehicleInfo'] as String?)?.isNotEmpty == true;

        case UserRole.staff:
          final staffDoc = await _firestore.collection('staff').doc(uid).get();
          final staffData = staffDoc.data();
          if (staffData == null) return false;
          return (staffData['fullName'] as String?)?.isNotEmpty == true &&
              (staffData['contactNumber'] as String?)?.isNotEmpty == true;

        case UserRole.admin:
          // Admin profile always considered complete if user exists
          return true;
      }
    } catch (e) {
      print('Error checking profile completion: $e');
      return false;
    }
  }

  /// Helper to convert string to UserRole
  UserRole? _stringToRole(String? roleString) {
    switch (roleString?.toLowerCase()) {
      case 'customer':
        return UserRole.customer;
      case 'driver':
        return UserRole.driver;
      case 'staff':
        return UserRole.staff;
      case 'admin':
        return UserRole.admin;
      default:
        return null;
    }
  }

  /// Get current authenticated user
  User? getCurrentUser() {
    return _auth.currentUser;
  }

  /// Sign out
  Future<void> signOut() async {
    await _auth.signOut();
  }
}
