import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import '../models/message_model.dart';
import '../models/product_model.dart';
import 'firestore_service.dart';

class ProductsService {
  static final CollectionReference _productsCollection = FirestoreService
      .instance
      .collection('products');

  /// Get all available products (Gatekeeper: only Approved)
  static Stream<List<ProductModel>> getProductsStream() {
    return _productsCollection
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map(
          (snapshot) =>
              snapshot.docs
                  .map((doc) => ProductModel.fromFirestore(doc))
                  .where(
                    (product) =>
                        product.isAvailable && product.status == 'Approved',
                  )
                  .toList(),
        );
  }

  /// Get products by seller
  static Stream<List<ProductModel>> getSellerProductsStream(String sellerId) {
    return _productsCollection
        .where('sellerId', isEqualTo: sellerId)
        .snapshots()
        .map((snapshot) {
          final products =
              snapshot.docs
                  .map((doc) => ProductModel.fromFirestore(doc))
                  .where((product) => product.isAvailable) // Filter in code
                  .toList();
          // Sort by createdAt descending in code to avoid index requirement
          products.sort((a, b) => b.createdAt.compareTo(a.createdAt));
          return products;
        });
  }

  /// Get products by category (Gatekeeper: only Approved)
  static Stream<List<ProductModel>> getProductsByCategoryStream(
    String category,
  ) {
    return _productsCollection
        .where('category', isEqualTo: category)
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map(
          (snapshot) =>
              snapshot.docs
                  .map((doc) => ProductModel.fromFirestore(doc))
                  .where(
                    (product) =>
                        product.isAvailable && product.status == 'Approved',
                  )
                  .toList(),
        );
  }

  /// Create a new product
  static Future<String> createProduct(ProductModel product) async {
    final docRef = await _productsCollection.add(product.toJson());
    return docRef.id;
  }

  /// Update a product
  static Future<void> updateProduct(
    String productId,
    Map<String, dynamic> updates,
  ) async {
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
    final messagesRef = _productsCollection
        .doc(productId)
        .collection('messages');
    final data = <String, dynamic>{
      'senderId': senderId,
      'senderName': senderName,
      'message': message,
      'isSeller': isSeller,
      'createdAt': FieldValue.serverTimestamp(),
    };
    if (parentId != null) data['parentId'] = parentId;
    final docRef = await messagesRef.add(data);
    String? sellerId;

    // Increment messagesCount
    await _productsCollection.doc(productId).update({
      'messagesCount': FieldValue.increment(1),
    });

    // Create notification for the product owner (client-side, no Cloud Functions).
    // Only notify the seller when a non-seller sends a message.
    try {
      final productSnap = await _productsCollection.doc(productId).get();
      final productData = productSnap.data() as Map<String, dynamic>?;
      sellerId = productData?['sellerId'] as String?;
      final sellerName = productData?['sellerName'] as String? ?? 'Unknown';
      final productTitle =
          productData?['title'] as String? ?? 'Unknown Product';

      print('Creating product message notification for seller: $sellerId');

      // Record this interaction for the sender (for Activity Log)
      if (!isSeller && senderId.isNotEmpty) {
        await recordUserProductInteraction(
          senderId,
          productId,
          productTitle,
          sellerId ?? '',
          sellerName,
        );
      }

      if (!isSeller && sellerId != null && sellerId != senderId) {
        final batch = FirestoreService.instance.batch();
        final notifRef =
            FirestoreService.instance.collection('notifications').doc();
        batch.set(notifRef, {
          'userId': sellerId,
          'senderId': senderId,
          'type': 'product_message',
          'productId': productId,
          'messageId': docRef.id,
          'isRead': false,
          'message': '$senderName sent you a message in your product post',
          'createdAt': FieldValue.serverTimestamp(),
        });
        final userRef = FirestoreService.instance
            .collection('users')
            .doc(sellerId);
        batch.set(userRef, {
          'unreadNotificationCount': FieldValue.increment(1),
        }, SetOptions(merge: true));
        await batch.commit();
        print(
          'Product message notification created successfully for product: $productId',
        );
      }
    } catch (e) {
      // Log but do not block sending the message.
      print(
        'FAILED to create product message notification for product $productId: $e',
      );
    }

    // Create notification for the parent message sender when this is a reply.
    if (parentId != null) {
      try {
        final parentMsg = await messagesRef.doc(parentId).get();
        if (parentMsg.exists) {
          final parentData = parentMsg.data();
          final parentSenderId = parentData?['senderId'] as String?;
          if (parentSenderId != null && parentSenderId != senderId) {
            // Avoid duplicate notifications for the seller on the same reply event.
            // Seller already receives product_message above for non-seller messages.
            if (!isSeller && sellerId != null && parentSenderId == sellerId) {
              return docRef.id;
            }
            final batch = FirestoreService.instance.batch();
            final notifRef =
                FirestoreService.instance.collection('notifications').doc();
            batch.set(notifRef, {
              'userId': parentSenderId,
              'senderId': senderId,
              'type': 'reply',
              'productId': productId,
              'parentMessageId': parentId,
              'messageId': docRef.id,
              'isRead': false,
              'message': '$senderName replied to your message',
              'createdAt': FieldValue.serverTimestamp(),
            });
            final userRef = FirestoreService.instance
                .collection('users')
                .doc(parentSenderId);
            batch.set(userRef, {
              'unreadNotificationCount': FieldValue.increment(1),
            }, SetOptions(merge: true));
            await batch.commit();
            print(
              'Reply notification created for parent sender: $parentSenderId',
            );
          }
        }
      } catch (e) {
        print('FAILED to create reply notification for product $productId: $e');
      }
    }

    return docRef.id;
  }

