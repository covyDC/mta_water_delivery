# System Architecture & Data Flow

## 🏗️ Complete System Architecture

```
┌─────────────────────────────────────────────────────────────────────────┐
│                     MTA WATER DELIVERY SYSTEM                           │
└─────────────────────────────────────────────────────────────────────────┘

┌──────────────────────────────────────────────────────────────────────────┐
│                           USERS / ROLES                                  │
├──────────────────────────────────────────────────────────────────────────┤
│                                                                          │
│  👤 CUSTOMER                  🧑‍💼 ON-SITE STAFF          🚗 DRIVER           │
│  ├─ Register                  ├─ Login                    ├─ Login       │
│  ├─ Profile Setup             ├─ Confirm Orders           ├─ View Orders │
│  ├─ Place Order               ├─ Manage Inventory         ├─ Start Delivery
│  ├─ View Deliveries           ├─ Assign to Driver         ├─ Complete    │
│  └─ Rate & Review             └─ View Activity            ├─ Upload Proof│
│                                                           └─ View Profile│
│                                                                          │
└──────────────────────────────────────────────────────────────────────────┘

┌──────────────────────────────────────────────────────────────────────────┐
│                         FLUTTER DASHBOARDS                              │
├──────────────────────────────────────────────────────────────────────────┤
│                                                                          │
│  customer_dashboard.dart        staff_dashboard.dart     driver_dashboard│
│  ├─ Deliveries Tab             ├─ Orders Tab             ├─ Assigned Tab
│  └─ Profile Tab                ├─ Inventory Tab          ├─ Completed Tab
│                                 ├─ Assign Tab             ├─ Notifications
│                                 ├─ Activity Tab           └─ Profile Tab
│                                 └─ Profile Tab                          │
│                                                                          │
│  ROUTING LOGIC (admin_login.dart):                                      │
│  User Role: "driver" → DriverDashboardPage                              │
│  User Role: "on-site staff" → StaffDashboardPage                        │
│                                                                          │
└──────────────────────────────────────────────────────────────────────────┘

┌──────────────────────────────────────────────────────────────────────────┐
│                      FIREBASE INTEGRATION                               │
├──────────────────────────────────────────────────────────────────────────┤
│                                                                          │
│  Firebase Core                                                          │
│  ├─ Project: mta-water-delivery-8697f                                   │
│  └─ Platform: Android, iOS, Web, Windows, macOS                         │
│                                                                          │
│  Firebase Auth                                                          │
│  ├─ Customer: Email/Password + Google Sign-In                           │
│  └─ Staff/Driver: Email/Password (stored in Firestore)                  │
│                                                                          │
│  Cloud Firestore (Real-time Database)                                   │
│  ├─ customers/          (Customer profiles & contact info)              │
│  ├─ orders/             (Customer orders: pending → confirmed)          │
│  ├─ deliveries/         (Confirmed orders: assigned → completed)        │
│  ├─ staff/              (Staff & driver accounts with roles)            │
│  ├─ notifications/      (Assignment & system alerts)                    │
│  └─ activity_logs/      (User action history)                           │
│                                                                          │
│  Firebase Storage                                                       │
│  └─ deliveries/{id}/proof_*.jpg (Delivery proof photos)                │
│                                                                          │
│  Security Rules                                                         │
│  ├─ Firestore: Read/Write permissions per collection                   │
│  └─ Storage: Photo upload/download permissions                         │
│                                                                          │
└──────────────────────────────────────────────────────────────────────────┘
```

---

## 📊 Data Flow Diagrams

### Complete Order Lifecycle

