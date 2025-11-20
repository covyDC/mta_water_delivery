# MTA Water Delivery - System Verification Checklist

## ✅ Pre-Launch Checklist

### Firebase Setup
- [x] Firebase project created: `mta-water-delivery-8697f`
- [x] Cloud Firestore enabled
- [x] Firebase Auth enabled
- [x] Firebase Storage enabled
- [x] Firebase options configured in `firebase_options.dart`
- [ ] **TODO**: Update Firestore Security Rules (see `FIREBASE_RULES.txt`)
- [ ] **TODO**: Update Storage Security Rules (see `FIREBASE_RULES.txt`)

### Code Quality
- [x] `flutter analyze` - **0 issues found** ✅
- [x] All imports corrected
- [x] No deprecated API usage
- [x] No null safety issues
- [x] All async/await properly handled

### Project Structure
- [x] `lib/screens/auth/` - Login, Register, AdminLogin, RegisterStaff
- [x] `lib/screens/dashboards/` - Admin, Customer, Staff, Driver dashboards
- [x] `lib/models/` - Order model with serialization
- [x] `lib/services/` - FirestoreService for database operations
- [x] Dependencies installed (pubspec.yaml)

---

## 🚀 Steps to Test Everything

### Step 1: Update Firebase Rules (CRITICAL)
```
⚠️ IMPORTANT: Do this FIRST or app will fail to connect to Firestore!
```

1. Go to [Firebase Console](https://console.firebase.google.com)
2. Select `mta-water-delivery-8697f` project
3. Go to **Firestore Database** → **Rules**
4. Copy content from `FIREBASE_RULES.txt` file
5. Paste into the rules editor
6. Click **Publish**
7. Verify it says "Rules published"

### Step 2: Update Storage Rules (Optional but Recommended)
1. In Firebase Console, go to **Storage** → **Rules**
2. Copy Storage rules from `FIREBASE_RULES.txt` (commented section)
3. Paste and publish

### Step 3: Run the Application
Choose one option:

**Option A: Windows Desktop (Best for Desktop Testing)**
```powershell
cd C:\COVY\mta_water_delivery
flutter run -d windows
```

**Option B: Chrome Web (Best for Quick Testing)**
```powershell
cd C:\COVY\mta_water_delivery
flutter run -d chrome
```

### Step 4: Follow Testing Workflow
See `TESTING_GUIDE.md` for detailed step-by-step testing instructions.

---

## 🔍 Verification Points

### Database Collections (Verify in Firestore Console)

After following the testing workflow, you should have:

1. **customers** collection
   - Documents for each registered customer
   - Fields: fullName, contactNumber, address, email, uid, updatedAt

2. **orders** collection
   - Order documents with status: pending → confirmed
   - Fields: customerId, customerName, productType, quantity, status, timestamp

3. **deliveries** collection
   - Created when order is confirmed
   - Fields: orderId, customerId, assignedTo (driver), status, proofUrl

4. **staff** collection
   - On-site staff and driver documents
   - Fields: name, email, role (on-site staff | driver), status, inventory
   - On-site staff should have inventory data

5. **notifications** collection
   - Created when deliveries assigned
   - Fields: driverId, type, title, message, timestamp

### Firebase Storage

After completing deliveries with photo upload:
- Delivery proof photos stored in: `deliveries/{deliveryId}/proof_*.jpg`

---

## 📱 Feature Verification

### ✅ Customer Features
- [x] Registration with email/password
- [x] Profile management (name, phone, address)
- [x] Order placement with options
- [x] View deliveries
- [x] Data persisted to Firestore

### ✅ On-Site Staff Features
- [x] Staff login with email/password
- [x] Confirm pending orders
- [x] Pre-confirm dialog with inventory check
- [x] Inventory management
- [x] Order assignment to drivers
- [x] Activity logging
- [x] Role-based access (on-site staff only)

### ✅ Driver Features
- [x] Driver login with email/password
- [x] View assigned deliveries
- [x] Start delivery (status update)
- [x] Complete delivery (status update)
- [x] Upload proof photos
- [x] View completed deliveries
- [x] View notifications
- [x] Role-based access (driver only)

### ✅ Role-Based Routing
- [x] On-site staff login → StaffDashboard
- [x] Driver login → DriverDashboard
- [x] Admin credentials → AdminDashboard

---

## 🧪 Quick Test Scenarios

### Scenario 1: Complete Order Flow
1. Customer registers and sets profile
2. Customer places order
3. On-site staff confirms order (checks inventory)
4. On-site staff assigns to driver
5. Driver accepts and completes delivery
6. **Expected**: All data appears in Firestore, photo in Storage

### Scenario 2: Inventory Validation
1. On-site staff inventory = 10 gallons
2. Customer orders 15 gallons
3. On-site staff tries to confirm
4. **Expected**: Dialog shows insufficient inventory, confirm button disabled

### Scenario 3: Role-Based Access
1. Login as on-site staff
2. **Expected**: StaffDashboard with Orders, Inventory, Assign tabs
3. Logout and login as driver
4. **Expected**: DriverDashboard with Assigned, Completed, Notifications tabs

---

## 🔧 Troubleshooting

### Issue: "Permission denied" in Firestore
**Solution**: Check if Firestore rules are published (Step 1 above)

### Issue: "Image upload fails"
**Solution**: Check if Storage rules are published (Step 2 above)

### Issue: "No orders appearing for staff"
**Solution**: Ensure customer placed order, check status is "pending"

### Issue: "Driver doesn't see assigned delivery"
**Solution**: Verify delivery.assignedTo matches driver's staff ID

### Issue: "Profile data not saving"
**Solution**: Check `customers` collection exists in Firestore

### Issue: "App won't compile"
**Solution**: Run `flutter clean && flutter pub get`

---

## 📊 Success Criteria

After testing, you should be able to check off:

- [ ] Customer can register and setup profile
- [ ] Customer profile visible in Firestore `customers` collection
- [ ] Customer can place orders
- [ ] Orders visible in Firestore `orders` collection with status "pending"
- [ ] On-site staff can login with correct dashboard
- [ ] On-site staff can confirm pending orders
- [ ] Inventory decrements in Firestore on confirmation
- [ ] Delivery created in Firestore with status "assigned"
- [ ] Driver can login with correct dashboard
- [ ] Driver can see assigned deliveries
- [ ] Driver can mark delivery complete
- [ ] Proof photos upload to Firebase Storage
- [ ] Activity logged in `activity_logs`
- [ ] Role-based navigation works correctly
- [ ] No analyzer errors (`flutter analyze`)

---

## 📝 Important Notes

1. **Security Rules**: The rules in `FIREBASE_RULES.txt` are permissive for testing. For production, implement proper authentication checks.

2. **Password Storage**: Currently storing passwords in plaintext in Firestore. For production, use Firebase Auth or hash passwords.

3. **Testing Credentials**:
   - Admin: username: `admin`, password: `12345678`
   - Can create test users with any email

4. **Firestore Structure**: All collections are created automatically when data is written (no need to create manually).

---

## 🎯 Next Steps After Verification

If all tests pass:
1. Deploy to actual devices (Android/iOS)
2. Implement push notifications with Firebase Cloud Messaging
3. Add payment processing
4. Implement production-grade security rules
5. Set up automated backups
6. Monitor and log analytics

---

## 📞 Support

If you encounter issues:
1. Check Firestore console for data
2. Check Storage console for uploaded files
3. Look at device console for error messages
4. Check Firebase logs for permission errors
5. Verify all Firestore rules are published

**Document Created**: November 19, 2025
**Status**: Ready for Testing ✅