  /// Delete a message from a product
  static Future<void> deleteMessage(String productId, String messageId) async {
    final messageRef = _productsCollection
        .doc(productId)
        .collection('messages')
        .doc(messageId);
    await messageRef.delete();

    // Decrement messagesCount
    await _productsCollection.doc(productId).update({
      'messagesCount': FieldValue.increment(-1),
    });
  }

  static Stream<List<MessageModel>> getMessagesStream(String productId) {
    return _productsCollection
        .doc(productId)
        .collection('messages')
        .orderBy('createdAt', descending: false)
        .snapshots()
        .map((snapshot) {
          return snapshot.docs.map((doc) {
            final data = doc.data();
            return MessageModel.fromMap({
              ...data,
              'createdAt': FirestoreService.parseTimestamp(data['createdAt']),
            }, id: doc.id);
          }).toList();
        });
  }

  static DocumentReference<Map<String, dynamic>> _messageReadDoc(
    String productId,
    String userId,
  ) =>
      _productsCollection.doc(productId).collection('message_read').doc(userId);

  /// Mark product messages as read by this user (e.g. when seller opens product detail).
  static Future<void> markProductMessagesAsRead(
    String productId,
    String userId,
  ) async {
    await _messageReadDoc(productId, userId).set({
      'lastReadAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
  }

  /// Unread = messages from non-seller after lastReadAt for the given viewer (typically the seller).
  static Stream<int> getUnreadProductMessagesCountStream(
    String productId,
    String viewerUserId,
  ) {
    // Important: unread count must update both when new messages arrive AND when the
    // viewer marks the thread as read (message_read/{userId} changes).
    return getMessagesStream(productId).asyncExpand((messages) {
      return _messageReadDoc(productId, viewerUserId).snapshots().map((
        readSnap,
      ) {
        try {
          final data = readSnap.data();
          final raw = data?['lastReadAt'];
          final lastReadAt =
              raw is Timestamp
                  ? raw.toDate()
                  : (raw is DateTime ? raw : DateTime(1970));
          return messages
              .where(
                (m) =>
                    m.senderId != viewerUserId &&
                    m.createdAt.isAfter(lastReadAt),
              )
              .length;
        } catch (_) {
          return 0;
        }
      });
    });
  }

  /// Total unread product message count for a seller (across all their products).
  /// Reactive: updates from unread notification docs for the seller.
  static Stream<int> getTotalUnreadProductMessagesForSellerStream(
    String sellerId,
  ) {
    return FirestoreService.instance
        .collection('notifications')
        .where('userId', isEqualTo: sellerId)
        .where('isRead', isEqualTo: false)
        .snapshots()
        .map((snapshot) {
          var total = 0;
          for (final doc in snapshot.docs) {
            final data = doc.data();
            final productId = data['productId'] as String?;
            if (productId != null && productId.isNotEmpty) {
              total++;
            }
          }
          return total;
        });
  }

  /// Stream of seller's products with unread message count per product (for My Products red dots).
  /// Reactive: updates from unread notification docs grouped by product.
  static Stream<List<MapEntry<ProductModel, int>>>
  getSellerProductsWithUnreadStream(String sellerId) {
    return getSellerProductsStream(sellerId).asyncExpand((products) {
      if (products.isEmpty) {
        return Stream.value(<MapEntry<ProductModel, int>>[]);
      }

      return FirestoreService.instance
          .collection('notifications')
          .where('userId', isEqualTo: sellerId)
          .where('isRead', isEqualTo: false)
          .snapshots()
          .map((snapshot) {
            final unreadByProduct = <String, int>{};
            for (final doc in snapshot.docs) {
              final data = doc.data();
              final productId = data['productId'] as String?;
              if (productId == null || productId.isEmpty) continue;
              unreadByProduct[productId] =
                  (unreadByProduct[productId] ?? 0) + 1;
            }

            return products
                .map((p) => MapEntry(p, unreadByProduct[p.id] ?? 0))
                .toList();
          });
    });
  }

  // ==================== INTERACTED PRODUCTS (Activity Log) ====================

  static final CollectionReference _interactionsCollection = FirestoreService
      .instance
      .collection('user_product_interactions');

  /// Record that a user has interacted with a product (called when sending a message)
  static Future<void> recordUserProductInteraction(
    String userId,
    String productId,
    String productTitle,
    String sellerId,
    String sellerName,
  ) async {
    final interactionRef = _interactionsCollection.doc('${userId}_$productId');
    await interactionRef.set({
      'userId': userId,
      'productId': productId,
      'productTitle': productTitle,
      'sellerId': sellerId,
      'sellerName': sellerName,
      'lastInteractedAt': FieldValue.serverTimestamp(),
      'unreadReplyCount': 0,
    }, SetOptions(merge: true));
  }

  /// Get all products that a user has interacted with (Activity Log)
  static Stream<List<MapEntry<ProductModel, int>>>
  getUserInteractedProductsStream(String userId) {
    final controller =
        StreamController<List<MapEntry<ProductModel, int>>>.broadcast();
    final Map<String, int> unreadByProduct = {};
    final Map<String, StreamSubscription<int>> productSubs = {};
    List<ProductModel> currentProducts = [];

    void emitList() {
      if (!controller.isClosed) {
        final list =
            currentProducts
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
      currentProducts = products;
      for (final p in products) {
        if (productSubs.containsKey(p.id)) continue;
        unreadByProduct[p.id] = 0;
        // For interacted products, user is not the seller, so we track unread replies from seller
        final sub = _getUnreadRepliesFromSellerStream(p.id, userId).listen((
          count,
        ) {
          unreadByProduct[p.id] = count;
          emitList();
        });
        productSubs[p.id] = sub;
      }
      emitList();
    }

    // Listen to user's interactions to get the list of product IDs
    final interactionsSub = _interactionsCollection
        .where('userId', isEqualTo: userId)
        .orderBy('lastInteractedAt', descending: true)
        .snapshots()
        .asyncMap((snapshot) async {
          final productIds =
              snapshot.docs
                  .map(
                    (doc) =>
                        (doc.data() as Map<String, dynamic>)['productId']
                            as String?,
                  )
                  .where((id) => id != null)
                  .cast<String>()
                  .toList();

          if (productIds.isEmpty) return <ProductModel>[];

          // Fetch the actual product documents
          final products = <ProductModel>[];
          for (final batch in _chunks(productIds, 10)) {
            final query =
                await _productsCollection
                    .where(FieldPath.documentId, whereIn: batch)
                    .get();
            products.addAll(
              query.docs
                  .map((doc) => ProductModel.fromFirestore(doc))
                  .where((p) => p.isAvailable),
            );
          }
          // Sort by the order from interactions (most recent first)
          final idOrder = Map.fromIterables(
            productIds,
            List.generate(productIds.length, (i) => i),
          );
          products.sort((a, b) => idOrder[a.id]!.compareTo(idOrder[b.id]!));
          return products;
        })
        .listen((products) {
          setProducts(products);
        });

    controller.onListen = () {
      if (!controller.isClosed) emitList();
    };
    controller.onCancel = () {
      interactionsSub.cancel();
    };

    return controller.stream;
  }

  /// Get unread replies from seller for a specific product (for user's Activity Log)
  static Stream<int> _getUnreadRepliesFromSellerStream(
    String productId,
    String userId,
  ) {
    return getMessagesStream(productId).asyncExpand((messages) {
      return _messageReadDoc(productId, userId).snapshots().map((readSnap) {
        try {
          final data = readSnap.data();
          final raw = data?['lastReadAt'];
          final lastReadAt =
              raw is Timestamp
                  ? raw.toDate()
                  : (raw is DateTime ? raw : DateTime(1970));
          // Count messages from seller (not from user) after lastReadAt
          return messages
              .where(
                (m) => m.senderId != userId && m.createdAt.isAfter(lastReadAt),
              )
              .length;
        } catch (_) {
          return 0;
        }
      });
    });
  }

  /// Total unread replies across all products the user has interacted with (for Activity Log tab badge)
  static Stream<int> getTotalUnreadRepliesForUserStream(String userId) {
    final controller = StreamController<int>.broadcast();
    final Map<String, int> unreadByProduct = {};
    final Map<String, StreamSubscription<int>> productSubs = {};
    List<String> currentProductIds = [];

    void emitSum() {
      if (!controller.isClosed) {
        final sum = currentProductIds.fold<int>(
          0,
          (s, id) => s + (unreadByProduct[id] ?? 0),
        );
        controller.add(sum);
      }
    }

    void setProductIds(List<String> productIds) {
      final newIds = productIds.toSet();
      for (final id in productSubs.keys.toList()) {
        if (!newIds.contains(id)) {
          productSubs[id]?.cancel();
          productSubs.remove(id);
          unreadByProduct.remove(id);
        }
      }
      currentProductIds = productIds;
      for (final id in productIds) {
        if (productSubs.containsKey(id)) continue;
        unreadByProduct[id] = 0;
        final sub = _getUnreadRepliesFromSellerStream(id, userId).listen((
          count,
        ) {
          unreadByProduct[id] = count;
          emitSum();
        });
        productSubs[id] = sub;
      }
      emitSum();
    }

    final sub = _interactionsCollection
        .where('userId', isEqualTo: userId)
        .snapshots()
        .map(
          (snapshot) =>
              snapshot.docs
                  .map(
                    (doc) =>
                        (doc.data() as Map<String, dynamic>)['productId']
                            as String?,
                  )
                  .where((id) => id != null)
                  .cast<String>()
                  .toList(),
        )
        .listen((productIds) {
          setProductIds(productIds);
        });

    controller.onListen = () {
      if (!controller.isClosed) emitSum();
    };
    controller.onCancel = () {
      sub.cancel();
      for (final s in productSubs.values) {
        s.cancel();
      }
    };

    return controller.stream;
  }

  /// Combined total unread count for Product Activity (seller products + interacted posts)
  /// This is used for the marketplace "My Product" button badge
  static Stream<int> getTotalProductActivityUnreadStream(String userId) {
    final controller = StreamController<int>.broadcast();
    int sellerUnread = 0;
    int interactedUnread = 0;

    void emitSum() {
      if (!controller.isClosed) {
        controller.add(sellerUnread + interactedUnread);
      }
    }

    // Listen to seller products unread
    final sellerSub = getTotalUnreadProductMessagesForSellerStream(
      userId,
    ).listen((count) {
      sellerUnread = count;
      emitSum();
    });

    // Listen to interacted posts unread
    final interactedSub = getTotalUnreadRepliesForUserStream(userId).listen((
      count,
    ) {
      interactedUnread = count;
      emitSum();
    });

    controller.onListen = () {
      if (!controller.isClosed) emitSum();
    };
    controller.onCancel = () {
      sellerSub.cancel();
      interactedSub.cancel();
    };

    return controller.stream;
  }

  /// Helper to chunk list for Firestore 'whereIn' queries (max 10 items)
  static List<List<T>> _chunks<T>(List<T> list, int chunkSize) {
    final chunks = <List<T>>[];
    for (var i = 0; i < list.length; i += chunkSize) {
      chunks.add(
        list.sublist(
          i,
          i + chunkSize > list.length ? list.length : i + chunkSize,
        ),
      );
    }
    return chunks;
  }
}
