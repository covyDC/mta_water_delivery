# MTA Water Delivery - Complete Feature Implementation Guide

## Overview
This document outlines the three new enhancement features that have been implemented:
1. **Push Notifications** - Real-time notifications for customers, drivers, and staff
2. **Two-Factor Authentication (2FA)** - Enhanced security for admin accounts
3. **Export Functionality** - CSV export reports for admin dashboard

---

## 1. PUSH NOTIFICATIONS

### Service: `PushNotificationService`
Location: `lib/services/push_notification_service.dart`

### Key Features:
- Real-time notification tracking using Firestore
- Support for multiple notification types (orders, deliveries, assignments)
- Mark as read / Mark all as read functionality
- Stream-based notifications for live updates
- Unread count tracking

### Methods:

#### FCM Token Management
```dart
Future<void> saveFCMToken(String userId, String fcmToken)
```
Saves FCM token to user document for push notification delivery.

#### Sending Notifications

```dart
// Order placed notification
Future<void> sendOrderPlacedNotification({
  required String customerId,
  required String orderId,
  required String productType,
})

// Delivery assigned to driver
Future<void> sendDeliveryAssignedNotification({
  required String driverId,
  required String deliveryId,
  required String customerName,
})

// Delivery in progress
Future<void> sendDeliveryInProgressNotification({
  required String customerId,
  required String deliveryId,
})

// Delivery completed
Future<void> sendDeliveryCompletedNotification({
  required String customerId,
  required String deliveryId,
})
```

#### Notification Management

```dart
// Get all notifications for user
Future<List<Map<String, dynamic>>> getUserNotifications(String userId)

// Mark single notification as read
Future<void> markNotificationAsRead(String notificationId)

// Mark all as read
Future<void> markAllNotificationsAsRead(String userId)

// Delete notification
Future<void> deleteNotification(String notificationId)

// Get unread count
Future<int> getUnreadNotificationCount(String userId)

// Stream notifications (live updates)
Stream<List<Map<String, dynamic>>> streamUserNotifications(String userId)
```

### Firestore Schema:
```
notifications/
├── {notificationId}
│   ├── type: string (order_placed, delivery_assigned, delivery_in_progress, delivery_completed)
│   ├── userId: string
│   ├── orderId/deliveryId: string
│   ├── title: string
│   ├── body: string
│   ├── read: boolean
│   ├── readAt: timestamp (optional)
│   └── createdAt: timestamp
```

### UI Widget: `NotificationCenter`
Location: `lib/widgets/notification_center.dart`

**Features:**
- Full notification list with status indicators
- Mark as read / Delete options
- Badge showing unread count
- Bottom sheet modal display
- Automatic icon selection based on notification type

**Usage in Dashboards:**
```dart
// Add to AppBar
AppBar(
  actions: [
    NotificationBadge(userId: currentUserId),
  ],
)

// Or display full center
NotificationCenter()
```

### Implementation Steps:

1. **Initialize FCM Token on Login:**
```dart
// In login.dart after successful authentication
final fcmToken = await FirebaseMessaging.instance.getToken();
if (fcmToken != null) {
  await PushNotificationService().saveFCMToken(userId, fcmToken);
}
```

2. **Send Notification When Order is Created:**
```dart
// In order creation flow
await PushNotificationService().sendOrderPlacedNotification(
  customerId: customerId,
  orderId: orderId,
  productType: productType,
);
```

3. **Send Driver Assignment Notification:**
```dart
// When delivery is assigned to driver
await PushNotificationService().sendDeliveryAssignedNotification(
  driverId: driverId,
  deliveryId: deliveryId,
  customerName: customerName,
);
```

---

## 2. TWO-FACTOR AUTHENTICATION (2FA)

### Service: `TwoFactorAuthService`
Location: `lib/services/two_factor_auth_service.dart`

### Key Features:
- OTP-based 2FA via email
- Backup codes for account recovery
- Automatic OTP expiration (5 minutes)
- Activity logging for failed attempts
- Support for enabling/disabling per user

### Methods:

#### Configuration
```dart
// Enable 2FA for user
Future<bool> enable2FA(String userId)

// Disable 2FA for user
Future<bool> disable2FA(String userId)

// Check if 2FA is enabled
Future<bool> is2FAEnabled(String userId)
```

#### OTP Management
```dart
// Send OTP via email (queued for email service)
Future<bool> sendOTPEmail(String email)

// Verify OTP (must be within 5 minutes)
Future<bool> verifyOTP(String email, String otp)
```

#### Backup Codes
```dart
// Generate 10 backup codes (one-time use)
Future<List<String>> generateBackupCodes(String userId)

// Verify backup code (removes it after use)
Future<bool> verifyBackupCode(String userId, String code)

// Get remaining backup codes count
Future<int> getRemainingBackupCodesCount(String userId)
```

#### Cleanup & Logging
```dart
// Remove expired OTPs (run periodically)
Future<void> cleanupExpiredOTPs()

// Log 2FA attempts for audit trail
Future<void> log2FAAttempt({
  required String userId,
  required String method, // 'otp' or 'backup_code'
  required bool success,
})
```

