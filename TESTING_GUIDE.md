# Testing Guide: MTA Water Delivery System

## Prerequisites
- ✅ Firebase Project Connected: `mta-water-delivery-8697f`
- ✅ Cloud Firestore Enabled
- ✅ Firebase Auth Enabled
- ✅ Firebase Storage Enabled
- ✅ All dependencies installed (pubspec.yaml)

## Available Test Devices
- Windows Desktop (Windows)
- Chrome Web Browser
- Microsoft Edge

---

## 1. QUICK START - Run the Application

### Option A: Run on Windows Desktop (Recommended for Desktop)
```powershell
cd C:\COVY\mta_water_delivery
flutter run -d windows
```

### Option B: Run on Chrome Web (Recommended for Quick Testing)
```powershell
cd C:\COVY\mta_water_delivery
flutter run -d chrome
```

### Option C: Run on Edge
```powershell
cd C:\COVY\mta_water_delivery
flutter run -d edge
```

---

## 2. TESTING WORKFLOW

### 2.1 TEST CUSTOMER FLOW

#### Step 1: Customer Registration
1. Click "Don't have an account? Register"
2. Fill in:
   - Email: `customer1@test.com`
   - Password: `Test@123456`
   - Confirm Password: `Test@123456`
3. Click "Register"
4. ✅ Should navigate to CustomerDashboard
5. ✅ Customer document created in Firestore `customers` collection

#### Step 2: Customer Profile Setup
1. In Customer Dashboard, click "Profile" tab (bottom nav)
2. Click "Edit Profile"
3. Fill in:
   - Full Name: `John Doe`
   - Contact Number: `+1-555-0123`
   - Delivery Address: `123 Main St, Springfield, IL 62701`
4. Click "Save"
5. ✅ Profile data saved to Firestore `customers` collection
6. ✅ SnackBar shows "Profile updated successfully!"

#### Step 3: Place Order
1. Click "Deliveries" tab (bottom nav)
2. Click floating action button (FAB) to place order
3. Fill order form:
   - Product Type: Select "Gallon" or "Bottled"
   - Container Type: Select "Full" or "Empty"
   - Refill Option: Yes/No
   - Quantity: Enter 5
   - Delivery Address: Address auto-filled from profile
4. Click "Place Order"
5. ✅ SnackBar shows "Order placed successfully!"
6. ✅ Order document created in Firestore `orders` collection with status: "pending"
7. ✅ Verify in Firestore:
   - Collection: `orders`
   - Fields: customerId, customerName, productType, quantity, address, status: "pending"

### 2.2 TEST ON-SITE STAFF FLOW

#### Step 1: Staff Registration (as Admin)
1. On login page, click "Login as Admin"
   - Username: `admin`
   - Password: `12345678`
2. Click "Register Staff / Carrier"
3. Fill form:
   - Full Name: `Alice Johnson`
   - Staff Email: `staff1@test.com`
   - Password: `Staff@123456`
   - Staff Role: Select "On-Site Staff"
4. Click "Register Staff"
5. ✅ SnackBar shows "Staff registered successfully!"
6. ✅ Staff document created in Firestore `staff` collection
7. ✅ Verify fields: name, email, role: "on-site staff", status: "active"

#### Step 2: Staff Login
1. On login page, click "Login as Staff / Carrier"
2. Enter:
   - Email: `staff1@test.com`
   - Password: `Staff@123456`
3. Click "Login as Staff / Carrier"
4. ✅ Should load StaffDashboard (not DriverDashboard)
5. ✅ AppBar shows "On-Site Staff Dashboard"

#### Step 3: Confirm Order
1. Click "Orders" tab (left navigation)
2. You should see the order placed by customer
   - Shows: Customer name, address, quantity
3. Click "Confirm" button
4. Pre-confirm dialog appears showing:
   - Available inventory
   - Required quantity
   - Expected remaining stock
5. Click "Confirm" if inventory is sufficient
6. ✅ SnackBar shows "Order confirmed successfully!"
7. ✅ In Firestore:
   - Order status changed from "pending" to "confirmed"
   - Delivery document created in `deliveries` collection
   - Staff inventory decremented in `staff` collection

#### Step 4: View Inventory
1. Click "Inventory" tab
2. Shows current stock:
   - Full Gallons
   - Empty Containers
   - Refill Returned
