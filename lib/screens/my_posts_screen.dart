import 'package:flutter/material.dart';
import '../models/task_model.dart';
import '../services/tasks_service.dart';
import '../services/task_chat_service.dart';
import '../services/firestore_service.dart';
import '../services/notifications_service.dart';
import '../widgets/errand_job_card.dart';
import '../widgets/optimized_image.dart';
import 'task_edit_screen.dart';
import 'task_detail_screen.dart';
import 'search_screen.dart';

class MyPostsScreen extends StatefulWidget {
  const MyPostsScreen({super.key});

  @override
  State<MyPostsScreen> createState() => _MyPostsScreenState();
}

class _MyPostsScreenState extends State<MyPostsScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final currentUserId = FirestoreService.currentUserId;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    if (currentUserId == null) {
      return Scaffold(
        backgroundColor:
            isDark ? const Color(0xFF121212) : const Color(0xFFF4F4F4),
        body: SafeArea(
          child: Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.error_outline, size: 48, color: Colors.red),
                const SizedBox(height: 16),
                Text(
                  'Please log in to view your posts',
                  style: TextStyle(
                    fontSize: 16,
                    color: isDark ? Colors.grey.shade400 : Colors.grey,
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    }

    return Scaffold(
      backgroundColor:
          isDark ? const Color(0xFF121212) : const Color(0xFFF4F4F4),
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
                    icon: Icon(
                      Icons.arrow_back_ios_new,
                      size: 20,
                      color: isDark ? Colors.white : Colors.black87,
                    ),
                    onPressed: () => Navigator.of(context).pop(),
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Post Activity',
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.w700,
                        color: isDark ? Colors.white : Colors.black87,
                      ),
                    ),
                  ),
                  IconButton(
                    icon: Icon(
                      Icons.search,
                      color:
                          isDark
                              ? Colors.grey.shade400
                              : const Color(0xFF6E6E6E),
                    ),
                    splashRadius: 22,
                    onPressed: () {
                      final uid = FirestoreService.currentUserId;
                      if (uid == null) return;
                      Navigator.of(context).push(
                        MaterialPageRoute(
                          builder:
                              (_) => SearchScreen(mode: SearchMode.myTasks),
                        ),
                      );
                    },
                  ),
                ],
              ),
            ),
            // Tab Bar with badge support
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: _TabBarWithBadge(
                tabController: _tabController,
                userId: currentUserId,
              ),
            ),
            // Tab Content
            Expanded(
              child: TabBarView(
                controller: _tabController,
                children: [
                  // Tab 1: MY POSTS
                  _MyPostsTab(userId: currentUserId),
                  // Tab 2: INTERACTED POSTS (Activity Log)
                  _InteractedPostsTab(userId: currentUserId),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Tab bar with number badges on both tabs
class _TabBarWithBadge extends StatelessWidget {
  final TabController tabController;
  final String userId;

  const _TabBarWithBadge({required this.tabController, required this.userId});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<int>(
      stream: TaskChatService.getTotalUnreadForRequesterStream(userId),
      initialData: 0,
      builder: (context, requesterChatSnapshot) {
        return StreamBuilder<List<TaskModel>>(
          stream: TasksService.getRequesterTasksStream(userId),
          builder: (context, requesterTasksSnapshot) {
            final requesterChatUnread = requesterChatSnapshot.data ?? 0;
            final requesterTasks = requesterTasksSnapshot.data ?? [];
            final unreadVolunteersCount = requesterTasks.fold<int>(
              0,
              (sum, task) => sum + task.unreadVolunteersCount,
            );
            final myPostsUnread = requesterChatUnread + unreadVolunteersCount;

            return StreamBuilder<int>(
              stream: TaskChatService.getTotalUnreadForAssignedStream(userId),
              initialData: 0,
              builder: (context, assignedSnapshot) {
                return StreamBuilder<int>(
                  stream:
                      NotificationsService.getVolunteerAcceptedUnreadCountStream(
                        userId,
                      ),
                  initialData: 0,
                  builder: (context, volunteerAcceptedSnapshot) {
                    final assignedUnread = assignedSnapshot.data ?? 0;
                    final volunteerAcceptedUnread =
                        volunteerAcceptedSnapshot.data ?? 0;
                    // Interacted posts = assigned tasks chat + volunteer_accepted notifications
                    final interactedUnread =
                        assignedUnread + volunteerAcceptedUnread;
                    final isDark =
                        Theme.of(context).brightness == Brightness.dark;

                    return Container(
                      decoration: BoxDecoration(
                        color:
                            isDark
                                ? const Color(0xFF1E1E1E)
                                : Colors.grey.shade200,
                        borderRadius: BorderRadius.circular(24),
                      ),
                      child: AnimatedBuilder(
                        animation: tabController,
                        builder: (context, child) {
                          return Row(
                            children: [
                              // MY POSTS Tab with badge
                              Expanded(
                                child: _TabButton(
                                  label: 'MY POSTS',
                                  isSelected: tabController.index == 0,
                                  badgeCount:
                                      myPostsUnread > 0 ? myPostsUnread : null,
                                  onTap: () => tabController.animateTo(0),
                                ),
                              ),
                              // INTERACTED POSTS Tab with badge
                              Expanded(
                                child: _TabButton(
                                  label: 'INTERACTED POSTS',
                                  isSelected: tabController.index == 1,
                                  badgeCount:
                                      interactedUnread > 0
                                          ? interactedUnread
                                          : null,
                                  onTap: () => tabController.animateTo(1),
                                ),
                              ),
                            ],
                          );
                        },
                      ),
                    );
                  },
                );
              },
            );
          },
        );
      },
    );
  }
}

/// Individual tab button with optional badge
class _TabButton extends StatelessWidget {
  final String label;
  final bool isSelected;
  final int? badgeCount;
  final VoidCallback onTap;

  const _TabButton({
    required this.label,
    required this.isSelected,
    this.badgeCount,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 10),
        decoration: BoxDecoration(
          color:
              isSelected
                  ? (isDark ? const Color(0xFF2C2C2C) : Colors.white)
                  : Colors.transparent,
          borderRadius: BorderRadius.circular(24),
          boxShadow:
              isSelected
                  ? [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.06),
                      blurRadius: 4,
                      offset: const Offset(0, 2),
                    ),
                  ]
                  : null,
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              label,
              style: TextStyle(
                fontSize: 12,
                fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
                color:
                    isSelected
                        ? const Color(0xFF20BF6B)
                        : (isDark
                            ? Colors.grey.shade400
                            : Colors.grey.shade600),
              ),
            ),
            if (badgeCount != null && badgeCount! > 0) ...[
              const SizedBox(width: 6),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                decoration: BoxDecoration(
                  color: Colors.red,
                  borderRadius: BorderRadius.circular(10),
                ),
                constraints: const BoxConstraints(minWidth: 18, minHeight: 18),
                child: Center(
                  child: Text(
                    badgeCount! > 99 ? '99+' : badgeCount.toString(),
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 10,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

/// Tab 1: MY POSTS (existing functionality)
class _MyPostsTab extends StatelessWidget {
  final String userId;

  const _MyPostsTab({required this.userId});

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

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return StreamBuilder<List<TaskModel>>(
      stream: TasksService.getRequesterTasksStream(userId),
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
                  style: TextStyle(
                    fontSize: 16,
                    color: isDark ? Colors.grey.shade400 : Colors.grey,
                  ),
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
                    color: isDark ? Colors.grey.shade400 : Colors.grey.shade600,
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
            final unreadVolunteerCount = task.unreadVolunteersCount;
            return StreamBuilder<int>(
              stream: TaskChatService.getUnreadCountStream(task.id, userId),
              initialData: 0,
              builder: (context, chatSnap) {
                final unreadChat = chatSnap.data ?? 0;
                final totalUnread = unreadVolunteerCount + unreadChat;
                return _MyPostCard(
                  title: task.title,
                  description: task.description,
                  postedBy: task.requesterName,
                  date: task.createdAt,
                  status: status,
                  statusLabel: task.status.displayName,
                  volunteerName: task.assignedByName,
                  unreadCount: totalUnread,
                  imageUrls: task.imageUrls,
                  onViewPressed: () {
                    Navigator.of(context).push(
                      MaterialPageRoute(
                        builder:
                            (_) => TaskEditScreen(
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
        );
      },
    );
  }
}

/// Tab 2: INTERACTED POSTS (Activity Log)
class _InteractedPostsTab extends StatelessWidget {
  final String userId;

  const _InteractedPostsTab({required this.userId});

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

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return StreamBuilder<List<MapEntry<TaskModel, int>>>(
      stream: TasksService.getUserInteractedTasksStream(userId),
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
        final list = snapshot.data ?? [];
        if (list.isEmpty) {
          return Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  Icons.history_outlined,
                  size: 60,
                  color: Colors.grey.shade400,
                ),
                const SizedBox(height: 12),
                Text(
                  'No interacted posts yet',
                  style: TextStyle(
                    fontSize: 16,
                    color: isDark ? Colors.grey.shade400 : Colors.grey.shade600,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'Posts you volunteer for will appear here',
                  style: TextStyle(
                    fontSize: 14,
                    color: isDark ? Colors.grey.shade500 : Colors.grey.shade500,
                  ),
                ),
              ],
            ),
          );
        }
        return ListView.separated(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
          physics: const ClampingScrollPhysics(),
          itemCount: list.length,
          separatorBuilder: (_, __) => const SizedBox(height: 16),
          itemBuilder: (context, index) {
            final entry = list[index];
            final task = entry.key;
            final unreadCount = entry.value;
            final status = _mapStatus(task.status);
            return _InteractedPostCard(
              title: task.title,
              description: task.description,
              postedBy: task.requesterName,
              date: task.createdAt,
              status: status,
              statusLabel: task.status.displayName,
              unreadCount: unreadCount,
              imageUrls: task.imageUrls,
              onViewPressed: () {
                // Mark volunteer_accepted notification as read when viewing the task
                NotificationsService.markVolunteerAcceptedAsReadByTask(
                  userId,
                  task.id,
                );
                Navigator.of(context).push(
                  MaterialPageRoute(
                    builder:
                        (_) => TaskDetailScreen(
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
    );
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
  final int unreadCount;
  final VoidCallback? onViewPressed;
  final List<String> imageUrls;

  const _MyPostCard({
    required this.title,
    required this.description,
    required this.postedBy,
    required this.date,
    this.status,
    this.statusLabel,
    this.volunteerName,
    this.unreadCount = 0,
    this.onViewPressed,
    this.imageUrls = const [],
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      margin: EdgeInsets.zero,
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E1E1E) : Colors.white,
        borderRadius: BorderRadius.circular(18),
        boxShadow: [
          if (!isDark)
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
                  style: TextStyle(
                    fontSize: 12,
                    color:
                        isDark ? Colors.grey.shade400 : const Color(0xFF6E6E6E),
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
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                      color: isDark ? Colors.white : Colors.black87,
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
                Icon(
                  Icons.person_outline,
                  size: 14,
                  color:
                      isDark ? Colors.grey.shade400 : const Color(0xFF6E6E6E),
                ),
                const SizedBox(width: 4),
                Text(
                  'Posted by: $postedBy',
                  style: TextStyle(
                    fontSize: 12.5,
                    color:
                        isDark ? Colors.grey.shade400 : const Color(0xFF6E6E6E),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            // Image section (when imageUrls provided)
            if (imageUrls.isNotEmpty) ...[
              _MyPostCardImage(imageUrls: imageUrls),
              const SizedBox(height: 12),
            ],
            // Description
            Text(
              description,
              style: const TextStyle(
                fontSize: 13.5,
                color: Color(0xFF4C4C4C),
                height: 1.4,
              ),
              softWrap: true,
              overflow: TextOverflow.visible,
            ),
            const SizedBox(height: 14),
            // Action button: Edit (owner's post - has volunteer) or View
            if (volunteerName != null)
              SizedBox(
                width: double.infinity,
                child: OutlinedButton(
                  onPressed: onViewPressed,
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 14,
                      vertical: 10,
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(26),
                    ),
                    side: BorderSide(
                      color:
                          isDark
                              ? Colors.grey.shade700
                              : const Color(0xFFD0D0D0),
                    ),
                    backgroundColor:
                        isDark ? const Color(0xFF2C2C2C) : Colors.white,
                  ),
                  child: Stack(
                    clipBehavior: Clip.none,
                    children: [
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            Icons.edit_outlined,
                            size: 16,
                            color:
                                isDark ? Colors.white : const Color(0xFF4C4C4C),
                          ),
                          const SizedBox(width: 8),
                          Text(
                            'Edit',
                            style: TextStyle(
                              fontSize: 13,
                              color:
                                  isDark
                                      ? Colors.white
                                      : const Color(0xFF4C4C4C),
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                      if (unreadCount > 0)
                        Positioned(
                          right: -12,
                          top: -4,
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 4,
                              vertical: 1,
                            ),
                            decoration: BoxDecoration(
                              color: Colors.red,
                              borderRadius: BorderRadius.circular(8),
                            ),
                            constraints: const BoxConstraints(
                              minWidth: 16,
                              minHeight: 16,
                            ),
                            child: Center(
                              child: Text(
                                unreadCount > 99
                                    ? '99+'
                                    : unreadCount.toString(),
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 9,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
              )
            else if (onViewPressed != null)
              // View button for open posts (white with gray border)
              SizedBox(
                width: double.infinity,
                child: OutlinedButton(
                  onPressed: onViewPressed,
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 14,
                      vertical: 10,
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(26),
                    ),
                    side: BorderSide(
                      color:
                          isDark
                              ? Colors.grey.shade700
                              : const Color(0xFFD0D0D0),
                    ),
                    backgroundColor:
                        isDark ? const Color(0xFF2C2C2C) : Colors.white,
                  ),
                  child: Stack(
                    clipBehavior: Clip.none,
                    children: [
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            Icons.visibility_outlined,
                            size: 16,
                            color:
                                isDark ? Colors.white : const Color(0xFF4C4C4C),
                          ),
                          const SizedBox(width: 8),
                          Text(
                            'View',
                            style: TextStyle(
                              fontSize: 13,
                              color:
                                  isDark
                                      ? Colors.white
                                      : const Color(0xFF4C4C4C),
                            ),
                          ),
                        ],
                      ),
                      if (unreadCount > 0)
                        Positioned(
                          right: -12,
                          top: -4,
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 4,
                              vertical: 1,
                            ),
                            decoration: BoxDecoration(
                              color: Colors.red,
                              borderRadius: BorderRadius.circular(8),
                            ),
                            constraints: const BoxConstraints(
                              minWidth: 16,
                              minHeight: 16,
                            ),
                            child: Center(
                              child: Text(
                                unreadCount > 99
                                    ? '99+'
                                    : unreadCount.toString(),
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 9,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                          ),
                        ),
                    ],
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
      'December',
    ];
    return months[month - 1];
  }
}

/// Image widget for My Post cards
class _MyPostCardImage extends StatelessWidget {
  final List<String> imageUrls;

  const _MyPostCardImage({required this.imageUrls});

  @override
  Widget build(BuildContext context) {
    if (imageUrls.isEmpty) {
      return const SizedBox.shrink();
    }
    if (imageUrls.length == 1) {
      return ClipRRect(
        borderRadius: BorderRadius.circular(12),
        child: AspectRatio(
          aspectRatio: 16 / 9,
          child: OptimizedNetworkImage(
            imageUrl: imageUrls.first,
            fit: BoxFit.cover,
            cacheWidth: 800,
            cacheHeight: 450,
            borderRadius: BorderRadius.circular(12),
            onTap:
                () => openFullScreenImages(context, imageUrls, initialIndex: 0),
          ),
        ),
      );
    }
    return ClipRRect(
      borderRadius: BorderRadius.circular(12),
      child: AspectRatio(
        aspectRatio: 16 / 9,
        child: PageView.builder(
          itemCount: imageUrls.length,
          itemBuilder: (context, index) {
            return GestureDetector(
              onTap:
                  () => openFullScreenImages(
                    context,
                    imageUrls,
                    initialIndex: index,
                  ),
              child: OptimizedNetworkImage(
                imageUrl: imageUrls[index],
                fit: BoxFit.cover,
                cacheWidth: 800,
                cacheHeight: 450,
                borderRadius: BorderRadius.circular(12),
              ),
            );
          },
        ),
      ),
    );
  }
}

/// Card for INTERACTED POSTS tab
class _InteractedPostCard extends StatelessWidget {
  final String title;
  final String description;
  final String postedBy;
  final DateTime date;
  final ErrandJobStatus? status;
  final String? statusLabel;
  final int unreadCount;
  final VoidCallback? onViewPressed;
  final List<String> imageUrls;

  const _InteractedPostCard({
    required this.title,
    required this.description,
    required this.postedBy,
    required this.date,
    this.status,
    this.statusLabel,
    this.unreadCount = 0,
    this.onViewPressed,
    this.imageUrls = const [],
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      margin: EdgeInsets.zero,
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E1E1E) : Colors.white,
        borderRadius: BorderRadius.circular(18),
        boxShadow: [
          if (!isDark)
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
            // Date and status in top right
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                Text(
                  _formatDate(date),
                  style: TextStyle(
                    fontSize: 12,
                    color:
                        isDark ? Colors.grey.shade400 : const Color(0xFF6E6E6E),
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
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                      color: isDark ? Colors.white : Colors.black87,
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
                Icon(
                  Icons.person_outline,
                  size: 14,
                  color:
                      isDark ? Colors.grey.shade400 : const Color(0xFF6E6E6E),
                ),
                const SizedBox(width: 4),
                Text(
                  'Posted by: $postedBy',
                  style: TextStyle(
                    fontSize: 12.5,
                    color:
                        isDark ? Colors.grey.shade400 : const Color(0xFF6E6E6E),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            // Image section (when imageUrls provided)
            if (imageUrls.isNotEmpty) ...[
              _MyPostCardImage(imageUrls: imageUrls),
              const SizedBox(height: 12),
            ],
            // Description
            Text(
              description,
              style: TextStyle(
                fontSize: 13.5,
                color: isDark ? Colors.grey.shade300 : const Color(0xFF4C4C4C),
                height: 1.4,
              ),
              softWrap: true,
              overflow: TextOverflow.visible,
            ),
            const SizedBox(height: 14),
            // View button with badge inside
            SizedBox(
              width: double.infinity,
              child: OutlinedButton(
                onPressed: onViewPressed,
                style: OutlinedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 10,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(26),
                  ),
                  side: BorderSide(
                    color:
                        isDark ? Colors.grey.shade700 : const Color(0xFFD0D0D0),
                  ),
                  backgroundColor:
                      isDark ? const Color(0xFF2C2C2C) : Colors.white,
                ),
                child: Stack(
                  clipBehavior: Clip.none,
                  children: [
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.visibility_outlined,
                          size: 16,
                          color:
                              isDark ? Colors.white : const Color(0xFF4C4C4C),
                        ),
                        const SizedBox(width: 8),
                        Text(
                          'View',
                          style: TextStyle(
                            fontSize: 13,
                            color:
                                isDark ? Colors.white : const Color(0xFF4C4C4C),
                          ),
                        ),
                      ],
                    ),
                    if (unreadCount > 0)
                      Positioned(
                        right: -12,
                        top: -4,
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 4,
                            vertical: 1,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.red,
                            borderRadius: BorderRadius.circular(8),
                          ),
                          constraints: const BoxConstraints(
                            minWidth: 16,
                            minHeight: 16,
                          ),
                          child: Center(
                            child: Text(
                              unreadCount > 99 ? '99+' : unreadCount.toString(),
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 9,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                        ),
                      ),
                  ],
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
      'December',
    ];
    return months[month - 1];
  }
}