### Firestore Schema:
```
users/{userId}
├── twoFactorEnabled: boolean
├── twoFactorEnabledAt: timestamp
├── twoFactorDisabledAt: timestamp
├── backupCodes: array[string] // Regenerates when used
└── backupCodesGeneratedAt: timestamp

otpTokens/
├── {tokenId}
│   ├── email: string
│   ├── otp: string (6-digit)
│   ├── expiresAt: timestamp (5 minutes)
│   ├── createdAt: timestamp
│   ├── used: boolean
│   └── verifiedAt: timestamp (optional)
```

### Implementation Steps:

1. **Create 2FA Settings Page in Admin Dashboard:**
```dart
ElevatedButton(
  onPressed: () => _enable2FA(),
  child: const Text('Enable 2FA'),
)
```

2. **Admin Enable 2FA Flow:**
```dart
final twoFactorService = TwoFactorAuthService();

// Step 1: Enable 2FA
await twoFactorService.enable2FA(adminUserId);

// Step 2: Generate backup codes
final backupCodes = await twoFactorService.generateBackupCodes(adminUserId);

// Step 3: Show codes to user (save securely)
showDialog(
  // Show backup codes in a modal
  // User must save or print them
)
```

3. **Login Flow with 2FA:**
```dart
// After email/password verification
final is2FAEnabled = await TwoFactorAuthService().is2FAEnabled(userId);

if (is2FAEnabled) {
  // Send OTP
  await TwoFactorAuthService().sendOTPEmail(email);
  
  // Navigate to OTP verification screen
  Navigator.push(
    context,
    MaterialPageRoute(builder: (_) => OTPVerificationPage(email: email))
  );
}
```

4. **OTP Verification Screen:**
```dart
// User enters 6-digit OTP
final isVerified = await TwoFactorAuthService().verifyOTP(
  email,
  otpCode,
);

if (isVerified) {
  // Proceed to dashboard
} else {
  // Show error: Invalid or expired OTP
  // User can enter backup code instead
}
```

---

## 3. EXPORT FUNCTIONALITY

### Service: `ExportService`
Location: `lib/services/export_service.dart`

### Key Features:
- Export orders to CSV
- Export deliveries to CSV
- Export staff performance metrics
- Export customer data
- Export comprehensive reports summary
- Date range filtering
- Proper CSV formatting with escaped values

### Methods:

#### Exports
```dart
// Export orders
Future<String> exportOrdersToCSV({
  DateTime? startDate,
  DateTime? endDate,
})

// Export deliveries
Future<String> exportDeliveriesToCSV({
  DateTime? startDate,
  DateTime? endDate,
})

// Export staff performance
Future<String> exportStaffPerformanceToCSV({
  DateTime? startDate,
  DateTime? endDate,
})

// Export customers
Future<String> exportCustomersToCSV()

// Export all reports summary
Future<String> exportReportsSummaryToCSV({
  DateTime? startDate,
  DateTime? endDate,
})
```

#### Utility
```dart
// Generate timestamped filename
String generateFilename(String reportType)
// Example: "orders_export_20240115_143022.csv"
```

### CSV Formats:

**Orders Export:**
```
Order ID,Customer ID,Product Type,Quantity,Total Amount,Status,Created Date,Delivery Date
ORD001,CUST001,Water Gallons,5,500.00,"pending",2024-01-15 10:30,2024-01-15
```

**Deliveries Export:**
```
Delivery ID,Order ID,Driver ID,Status,Created Date,Delivered Date,Delivery Time (hours)
DEL001,ORD001,DRV001,"completed",2024-01-15 10:30,2024-01-15 12:00,1.50
```

**Staff Performance Export:**
```
Staff ID,Name,Role,Total Deliveries,Completed Deliveries,Completion Rate (%),Avg Delivery Time (hours)
STAFF001,"Juan Dela Cruz","driver",25,24,96.00,1.75
```

**Customers Export:**
```
Customer ID,Name,Email,Contact,Address,Total Orders,Total Spent
CUST001,"Maria Santos","maria@email.com","09123456789","123 Main St",5,2500.00
```

**Reports Summary Export:**
```
=== MTA WATER DELIVERY REPORTS SUMMARY ===
Generated Date,2024-01-15 14:30
Report Period,"2024-01-01 to 2024-01-31"

=== ORDERS SUMMARY ===
Total Orders,150
Completed Orders,145
Pending Orders,5
Total Revenue,₱75000.00
Average Order Value,₱500.00

=== DELIVERIES SUMMARY ===
Total Deliveries,140
Completed Deliveries,138
In Progress Deliveries,2
Delivery Success Rate,98.57%
```

### Implementation Steps:

1. **Add Export Buttons to Admin Dashboard Reports Tab:**
```dart
Row(
  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
  children: [
    ElevatedButton.icon(
      onPressed: () => _exportOrders(),
      icon: const Icon(Icons.download),
      label: const Text('Orders CSV'),
    ),
    ElevatedButton.icon(
      onPressed: () => _exportDeliveries(),
      icon: const Icon(Icons.download),
      label: const Text('Deliveries CSV'),
    ),
    ElevatedButton.icon(
      onPressed: () => _exportStaffPerformance(),
      icon: const Icon(Icons.download),
      label: const Text('Staff CSV'),
    ),
  ],
)
```

