# Quick Reference - Testing Your MTA Water Delivery System

## TL;DR - Quick Start (5 minutes)

### 1️⃣ UPDATE FIREBASE RULES (DO THIS FIRST!)
```
Go to Firebase Console > Firestore > Rules
Copy from FIREBASE_RULES.txt and paste > Publish
```

### 2️⃣ RUN THE APP
```powershell
cd C:\COVY\mta_water_delivery
flutter run -d chrome    # or: flutter run -d windows
```

### 3️⃣ TEST FLOW (10 minutes)
1. **Register Customer**: `cust@test.com` / `Test@123`
2. **Set Profile**: Name, Phone, Address
3. **Place Order**: Select product, quantity, confirm
4. **Login as Admin**: `admin` / `12345678`
5. **Register Staff**: `staff@test.com` / `Staff@123` → Select "On-Site Staff"
6. **Register Driver**: `driver@test.com` / `Driver@123` → Select "Driver"
7. **Staff Login**: Confirm order, check inventory, assign to driver
8. **Driver Login**: See delivery, mark complete, upload photo

---

## File Reference Guide

| Document | Purpose |
|----------|---------|
| `TESTING_GUIDE.md` | Complete step-by-step testing instructions |
| `VERIFICATION_CHECKLIST.md` | Pre-launch checklist and success criteria |
| `FIREBASE_RULES.txt` | Security rules to paste in Firebase Console |
| `ROLE_BASED_ACCESS.md` | Documentation of staff roles and permissions |
| `lib/test_firebase_connection.dart` | Firebase connectivity test (run as: `dart lib/test_firebase_connection.dart`) |

---

## Key Files by Role

### **CUSTOMER**
- `lib/screens/auth/login.dart` - Login & register
- `lib/screens/dashboards/customer_dashboard.dart` - Profile & orders
- `lib/models/order.dart` - Order data structure

### **ON-SITE STAFF**
- `lib/screens/auth/admin_login.dart` - Staff login (with role routing)
- `lib/screens/auth/register_staff.dart` - Register staff with role selector
- `lib/screens/dashboards/staff_dashboard.dart` - Orders, inventory, assignment

### **DRIVER**
- `lib/screens/dashboards/driver_dashboard.dart` - Assigned deliveries & completion
- Both use `lib/screens/auth/admin_login.dart` for login

### **ADMIN**
- `lib/screens/auth/admin_login.dart` - Admin login
- `lib/screens/dashboards/admin_dashboard.dart` - Staff registration

### **DATABASE**
- `lib/services/firestore_service.dart` - All Firestore operations
- Collections: customers, orders, deliveries, staff, notifications, activity_logs

---

## Login Credentials for Testing

### Admin
```
Username: admin
Password: 12345678
```

### Test Customers (Create yourself)
```
Email: customer1@test.com
Password: Test@123456
```

### Test On-Site Staff (Create via admin)
```
Email: staff1@test.com
Password: Staff@123456
Role: On-Site Staff
```

### Test Driver (Create via admin)
```
Email: driver1@test.com
Password: Driver@123456
Role: Driver
```

---

## Common Tasks

### Test Customer Registration & Order
1. Run app → `flutter run -d chrome`
2. Click "Register" 
3. Enter email/password
4. Set profile (name, phone, address)
5. Place order (Orders tab, FAB, select options, confirm)
6. ✅ Check Firestore: `orders` collection should have the order

### Test On-Site Staff Workflow
1. Run app → Login as admin (admin / 12345678)
2. Click "Register Staff / Carrier"
3. Fill form, select "On-Site Staff" role
4. Click "Register Staff"
5. Logout → Login as staff (staff@test.com / Staff@123456)
6. ✅ Should see StaffDashboard (not DriverDashboard)
7. View Orders tab, click Confirm, check inventory dialog
8. Confirm order → Check Firestore: order status should be "confirmed"

### Test Driver Workflow
1. Register driver (same as above, but select "Driver" role)
2. Logout → Login as driver (driver@test.com / Driver@123456)
3. ✅ Should see DriverDashboard (not StaffDashboard)
4. Check Assigned tab → click "Start Delivery"
5. Mark delivered (upload photo if available)
6. ✅ Check Firestore: delivery status should be "completed"

