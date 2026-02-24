import 'package:flutter/material.dart';

import '../models/task_model.dart';
import '../widgets/errand_job_card.dart';
import '../services/tasks_service.dart';
import '../services/firestore_service.dart';
import 'create_task_screen.dart';
import 'my_posts_screen.dart';
import 'task_detail_screen.dart';
import 'task_edit_screen.dart';
import 'search_screen.dart';

class TasksScreen extends StatefulWidget {
  const TasksScreen({super.key});

  @override
  State<TasksScreen> createState() => TasksScreenState();
}

class TasksScreenState extends State<TasksScreen> {
  static const String _filterAll = 'All';
  static const List<String> _taskCategories = [
    'General',
    'Labor',
    'Tutoring',
    'Transportation',
    'Home Repair',
    'Other',
  ];
  List<String> get _categoryFilters => [_filterAll, ..._taskCategories];
  String _selectedFilter = _filterAll;

  static const int _initialPageSize = 15;
  static const int _loadMorePageSize = 15;
  int _displayCount = _initialPageSize;
  int _totalTaskCount = 0;
  final ScrollController _scrollController = ScrollController();
  String? _cachedMyPostUid;
  Stream<int>? _cachedMyPostStream;

  List<TaskModel> _filterByCategory(List<TaskModel> tasks) {
    if (_selectedFilter == _filterAll) return tasks;
    return tasks.where((t) => (t.category ?? 'General') == _selectedFilter).toList();
  }

  void addTask(TaskModel task) {
    // Task will be added to Firestore and stream will update automatically
  }

