import 'package:flutter/material.dart';
import '../models/task_model.dart';
import '../services/dummy_data_service.dart';

class TaskEditScreen extends StatefulWidget {
  final TaskModel task;
  final String? contactNumber;

  const TaskEditScreen({
    super.key,
    required this.task,
    this.contactNumber,
  });

  @override
  State<TaskEditScreen> createState() => _TaskEditScreenState();
}

class _TaskEditScreenState extends State<TaskEditScreen> {
  TaskStatus _selectedStatus = TaskStatus.open;
  final DummyDataService _dataService = DummyDataService();
  final List<String> _volunteers = [
    'Regine Mae Lagura',
    'Regine Mae Lagura',
    'Regine Mae Lagura',
    'Regine Mae Lagura',
  ];

  @override
  void initState() {
    super.initState();
    _selectedStatus = widget.task.status;
  }

  void _handleSetStatus() {
    _dataService.updateTaskStatus(widget.task.id, _selectedStatus);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Status set to ${_selectedStatus.displayName}'),
        duration: const Duration(seconds: 2),
      ),
    );
    Navigator.of(context).pop();
  }

  void _handleAcceptVolunteer(String volunteerName) {
    // TODO: Accept volunteer
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Accepted volunteer: $volunteerName'),
        duration: const Duration(seconds: 2),
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
          _buildSectionHeader('Status'),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: _buildStatusDropdown(),
              ),
              const SizedBox(width: 12),
              ElevatedButton(
                onPressed: _handleSetStatus,
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF20BF6B),
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                  minimumSize: const Size(80, 48),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                  elevation: 0,
                ),
                child: const Text(
                  'Set',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
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

  Widget _buildStatusDropdown() {
    return Container(
      height: 48,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.grey.shade300, width: 1),
      ),
      child: DropdownButtonFormField<TaskStatus>(
        value: _selectedStatus,
        decoration: const InputDecoration(
          contentPadding: EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          border: InputBorder.none,
          enabledBorder: InputBorder.none,
          focusedBorder: InputBorder.none,
        ),
        items: TaskStatus.values.map((status) {
          return DropdownMenuItem<TaskStatus>(
            value: status,
            child: Text(
              status.displayName,
              style: const TextStyle(
                fontSize: 14,
                color: Colors.black87,
              ),
            ),
          );
        }).toList(),
        onChanged: (value) {
          if (value != null) {
            setState(() {
              _selectedStatus = value;
            });
          }
        },
        icon: const Padding(
          padding: EdgeInsets.only(right: 8),
          child: Icon(
            Icons.keyboard_arrow_down,
            color: Color(0xFF6E6E6E),
            size: 20,
          ),
        ),
        isExpanded: true,
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
              padding: EdgeInsets.only(bottom: index < _volunteers.length - 1 ? 14 : 0),
              child: _buildVolunteerItem(volunteer),
            );
          }),
        ],
      ),
    );
  }

  Widget _buildVolunteerItem(String volunteerName) {
    return Row(
      children: [
        Container(
          width: 40,
          height: 40,
          decoration: BoxDecoration(
            color: Colors.grey.shade100,
            shape: BoxShape.circle,
          ),
          child: const Icon(
            Icons.person_outline,
            size: 22,
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
        OutlinedButton(
          onPressed: () => _handleAcceptVolunteer(volunteerName),
          style: OutlinedButton.styleFrom(
            padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
            minimumSize: const Size(80, 40),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(14),
            ),
            side: BorderSide(color: Colors.grey.shade300, width: 1),
            backgroundColor: Colors.white,
          ),
          child: const Text(
            'Accept',
            style: TextStyle(
              fontSize: 13,
              color: Color(0xFF4C4C4C),
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      ],
    );
  }
}