2. **Add Export Methods to Admin Dashboard:**
```dart
Future<void> _exportOrders() async {
  final csv = await ExportService().exportOrdersToCSV();
  final filename = ExportService().generateFilename('orders');
  
  // Save to device
  // For web: use html.AnchorElement
  // For mobile: use path_provider + file plugins
  
  ScaffoldMessenger.of(context).showSnackBar(
    SnackBar(content: Text('Exported to $filename')),
  );
}
```

3. **Date Range Filtering:**
```dart
// Show date range picker
final dateRange = await showDateRangePicker(
  context: context,
  firstDate: DateTime(2020),
  lastDate: DateTime.now(),
);

if (dateRange != null) {
  final csv = await ExportService().exportOrdersToCSV(
    startDate: dateRange.start,
    endDate: dateRange.end,
  );
}
```

---

## Firestore Collections Update

### New Collections Added:

#### notifications/
- Real-time push notifications
- Indexed by: userId, read, createdAt

#### emailQueue/
- Pending emails to be sent
- Status tracking: pending, sent, failed
- Processed by Cloud Functions

#### otpTokens/
- Temporary OTP storage
- Auto-cleanup of expired tokens
- One-time use codes

### Updated Collections:
- **users**: Added twoFactorEnabled, backupCodes fields
- **activityLogs**: Added 2fa_verification type logging

---

## Database Security Rules

All new collections are protected by updated Firestore rules:

```firestore
// Notifications - only owner can read
match /notifications/{notificationId} {
  allow read: if request.auth.uid == resource.data.userId;
  allow create, update, delete: if request.auth.uid == resource.data.userId || isAdmin();
}

// Email Queue - admin only
match /emailQueue/{emailId} {
  allow read, update, delete: if isAdmin();
  allow create: if isSignedIn();
}

// OTP Tokens - write-only for security
match /otpTokens/{tokenId} {
  allow create: if isSignedIn();
  allow read, update, delete: if false;
}
```

---

## Integration Checklist

- [ ] **Push Notifications**
  - [ ] Add PushNotificationService import to dashboards
  - [ ] Add NotificationBadge to AppBar
  - [ ] Add NotificationCenter widget
  - [ ] Call sendNotification methods on order/delivery events
  - [ ] Test notification creation and retrieval

- [ ] **Two-Factor Authentication**
  - [ ] Create OTP verification page
  - [ ] Add 2FA enable/disable button in admin settings
  - [ ] Create backup codes display dialog
  - [ ] Integrate into login flow
  - [ ] Test OTP generation, verification, and expiration

- [ ] **Export Functionality**
  - [ ] Add export buttons to reports tab
  - [ ] Implement file download for web/mobile
  - [ ] Add date range filtering
  - [ ] Test CSV format and data accuracy
  - [ ] Verify special characters handling

---

## Next Steps

1. **Cloud Functions Setup** (for email sending):
   - Deploy function to process emailQueue
   - Configure email service (SendGrid, Firebase, etc.)
   - Set up email templates

2. **Firebase Cloud Messaging**:
   - Configure FCM in Firebase Console
   - Download google-services.json
   - Set up iOS APNs credentials
   - Test push notification delivery

3. **File Download Enhancement**:
   - Add path_provider for mobile
   - Implement file_picker for web
   - Add file sharing options

4. **Advanced 2FA**:
   - Add QR code TOTP app support
   - Implement biometric fallback
   - Add device trust/whitelist feature

---

## Testing & Validation

### Push Notifications
```dart
// Test notification creation
final service = PushNotificationService();
await service.sendOrderPlacedNotification(
  customerId: 'test_user',
  orderId: 'ORD123',
  productType: 'Water',
);

// Verify in Firestore
// Check notifications collection for new entry
```

### Two-Factor Authentication
```dart
// Test OTP generation
await TwoFactorAuthService().sendOTPEmail('test@email.com');
// Check otpTokens collection

// Test verification
final isValid = await TwoFactorAuthService().verifyOTP(
  'test@email.com',
  '123456',
);
```

### Export
```dart
// Test CSV generation
final csv = await ExportService().exportOrdersToCSV();
// Verify CSV format
assert(csv.contains('Order ID,Customer ID'));
```

---

## Performance Considerations

- **Notifications**: Indexed queries on userId + read field for efficiency
- **OTP Tokens**: Set TTL/cleanup job for expired documents
- **Exports**: Batch read operations, consider pagination for large datasets
- **2FA**: Rate limit OTP generation (max 3 per day)

---

## Support & Documentation

For detailed API documentation, refer to:
- `lib/services/push_notification_service.dart`
- `lib/services/two_factor_auth_service.dart`
- `lib/services/export_service.dart`
- `lib/widgets/notification_center.dart`

All services follow singleton pattern for consistency and resource management.
