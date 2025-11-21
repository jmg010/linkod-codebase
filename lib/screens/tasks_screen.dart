import 'package:flutter/material.dart';
import '../models/task_model.dart';
import '../widgets/errand_job_card.dart';

class TasksScreen extends StatefulWidget {
  const TasksScreen({super.key});

  @override
  State<TasksScreen> createState() => TasksScreenState();
}

class TasksScreenState extends State<TasksScreen> {
  final List<TaskModel> _tasks = [
    TaskModel(
      id: '1',
      title: 'Need help carrying rice sacks',
      description:
          'I need help carrying 10 sacks of rice from the truck to my storage. The truck will arrive tomorrow morning at 8 AM. Looking for 2-3 strong volunteers.',
      requesterName: 'Maria Santos',
      createdAt: DateTime.now().subtract(const Duration(hours: 3)),
      status: TaskStatus.open,
      priority: TaskPriority.medium,
    ),
    TaskModel(
      id: '2',
      title: 'Looking for tutor',
      description:
          'My daughter needs help with Math and Science subjects. Grade 6 level. Looking for someone who can tutor 2-3 times a week in the afternoon.',
      requesterName: 'Juan Dela Cruz',
      createdAt: DateTime.now().subtract(const Duration(days: 1)),
      status: TaskStatus.ongoing,
      assignedTo: 'Ana Garcia',
      priority: TaskPriority.high,
    ),
    TaskModel(
      id: '3',
      title: 'Help with garden cleanup',
      description:
          'Need help cleaning up my backyard garden. There are fallen branches and overgrown plants. Will provide snacks and refreshments!',
      requesterName: 'Lola Rosa',
      createdAt: DateTime.now().subtract(const Duration(days: 2)),
      status: TaskStatus.open,
      priority: TaskPriority.low,
    ),
    TaskModel(
      id: '4',
      title: 'Need someone to fix leaky roof',
      description:
          'My roof has a leak and I need someone who knows basic roofing repair. Materials will be provided. Urgent!',
      requesterName: 'Pedro Martinez',
      createdAt: DateTime.now().subtract(const Duration(days: 3)),
      status: TaskStatus.ongoing,
      assignedTo: 'Carlos Reyes',
      priority: TaskPriority.urgent,
    ),
    TaskModel(
      id: '5',
      title: 'Looking for someone to walk my dog',
      description:
          'I need someone to walk my dog in the morning (7-8 AM) while I\'m at work. Dog is friendly and well-behaved. Willing to pay for the service.',
      requesterName: 'Sofia Torres',
      createdAt: DateTime.now().subtract(const Duration(days: 4)),
      status: TaskStatus.completed,
      assignedTo: 'Miguel Lopez',
      priority: TaskPriority.medium,
    ),
    TaskModel(
      id: '6',
      title: 'Need help moving furniture',
      description:
          'Moving to a new house next week. Need help moving heavy furniture. Will provide lunch and transportation.',
      requesterName: 'Roberto Cruz',
      createdAt: DateTime.now().subtract(const Duration(days: 5)),
      status: TaskStatus.open,
      priority: TaskPriority.medium,
    ),
    TaskModel(
      id: '7',
      title: 'Looking for cooking lessons',
      description:
          'Want to learn how to cook traditional Filipino dishes. Looking for someone who can teach me on weekends.',
      requesterName: 'Elena Fernandez',
      createdAt: DateTime.now().subtract(const Duration(days: 6)),
      status: TaskStatus.open,
      priority: TaskPriority.low,
    ),
  ];

  void addTask(TaskModel task) {
    setState(() {
      _tasks.insert(0, task); // Add to the top of the list
    });
  }

  void _handleVolunteer(TaskModel task) {
    // Dummy volunteer action
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('You volunteered for: ${task.title}'),
        duration: const Duration(seconds: 2),
      ),
    );
  }

  void _handlePostTask() {
    // Dummy post task action
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Post Task feature coming soon!'),
        duration: Duration(seconds: 2),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey.shade100,
      appBar: AppBar(
        automaticallyImplyLeading: false,
        elevation: 0,
        backgroundColor: Colors.white,
        title: const Text(
          'Errand/Job Post',
          style: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.bold,
            color: Colors.black87,
          ),
        ),
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 12),
            child: Row(
              children: [
                _PillButton(
                  label: 'Create post',
                  icon: Icons.edit,
                  color: const Color(0xFF20BF6B),
                  foreground: Colors.white,
                  onPressed: _handlePostTask,
                ),
                const SizedBox(width: 12),
                _PillButton(
                  label: 'My post',
                  icon: Icons.inventory_2,
                  color: Colors.grey.shade200,
                  foreground: Colors.black87,
                  onPressed: () {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('My posts coming soon!')),
                    );
                  },
                ),
              ],
            ),
          ),
          Expanded(
            child: _tasks.isEmpty
                ? Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.task_alt, size: 64, color: Colors.grey[400]),
                        const SizedBox(height: 16),
                        Text(
                          'No tasks available',
                          style: TextStyle(fontSize: 18, color: Colors.grey[600]),
                        ),
                      ],
                    ),
                  )
                : Scrollbar(
                    thumbVisibility: false,
                    child: ListView.builder(
                      itemCount: _tasks.length,
                      padding: const EdgeInsets.symmetric(vertical: 8),
                      itemBuilder: (context, index) {
                        final task = _tasks[index];
                        ErrandJobStatus? status;
                        if (task.status == TaskStatus.open) {
                          status = ErrandJobStatus.open;
                        } else if (task.status == TaskStatus.ongoing) {
                          status = ErrandJobStatus.ongoing;
                        } else if (task.status == TaskStatus.completed) {
                          status = ErrandJobStatus.completed;
                        }
                        
                        return ErrandJobCard(
                          title: task.title,
                          description: task.description,
                          postedBy: task.requesterName,
                          date: task.createdAt,
                          status: status,
                          statusLabel: task.status.displayName,
                          volunteerName: task.assignedTo,
                          onViewPressed: () {
                            debugPrint('View task: ${task.title}');
                          },
                          onVolunteerPressed: task.status == TaskStatus.open && task.assignedTo == null
                              ? () => _handleVolunteer(task)
                              : null,
                        );
                      },
                    ),
                  ),
          ),
        ],
      ),
    );
  }
}

class _PillButton extends StatelessWidget {
  final String label;
  final IconData icon;
  final Color color;
  final Color foreground;
  final VoidCallback onPressed;

  const _PillButton({
    required this.label,
    required this.icon,
    required this.color,
    required this.foreground,
    required this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    return FilledButton.icon(
      onPressed: onPressed,
      icon: Icon(icon, size: 18),
      label: Text(label),
      style: FilledButton.styleFrom(
        backgroundColor: color,
        foregroundColor: foreground,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(24),
        ),
        elevation: 0,
      ),
    );
  }
}
