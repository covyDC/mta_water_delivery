// ROLE-BASED ACCESS CONTROL DOCUMENTATION
//
// This file explains the role-based system for on-site staff and drivers.
//
// ============================================================================
// ROLE DEFINITIONS
// ============================================================================
//
// 1. ON-SITE STAFF
//    Role value: 'on-site staff'
//    Location: lib/screens/dashboards/staff_dashboard.dart
//    
//    Responsibilities:
//    - Order Management: View and confirm customer orders
//    - Inventory Tracking: Track water gallons (full, empty, refill returned)
//    - Assignment: Assign confirmed orders to drivers
//    - Activity Logging: View staff activity history
//    - Notifications: Receive system notifications
//    - Profile: Manage personal profile
//
//    Navigation Pages:
//    0. Orders - Shows pending orders for confirmation with pre-confirm dialog
//    1. Inventory - Tracks stock levels (full, empty, refillReturned)
//    2. Assign - Shows confirmed orders ready for driver assignment
//    3. Activity - Activity log of all staff actions
//    4. Completed Deliveries - View delivered orders
//    5. Profile - Personal profile information
//
// ============================================================================
// 2. DRIVER (DELIVERY PERSONNEL)
//    Role value: 'driver'
//    Location: lib/screens/dashboards/driver_dashboard.dart
//    
//    Responsibilities:
//    - Assigned Deliveries: View and manage assigned deliveries
//    - Complete Deliveries: Mark deliveries as completed with proof photos
//    - Notifications: Receive assignment notifications
//    - Profile: View personal profile
//
//    Navigation Pages:
//    0. Assigned - Shows assigned and on-the-way deliveries
//       Actions: Start Delivery, Mark Delivered, Mark Failed
//    1. Completed - Shows completed deliveries with delivery timestamps
//    2. Notifications - Shows assignment and system notifications
//    3. Profile - Personal driver profile information
//
// ============================================================================
// AUTHENTICATION & ROUTING
// ============================================================================
//
// File: lib/screens/auth/admin_login.dart
// 
// Login Flow:
// 1. Staff enter email and password
// 2. System queries 'staff' collection by email
// 3. Validates password against stored password
// 4. Routes based on staff['role']:
//    - 'driver' → DriverDashboardPage
//    - 'on-site staff' → StaffDashboardPage (default)
//
// Registration Flow:
// File: lib/screens/auth/register_staff.dart
// 
// 1. Admin selects staff role from dropdown:
//    - On-Site Staff (default)
//    - Driver
// 2. System creates staff document in 'staff' collection:
//    {
//      name: String,
//      email: String,
//      role: String ('on-site staff' | 'driver'),
//      password: String,
//      status: 'active',
//      inventory: {full: 0, empty: 0, refillReturned: 0},
//      createdAt: Timestamp
//    }
//
// ============================================================================
// FIRESTORE COLLECTIONS USED
// ============================================================================
//
// ON-SITE STAFF USES:
// - orders (read for pending confirmations)
// - deliveries (write for creating delivery docs after confirmation)
// - staff (read/write for inventory and profile)
// - activity_logs (write for action logging)
// - notifications (read/write)
//
// DRIVER USES:
// - deliveries (read for assigned, write for status updates)
// - notifications (read for assignment alerts)
// - activity_logs (write for delivery actions)
// - staff/[id]/activity_logs (write for activity)
//
// ============================================================================
// TRANSITION WORKFLOW
// ============================================================================
//
// Customer Order → On-Site Staff Confirmation → Driver Assignment → Driver Delivery
//
// 1. CUSTOMER places order
//    - Stored in 'orders' collection with status: 'pending'
//
// 2. ON-SITE STAFF CONFIRMS
//    - Views pending orders in Orders page
//    - Pre-confirm dialog shows inventory
//    - On Confirm: Creates delivery doc, inventory decrements, order → confirmed
//
// 3. ON-SITE STAFF ASSIGNS
//    - Views confirmed orders in Assign page
//    - Selects a driver to assign delivery to
//    - Updates delivery.assignedTo = driverId
//    - Creates notification for driver
//
// 4. DRIVER ACCEPTS & COMPLETES
//    - Sees assigned delivery in Assigned Deliveries
//    - Marks as "Start Delivery" → status changes to 'on_the_way'
//    - Takes proof photo
//    - Marks as "Mark Delivered" → status changes to 'completed'
//    - Delivery appears in Completed Deliveries
//
// ============================================================================
// FILE REFERENCES
// ============================================================================
//
// Authentication Files:
// - lib/screens/auth/login.dart (Customer login)
// - lib/screens/auth/register.dart (Customer registration)
// - lib/screens/auth/admin_login.dart (Staff/Admin login with role routing)
// - lib/screens/auth/register_staff.dart (Staff registration with role selector)
//
// Dashboard Files:
// - lib/screens/dashboards/staff_dashboard.dart (On-site staff dashboard)
// - lib/screens/dashboards/driver_dashboard.dart (Driver dashboard)
// - lib/screens/dashboards/admin_dashboard.dart (Admin dashboard)
// - lib/screens/dashboards/customer_dashboard.dart (Customer dashboard)
//
// Service Files:
// - lib/services/firestore_service.dart (Firestore operations)
//
// Model Files:
// - lib/models/order.dart (Order data model)
//
// ============================================================================
