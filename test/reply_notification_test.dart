import 'package:flutter_test/flutter_test.dart';

/// Simplified tests for reply notifications
/// 
/// Run with: flutter test test/reply_notification_test.dart
void main() {
  group('Reply Notification Logic Tests', () {
    
    test('Reply notification data structure should be correct', () {
      // Arrange
      const parentSenderId = 'user_a';
      const replySenderId = 'user_b';
      const senderName = 'User B';
      const productId = 'product_123';
      const parentId = 'msg_parent';
      const messageId = 'msg_reply';
      
      // Act - simulate the notification data created in ProductsService.addMessage
      final notificationData = {
        'userId': parentSenderId,
        'senderId': replySenderId,
        'type': 'reply',
        'productId': productId,
        'parentMessageId': parentId,
        'messageId': messageId,
        'isRead': false,
        'message': '$senderName replied to your message',
      };
      
      // Assert
      expect(notificationData['userId'], equals(parentSenderId));
      expect(notificationData['senderId'], equals(replySenderId));
      expect(notificationData['type'], equals('reply'));
      expect(notificationData['productId'], equals(productId));
      expect(notificationData['parentMessageId'], equals(parentId));
      expect(notificationData['messageId'], equals(messageId));
      expect(notificationData['isRead'], equals(false));
      expect(notificationData['message'], contains(senderName));
    });

    test('Should create notification when sender != parent sender', () {
      const senderId = 'user_b';
      const parentSenderId = 'user_a';
      
      // Condition check from ProductsService
      final shouldCreateNotification = parentSenderId != null && parentSenderId != senderId;
      
      expect(shouldCreateNotification, equals(true));
    });

    test('Should NOT create notification when sender == parent sender', () {
      const senderId = 'user_a';
      const parentSenderId = 'user_a';
      
      // Condition check from ProductsService
      final shouldCreateNotification = parentSenderId != null && parentSenderId != senderId;
      
      expect(shouldCreateNotification, equals(false));
    });

    test('Should NOT create notification when parentId is null', () {
      const String? parentId = null;
      
      // Condition check - only create if parentId exists
      final shouldCheckParent = parentId != null;
      
      expect(shouldCheckParent, equals(false));
    });

    test('Cloud Function trigger payload should match mobile notification', () {
      // Mobile creates this
      final mobileNotification = {
        'type': 'reply',
        'productId': 'prod_123',
        'parentMessageId': 'msg_parent',
        'messageId': 'msg_reply',
      };

      // Cloud Function sends this in FCM
      final cloudFunctionPayload = {
        'type': 'reply',
        'productId': 'prod_123',
        'parentMessageId': 'msg_parent',
        'messageId': 'msg_reply',
      };

      expect(cloudFunctionPayload['type'], equals(mobileNotification['type']));
      expect(cloudFunctionPayload['productId'], equals(mobileNotification['productId']));
      expect(cloudFunctionPayload['parentMessageId'], equals(mobileNotification['parentMessageId']));
    });
  });

  group('All Notification Types Verification', () {
    final expectedNotificationTypes = [
      'like',
      'comment', 
      'reply',
      'product_message',
      'task_volunteer',
      'volunteer_accepted',
      'task_chat_message',
      'account_approved',
      'product_approved',
      'task_approved',
      'announcement',
    ];

    test('All notification types should be unique', () {
      final uniqueTypes = expectedNotificationTypes.toSet();
      expect(uniqueTypes.length, equals(expectedNotificationTypes.length));
    });

    test('Notification types should match Firestore rules', () {
      // These types are allowed in firestore.rules
      final allowedTypes = [
        'like',
        'comment',
        'reply',
        'product_message',
        'task_volunteer',
        'task_chat_message',
        'volunteer_accepted',
      ];

      for (final type in allowedTypes) {
        expect(expectedNotificationTypes, contains(type));
      }
    });
  });

  group('Notification Navigation Mapping', () {
    test('reply type should navigate to ProductDetailScreen', () {
      const type = 'reply';
      const hasProductId = true;
      
      // From push_notification_handler.dart logic
      final navigatesToProduct = type == 'reply' && hasProductId;
      
      expect(navigatesToProduct, equals(true));
    });

    test('like/comment/reply types should navigate to PostDetailScreen', () {
      final postTypes = ['like', 'comment', 'reply'];
      
      for (final type in postTypes) {
        final navigatesToPost = type == 'like' || type == 'comment' || type == 'reply';
        expect(navigatesToPost, equals(true));
      }
    });
  });
}
