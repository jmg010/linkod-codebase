import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/product_model.dart';
import 'firestore_service.dart';

class ProductsService {
  static final CollectionReference _productsCollection =
      FirestoreService.instance.collection('products');

  /// Get all available products
  static Stream<List<ProductModel>> getProductsStream() {
    return _productsCollection
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map((snapshot) => snapshot.docs
            .map((doc) => ProductModel.fromFirestore(doc))
            .where((product) => product.isAvailable) // Filter in code to avoid index requirement
            .toList());
  }

  /// Get products by seller
  static Stream<List<ProductModel>> getSellerProductsStream(String sellerId) {
    return _productsCollection
        .where('sellerId', isEqualTo: sellerId)
        .snapshots()
        .map((snapshot) {
          final products = snapshot.docs
              .map((doc) => ProductModel.fromFirestore(doc))
              .where((product) => product.isAvailable) // Filter in code
              .toList();
          // Sort by createdAt descending in code to avoid index requirement
          products.sort((a, b) => b.createdAt.compareTo(a.createdAt));
          return products;
        });
  }

  /// Get products by category
  static Stream<List<ProductModel>> getProductsByCategoryStream(String category) {
    return _productsCollection
        .where('category', isEqualTo: category)
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map((snapshot) => snapshot.docs
            .map((doc) => ProductModel.fromFirestore(doc))
            .where((product) => product.isAvailable) // Filter in code
            .toList());
  }

  /// Create a new product
  static Future<String> createProduct(ProductModel product) async {
    final docRef = await _productsCollection.add(product.toJson());
    return docRef.id;
  }

  /// Update a product
  static Future<void> updateProduct(String productId, Map<String, dynamic> updates) async {
    updates['updatedAt'] = FieldValue.serverTimestamp();
    await _productsCollection.doc(productId).update(updates);
  }

  /// Delete a product (soft delete by setting isAvailable to false)
  static Future<void> deleteProduct(String productId) async {
    await _productsCollection.doc(productId).update({
      'isAvailable': false,
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }

  /// Add a message to a product
  static Future<String> addMessage(
    String productId,
    String senderId,
    String senderName,
    String message,
    bool isSeller,
  ) async {
    final messagesRef = _productsCollection.doc(productId).collection('messages');
    final docRef = await messagesRef.add({
      'senderId': senderId,
      'senderName': senderName,
      'message': message,
      'isSeller': isSeller,
      'createdAt': FieldValue.serverTimestamp(),
    });
    
    // Increment messagesCount
    await _productsCollection.doc(productId).update({
      'messagesCount': FieldValue.increment(1),
    });
    
    return docRef.id;
  }

  /// Get messages for a product
  static Stream<List<Map<String, dynamic>>> getMessagesStream(String productId) {
    return _productsCollection
        .doc(productId)
        .collection('messages')
        .orderBy('createdAt', descending: false)
        .snapshots()
        .map((snapshot) => snapshot.docs
            .map((doc) {
                  final data = doc.data() as Map<String, dynamic>;
                  return <String, dynamic>{
                    'messageId': doc.id,
                    ...data,
                    'createdAt': FirestoreService.parseTimestamp(data['createdAt']),
                  };
                })
            .toList());
  }
}
