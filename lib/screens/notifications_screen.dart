import 'package:flutter/material.dart';
import '../models/task_model.dart';
import '../models/product_model.dart';
import 'task_detail_screen.dart';
import 'product_detail_screen.dart';

enum NotificationType {
  volunteerAccepted,
  errandJobVolunteers,
  productMessages,
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

class NotificationsScreen extends StatelessWidget {
  const NotificationsScreen({super.key});

  // Sample notifications with types
  List<NotificationItem> get _notifications => [
    NotificationItem(
      message: 'Clinch James Lansaderas accepted you to volunteer in hist request post.',
      type: NotificationType.volunteerAccepted,
      taskId: 'task_1',
    ),
    NotificationItem(
      message: '5 People volunteered to your errand/job post.',
      type: NotificationType.errandJobVolunteers,
      taskId: 'task_2',
    ),
    NotificationItem(
      message: '2 People dropped a message to your product post.',
      type: NotificationType.productMessages,
      productId: 'product_1',
    ),
  ];

  void _handleNotificationTap(BuildContext context, NotificationItem notification) {
    switch (notification.type) {
      case NotificationType.volunteerAccepted:
      case NotificationType.errandJobVolunteers:
        // Navigate to TaskDetailScreen
        final task = _createSampleTask(notification.taskId ?? 'task_1');
        Navigator.of(context).push(
          MaterialPageRoute(
            builder: (_) => TaskDetailScreen(
              task: task,
              contactNumber: '09026095205',
            ),
          ),
        );
        break;
      case NotificationType.productMessages:
        // Navigate to ProductDetailScreen
        final product = _createSampleProduct(notification.productId ?? 'product_1');
        Navigator.of(context).push(
          MaterialPageRoute(
            builder: (_) => ProductDetailScreen(
              product: product,
            ),
          ),
        );
        break;
    }
  }

  TaskModel _createSampleTask(String taskId) {
    return TaskModel(
      id: taskId,
      title: 'Sample Errand/Job Post',
      description: 'This is a sample errand/job post that you can view details for.',
      requesterName: 'Juan Dela Cruz',
      createdAt: DateTime.now().subtract(const Duration(days: 2)),
      status: TaskStatus.open,
      priority: TaskPriority.medium,
      assignedTo: taskId == 'task_1' ? 'Clinch James Lansaderas' : null,
    );
  }

  ProductModel _createSampleProduct(String productId) {
    return ProductModel(
      id: productId,
      sellerId: 'seller_1',
      sellerName: 'Juan Dela Cruz',
      title: 'Sample Product',
      description: 'This is a sample product that you can view details for.',
      price: 150.00,
      category: 'General',
      createdAt: DateTime.now().subtract(const Duration(days: 1)),
      isAvailable: true,
      location: 'Purok 4 Kidid sa daycare center',
      contactNumber: '0978192739813',
    );
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
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          ..._notifications.map((notification) => InkWell(
                onTap: () => _handleNotificationTap(context, notification),
                child: Container(
                  margin: const EdgeInsets.only(bottom: 16),
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: Colors.white,
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
                          notification.message,
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w400,
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
              )),
        ],
      ),
    );
  }
}
