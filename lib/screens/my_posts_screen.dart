import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/task_model.dart';
import '../services/tasks_service.dart';
import '../services/firestore_service.dart';
import '../widgets/errand_job_card.dart';
import 'task_edit_screen.dart';

class MyPostsScreen extends StatefulWidget {
  const MyPostsScreen({super.key});

  @override
  State<MyPostsScreen> createState() => _MyPostsScreenState();
}

class _MyPostsScreenState extends State<MyPostsScreen> {
  String? _currentUserName;
  bool _isLoadingUser = true;

  @override
  void initState() {
    super.initState();
    _loadCurrentUser();
  }

  Future<void> _loadCurrentUser() async {
    final currentUser = FirestoreService.auth.currentUser;
    if (currentUser == null) {
      setState(() {
        _isLoadingUser = false;
      });
      return;
    }

    try {
      final userDoc = await FirestoreService.instance
          .collection('users')
          .doc(currentUser.uid)
          .get();
      
      if (userDoc.exists) {
        final data = userDoc.data();
        setState(() {
          _currentUserName = data?['fullName'] as String? ?? 'User';
          _isLoadingUser = false;
        });
      } else {
        setState(() {
          _currentUserName = 'User';
          _isLoadingUser = false;
        });
      }
    } catch (e) {
      debugPrint('Error loading user: $e');
      setState(() {
        _currentUserName = 'User';
        _isLoadingUser = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final currentUserId = FirestoreService.currentUserId;
    
    if (currentUserId == null) {
      return Scaffold(
        backgroundColor: const Color(0xFFF4F4F4),
        body: SafeArea(
          child: Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.error_outline, size: 48, color: Colors.red),
                const SizedBox(height: 16),
                const Text(
                  'Please log in to view your posts',
                  style: TextStyle(fontSize: 16, color: Colors.grey),
                ),
              ],
            ),
          ),
        ),
      );
    }

    if (_isLoadingUser) {
      return Scaffold(
        backgroundColor: const Color(0xFFF4F4F4),
        body: const SafeArea(
          child: Center(child: CircularProgressIndicator()),
        ),
      );
    }

