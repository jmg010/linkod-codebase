import 'package:flutter/material.dart';
import '../models/task_model.dart';
import '../services/tasks_service.dart';
import '../services/firestore_service.dart';
import '../services/task_chat_service.dart';
import 'task_chat_screen.dart';

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
  bool _isUpdatingStatus = false;
  bool _isAcceptingVolunteer = false;

  @override
  void initState() {
    super.initState();
    _selectedStatus = widget.task.status;
  }

  Future<void> _handleSetStatus() async {
    if (_isUpdatingStatus) return;

    setState(() {
      _isUpdatingStatus = true;
    });

    try {
      await TasksService.updateTask(widget.task.id, {
        'status': _selectedStatus.name,
      });

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Status updated to ${_selectedStatus.displayName}'),
          duration: const Duration(seconds: 2),
          backgroundColor: const Color(0xFF20BF6B),
        ),
      );
    } catch (e) {
      debugPrint('Error updating status: $e');
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error updating status: ${e.toString()}'),
          duration: const Duration(seconds: 2),
          backgroundColor: Colors.red,
        ),
      );
    } finally {
      if (mounted) {
        setState(() {
          _isUpdatingStatus = false;
        });
      }
    }
  }

  Future<void> _handleRejectVolunteer(String volunteerDocId) async {
    final currentUser = FirestoreService.auth.currentUser;
    if (currentUser == null) return;

    try {
      await TasksService.rejectVolunteer(widget.task.id, volunteerDocId);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Volunteer rejected'),
          duration: Duration(seconds: 2),
          backgroundColor: Color(0xFF4C4C4C),
        ),
      );
    } catch (e) {
      debugPrint('Error rejecting volunteer: $e');
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error: ${e.toString()}'),
          duration: const Duration(seconds: 2),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  void _openChatWithVolunteer(String volunteerId, String volunteerName) {
    final currentUser = FirestoreService.auth.currentUser;
    if (currentUser == null) return;
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => TaskChatScreen(
          taskId: widget.task.id,
          taskTitle: widget.task.title,
          otherPartyName: volunteerName,
          otherPartyId: volunteerId,
          currentUserId: currentUser.uid,
        ),
      ),
    );
  }

  Future<void> _handleAcceptVolunteer(String volunteerDocId, String volunteerName) async {
    if (_isAcceptingVolunteer) return;

    final currentUser = FirestoreService.auth.currentUser;
    if (currentUser == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please log in to accept volunteers'),
          duration: Duration(seconds: 2),
        ),
      );
      return;
    }

    setState(() {
      _isAcceptingVolunteer = true;
    });

    try {
      await TasksService.acceptVolunteer(
        widget.task.id,
        volunteerDocId,
        widget.task.requesterId,
      );

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Accepted volunteer: $volunteerName'),
          duration: const Duration(seconds: 2),
          backgroundColor: const Color(0xFF20BF6B),
        ),
      );
    } catch (e) {
      debugPrint('Error accepting volunteer: $e');
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error accepting volunteer: ${e.toString()}'),
          duration: const Duration(seconds: 2),
          backgroundColor: Colors.red,
        ),
      );
    } finally {
      if (mounted) {
        setState(() {
          _isAcceptingVolunteer = false;
        });
      }
    }
  }

  void _showVolunteersDropdown(BuildContext context) {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => DraggableScrollableSheet(
        initialChildSize: 0.5,
        minChildSize: 0.3,
        maxChildSize: 0.85,
        builder: (_, scrollController) => Container(
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
          ),
          child: Column(
            children: [
              const SizedBox(height: 12),
              Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.grey.shade300,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const Padding(
                padding: EdgeInsets.all(16),
                child: Text(
                  'Volunteers',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                    color: Colors.black87,
                  ),
                ),
              ),
              Expanded(
                child: StreamBuilder<List<Map<String, dynamic>>>(
                  stream: TasksService.getVolunteersStream(widget.task.id),
                  builder: (context, snapshot) {
                    if (snapshot.connectionState == ConnectionState.waiting) {
                      return const Center(child: CircularProgressIndicator());
                    }
                    if (snapshot.hasError) {
                      return Center(
                        child: Text(
                          'Error: ${snapshot.error}',
                          style: const TextStyle(color: Colors.red),
                        ),
                      );
                    }
                    final volunteers = snapshot.data ?? [];
                    final pending = volunteers
                        .where((v) => (v['status'] as String? ?? 'pending') == 'pending')
                        .toList();
                    if (pending.isEmpty) {
                      return Center(
                        child: Text(
                          'No pending volunteers',
                          style: TextStyle(
                            fontSize: 14,
                            color: Colors.grey.shade600,
                          ),
                        ),
                      );
                    }
                    return ListView(
                      controller: scrollController,
                      padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
                      children: pending.map((v) => _dropdownPendingItem(v)).toList(),
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _dropdownSectionHeader(String label) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w700,
          color: Colors.grey.shade600,
          letterSpacing: 0.5,
        ),
      ),
    );
  }

  Widget _dropdownPendingItem(Map<String, dynamic> volunteer) {
    final volunteerDocId = volunteer['volunteerDocId'] as String;
    final volunteerName = volunteer['volunteerName'] as String? ?? 'Unknown';
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          color: Colors.grey.shade100,
          borderRadius: BorderRadius.circular(14),
        ),
        child: Row(
          children: [
            Expanded(
              child: Text(
                volunteerName,
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                  color: Colors.black87,
                ),
              ),
            ),
            IconButton(
              onPressed: _isAcceptingVolunteer
                  ? null
                  : () {
                      Navigator.pop(context);
                      _handleAcceptVolunteer(volunteerDocId, volunteerName);
                    },
              icon: Icon(Icons.check_circle, color: Colors.green.shade700, size: 26),
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints(minWidth: 40, minHeight: 40),
            ),
            IconButton(
              onPressed: _isAcceptingVolunteer
                  ? null
                  : () {
                      Navigator.pop(context);
                      _handleRejectVolunteer(volunteerDocId);
                    },
              icon: Icon(Icons.cancel, color: Colors.red.shade700, size: 26),
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints(minWidth: 40, minHeight: 40),
            ),
          ],
        ),
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
              Row(
                children: [
                  IconButton(
                    icon: const Icon(Icons.arrow_back_ios_new, size: 20),
                    onPressed: () => Navigator.of(context).pop(),
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(),
                    color: Colors.black87,
                  ),
                  const Spacer(),
                  StreamBuilder<List<Map<String, dynamic>>>(
                    stream: TasksService.getVolunteersStream(widget.task.id),
                    builder: (context, volSnap) {
                      final volunteers = volSnap.data ?? [];
                      final pendingCount = volunteers
                          .where((v) => (v['status'] as String? ?? 'pending') == 'pending')
                          .length;
                      return Stack(
                        clipBehavior: Clip.none,
                        children: [
                          Material(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(14),
                            child: InkWell(
                              onTap: () => _showVolunteersDropdown(context),
                              borderRadius: BorderRadius.circular(14),
                              child: Container(
                                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                                decoration: BoxDecoration(
                                  borderRadius: BorderRadius.circular(14),
                                  border: Border.all(color: Colors.grey.shade300),
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    const Text(
                                      'Volunteers',
                                      style: TextStyle(
                                        fontSize: 14,
                                        fontWeight: FontWeight.w600,
                                        color: Color(0xFF4C4C4C),
                                      ),
                                    ),
                                    const SizedBox(width: 6),
                                    Icon(Icons.keyboard_arrow_down, size: 20, color: Colors.grey.shade600),
                                  ],
                                ),
                              ),
                            ),
                          ),
                          if (pendingCount > 0)
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
                ],
              ),
              const SizedBox(height: 12),
              // Request Details Card
              _buildRequestDetailsCard(),
              const SizedBox(height: 16),
              // List of Volunteers Card (pending + confirmed with Message)
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
                onPressed: _isUpdatingStatus ? null : _handleSetStatus,
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
                child: _isUpdatingStatus
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                        ),
                      )
                    : const Text(
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
          const Text(
            'List of volunteers',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w700,
              color: Colors.black87,
            ),
          ),
          const SizedBox(height: 16),
          StreamBuilder<List<Map<String, dynamic>>>(
            stream: TasksService.getVolunteersStream(widget.task.id),
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const Center(
                  child: Padding(
                    padding: EdgeInsets.all(20.0),
                    child: CircularProgressIndicator(),
                  ),
                );
              }
              if (snapshot.hasError) {
                return Padding(
                  padding: const EdgeInsets.all(20.0),
                  child: Text(
                    'Error loading volunteers: ${snapshot.error}',
                    style: const TextStyle(color: Colors.red),
                  ),
                );
              }
              final volunteers = snapshot.data ?? [];
              final confirmed = volunteers
                  .where((v) => (v['status'] as String?) == 'accepted')
                  .toList();

              if (confirmed.isEmpty) {
                return Padding(
                  padding: const EdgeInsets.all(20.0),
                  child: Text(
                    'No approved volunteers yet',
                    style: TextStyle(
                      fontSize: 14,
                      color: Colors.grey.shade600,
                    ),
                  ),
                );
              }

              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: confirmed.asMap().entries.map((entry) {
                  final index = entry.key;
                  return Padding(
                    padding: EdgeInsets.only(
                      bottom: index < confirmed.length - 1 ? 12 : 0,
                    ),
                    child: _buildConfirmedVolunteerItem(entry.value),
                  );
                }).toList(),
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _cardSectionLabel(String label) {
    return Text(
      label,
      style: TextStyle(
        fontSize: 12,
        fontWeight: FontWeight.w700,
        color: Colors.grey.shade600,
        letterSpacing: 0.5,
      ),
    );
  }

  Widget _buildPendingVolunteerItem(Map<String, dynamic> volunteer) {
    final volunteerDocId = volunteer['volunteerDocId'] as String;
    final volunteerName = volunteer['volunteerName'] as String? ?? 'Unknown';
    final volunteerId = volunteer['volunteerId'] as String?;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: Colors.grey.shade100,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: Colors.grey.shade200,
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
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  volunteerName,
                  style: const TextStyle(
                    fontSize: 14,
                    color: Colors.black87,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                if (volunteerId != null && volunteerId.isNotEmpty)
                  FutureBuilder<String?>(
                    future: _getVolunteerPhone(volunteerId),
                    builder: (context, snap) {
                      final phone = snap.data;
                      if (phone == null || phone.isEmpty) return const SizedBox.shrink();
                      return Padding(
                        padding: const EdgeInsets.only(top: 2),
                        child: Text(
                          phone,
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.blue.shade700,
                          ),
                        ),
                      );
                    },
                  ),
              ],
            ),
          ),
          IconButton(
            onPressed: _isAcceptingVolunteer
                ? null
                : () => _handleAcceptVolunteer(volunteerDocId, volunteerName),
            icon: Icon(Icons.check_circle, color: Colors.green.shade700, size: 28),
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(minWidth: 44, minHeight: 44),
          ),
          IconButton(
            onPressed: _isAcceptingVolunteer
                ? null
                : () => _handleRejectVolunteer(volunteerDocId),
            icon: Icon(Icons.cancel, color: Colors.red.shade700, size: 28),
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(minWidth: 44, minHeight: 44),
          ),
        ],
      ),
    );
  }

  Widget _buildConfirmedVolunteerItem(Map<String, dynamic> volunteer) {
    final volunteerId = volunteer['volunteerId'] as String?;
    final volunteerName = volunteer['volunteerName'] as String? ?? 'Unknown';
    if (volunteerId == null || volunteerId.isEmpty) return const SizedBox.shrink();
    final ownerId = FirestoreService.auth.currentUser?.uid ?? '';
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: Colors.green.shade50,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.green.shade200),
      ),
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: Colors.green.shade200,
              shape: BoxShape.circle,
            ),
            child: Icon(
              Icons.check_circle,
              size: 22,
              color: Colors.green.shade700,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              volunteerName,
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: Colors.green.shade800,
              ),
            ),
          ),
          StreamBuilder<int>(
            stream: TaskChatService.getUnreadCountStream(widget.task.id, ownerId),
            builder: (context, unreadSnap) {
              final unreadCount = unreadSnap.data ?? 0;
              return Stack(
                clipBehavior: Clip.none,
                children: [
                  IconButton(
                    onPressed: () => _openChatWithVolunteer(volunteerId, volunteerName),
                    icon: const Icon(Icons.message_outlined, size: 22, color: Color(0xFF4C4C4C)),
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(minWidth: 44, minHeight: 44),
                  ),
                  if (unreadCount > 0)
                    Positioned(
                      right: 4,
                      top: 4,
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
        ],
      ),
    );
  }

  Future<String?> _getVolunteerPhone(String volunteerId) async {
    try {
      final doc = await FirestoreService.instance
          .collection('users')
          .doc(volunteerId)
          .get();
      return doc.data()?['phoneNumber'] as String?;
    } catch (_) {
      return null;
    }
  }
}