  static bool _isFromToday(DateTime? date) {
    if (date == null) return false;
    final now = DateTime.now();
    return date.year == now.year && date.month == now.month && date.day == now.day;
  }

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_onScroll);
  }

  @override
  void dispose() {
    _scrollController.removeListener(_onScroll);
    _scrollController.dispose();
    super.dispose();
  }

  void _onScroll() {
    final maxScroll = _scrollController.position.maxScrollExtent;
    final currentScroll = _scrollController.position.pixels;
    if (maxScroll - currentScroll < 200) _loadMoreIfNeeded();
  }

  void _loadMoreIfNeeded() {
    if (_displayCount >= _totalTaskCount) return;
    setState(() {
      _displayCount = (_displayCount + _loadMorePageSize).clamp(0, _totalTaskCount);
    });
  }

  Future<void> _showCategoryPicker() async {
    final selected = await showModalBottomSheet<String>(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(18)),
      ),
      builder: (ctx) {
        final items = _categoryFilters;
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 16, 20, 12),
                child: Row(
                  children: [
                    const Icon(Icons.category_outlined, size: 20, color: Color(0xFF30383F)),
                    const SizedBox(width: 8),
                    const Text(
                      'Change Category',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                        color: Colors.black87,
                      ),
                    ),
                  ],
                ),
              ),
              const Divider(height: 1),
              SizedBox(
                height: 380,
                child: ListView.builder(
                  itemCount: items.length,
                  itemBuilder: (context, index) {
                    final cat = items[index];
                    final isSelected = cat == _selectedFilter;
                    return ListTile(
                      title: Text(
                        cat == _filterAll ? 'All categories' : cat,
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: isSelected ? FontWeight.w600 : FontWeight.w400,
                          color: isSelected ? const Color(0xFF20BF6B) : Colors.black87,
                        ),
                      ),
                      onTap: () => Navigator.of(context).pop(cat),
                    );
                  },
                ),
              ),
            ],
          ),
        );
      },
    );

    if (selected != null && selected != _selectedFilter) {
      setState(() {
        _selectedFilter = selected;
        _displayCount = _initialPageSize;
      });
    }
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

  static Stream<int> _ownerPendingVolunteersCountStream(String? uid) {
    if (uid == null) return Stream<int>.value(0);
    return TasksService.getRequesterTasksStream(uid).asyncMap((tasks) async {
      try {
        int total = 0;
        for (final t in tasks) {
          final list = await TasksService.getVolunteersStream(t.id).first;
          total += list.where((v) => (v['status'] as String? ?? 'pending') == 'pending').length;
        }
        return total;
      } catch (_) {
        return 0;
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final currentUserId = FirestoreService.currentUserId;
    if (_cachedMyPostUid != currentUserId) {
      _cachedMyPostUid = currentUserId;
      _cachedMyPostStream = _ownerPendingVolunteersCountStream(currentUserId);
    }
    final myPostStream = _cachedMyPostStream ?? Stream<int>.value(0);

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
                  onPressed: () {
                    Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (_) => const SearchScreen(mode: SearchMode.tasks),
                      ),
                    );
                  },
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 8, 20, 8),
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
                StreamBuilder<int>(
                  stream: myPostStream,
                  initialData: 0,
                  builder: (context, snap) {
                    final hasNotification = (snap.data ?? 0) > 0;
                    return Stack(
                      clipBehavior: Clip.none,
                      children: [
                        _ActionPill(
                          label: 'My post',
                          icon: Icons.inventory_2_outlined,
                          backgroundColor: const Color(0xFFE9E9E9),
                          foregroundColor: const Color(0xFF4A4A4A),
                          onPressed: _handleMyPosts,
                        ),
                        if (hasNotification)
                          Positioned(
                            right: -2,
                            top: -2,
                            child: Container(
                              width: 10,
                              height: 10,
                              decoration: const BoxDecoration(
                                color: Colors.red,
                                shape: BoxShape.circle,
                              ),
                            ),
                          ),
                      ],
                    );
                  },
                ),
                const SizedBox(width: 12),
                Flexible(
                  child: _ActionPill(
                    label: _selectedFilter == _filterAll ? 'Categories' : _selectedFilter,
                    icon: Icons.category_outlined,
                    backgroundColor: const Color(0xFFE9E9E9),
                    foregroundColor: const Color(0xFF4A4A4A),
                    onPressed: _showCategoryPicker,
                  ),
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

                  final allFromStream = snapshot.data ?? [];
                  final nonCompleted = allFromStream.where((t) => t.status != TaskStatus.completed).toList();
                  // Exclude owner's posts from feed; owner sees their tasks only in My Post
                  final feedTasks = currentUserId != null
                      ? nonCompleted.where((t) => t.requesterId != currentUserId).toList()
                      : nonCompleted;
                  final allTasks = _filterByCategory(feedTasks);
                  final today = DateTime(DateTime.now().year, DateTime.now().month, DateTime.now().day);
                  final todayTasks = allTasks.where((t) {
                    final d = t.createdAt;
                    return d.year == today.year && d.month == today.month && d.day == today.day;
                  }).toList();
                  final restTasks = allTasks.where((t) => !_isFromToday(t.createdAt)).toList();
                  final orderedTasks = [...todayTasks, ...restTasks];
                  _totalTaskCount = orderedTasks.length;

                  if (orderedTasks.isEmpty) {
                    return _EmptyState();
                  }

                  final visibleCount = _displayCount.clamp(0, orderedTasks.length);
                  final showLoadMore = visibleCount < orderedTasks.length;
                  final hasNewListing = todayTasks.isNotEmpty;
                  final visibleRestCount = (visibleCount - todayTasks.length).clamp(0, restTasks.length);

                  return ListView.builder(
                    controller: _scrollController,
                    padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
                    physics: const ClampingScrollPhysics(),
                    itemCount: 2 + visibleRestCount + (showLoadMore ? 1 : 0),
                    itemBuilder: (context, index) {
                      if (index == 0) {
                        return Container(
                          margin: const EdgeInsets.only(bottom: 16),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: const Color(0xFF00A651).withOpacity(0.4), width: 1.5),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withOpacity(0.06),
                                blurRadius: 8,
                                offset: const Offset(0, 2),
                              ),
                            ],
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Padding(
                                padding: const EdgeInsets.fromLTRB(16, 14, 16, 12),
                                child: Text(
                                  'New Listing',
                                  style: TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.w600,
                                    color: const Color(0xFF00A651),
                                  ),
                                ),
                              ),
                              if (todayTasks.isEmpty)
                                const Padding(
                                  padding: EdgeInsets.fromLTRB(16, 0, 16, 12),
                                  child: Text('No new postings today.', style: TextStyle(fontSize: 14, color: Colors.black54)),
                                )
                              else
                                ...todayTasks.map((task) => Padding(
                                  padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
                                  child: ErrandJobCard(
                                    title: task.title,
                                    description: task.description,
                                    postedBy: task.requesterName,
                                    date: task.createdAt,
                                    status: _mapStatus(task.status)!,
                                    statusLabel: task.status.displayName,
                                    volunteerName: task.assignedByName,
                                    viewButtonLabel: (currentUserId != null && task.requesterId == currentUserId)
                                        ? 'Edit'
                                        : 'View',
                                    viewButtonIcon: (currentUserId != null && task.requesterId == currentUserId)
                                        ? Icons.edit_outlined
                                        : Icons.visibility_outlined,
                                    onViewPressed: () {
                                      final isOwner = currentUserId != null && task.requesterId == currentUserId;
                                      Navigator.of(context).push(
                                        MaterialPageRoute(
                                          builder: (_) => isOwner
                                              ? TaskEditScreen(
                                                  task: task,
                                                  contactNumber: task.contactNumber ?? '',
                                                )
                                              : TaskDetailScreen(
                                                  task: task,
                                                  contactNumber: task.contactNumber ?? '',
                                                ),
                                        ),
                                      );
                                    },
                                  ),
                                )),
                            ],
                          ),
                        );
                      }
                      if (index == 1) {
                        return Padding(
                          padding: const EdgeInsets.fromLTRB(0, 4, 0, 12),
                          child: Text(
                            'Older',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                              color: Colors.grey.shade700,
                            ),
                          ),
                        );
                      }
                      if (showLoadMore && index == 2 + visibleRestCount) {
                        return Padding(
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          child: Center(
                            child: GestureDetector(
                              onTap: _loadMoreIfNeeded,
                              child: Text(
                                'Load more',
                                style: TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w600,
                                  color: const Color(0xFF00A651),
                                ),
                              ),
                            ),
                          ),
                        );
                      }
                      final task = restTasks[index - 2];
                      final status = _mapStatus(task.status);
                      return Padding(
                        padding: EdgeInsets.only(
                          bottom: index - 2 < visibleRestCount - 1 ? 16 : 0,
                        ),
                        child: ErrandJobCard(
                          title: task.title,
                          description: task.description,
                          postedBy: task.requesterName,
                          date: task.createdAt,
                          status: status!,
                          statusLabel: task.status.displayName,
                          volunteerName: task.assignedByName,
                          viewButtonLabel: (currentUserId != null && task.requesterId == currentUserId)
                              ? 'Edit'
                              : 'View',
                          viewButtonIcon: (currentUserId != null && task.requesterId == currentUserId)
                              ? Icons.edit_outlined
                              : Icons.visibility_outlined,
                          onViewPressed: () {
                            final isOwner = currentUserId != null && task.requesterId == currentUserId;
                            Navigator.of(context).push(
                              MaterialPageRoute(
                                builder: (_) => isOwner
                                    ? TaskEditScreen(
                                        task: task,
                                        contactNumber: task.contactNumber ?? '',
                                      )
                                    : TaskDetailScreen(
                                        task: task,
                                        contactNumber: task.contactNumber ?? '',
                                      ),
                              ),
                            );
                          },
                        ),
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
        overflow: TextOverflow.ellipsis,
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
