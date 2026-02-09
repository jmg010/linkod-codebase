import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../models/task_model.dart';
import '../models/product_model.dart';
import '../models/post_model.dart';
import '../services/notifications_service.dart';
import '../services/tasks_service.dart';
import '../services/products_service.dart';
import '../services/posts_service.dart';
import '../services/firestore_service.dart';
import 'task_detail_screen.dart';
import 'product_detail_screen.dart';
import 'announcement_detail_screen.dart';
import 'post_detail_screen.dart';

enum NotificationType {
  volunteerAccepted,
  errandJobVolunteers,
  productMessages,
  accountApproved,
  announcement,
  postComment,
  postLike,
  taskAssigned,
}

class NotificationItem {
  final String message;
  final NotificationType type;
  final String? taskId;
  final String? productId;

  NotificationItem({
    required this.message,
    required this.type,
    this.taskId,
    this.productId,
  });
}

class NotificationsScreen extends StatefulWidget {
  const NotificationsScreen({super.key});

  @override
  State<NotificationsScreen> createState() => _NotificationsScreenState();
}

class _NotificationsScreenState extends State<NotificationsScreen> {
  Future<void> _handleNotificationTap(BuildContext context, Map<String, dynamic> notification) async {
    final type = notification['type'] as String?;
    final taskId = notification['taskId'] as String?;
    final productId = notification['productId'] as String?;
    final postId = notification['postId'] as String?;
    final announcementId = notification['announcementId'] as String?;
    final notificationId = notification['notificationId'] as String?;

    // Mark as read
    if (notificationId != null) {
      await NotificationsService.markAsRead(notificationId);
    }

    if (announcementId != null && announcementId.isNotEmpty) {
      if (mounted) {
        Navigator.of(context).push(
          MaterialPageRoute(
            builder: (_) => AnnouncementDetailScreen(announcementId: announcementId),
          ),
        );
      }
    } else if (postId != null && postId.isNotEmpty) {
      if (mounted) {
        Navigator.of(context).push(
          MaterialPageRoute(
            builder: (_) => PostDetailScreen(postId: postId),
          ),
        );
      }
    } else if (taskId != null) {
      try {
        final taskDoc = await FirestoreService.instance
            .collection('tasks')
            .doc(taskId)
            .get();
        
        if (taskDoc.exists) {
          final task = TaskModel.fromFirestore(taskDoc);
          if (mounted) {
            Navigator.of(context).push(
              MaterialPageRoute(
                builder: (_) => TaskDetailScreen(
                  task: task,
                  contactNumber: task.contactNumber,
                ),
              ),
            );
          }
        }
      } catch (e) {
        debugPrint('Error loading task: $e');
      }
    } else if (productId != null) {
      try {
        final productDoc = await FirestoreService.instance
            .collection('products')
            .doc(productId)
            .get();
        
        if (productDoc.exists) {
          final product = ProductModel.fromFirestore(productDoc);
          if (mounted) {
            Navigator.of(context).push(
              MaterialPageRoute(
                builder: (_) => ProductDetailScreen(product: product),
              ),
            );
          }
        }
      } catch (e) {
        debugPrint('Error loading product: $e');
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey.shade100,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.black87),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: const Text(
          'Notifications',
          style: TextStyle(
            fontSize: 24,
            fontWeight: FontWeight.w700,
            color: Colors.black87,
          ),
        ),
        centerTitle: true,
      ),
      body: FirestoreService.auth.currentUser == null
          ? Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.login, size: 64, color: Colors.grey[400]),
                  const SizedBox(height: 16),
                  Text(
                    'Please log in to view notifications',
                    style: TextStyle(fontSize: 18, color: Colors.grey[600]),
                  ),
                ],
              ),
            )
          : StreamBuilder<List<Map<String, dynamic>>>(
              stream: NotificationsService.getUserNotificationsStream(
                FirestoreService.auth.currentUser!.uid,
              ),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          if (snapshot.hasError) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.error_outline, size: 64, color: Colors.grey[400]),
                  const SizedBox(height: 16),
                  Text(
                    'Error loading notifications',
                    style: TextStyle(fontSize: 18, color: Colors.grey[600]),
                  ),
                ],
              ),
            );
          }

          final notifications = snapshot.data ?? [];

          if (notifications.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.notifications_none, size: 64, color: Colors.grey[400]),
                  const SizedBox(height: 16),
                  Text(
                    'No notifications yet',
                    style: TextStyle(fontSize: 18, color: Colors.grey[600]),
                  ),
                ],
              ),
            );
          }

          return ListView(
            padding: const EdgeInsets.all(20),
            children: notifications.map((notification) {
              final isRead = notification['isRead'] as bool? ?? false;
              return InkWell(
                onTap: () => _handleNotificationTap(context, notification),
                child: Container(
                  margin: const EdgeInsets.only(bottom: 16),
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: isRead ? Colors.white : Colors.blue.shade50,
                    borderRadius: BorderRadius.circular(18),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.06),
                        blurRadius: 8,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        child: Text(
                          notification['message'] as String? ?? '',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: isRead ? FontWeight.w400 : FontWeight.w600,
                            color: Colors.black87,
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Icon(
                        Icons.chevron_right,
                        color: Colors.grey.shade400,
                        size: 20,
                      ),
                    ],
                  ),
                ),
              );
            }).toList(),
          );
        },
      ),
    );
  }
}
