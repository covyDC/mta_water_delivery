import 'package:cloud_firestore/cloud_firestore.dart';

class ProductService {
  static final ProductService _instance = ProductService._internal();

  factory ProductService() {
    return _instance;
  }

  ProductService._internal();

  final _firestore = FirebaseFirestore.instance;

  /// Get all available products
  Future<List<Map<String, dynamic>>> getAllProducts() async {
    try {
      final snapshot = await _firestore.collection('products').orderBy('createdAt', descending: false).get();
      return snapshot.docs.map((doc) => {'id': doc.id, ...doc.data()}).toList();
    } catch (e) {
      print('Error fetching products: $e');
      return [];
    }
  }

  /// Stream all products (real-time updates)
  Stream<List<Map<String, dynamic>>> streamProducts() {
    return _firestore.collection('products').orderBy('createdAt', descending: false).snapshots().map((snapshot) =>
      snapshot.docs.map((doc) => {'id': doc.id, ...doc.data()}).toList()
    );
  }

  /// Get a single product by ID
  Future<Map<String, dynamic>?> getProduct(String productId) async {
    try {
      final doc = await _firestore.collection('products').doc(productId).get();
      if (doc.exists) {
        return {'id': doc.id, ...doc.data() as Map<String, dynamic>};
      }
      return null;
    } catch (e) {
      print('Error fetching product: $e');
      return null;
    }
  }

  /// Get product by type (e.g., 'gallon', 'bottled')
  Future<Map<String, dynamic>?> getProductByType(String type) async {
    try {
      final snapshot = await _firestore.collection('products').where('type', isEqualTo: type).limit(1).get();
      if (snapshot.docs.isNotEmpty) {
        final doc = snapshot.docs.first;
        return {'id': doc.id, ...doc.data()};
      }
      return null;
    } catch (e) {
      print('Error fetching product by type: $e');
      return null;
    }
  }




  // Product management (create/update/delete/toggle) has been removed —
  // product prices are now fixed in `lib/config/product_prices.dart` and
  // the products collection is read-only in Firestore rules.

  /// Get all active products
  Future<List<Map<String, dynamic>>> getActiveProducts() async {
    try {
      final snapshot = await _firestore
          .collection('products')
          .where('isActive', isEqualTo: true)
          .orderBy('createdAt', descending: false)
          .get();
      return snapshot.docs.map((doc) => {'id': doc.id, ...doc.data()}).toList();
    } catch (e) {
      print('Error fetching active products: $e');
      return [];
    }
  }
}