3. Click "Edit Inventory" to manually update stock
4. ✅ Changes persist to Firestore

#### Step 5: Assign to Driver
1. Click "Assign" tab
2. Shows confirmed orders ready for driver assignment
3. Select a driver from the list
4. Click "Assign" button
5. ✅ Delivery assigned to driver
6. ✅ Driver notification created in Firestore

### 2.3 TEST DRIVER FLOW

#### Step 1: Driver Registration
1. As Admin, register a driver:
   - Full Name: `Bob Driver`
   - Staff Email: `driver1@test.com`
   - Password: `Driver@123456`
   - Staff Role: Select "Driver"
2. ✅ Driver document created with role: "driver"

#### Step 2: Driver Login
1. On login page, click "Login as Staff / Carrier"
2. Enter:
   - Email: `driver1@test.com`
   - Password: `Driver@123456`
3. Click "Login as Staff / Carrier"
4. ✅ Should load DriverDashboard (not StaffDashboard)
5. ✅ AppBar shows "Driver Dashboard"
6. ✅ Navigation shows: Assigned, Completed, Notifications, Profile

#### Step 3: View Assigned Deliveries
1. Click "Assigned" tab
2. Shows deliveries assigned to this driver
3. Shows: Customer name, address, gallons, payment type
4. Click delivery card to see full details

#### Step 4: Start Delivery
1. From assigned delivery, click popup menu
2. Select "Start Delivery"
3. ✅ Status changes to "on_the_way"
4. ✅ Activity logged to `activity_logs`

#### Step 5: Complete Delivery
1. Click popup menu again
2. Select "Mark Delivered" or click delivery and upload proof photo
3. ✅ Proof photo uploaded to Firebase Storage
4. ✅ Status changes to "completed"
5. ✅ Delivery appears in "Completed" tab

#### Step 6: View Notifications
1. Click "Notifications" tab
2. Shows assignment notifications
3. Shows timestamp of each notification

#### Step 7: View Profile
1. Click "Profile" tab
2. Shows driver information
3. Click "Logout" to exit

---

## 3. FIRESTORE VERIFICATION CHECKLIST

### Collections to Verify:

#### 3.1 `customers` Collection
```
customers/
  ├── {uid}
      ├── fullName: "John Doe"
      ├── contactNumber: "+1-555-0123"
      ├── address: "123 Main St, Springfield, IL 62701"
      ├── email: "customer1@test.com"
      ├── uid: "{uid}"
      └── updatedAt: Timestamp
```

#### 3.2 `orders` Collection
```
orders/
  ├── {orderId}
      ├── customerId: "{uid}"
      ├── customerName: "John Doe"
      ├── productType: "gallon" | "bottled"
      ├── options: {
      │   container: "full" | "empty",
      │   refill: true | false
      │ }
      ├── quantity: 5
      ├── address: "123 Main St, Springfield, IL 62701"
      ├── status: "pending" | "confirmed"
      └── timestamp: Timestamp
```

#### 3.3 `deliveries` Collection
```
deliveries/
  ├── {deliveryId}
      ├── orderId: "{orderId}"
      ├── customerId: "{uid}"
      ├── customerName: "John Doe"
      ├── address: "123 Main St, Springfield, IL 62701"
      ├── gallons: {container: "full", quantity: 5}
      ├── phone: "{phone}"
      ├── paymentType: "cash" | "card"
      ├── assignedTo: "{staffId}" (driver)
      ├── status: "assigned" | "on_the_way" | "completed" | "failed"
      ├── proofUrl: "https://..." (Firebase Storage URL)
      ├── deliveredAt: Timestamp
      └── scheduledAt: Timestamp
```

#### 3.4 `staff` Collection
```
staff/
  ├── {staffId}
      ├── name: "Alice Johnson"
      ├── email: "staff1@test.com"
      ├── role: "on-site staff" | "driver"
      ├── password: "Staff@123456" (plaintext - consider hashing)
      ├── status: "active" | "inactive"
      ├── inventory: {
      │   full: 100,
      │   empty: 25,
      │   refillReturned: 15
      │ }
      ├── createdAt: Timestamp
      └── activity_logs/ (subcollection)
          ├── {logId}
              ├── message: "Confirmed order X"
              └── timestamp: Timestamp
```

