import 'package:flutter/material.dart';

import '../models/task_model.dart';
import '../widgets/errand_job_card.dart';
import 'create_task_screen.dart';
import 'my_posts_screen.dart';
import 'task_detail_screen.dart';

class TasksScreen extends StatefulWidget {
  const TasksScreen({super.key});

  @override
  State<TasksScreen> createState() => TasksScreenState();
}

class TasksScreenState extends State<TasksScreen> {
  final List<TaskModel> _tasks = [
    TaskModel(
      id: '1',
      title: 'Kinahanglan og mo alsag bugas',
      description:
          'I need help carrying 10 sacks of rice from the truck to my storage. The truck will arrive tomorrow morning at 8 AM. Looking for 2-3 strong volunteers.',
      requesterName: 'Maria Santos',
      createdAt: DateTime(2025, 11, 24, 16, 50),
      status: TaskStatus.open,
      priority: TaskPriority.medium,
    ),
    TaskModel(
      id: '2',
      title: 'Hanap kog maka tutor sakong anak',
      description:
          'My daughter needs help with Math and Science subjects. Grade 6 level. Looking for someone who can tutor 2-3 times a week in the afternoon.',
      requesterName: 'Jason Kurada',
      createdAt: DateTime(2025, 11, 24, 16, 50),
      status: TaskStatus.ongoing,
      assignedTo: 'Ana Garcia',
      priority: TaskPriority.high,
    ),
    TaskModel(
      id: '3',
      title: 'Kinahanglan kog manlilugay',
      description:
          'Kinahanglan ko manglimpyo kay mag padag akoa, kinahanglan ko 3 ka tao.',
      requesterName: 'Maria Otakan',
      createdAt: DateTime(2025, 11, 24, 16, 50),
      status: TaskStatus.completed,
      assignedTo: 'Barangay Youth',
      priority: TaskPriority.low,
    ),
    // Juan Dela Cruz's posts for "My post" screen
    TaskModel(
      id: '4',
      title: 'Magpa buak og lugit ng lubi',
      description:
          'Nanginahanglan kog 1 ka tao na mo buak, og 3 ka taon na mo lugit. Karong sabado ko magpa trabaho',
      requesterName: 'Juan Dela Cruz',
      createdAt: DateTime(2025, 11, 24, 16, 50),
      status: TaskStatus.open,
      priority: TaskPriority.medium,
    ),
    TaskModel(
      id: '5',
      title: 'Hanap kog maka Dag ug niyug',
      description:
          'Magpakopras ko karung Sabado, need nako og 3 ka menadadag.',
      requesterName: 'Juan Dela Cruz',
      createdAt: DateTime(2025, 11, 24, 16, 50),
      status: TaskStatus.ongoing,
      assignedTo: 'Ana Garcia',
      priority: TaskPriority.medium,
    ),
    TaskModel(
      id: '6',
      title: 'Nag hanap kog mo garas',
      description:
          'Nag hanap kog mo garas sa bukid, libri kaon. Pacquiao akong gusto.',
      requesterName: 'Juan Dela Cruz',
      createdAt: DateTime(2025, 11, 24, 16, 50),
      status: TaskStatus.completed,
      assignedTo: 'Clinch Lansaderas',
      priority: TaskPriority.low,
    ),
  ];

  void addTask(TaskModel task) {
    setState(() {
      _tasks.insert(0, task);
    });
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
        builder: (_) => MyPostsScreen(
          allTasks: _tasks,
          currentUserName: 'Juan Dela Cruz',
        ),
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
              child: _tasks.isEmpty
                  ? _EmptyState()
                  : ListView.separated(
                      padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
                      physics: const ClampingScrollPhysics(),
                      itemCount: _tasks.length,
                      separatorBuilder: (_, __) => const SizedBox(height: 16),
                      itemBuilder: (context, index) {
                        final task = _tasks[index];
                        final status = _mapStatus(task.status);
                        return ErrandJobCard(
                          title: task.title,
                          description: task.description,
                          postedBy: task.requesterName,
                          date: task.createdAt,
                          status: status,
                          statusLabel: task.status.displayName,
                          volunteerName: task.assignedTo,
                          onViewPressed: () {
                            Navigator.of(context).push(
                              MaterialPageRoute(
                                builder: (_) => TaskDetailScreen(
                                  task: task,
                                  contactNumber: '09026095205',
                                ),
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