    return Scaffold(
      backgroundColor: const Color(0xFFF4F4F4),
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header with back button, title, and search icon
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
              child: Row(
                children: [
                  IconButton(
                    icon: const Icon(Icons.arrow_back_ios_new, size: 20),
                    onPressed: () => Navigator.of(context).pop(),
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(),
                  ),
                  const SizedBox(width: 8),
                  const Expanded(
                    child: Text(
                      'My post',
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.w700,
                        color: Colors.black87,
                      ),
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.search, color: Color(0xFF6E6E6E)),
                    splashRadius: 22,
                    onPressed: () {},
                  ),
                ],
              ),
            ),
            // Posts list
            Expanded(
              child: StreamBuilder<List<TaskModel>>(
                stream: TasksService.getRequesterTasksStream(currentUserId),
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return const Center(child: CircularProgressIndicator());
                  }
                  if (snapshot.hasError) {
                    return Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Icon(Icons.error_outline, size: 48, color: Colors.red),
                          const SizedBox(height: 16),
                          Text(
                            'Error: ${snapshot.error}',
                            style: const TextStyle(fontSize: 16, color: Colors.grey),
                          ),
                        ],
                      ),
                    );
                  }
                  final tasks = snapshot.data ?? [];
                  if (tasks.isEmpty) {
                    return Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.task_alt, size: 62, color: Colors.grey.shade400),
                          const SizedBox(height: 12),
                          Text(
                            'No posts yet',
                            style: TextStyle(
                              fontSize: 16,
                              color: Colors.grey.shade600,
                            ),
                          ),
                        ],
                      ),
                    );
                  }
                  return ListView.separated(
                    padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
                    physics: const ClampingScrollPhysics(),
                    itemCount: tasks.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 16),
                    itemBuilder: (context, index) {
                      final task = tasks[index];
                      final status = _mapStatus(task.status);
                      return _MyPostCard(
                        title: task.title,
                        description: task.description,
                        postedBy: task.requesterName,
                        date: task.createdAt,
                        status: status,
                        statusLabel: task.status.displayName,
                        volunteerName: task.assignedByName,
                        onViewPressed: () {
                          Navigator.of(context).push(
                            MaterialPageRoute(
                              builder: (_) => TaskEditScreen(
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

class _MyPostCard extends StatelessWidget {
  final String title;
  final String description;
  final String postedBy;
  final DateTime date;
  final ErrandJobStatus? status;
  final String? statusLabel;
  final String? volunteerName;
  final VoidCallback? onViewPressed;

  const _MyPostCard({
    required this.title,
    required this.description,
    required this.postedBy,
    required this.date,
    this.status,
    this.statusLabel,
    this.volunteerName,
    this.onViewPressed,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: EdgeInsets.zero,
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
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 14, 16, 16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Date and status in top right (for Ongoing/Completed) or just date (for Open)
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                Text(
                  _formatDate(date),
                  style: const TextStyle(
                    fontSize: 12,
                    color: Color(0xFF6E6E6E),
                  ),
                ),
                if (status != null && status != ErrandJobStatus.open) ...[
                  const SizedBox(width: 8),
                  _buildStatusPill(status!, statusLabel),
                ],
              ],
            ),
            const SizedBox(height: 10),
            // Title and status tag in same row (for Open status)
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Text(
                    title,
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                      color: Colors.black87,
                      height: 1.25,
                    ),
                  ),
                ),
                if (status == ErrandJobStatus.open) ...[
                  const SizedBox(width: 8),
                  _buildStatusPill(status!, statusLabel),
                ],
              ],
            ),
            const SizedBox(height: 8),
            // Posted by
            Row(
              children: [
                const Icon(
                  Icons.person_outline,
                  size: 14,
                  color: Color(0xFF6E6E6E),
                ),
                const SizedBox(width: 4),
                Text(
                  'Posted by: $postedBy',
                  style: const TextStyle(
                    fontSize: 12.5,
                    color: Color(0xFF6E6E6E),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            // Description
            Text(
              description,
              style: const TextStyle(
                fontSize: 13.5,
                color: Color(0xFF4C4C4C),
                height: 1.4,
              ),
            ),
            const SizedBox(height: 14),
            // Action button or volunteer status
            if (volunteerName != null)
              // Volunteer button (full width, centered)
              SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  onPressed: null,
                  icon: const Icon(
                    Icons.check_circle_outline,
                    size: 16,
                    color: Color(0xFF20BF6B),
                  ),
                  label: Text(
                    'Volunteered by: $volunteerName',
                    style: const TextStyle(
                      fontSize: 13,
                      color: Color(0xFF20BF6B),
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(26),
                    ),
                    side: const BorderSide(color: Color(0xFFD0D0D0)),
                    backgroundColor: Colors.white,
                    foregroundColor: const Color(0xFF20BF6B),
                    disabledBackgroundColor: Colors.white,
                    disabledForegroundColor: const Color(0xFF20BF6B),
                  ),
                ),
              )
            else if (onViewPressed != null)
              // View button for open posts (white with gray border)
              SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  onPressed: onViewPressed,
                  icon: const Icon(
                    Icons.visibility_outlined,
                    size: 16,
                    color: Color(0xFF4C4C4C),
                  ),
                  label: const Text(
                    'View',
                    style: TextStyle(
                      fontSize: 13,
                      color: Color(0xFF4C4C4C),
                    ),
                  ),
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(26),
                    ),
                    side: const BorderSide(color: Color(0xFFD0D0D0)),
                    backgroundColor: Colors.white,
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatusPill(ErrandJobStatus status, String? label) {
    late Color bgColor;
    late Color textColor;
    final raw = (label ?? status.name);
    final displayText =
        raw.isEmpty ? raw : '${raw[0].toUpperCase()}${raw.substring(1)}';

    switch (status) {
      case ErrandJobStatus.open:
        bgColor = const Color(0xFFE3F2FD);
        textColor = const Color(0xFF1976D2);
        break;
      case ErrandJobStatus.ongoing:
        bgColor = const Color(0xFFFFF3E0);
        textColor = const Color(0xFFF57C00);
        break;
      case ErrandJobStatus.completed:
        bgColor = const Color(0xFFE8F5E9);
        textColor = const Color(0xFF388E3C);
        break;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(18),
      ),
      child: Text(
        displayText,
        style: TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w600,
          color: textColor,
        ),
      ),
    );
  }

  String _formatDate(DateTime date) {
    final month = _monthName(date.month);
    final hour = date.hour % 12 == 0 ? 12 : date.hour % 12;
    final minute = date.minute.toString().padLeft(2, '0');
    final period = date.hour >= 12 ? 'PM' : 'AM';
    return '$month ${date.day} at $hour:$minute $period';
  }

  String _monthName(int month) {
    const months = [
      'January',
      'February',
      'March',
      'April',
      'May',
      'June',
      'July',
      'August',
      'September',
      'October',
      'November',
      'December'
    ];
    return months[month - 1];
  }
}

