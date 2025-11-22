import 'package:flutter/material.dart';
import '../widgets/announcement_card.dart';
import '../widgets/errand_job_card.dart';
import '../widgets/product_card.dart';
import '../models/product_model.dart';
import '../models/task_model.dart';
import '../services/dummy_data_service.dart';
import 'product_detail_screen.dart';
import 'task_detail_screen.dart';

class HomeFeedScreen extends StatefulWidget {
  const HomeFeedScreen({super.key});

  @override
  State<HomeFeedScreen> createState() => _HomeFeedScreenState();
}

class _HomeFeedScreenState extends State<HomeFeedScreen> {
  final DummyDataService _dataService = DummyDataService();
  
  List<Map<String, dynamic>> get _feed => _dataService.homeFeed;
  
  void _refreshFeed() {
    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey.shade100,
      body: Column(
          children: [
            // Title and Search icon row with white background
            Container(
              color: Colors.white,
              padding: const EdgeInsets.fromLTRB(20, 12, 20, 12),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    'Home',
                    style: TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.w700,
                      color: Colors.black87,
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.search, color: Color(0xFF6E6E6E), size: 26),
                    onPressed: () {
                      debugPrint('Search pressed');
                    },
                  ),
                ],
              ),
            ),
            
            // Mixed feed list
            Expanded(
              child: _feed.isEmpty
                  ? Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.home, size: 64, color: Colors.grey[400]),
                          const SizedBox(height: 16),
                          Text(
                            'No posts yet',
                            style: TextStyle(fontSize: 18, color: Colors.grey[600]),
                          ),
                        ],
                      ),
                    )
                  : Scrollbar(
                      thumbVisibility: false,
                      child: ListView.separated(
                        padding: const EdgeInsets.symmetric(vertical: 8),
                        physics: const ClampingScrollPhysics(),
                        itemCount: _feed.length,
                        separatorBuilder: (context, index) => const SizedBox(height: 0),
                        itemBuilder: (context, index) {
                          final item = _feed[index];
                          final type = item['type'] as String;
                          
                          if (type == 'announcement') {
                            return AnnouncementCard(
                              title: item['title'] as String,
                              description: item['description'] as String,
                              postedBy: item['postedBy'] as String,
                              date: item['date'] as DateTime,
                              category: item['category'] as String?,
                              unreadCount: item['unreadCount'] as int?,
                              viewCount: item['viewCount'] as int?,
                              isRead: item['isRead'] as bool? ?? false,
                              showTag: true,
                              onMarkAsReadPressed: () {
                                final announcementId = item['id'] as String?;
                                if (announcementId != null) {
                                  _dataService.markAnnouncementAsRead(announcementId);
                                  _refreshFeed();
                                }
                              },
                            );
                          } else if (type == 'request') {
                            final errandStatus = item['status'] as ErrandJobStatus?;
                            final taskId = item['id'] as String?;
                            
                            // Find the actual task from data service
                            TaskModel? task;
                            if (taskId != null) {
                              task = _dataService.tasks.firstWhere(
                                (t) => t.id == taskId,
                                orElse: () => TaskModel(
                                  id: taskId,
                                  title: item['title'] as String,
                                  description: item['description'] as String,
                                  requesterName: item['postedBy'] as String,
                                  createdAt: item['date'] as DateTime,
                                  status: _mapErrandStatusToTaskStatus(errandStatus),
                                  assignedTo: item['volunteerName'] as String?,
                                  priority: TaskPriority.medium,
                                ),
                              );
                            }
                            
                            return ErrandJobCard(
                              title: item['title'] as String,
                              description: item['description'] as String,
                              postedBy: item['postedBy'] as String,
                              date: item['date'] as DateTime,
                              status: errandStatus,
                              statusLabel: item['statusLabel'] as String?,
                              volunteerName: item['volunteerName'] as String?,
                              showTag: true,
                              onViewPressed: task != null
                                  ? () {
                                      Navigator.of(context).push(
                                        MaterialPageRoute(
                                          builder: (_) => TaskDetailScreen(
                                            task: task!,
                                            contactNumber: '09026095205',
                                          ),
                                        ),
                                      );
                                    }
                                  : null,
                              onVolunteerPressed: item['volunteerName'] == null
                                  ? () {
                                      final taskId = item['id'] as String?;
                                      if (taskId != null) {
                                        _dataService.volunteerForTask(taskId, 'You');
                                        _refreshFeed();
                                        ScaffoldMessenger.of(context).showSnackBar(
                                          const SnackBar(
                                            content: Text('You have volunteered for this task!'),
                                            duration: Duration(seconds: 2),
                                          ),
                                        );
                                      }
                                    }
                                  : null,
                            );
                          } else if (type == 'product') {
                            return ProductCard(
                              product: item['product'] as ProductModel,
                              showTag: true,
                              onInteract: () {
                                Navigator.of(context).push(
                                  MaterialPageRoute(
                                    builder: (_) => ProductDetailScreen(
                                      product: item['product'] as ProductModel,
                                    ),
                                  ),
                                );
                              },
                            );
                          }
                          return const SizedBox.shrink();
                        },
                      ),
                    ),
            ),
          ],
        ),
      );
    }

  TaskStatus _mapErrandStatusToTaskStatus(ErrandJobStatus? errandStatus) {
    if (errandStatus == null) return TaskStatus.open;
    switch (errandStatus) {
      case ErrandJobStatus.open:
        return TaskStatus.open;
      case ErrandJobStatus.ongoing:
        return TaskStatus.ongoing;
      case ErrandJobStatus.completed:
        return TaskStatus.completed;
    }
  }
}