```
STEP 1: CUSTOMER PLACES ORDER
┌─────────────────────────────┐
│  Customer                   │
│  ├─ Registers               │
│  ├─ Sets Profile            │
│  ├─ Place Order:            │
│  │  ├─ Product Type         │
│  │  ├─ Quantity             │
│  │  └─ Address              │
│  └─ submits                 │
└────────────┬────────────────┘
             │
             ↓
      Firebase Auth
      (Email/Password)
             │
             ↓
      Firestore Write
┌────────────────────────────────┐
│ orders/ {orderId}              │
│ ├─ customerId                  │
│ ├─ customerName                │
│ ├─ productType: "gallon"       │
│ ├─ quantity: 5                 │
│ ├─ address: "..."              │
│ ├─ status: "PENDING"           │
│ └─ timestamp                   │
└────────────────────────────────┘

STEP 2: ON-SITE STAFF CONFIRMS
┌─────────────────────────────┐
│  On-Site Staff              │
│  ├─ Logins                  │
│  ├─ Views Orders Tab        │
│  ├─ Sees Pending Order      │
│  ├─ Clicks Confirm          │
│  ├─ Dialog Shows:           │
│  │  ├─ Available Stock: 100  │
│  │  ├─ Needed: 5            │
│  │  └─ Remaining: 95        │
│  ├─ Confirms                │
│  └─ (Firestore Transaction) │
└────────────┬────────────────┘
             │
             ↓ (Atomic Update)
    ┌────────┴────────┐
    ↓                 ↓
Order Status      Inventory
Updated to        Decremented
"CONFIRMED"       full: 100→95
    │                 │
    ↓                 ↓
    └────────┬────────┘
             ↓
      Delivery Created
┌────────────────────────────────┐
│ deliveries/ {deliveryId}       │
│ ├─ orderId                     │
│ ├─ customerId                  │
│ ├─ customerName                │
│ ├─ address                     │
│ ├─ gallons: 5                  │
│ ├─ status: "ASSIGNED"          │
│ ├─ assignedTo: null            │
│ └─ timestamp                   │
└────────────────────────────────┘

STEP 3: ON-SITE STAFF ASSIGNS TO DRIVER
┌─────────────────────────────┐
│  On-Site Staff              │
│  ├─ Clicks Assign Tab       │
│  ├─ Sees Confirmed Orders   │
│  ├─ Selects Driver:         │
│  │  └─ Bob (driver1)        │
│  ├─ Clicks Assign           │
│  └─ Submits                 │
└────────────┬────────────────┘
             │
             ↓
      Firestore Update
┌────────────────────────────────┐
│ deliveries/ {deliveryId}       │
│ ├─ assignedTo: "driver1"       │
│ ├─ status: "ASSIGNED"          │
│ └─ timestamp                   │
└────────────────────────────────┘
             │
             ↓
      Notification Created
┌────────────────────────────────┐
│ notifications/ {notifId}       │
│ ├─ driverId: "driver1"         │
│ ├─ type: "assignment"          │
│ ├─ title: "New Delivery"       │
│ ├─ message: "Order assigned"   │
│ └─ timestamp                   │
└────────────────────────────────┘

STEP 4: DRIVER ACCEPTS & COMPLETES
┌─────────────────────────────┐
│  Driver                     │
│  ├─ Logins                  │
│  ├─ Views Assigned Tab      │
│  ├─ Sees Delivery           │
│  ├─ Clicks "Start"          │
│  ├─ Status → "ON_THE_WAY"   │
│  ├─ Clicks "Complete"       │
│  ├─ Uploads Proof Photo     │
│  └─ Submits                 │
└────────────┬────────────────┘
             │
             ↓
      Firestore Updates
┌────────────────────────────────┐
│ deliveries/ {deliveryId}       │
│ ├─ status: "COMPLETED"         │
│ ├─ proofUrl: "firebase URL"    │
│ ├─ deliveredAt: timestamp      │
│ └─ activity logged             │
└────────────────────────────────┘
             │
             ↓
      Photo in Storage
┌──────────────────────────────────┐
│ deliveries/                      │
│ └─ {deliveryId}/                │
│    └─ proof_1234567890.jpg      │
└──────────────────────────────────┘
```

---

## 🗄️ Firestore Schema

### customers Collection
```javascript
customers/ {
  {uid}: {
    fullName: string,
    contactNumber: string,
    address: string,
    email: string (from Firebase Auth),
    uid: string,
    updatedAt: timestamp
  }
}
```

