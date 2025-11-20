import 'package:firebase_core/firebase_core.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'firebase_options.dart';

/// Quick Firebase Connectivity Test
/// Run this to verify Firebase is properly connected before running the app
Future<void> testFirebaseConnection() async {
  try {
    // Initialize Firebase
    print('🔄 Initializing Firebase...');
    await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    );
    print('✅ Firebase initialized successfully!');

    // Test Firestore connection
    print('\n🔄 Testing Firestore connection...');
    final firestore = FirebaseFirestore.instance;
    
    // Try to read collections
    final staffSnapshot = await firestore
        .collection('staff')
        .limit(1)
        .get();
    print('✅ Firestore connected! Found ${staffSnapshot.docs.length} staff documents');

    // Test write capability
    print('\n🔄 Testing Firestore write capability...');
    await firestore
        .collection('test')
        .doc('connectivity_test')
        .set({
          'message': 'Firebase is working!',
          'timestamp': DateTime.now(),
        });
    print('✅ Firestore write successful!');

    // Read it back
    final testDoc = await firestore
        .collection('test')
        .doc('connectivity_test')
        .get();
    print('✅ Firestore read successful: ${testDoc.data()}');

    // Cleanup
    await firestore
        .collection('test')
        .doc('connectivity_test')
        .delete();
    print('✅ Cleanup successful');

    final separator = '=' * 50;
    print('\n$separator');
    print('✅ ALL FIREBASE TESTS PASSED!');
    print(separator);

  } catch (e) {
    final separator = '=' * 50;
    print('\n$separator');
    print('❌ FIREBASE TEST FAILED');
    print(separator);
    print('Error: $e');
    print('\nTroubleshooting steps:');
    print('1. Check Firebase project is properly configured');
    print('2. Verify Firestore is enabled in Firebase Console');
    print('3. Check Firestore security rules allow read/write');
    print('4. Ensure google-services.json (Android) is in place');
    print('5. Check internet connection');
  }
}

void main() async {
  await testFirebaseConnection();
}