#### 3.5 `notifications` Collection
```
notifications/
  ├── {notificationId}
      ├── driverId: "{staffId}"
      ├── type: "assignment" | "update"
      ├── title: "New Order Assigned"
      ├── message: "Order #123 assigned to you"
      └── timestamp: Timestamp
```

---

## 4. COMMON TEST CASES

### Test Case 1: Inventory Check Prevents Confirmation
1. Create order with quantity: 1000
2. On-site staff tries to confirm
3. ✅ Pre-confirm dialog shows insufficient inventory
4. ✅ "Confirm" button is disabled with red warning

### Test Case 2: Inventory Decrement Works
1. Staff inventory before: Full: 100
2. Confirm order for quantity: 10
3. ✅ Staff inventory after: Full: 90
4. ✅ Verify in Firestore `staff` collection

### Test Case 3: Driver Only Sees Own Deliveries
1. Create multiple deliveries assigned to different drivers
2. Login as Driver A
3. ✅ Only deliveries assigned to Driver A appear
4. ✅ Other drivers' deliveries not visible

### Test Case 4: Role-Based Dashboard
1. Login with on-site staff account
2. ✅ StaffDashboard loads (Orders, Inventory, Assign tabs)
3. Logout and login with driver account
4. ✅ DriverDashboard loads (Assigned, Completed, Notifications tabs)

---

## 5. ERROR SCENARIOS TO TEST

### Scenario 1: Invalid Credentials
- Try login with wrong password
- ✅ SnackBar shows "Incorrect staff password"

### Scenario 2: Non-existent User
- Try login with email not in database
- ✅ SnackBar shows "No staff account found with that email"

### Scenario 3: Incomplete Profile
- Customer places order without setting up profile
- ✅ Order should still work with auto-filled address

### Scenario 4: Duplicate Email
- Try registering staff with existing email
- ✅ System should prevent or warn about duplicate

---

## 6. TROUBLESHOOTING

### Issue: "Firebase not initialized"
- Solution: Ensure `Firebase.initializeApp()` completes before running app
- Check: `main.dart` has `async` and `await Firebase.initializeApp()`

### Issue: "Firestore rules error"
- Solution: Update Firestore security rules to allow testing
- Add to rules: 
  ```
  rules_version = '2';
  service cloud.firestore {
    match /databases/{database}/documents {
      match /{document=**} {
        allow read, write: if true;
      }
    }
  }
  ```

### Issue: "Cannot upload image to Firebase Storage"
- Solution: Update Storage security rules
- Add to rules:
  ```
  rules_version = '2';
  service firebase.storage {
    match /b/{bucket}/o {
      match /{allPaths=**} {
        allow read, write: if true;
      }
    }
  }
  ```

### Issue: "Delivery not appearing in driver dashboard"
- Solution: Verify:
  1. Delivery status is "assigned" or "on_the_way"
  2. Driver's staff ID matches delivery.assignedTo
  3. Firestore query filters are correct

---

## 7. QUICK COMMANDS FOR TESTING

```powershell
# Run app on Windows desktop
flutter run -d windows

# Run app on Chrome web
flutter run -d chrome

# Run with verbose logging
flutter run -v

# Run tests
flutter test

# Check all errors
flutter analyze

# Clean and rebuild
flutter clean
flutter pub get
flutter run

# Debug print to see Firestore operations
# Add to code: debugPrint('Debug message: $value');
```

---

## 8. SUCCESS CRITERIA

✅ Customer can register and setup profile
✅ Customer can place order with full details
✅ Order appears in Firestore as "pending"
✅ On-site staff can confirm order
✅ Inventory decrements on confirmation
✅ Delivery document created in Firestore
✅ Driver can see assigned deliveries
✅ Driver can mark delivery complete
✅ Proof photo uploads to Firebase Storage
✅ Activity logs record all actions
✅ Role-based routing works (staff vs driver)
✅ No analyzer errors (`flutter analyze`)

---

## Next Steps

1. Run `flutter run -d windows` or `flutter run -d chrome`
2. Follow the testing workflow above
3. Monitor Firestore console for data creation
4. Check Firebase Storage for uploaded images
5. Verify activity logs in Firestore

**If you encounter any issues, check the Firestore rules and Firebase Security Settings!**