### orders Collection
```javascript
orders/ {
  {orderId}: {
    customerId: string (uid),
    customerName: string,
    productType: string ('gallon' | 'bottled'),
    options: {
      container: string ('full' | 'empty'),
      refill: boolean
    },
    quantity: number,
    address: string,
    status: string ('pending' | 'confirmed'),
    timestamp: timestamp
  }
}
```

### deliveries Collection
```javascript
deliveries/ {
  {deliveryId}: {
    orderId: string,
    customerId: string,
    customerName: string,
    address: string,
    gallons: {
      container: string,
      quantity: number
    },
    phone: string,
    paymentType: string,
    notes: string,
    assignedTo: string (staff id),
    status: string ('assigned' | 'on_the_way' | 'completed' | 'failed'),
    proofUrl: string (Firebase Storage URL),
    deliveredAt: timestamp,
    scheduledAt: timestamp
  }
}
```

### staff Collection
```javascript
staff/ {
  {staffId}: {
    name: string,
    email: string,
    role: string ('on-site staff' | 'driver'),
    password: string (plaintext - use hashing in production),
    status: string ('active' | 'inactive'),
    inventory: {
      full: number,
      empty: number,
      refillReturned: number
    },
    createdAt: timestamp,
    activity_logs: {
      {logId}: {
        message: string,
        timestamp: timestamp
      }
    }
  }
}
```

### notifications Collection
```javascript
notifications/ {
  {notificationId}: {
    driverId: string,
    type: string ('assignment' | 'update'),
    title: string,
    message: string,
    timestamp: timestamp
  }
}
```

---

## 🔄 Role-Based Access Control

### Customer (Firebase Auth User)
```
Accessible:
├─ Create: orders, profile (customers collection)
├─ Read: own orders, own deliveries, own profile
└─ Update: own profile, delivery address

Cannot Access:
├─ Other customers' data
├─ Inventory
├─ Staff functionality
└─ Driver functionality
```

### On-Site Staff (Firestore User)
```
Accessible:
├─ Read: pending orders, confirmed orders
├─ Write: confirm orders, update inventory
├─ Create: deliveries, assignments, activity logs
├─ Update: order status, inventory levels
└─ Assign: deliveries to drivers

Cannot Access:
├─ Customer personal data (except name, address)
├─ Driver's delivery details
├─ Other staff inventory
└─ Proof photos until delivery complete
```

### Driver (Firestore User)
```
Accessible:
├─ Read: own assigned deliveries
├─ Update: delivery status (assigned → on_the_way → completed)
├─ Create: proof photo uploads, activity logs
└─ Read: own notifications

Cannot Access:
├─ Orders (before assignment)
├─ Other drivers' deliveries
├─ Customer personal data (only name, address, phone)
├─ Inventory management
└─ Order confirmation
```

---

## 🔐 Security & Authentication

### Firebase Auth (Customers)
```
Registration:
├─ Email/Password validation
├─ Creates user in Firebase Auth
└─ Links to customers collection

Login:
├─ Firebase Auth checks credentials
├─ Routes to CustomerDashboard
└─ User ID from Firebase Auth used for queries
```

### Firestore Auth (Staff/Drivers)
```
Registration (by Admin):
├─ Stores in staff collection
├─ Sets role (on-site staff | driver)
└─ Stores password (plaintext for now)

Login:
├─ Queries staff collection by email
├─ Validates password
├─ Routes based on role:
│  ├─ driver → DriverDashboardPage
│  └─ on-site staff → StaffDashboardPage
└─ Staff object passed to dashboard
```

---

## 🔍 Query Patterns

### Customer Retrieving Own Orders
```dart
FirebaseFirestore.instance
  .collection('orders')
  .where('customerId', isEqualTo: userId)
  .snapshots()
```

### Staff Viewing Pending Orders
```dart
FirebaseFirestore.instance
  .collection('orders')
  .where('status', isEqualTo: 'pending')
  .snapshots()
```

### Driver Viewing Assigned Deliveries
```dart
FirebaseFirestore.instance
  .collection('deliveries')
  .where('assignedTo', isEqualTo: driverId)
  .where('status', whereIn: ['assigned', 'on_the_way'])
  .snapshots()
```

