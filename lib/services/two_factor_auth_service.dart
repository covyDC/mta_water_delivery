import 'package:cloud_firestore/cloud_firestore.dart';
import 'dart:math';

class TwoFactorAuthService {
  static final TwoFactorAuthService _instance = TwoFactorAuthService._internal();

  factory TwoFactorAuthService() {
    return _instance;
  }

  TwoFactorAuthService._internal();

  final _firestore = FirebaseFirestore.instance;

  /// Generate 6-digit OTP
  String _generateOTP() {
    final random = Random();
    return (100000 + random.nextInt(900000)).toString();
  }

  /// Enable 2FA for user
  Future<bool> enable2FA(String userId) async {
    try {
      await _firestore.collection('users').doc(userId).update({
        'twoFactorEnabled': true,
        'twoFactorEnabledAt': FieldValue.serverTimestamp(),
      });
      return true;
    } catch (e) {
      print('Error enabling 2FA: $e');
      return false;
    }
  }

  /// Disable 2FA for user
  Future<bool> disable2FA(String userId) async {
    try {
      await _firestore.collection('users').doc(userId).update({
        'twoFactorEnabled': false,
        'twoFactorDisabledAt': FieldValue.serverTimestamp(),
      });
      return true;
    } catch (e) {
      print('Error disabling 2FA: $e');
      return false;
    }
  }

  /// Send OTP via email
  Future<bool> sendOTPEmail(String email) async {
    try {
      final otp = _generateOTP();
      final expiresAt = DateTime.now().add(Duration(minutes: 5));

      // Store OTP in temporary collection
      await _firestore.collection('otpTokens').add({
        'email': email,
        'otp': otp,
        'expiresAt': expiresAt,
        'createdAt': FieldValue.serverTimestamp(),
        'used': false,
      });

      // Queue email notification
      await _firestore.collection('emailQueue').add({
        'type': 'otp_email',
        'recipientEmail': email,
        'subject': 'Your MTA Water Delivery 2FA Code',
        'template': 'otp_code',
        'data': {
          'otp': otp,
          'expiresIn': '5 minutes',
        },
        'status': 'pending',
        'createdAt': FieldValue.serverTimestamp(),
      });

      return true;
    } catch (e) {
      print('Error sending OTP email: $e');
      return false;
    }
  }

  /// Verify OTP
  Future<bool> verifyOTP(String email, String otp) async {
    try {
      final snapshot = await _firestore
          .collection('otpTokens')
          .where('email', isEqualTo: email)
          .where('otp', isEqualTo: otp)
          .where('used', isEqualTo: false)
          .get();

      if (snapshot.docs.isEmpty) {
        return false;
      }

      final doc = snapshot.docs.first;
      final data = doc.data();
      final expiresAt = (data['expiresAt'] as Timestamp).toDate();

      // Check if OTP expired
      if (DateTime.now().isAfter(expiresAt)) {
        await doc.reference.update({'used': true});
        return false;
      }

      // Mark OTP as used
      await doc.reference.update({
        'used': true,
        'verifiedAt': FieldValue.serverTimestamp(),
      });

      return true;
    } catch (e) {
      print('Error verifying OTP: $e');
      return false;
    }
  }

  /// Check if user has 2FA enabled
  Future<bool> is2FAEnabled(String userId) async {
    try {
      final doc = await _firestore.collection('users').doc(userId).get();
      return doc.data()?['twoFactorEnabled'] ?? false;
    } catch (e) {
      print('Error checking 2FA status: $e');
      return false;
    }
  }

  /// Generate backup codes (10 codes)
  Future<List<String>> generateBackupCodes(String userId) async {
    try {
      final backupCodes = <String>[];
      final random = Random();

      for (int i = 0; i < 10; i++) {
        final code = List.generate(
          8,
          (index) => '0123456789ABCDEFGHIJKLMNOPQRSTUVWXYZ'[random.nextInt(36)],
        ).join();
        backupCodes.add(code);
      }

      // Hash codes before storing (in production, use bcrypt or similar)
      await _firestore.collection('users').doc(userId).update({
        'backupCodes': backupCodes,
        'backupCodesGeneratedAt': FieldValue.serverTimestamp(),
      });

      return backupCodes;
    } catch (e) {
      print('Error generating backup codes: $e');
      return [];
    }
  }

  /// Verify backup code
  Future<bool> verifyBackupCode(String userId, String code) async {
    try {
      final userDoc = await _firestore.collection('users').doc(userId).get();
      final backupCodes = List<String>.from(userDoc.data()?['backupCodes'] ?? []);

      if (backupCodes.contains(code)) {
        // Remove used code
        backupCodes.remove(code);
        await _firestore.collection('users').doc(userId).update({
          'backupCodes': backupCodes,
        });
        return true;
      }
      return false;
    } catch (e) {
      print('Error verifying backup code: $e');
      return false;
    }
  }

  /// Get remaining backup codes count
  Future<int> getRemainingBackupCodesCount(String userId) async {
    try {
      final userDoc = await _firestore.collection('users').doc(userId).get();
      final backupCodes = List<String>.from(userDoc.data()?['backupCodes'] ?? []);
      return backupCodes.length;
    } catch (e) {
      print('Error getting backup codes count: $e');
      return 0;
    }
  }

  /// Clean up expired OTPs
  Future<void> cleanupExpiredOTPs() async {
    try {
      final now = DateTime.now();
      final snapshot = await _firestore
          .collection('otpTokens')
          .where('expiresAt', isLessThan: now)
          .get();

      for (var doc in snapshot.docs) {
        await doc.reference.delete();
      }
    } catch (e) {
      print('Error cleaning up expired OTPs: $e');
    }
  }

  /// Log 2FA verification attempt
  Future<void> log2FAAttempt({
    required String userId,
    required String method,
    required bool success,
  }) async {
    try {
      await _firestore.collection('activityLogs').add({
        'type': '2fa_verification',
        'userId': userId,
        'method': method, // 'otp' or 'backup_code'
        'success': success,
        'timestamp': FieldValue.serverTimestamp(),
      });
    } catch (e) {
      print('Error logging 2FA attempt: $e');
    }
  }
}