### Check Firestore Data
1. Go to [Firebase Console](https://console.firebase.google.com)
2. Select project: `mta-water-delivery-8697f`
3. Click Firestore Database
4. Check collections:
   - `customers` - customer profiles
   - `orders` - placed orders
   - `deliveries` - confirmed orders ready for delivery
   - `staff` - staff and driver accounts with inventory
   - `notifications` - assignments and alerts

### Check Firebase Storage
1. In Firebase Console, go to Storage
2. Look for: `deliveries/{deliveryId}/proof_*.jpg`
3. These are proof photos uploaded by drivers

---

## What Should Happen

### Customer Places Order
```
Customer Registration
    ↓
Profile Setup (Firestore: customers collection)
    ↓
Place Order (Firestore: orders collection, status="pending")
    ↓
Order appears in customer's Deliveries view
```

### On-Site Staff Confirms
```
Login (role check: "on-site staff")
    ↓
See pending orders (Orders tab)
    ↓
Click Confirm → Pre-confirm dialog shows inventory
    ↓
Confirm order (if inventory sufficient)
    ↓
Firestore: order status="confirmed", delivery created, inventory decremented
```

### On-Site Staff Assigns
```
View confirmed orders (Assign tab)
    ↓
Select driver
    ↓
Click Assign
    ↓
Firestore: delivery.assignedTo=driverId, notification created
    ↓
Driver sees it in their Assigned Deliveries
```

### Driver Completes
```
Login (role check: "driver")
    ↓
See assigned deliveries (Assigned tab)
    ↓
Click "Start Delivery" → status changes to "on_the_way"
    ↓
Click "Mark Delivered" → takes photo or uploads proof
    ↓
Firestore: status="completed", proofUrl saved, activity logged
    ↓
Delivery moves to Completed tab
```

---

## Verification Checklist (Quick)

After testing each flow, verify:

- [ ] Customer profile in Firestore `customers` collection
- [ ] Order in Firestore `orders` collection with status "pending"
- [ ] Staff member in Firestore `staff` collection with role "on-site staff"
- [ ] Driver in Firestore `staff` collection with role "driver"
- [ ] Order status changed to "confirmed" after staff approval
- [ ] Delivery in Firestore `deliveries` collection
- [ ] Driver sees delivery in their dashboard
- [ ] Proof photo in Firebase Storage: `deliveries/{id}/proof_*.jpg`
- [ ] Delivery status "completed" after driver finishes
- [ ] Activity logged in `activity_logs`
- [ ] No console errors (`flutter analyze` shows 0 issues)

---

## If Something Doesn't Work

### App won't start
```
flutter clean
flutter pub get
flutter run -d chrome
```

### Firestore connection fails
→ Check FIREBASE_RULES.txt was pasted and published
→ Check internet connection
→ Check Firebase project ID is correct

### Orders not appearing
→ Verify customer placed order (check their Deliveries tab)
→ Check Firestore `orders` collection exists
→ Check order status is "pending"

### Staff can't see orders
→ Verify staff is logged in (check AppBar)
→ Verify you're on the correct tab
→ Check Firestore: `orders` collection has documents with status="pending"

### Driver doesn't see assignment
→ Verify staff assigned the delivery to that specific driver
→ Check Firestore: delivery.assignedTo matches driver's staff ID
→ Check delivery status is "assigned" or "on_the_way"

---

## Commands You'll Need

```powershell
# Run the app
flutter run -d chrome          # Chrome browser
flutter run -d windows         # Windows desktop
flutter run -d edge            # Edge browser

# Check for errors
flutter analyze                # Find code issues
flutter doctor                 # Check Flutter setup

# Clean and rebuild
flutter clean
flutter pub get
flutter run

# Test Firebase connection
dart lib/test_firebase_connection.dart
```

---

## Success! 🎉

If you can:
✅ Register as customer and place order
✅ Login as staff and confirm order
✅ Login as driver and complete delivery
✅ See all data in Firestore
✅ See photos in Firebase Storage
✅ No analyzer errors

**Then your system is fully working!**

---

For detailed instructions, see:
- **Full Testing**: `TESTING_GUIDE.md`
- **Pre-Launch Checklist**: `VERIFICATION_CHECKLIST.md`
- **Role Documentation**: `ROLE_BASED_ACCESS.md`