### Confirming Order (Transactional)
```dart
WriteBatch batch = FirebaseFirestore.instance.batch();

// Check inventory
final staffDoc = await batch.get('staff/staffId');
if (staffDoc['inventory']['full'] < orderQuantity) {
  throw Exception('Insufficient inventory');
}

// Update order status
batch.update('orders/orderId', {'status': 'confirmed'});

// Create delivery
batch.set('deliveries/newId', deliveryData);

// Decrement inventory
batch.update('staff/staffId', {
  'inventory.full': FieldValue.increment(-quantity)
});

await batch.commit();
```

---

## 📱 UI Flow Diagram

```
┌─────────────────────────────────────────────┐
│          LOGIN PAGE (admin_login.dart)      │
├─────────────────────────────────────────────┤
│  [ Admin Login ]  or  [ Staff Login ]       │
│                                             │
│  Admin (admin/12345678)                     │
│      ↓                                      │
│  AdminDashboardPage                         │
│      ├─ Register Staff                      │
│      └─ Register Driver                     │
│                                             │
│  Staff/Driver (email/password)              │
│      ↓                                      │
│      Role Check                             │
│      ├─ driver → DriverDashboardPage       │
│      └─ on-site staff → StaffDashboardPage │
│                                             │
└─────────────────────────────────────────────┘

┌────────────────────────────────────────────┐
│   CUSTOMER LOGIN PAGE (login.dart)         │
├────────────────────────────────────────────┤
│   Email/Password or Google Sign-In         │
│           ↓                                │
│  CustomerDashboardPage                     │
│   ├─ Deliveries Tab (View Orders)         │
│   │  └─ [+] Place Order                   │
│   └─ Profile Tab (Manage Profile)         │
│      └─ [Edit] Button                     │
│                                            │
└────────────────────────────────────────────┘

┌──────────────────────────────────────────────┐
│    STAFF DASHBOARD (staff_dashboard.dart)    │
├──────────────────────────────────────────────┤
│  Left Navigation:                            │
│  ├─ Orders (Confirm pending)                 │
│  ├─ Inventory (View/Edit stock)              │
│  ├─ Assign (Assign to drivers)               │
│  ├─ Activity (View logs)                     │
│  ├─ Completed (View delivered orders)        │
│  └─ Profile (Staff info)                     │
│                                              │
└──────────────────────────────────────────────┘

┌──────────────────────────────────────────────┐
│   DRIVER DASHBOARD (driver_dashboard.dart)   │
├──────────────────────────────────────────────┤
│  Left Navigation:                            │
│  ├─ Assigned (Start/Complete)                │
│  │  └─ Delivery Details                      │
│  │     ├─ Call Customer                      │
│  │     ├─ Navigate to Address                │
│  │     └─ Upload Proof Photo                 │
│  ├─ Completed (View history)                 │
│  ├─ Notifications (Assignment alerts)        │
│  └─ Profile (Driver info)                    │
│                                              │
└──────────────────────────────────────────────┘
```

---

## 🌐 Deployment Architecture

```
Local Development
├─ Flutter App (Windows/Chrome)
├─ Firebase Emulator (optional)
└─ Real Firestore (development project)

Production Ready
├─ Flutter App (Web/Android/iOS/Windows)
├─ Firebase Project (mta-water-delivery-8697f)
│  ├─ Cloud Firestore (Real Database)
│  ├─ Firebase Auth (User Management)
│  ├─ Firebase Storage (Photo Upload)
│  ├─ Firestore Rules (Security)
│  └─ Storage Rules (Security)
└─ Monitoring
   ├─ Firebase Console Logs
   ├─ Crashlytics (optional)
   └─ Google Analytics (optional)
```

---

This architecture provides:
✅ Separation of concerns  
✅ Role-based access control  
✅ Real-time data synchronization  
✅ Scalable cloud infrastructure  
✅ Secure authentication & authorization  
✅ Photo storage and delivery proof tracking  

Perfect for a production water delivery management system!
