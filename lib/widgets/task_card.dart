import 'package:flutter/material.dart';
import '../models/task_model.dart';

class TaskCard extends StatelessWidget {
  final TaskModel task;
  final VoidCallback? onVolunteer;

  const TaskCard({
    super.key,
    required this.task,
    this.onVolunteer,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Card(
      clipBehavior: Clip.antiAlias,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Title and Status
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Text(
                    task.title,
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                _buildStatusChip(task.status),
              ],
            ),
            const SizedBox(height: 12),
            // Requester name
            Row(
              children: [
                Icon(
                  Icons.person_outline,
                  size: 18,
                  color: colorScheme.primary,
                ),
                const SizedBox(width: 4),
                Text(
                  'Requested by: ${task.requesterName}',
                  style: TextStyle(
                    fontSize: 14,
                    color: Colors.grey[700],
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            // Task details
            Text(
              task.description,
              style: TextStyle(
                fontSize: 14,
                color: Colors.grey[700],
              ),
            ),
            if (task.assignedTo != null) ...[
              const SizedBox(height: 12),
              Row(
                children: [
                  Icon(
                    Icons.check_circle_outline,
                    size: 16,
                    color: colorScheme.primary,
                  ),
                  const SizedBox(width: 4),
                  Text(
                    'Volunteered by: ${task.assignedTo}',
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.green[700],
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
            ],
            if (task.dueDate != null) ...[
              const SizedBox(height: 8),
              Row(
                children: [
                  Icon(
                    Icons.calendar_today,
                    size: 16,
                    color: Colors.grey[600],
                  ),
                  const SizedBox(width: 4),
                  Text(
                    'Due: ${_formatDate(task.dueDate!)}',
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.grey[600],
                    ),
                  ),
                ],
              ),
            ],
            // Volunteer button (only show if task is open and not assigned)
            if (task.status == TaskStatus.open && task.assignedTo == null) ...[
              const SizedBox(height: 16),
              SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  onPressed: onVolunteer,
                  icon: const Icon(Icons.volunteer_activism),
                  label: const Text('Volunteer'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: colorScheme.primary,
                    side: BorderSide(
                      color: colorScheme.primary.withValues(alpha: 0.4),
                    ),
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildStatusChip(TaskStatus status) {
    Color backgroundColor;
    Color textColor;
    String text = status.displayName;

    switch (status) {
      case TaskStatus.open:
        backgroundColor = Colors.blue.shade100;
        textColor = Colors.blue.shade800;
        break;
      case TaskStatus.ongoing:
        backgroundColor = Colors.orange.shade100;
        textColor = Colors.orange.shade800;
        break;
      case TaskStatus.completed:
        backgroundColor = Colors.green.shade100;
        textColor = Colors.green.shade800;
        break;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: backgroundColor,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Text(
        text,
        style: TextStyle(
          fontSize: 12,
          color: textColor,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }

  String _formatDate(DateTime date) {
    return '${date.day}/${date.month}/${date.year}';
  }
}
