import 'package:flutter/material.dart';
import '../models/task_model.dart';

class TaskDetailScreen extends StatefulWidget {
  final TaskModel task;
  final String? contactNumber;

  const TaskDetailScreen({
    super.key,
    required this.task,
    this.contactNumber,
  });

  @override
  State<TaskDetailScreen> createState() => _TaskDetailScreenState();
}

class _TaskDetailScreenState extends State<TaskDetailScreen> {
  final List<String> _volunteers = [
    'Regine Mae Lagura',
    'Clinch James Lansaderas',
    'Andrew James Benuaflor',
    'Eugene Dave Festejo',
  ];

  void _handleVolunteer() {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('You have volunteered for this task!'),
        duration: Duration(seconds: 2),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF4F4F4),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Back button
              IconButton(
                icon: const Icon(Icons.arrow_back_ios_new, size: 20),
                onPressed: () => Navigator.of(context).pop(),
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(),
                color: Colors.black87,
              ),
              const SizedBox(height: 12),
              // Request Details Card
              _buildRequestDetailsCard(),
              const SizedBox(height: 16),
              // List of Volunteers Card
              _buildVolunteersCard(),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildRequestDetailsCard() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
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
        children: [
          // Title
          Text(
            widget.task.title,
            style: const TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w700,
              color: Colors.black87,
              height: 1.4,
              letterSpacing: 0.1,
            ),
          ),
          const SizedBox(height: 20),
          // Description Section
          _buildSectionHeader('Description'),
          const SizedBox(height: 10),
          Text(
            widget.task.description,
            style: const TextStyle(
              fontSize: 14,
              color: Color(0xFF4C4C4C),
              height: 1.5,
            ),
          ),
          const SizedBox(height: 20),
          // Contact Section
          _buildSectionHeader('Contact'),
          const SizedBox(height: 10),
          Text(
            widget.contactNumber ?? '09026095205',
            style: const TextStyle(
              fontSize: 14,
              color: Color(0xFF4C4C4C),
            ),
          ),
          const SizedBox(height: 20),
          // Status Section
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              _buildSectionHeader('Status'),
              const SizedBox(width: 12),
              _buildStatusPill(widget.task.status),
            ],
          ),
          const SizedBox(height: 20),
          // Volunteer Button
          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              onPressed: _handleVolunteer,
              icon: const Icon(
                Icons.favorite_border,
                size: 18,
                color: Color(0xFF4C4C4C),
              ),
              label: const Text(
                'Volunteer',
                style: TextStyle(
                  fontSize: 14,
                  color: Color(0xFF4C4C4C),
                  fontWeight: FontWeight.w600,
                ),
              ),
              style: OutlinedButton.styleFrom(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                minimumSize: const Size(0, 48),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
                side: BorderSide(color: Colors.grey.shade300, width: 1),
                backgroundColor: Colors.white,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSectionHeader(String text) {
    return Text(
      text,
      style: const TextStyle(
        fontSize: 14,
        fontWeight: FontWeight.w700,
        color: Colors.black87,
        letterSpacing: 0.2,
      ),
    );
  }

  Widget _buildStatusPill(TaskStatus status) {
    late Color bgColor;
    late Color textColor;
    final displayText = status.displayName;

    switch (status) {
      case TaskStatus.open:
        bgColor = const Color(0xFF2196F3);
        textColor = Colors.white;
        break;
      case TaskStatus.ongoing:
        bgColor = const Color(0xFFFFF3E0);
        textColor = const Color(0xFFF57C00);
        break;
      case TaskStatus.completed:
        bgColor = const Color(0xFFE8F5E9);
        textColor = const Color(0xFF388E3C);
        break;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
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

  Widget _buildVolunteersCard() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
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
        children: [
          // Section Title
          const Text(
            'List of volunteers',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w700,
              color: Colors.black87,
            ),
          ),
          const SizedBox(height: 16),
          // Volunteer List
          ..._volunteers.asMap().entries.map((entry) {
            final index = entry.key;
            final volunteer = entry.value;
            return Padding(
              padding: EdgeInsets.only(bottom: index < _volunteers.length - 1 ? 12 : 0),
              child: _buildVolunteerItem(volunteer),
            );
          }),
        ],
      ),
    );
  }

  Widget _buildVolunteerItem(String volunteerName) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
      decoration: BoxDecoration(
        color: Colors.grey.shade100,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: Colors.grey.shade200,
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.person_outline,
              size: 20,
              color: Color(0xFF6E6E6E),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              volunteerName,
              style: const TextStyle(
                fontSize: 14,
                color: Colors.black87,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
