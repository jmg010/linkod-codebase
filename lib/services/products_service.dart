import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/message_model.dart';
import '../models/product_model.dart';
import 'firestore_service.dart';

class ProductsService {
  static final CollectionReference _productsCollection =
      FirestoreService.instance.collection('products');

  /// Get all available products (Gatekeeper: only Approved)
  static Stream<List<ProductModel>> getProductsStream() {
    return _productsCollection
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map((snapshot) => snapshot.docs
            .map((doc) => ProductModel.fromFirestore(doc))
            .where((product) => product.isAvailable && product.status == 'Approved')
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

  /// Get products by category (Gatekeeper: only Approved)
  static Stream<List<ProductModel>> getProductsByCategoryStream(String category) {
    return _productsCollection
        .where('category', isEqualTo: category)
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map((snapshot) => snapshot.docs
            .map((doc) => ProductModel.fromFirestore(doc))
            .where((product) => product.isAvailable && product.status == 'Approved')
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

  /// Add a message to a product. [parentId] optional; when set, message is a reply to that message.
  static Future<String> addMessage(
    String productId,
    String senderId,
    String senderName,
    String message,
    bool isSeller, {
    String? parentId,
  }) async {
    final messagesRef = _productsCollection.doc(productId).collection('messages');
    final data = <String, dynamic>{
      'senderId': senderId,
      'senderName': senderName,
      'message': message,
      'isSeller': isSeller,
      'createdAt': FieldValue.serverTimestamp(),
    };
    if (parentId != null) data['parentId'] = parentId;
    final docRef = await messagesRef.add(data);
    
    // Increment messagesCount
    await _productsCollection.doc(productId).update({
      'messagesCount': FieldValue.increment(1),
    });
    
    return docRef.id;
  }

  /// Get all messages for a product in a single list (top-level and replies).
  static Stream<List<MessageModel>> getMessagesStream(String productId) {
    return _productsCollection
        .doc(productId)
        .collection('messages')
        .orderBy('createdAt', descending: false)
        .snapshots()
        .map((snapshot) {
          return snapshot.docs.map((doc) {
            final data = doc.data() as Map<String, dynamic>;
            return MessageModel.fromMap(
              {...data, 'createdAt': FirestoreService.parseTimestamp(data['createdAt'])},
              id: doc.id,
            );
          }).toList();
        });
  }

  static DocumentReference<Map<String, dynamic>> _messageReadDoc(String productId, String userId) =>
      _productsCollection.doc(productId).collection('message_read').doc(userId);

  /// Mark product messages as read by this user (e.g. when seller opens product detail).
  static Future<void> markProductMessagesAsRead(String productId, String userId) async {
    await _messageReadDoc(productId, userId).set(
      {'lastReadAt': FieldValue.serverTimestamp()},
      SetOptions(merge: true),
    );
  }

  /// Unread = messages from non-seller after lastReadAt for the given viewer (typically the seller).
  static Stream<int> getUnreadProductMessagesCountStream(String productId, String viewerUserId) {
    return getMessagesStream(productId).asyncMap((messages) async {
      try {
        final readSnap = await _messageReadDoc(productId, viewerUserId).get();
        final data = readSnap.data() as Map<String, dynamic>?;
        final lastReadAt = data?['lastReadAt'] != null
            ? (data!['lastReadAt'] is Timestamp)
                ? (data['lastReadAt'] as Timestamp).toDate()
                : DateTime(1970)
            : DateTime(1970);
        return messages
            .where((m) => m.senderId != viewerUserId && m.createdAt.isAfter(lastReadAt))
            .length;
      } catch (_) {
        return 0;
      }
    });
  }

  /// Total unread product message count for a seller (across all their products).
  /// Reactive: updates when messages or read state change on any of the seller's products.
  static Stream<int> getTotalUnreadProductMessagesForSellerStream(String sellerId) {
    final controller = StreamController<int>.broadcast();
    final Map<String, int> unreadByProduct = {};
    final Map<String, StreamSubscription<int>> productSubs = {};
    List<ProductModel> _currentProducts = [];

    void emitSum() {
      if (!controller.isClosed) {
        final sum = _currentProducts.fold<int>(0, (s, p) => s + (unreadByProduct[p.id] ?? 0));
        controller.add(sum);
      }
    }

    void setProducts(List<ProductModel> products) {
      final newIds = products.map((p) => p.id).toSet();
      for (final id in productSubs.keys.toList()) {
        if (!newIds.contains(id)) {
          productSubs[id]?.cancel();
          productSubs.remove(id);
          unreadByProduct.remove(id);
        }
      }
      _currentProducts = products;
      for (final p in products) {
        if (productSubs.containsKey(p.id)) continue;
        final sub = getUnreadProductMessagesCountStream(p.id, sellerId).listen((count) {
          unreadByProduct[p.id] = count;
          emitSum();
        });
        productSubs[p.id] = sub;
      }
      emitSum();
    }

    final sub = getSellerProductsStream(sellerId).listen((products) {
      setProducts(products);
    });

    controller.onCancel = () {
      sub.cancel();
      for (final s in productSubs.values) {
        s.cancel();
      }
      productSubs.clear();
      unreadByProduct.clear();
    };

    return controller.stream;
  }

  /// Stream of seller's products with unread message count per product (for My Products red dots).
  /// Reactive: updates when messages or read state change on any product.
  static Stream<List<MapEntry<ProductModel, int>>> getSellerProductsWithUnreadStream(String sellerId) {
    final controller = StreamController<List<MapEntry<ProductModel, int>>>.broadcast();
    final Map<String, int> unreadByProduct = {};
    final Map<String, StreamSubscription<int>> productSubs = {};
    List<ProductModel> _currentProducts = [];

    void emitList() {
      if (!controller.isClosed) {
        final list = _currentProducts
            .map((p) => MapEntry(p, unreadByProduct[p.id] ?? 0))
            .toList();
        controller.add(list);
      }
    }

    void setProducts(List<ProductModel> products) {
      final newIds = products.map((p) => p.id).toSet();
      for (final id in productSubs.keys.toList()) {
        if (!newIds.contains(id)) {
          productSubs[id]?.cancel();
          productSubs.remove(id);
          unreadByProduct.remove(id);
        }
      }
      _currentProducts = products;
      for (final p in products) {
        if (productSubs.containsKey(p.id)) continue;
        unreadByProduct[p.id] = 0;
        final sub = getUnreadProductMessagesCountStream(p.id, sellerId).listen((count) {
          unreadByProduct[p.id] = count;
          emitList();
        });
        productSubs[p.id] = sub;
      }
      emitList();
    }

    final sub = getSellerProductsStream(sellerId).listen((products) {
      setProducts(products);
    });

    controller.onCancel = () {
      sub.cancel();
      for (final s in productSubs.values) {
        s.cancel();
      }
      productSubs.clear();
      unreadByProduct.clear();
    };

    return controller.stream;
  }
}
