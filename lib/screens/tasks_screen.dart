import 'package:flutter/material.dart';

import '../models/task_model.dart';
import '../widgets/errand_job_card.dart';
import '../services/tasks_service.dart';
import 'create_task_screen.dart';
import 'my_posts_screen.dart';
import 'task_detail_screen.dart';

class TasksScreen extends StatefulWidget {
  const TasksScreen({super.key});

  @override
  State<TasksScreen> createState() => TasksScreenState();
}

class TasksScreenState extends State<TasksScreen> {
  void addTask(TaskModel task) {
    // Task will be added to Firestore and stream will update automatically
  }

  void _handlePostTask() {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => CreateTaskScreen(
          onTaskCreated: (task) {
            addTask(task);
          },
        ),
      ),
    );
  }

  void _handleMyPosts() {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => const MyPostsScreen(),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF4F4F4),
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Title and Search icon row with white background
          Container(
            color: Colors.white,
            padding: const EdgeInsets.fromLTRB(20, 12, 20, 12),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'Errand/Job Post',
                  style: TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.w700,
                    color: Colors.black87,
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.search,
                      color: Color(0xFF6E6E6E), size: 26),
                  splashRadius: 22,
                  onPressed: () {},
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 12, 20, 8),
            child: Row(
              children: [
                _ActionPill(
                  label: 'Create post',
                  icon: Icons.edit_outlined,
                  backgroundColor: const Color(0xFF20BF6B),
                  foregroundColor: Colors.white,
                  onPressed: _handlePostTask,
                ),
                const SizedBox(width: 12),
                _ActionPill(
                  label: 'My post',
                  icon: Icons.inventory_2_outlined,
                  backgroundColor: const Color(0xFFE9E9E9),
                  foregroundColor: const Color(0xFF4A4A4A),
                  onPressed: _handleMyPosts,
                ),
              ],
            ),
          ),
            Expanded(
              child: StreamBuilder<List<TaskModel>>(
                stream: TasksService.getTasksStream(),
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
                            'Error loading tasks',
                            style: TextStyle(fontSize: 18, color: Colors.grey[600]),
                          ),
                        ],
                      ),
                    );
                  }

                  final tasks = snapshot.data ?? [];

                  if (tasks.isEmpty) {
                    return _EmptyState();
                  }

                  return ListView.separated(
                    padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
                    physics: const ClampingScrollPhysics(),
                    itemCount: tasks.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 16),
                    itemBuilder: (context, index) {
                      final task = tasks[index];
                      final status = _mapStatus(task.status);
                      return ErrandJobCard(
                        title: task.title,
                        description: task.description,
                        postedBy: task.requesterName,
                        date: task.createdAt,
                        status: status,
                        statusLabel: task.status.displayName,
                        volunteerName: task.assignedByName, // Use assignedByName instead of assignedTo
                        onViewPressed: () {
                          Navigator.of(context).push(
                            MaterialPageRoute(
                              builder: (_) => TaskDetailScreen(
                                task: task,
                                contactNumber: task.contactNumber ?? '',
                              ),
                            ),
                          );
                        },
                      );
                    },
                  );
                },
              ),
            ),
          ],
        ),
      );
    }

  ErrandJobStatus? _mapStatus(TaskStatus status) {
    switch (status) {
      case TaskStatus.open:
        return ErrandJobStatus.open;
      case TaskStatus.ongoing:
        return ErrandJobStatus.ongoing;
      case TaskStatus.completed:
        return ErrandJobStatus.completed;
    }
  }
}

class _ActionPill extends StatelessWidget {
  const _ActionPill({
    required this.label,
    required this.icon,
    required this.backgroundColor,
    required this.foregroundColor,
    required this.onPressed,
  });

  final String label;
  final IconData icon;
  final Color backgroundColor;
  final Color foregroundColor;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return ElevatedButton.icon(
      onPressed: onPressed,
      icon: Icon(icon, size: 16),
      label: Text(
        label,
        style: const TextStyle(
          fontSize: 13,
          fontWeight: FontWeight.w600,
        ),
      ),
      style: ElevatedButton.styleFrom(
        backgroundColor: backgroundColor,
        foregroundColor: foregroundColor,
        elevation: 0,
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        minimumSize: const Size(0, 36),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(28),
        ),
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.task_alt, size: 62, color: Colors.grey.shade400),
          const SizedBox(height: 12),
          Text(
            'No errands posted yet',
            style: TextStyle(
              fontSize: 16,
              color: Colors.grey.shade600,
            ),
          ),
        ],
      ),
    );
  }
}
