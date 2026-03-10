import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../models/task_model.dart';
import '../services/tasks_service.dart';
import '../services/firestore_service.dart';
import '../services/task_chat_service.dart';
import '../widgets/optimized_image.dart';
import 'task_edit_screen.dart';
import 'task_chat_screen.dart';

class TaskDetailScreen extends StatefulWidget {
  final TaskModel task;
  final String? contactNumber;

  const TaskDetailScreen({super.key, required this.task, this.contactNumber});

  @override
  State<TaskDetailScreen> createState() => _TaskDetailScreenState();
}

class _TaskDetailScreenState extends State<TaskDetailScreen> {
  bool _isVolunteering = false;
  bool _isCancelling = false;
  bool _isOwner = false;
  bool _isEditingConfirmedVolunteer = false;
  final PageController _imagePageController = PageController();
  int _imagePageIndex = 0;

  @override
  void initState() {
    super.initState();
    final uid = FirestoreService.auth.currentUser?.uid;
    _isOwner = uid != null && uid == widget.task.requesterId;
    // Do NOT mark chat read here; mark only when user opens TaskChatScreen.
  }

  @override
  void dispose() {
    _imagePageController.dispose();
    super.dispose();
  }

  Future<void> _confirmRemoveAcceptedVolunteer(
    String volunteerDocId,
    String volunteerName,
  ) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder:
          (ctx) => AlertDialog(
            title: const Text('Remove volunteer?'),
            content: Text(
              'Remove $volunteerName from this errand? This will unassign them.',
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(ctx).pop(false),
                child: Text(
                  'Cancel',
                  style: TextStyle(color: Colors.grey.shade700),
                ),
              ),
              TextButton(
                onPressed: () => Navigator.of(ctx).pop(true),
                child: const Text(
                  'Remove',
                  style: TextStyle(
                    color: Colors.red,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
    );
    if (confirm != true || !mounted) return;
    try {
      await TasksService.rejectVolunteer(widget.task.id, volunteerDocId);
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Volunteer removed')));
      setState(() => _isEditingConfirmedVolunteer = false);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Error: ${e.toString()}')));
    }
  }

  Future<void> _handleVolunteer() async {
    final currentUser = FirestoreService.auth.currentUser;
    if (currentUser == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please log in to volunteer')),
      );
      return;
    }

    setState(() => _isVolunteering = true);

    try {
      final userDoc =
          await FirestoreService.instance
              .collection('users')
              .doc(currentUser.uid)
              .get();
      final userName = userDoc.data()?['fullName'] as String? ?? 'User';

      await TasksService.volunteerForTask(
        widget.task.id,
        currentUser.uid,
        userName,
      );

      setState(() => _isVolunteering = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('You have volunteered for this task!'),
            duration: Duration(seconds: 2),
          ),
        );
      }
    } catch (e) {
      setState(() => _isVolunteering = false);
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Error: ${e.toString()}')));
      }
    }
  }

  Future<void> _handleCancelVolunteer() async {
    final currentUser = FirestoreService.auth.currentUser;
    if (currentUser == null) return;
    if (_isCancelling) return;

    setState(() => _isCancelling = true);
    try {
      await TasksService.cancelVolunteer(widget.task.id, currentUser.uid);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Volunteer request cancelled')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Error: ${e.toString()}')));
      }
    } finally {
      if (mounted) setState(() => _isCancelling = false);
    }
  }

  void _openChatWithVolunteer(String volunteerId, String volunteerName) {
    final currentUser = FirestoreService.auth.currentUser;
    if (currentUser == null) return;
    Navigator.of(context).push(
      MaterialPageRoute(
        builder:
            (_) => TaskChatScreen(
              taskId: widget.task.id,
              taskTitle: widget.task.title,
              otherPartyName: volunteerName,
              otherPartyId: volunteerId,
              currentUserId: currentUser.uid,
            ),
      ),
    );
  }

  void _openTaskChat() {
    final currentUser = FirestoreService.auth.currentUser;
    if (currentUser == null) return;
    final isOwner = currentUser.uid == widget.task.requesterId;
    final otherName =
        isOwner
            ? (widget.task.assignedByName ?? 'Volunteer')
            : widget.task.requesterName;
    final otherId = isOwner ? widget.task.assignedTo : widget.task.requesterId;
    if (otherId == null || otherId.isEmpty) return;
    Navigator.of(context).push(
      MaterialPageRoute(
        builder:
            (_) => TaskChatScreen(
              taskId: widget.task.id,
              taskTitle: widget.task.title,
              otherPartyName: otherName,
              otherPartyId: otherId,
              currentUserId: currentUser.uid,
            ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor:
          isDark ? const Color(0xFF121212) : const Color(0xFFF4F4F4),
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
                color: isDark ? Colors.white : Colors.black87,
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
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E1E1E) : Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color:
                isDark
                    ? Colors.black.withOpacity(0.3)
                    : Colors.black.withOpacity(0.06),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (widget.task.imageUrls.isNotEmpty) ...[
            _buildImageSection(),
            const SizedBox(height: 16),
          ],
          // Title
          Text(
            widget.task.title,
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w700,
              color: isDark ? Colors.white : Colors.black87,
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
            style: TextStyle(
              fontSize: 14,
              color: isDark ? Colors.grey.shade300 : const Color(0xFF4C4C4C),
              height: 1.5,
            ),
          ),
          const SizedBox(height: 20),
          // Contact Section
          _buildSectionHeader('Contact'),
          const SizedBox(height: 10),
          Text(
            widget.contactNumber ?? '09026095205',
            style: TextStyle(
              fontSize: 14,
              color: isDark ? Colors.grey.shade300 : const Color(0xFF4C4C4C),
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
          // Volunteer / Edit / Cancel / Message Button
          _buildActionButton(),
        ],
      ),
    );
  }

  Widget _buildImageSection() {
    final urls = widget.task.imageUrls;
    if (urls.isEmpty) return const SizedBox.shrink();
    if (urls.length == 1) {
      return ClipRRect(
        borderRadius: BorderRadius.circular(16),
        child: SizedBox(
          height: 190,
          width: double.infinity,
          child: OptimizedNetworkImage(
            imageUrl: urls.first,
            height: 190,
            fit: BoxFit.cover,
            cacheWidth: 400,
            cacheHeight: 380,
            borderRadius: BorderRadius.circular(16),
            onTap: () => openFullScreenImages(context, urls, initialIndex: 0),
          ),
        ),
      );
    }
    return ClipRRect(
      borderRadius: BorderRadius.circular(16),
      child: SizedBox(
        height: 190,
        width: double.infinity,
        child: Stack(
          children: [
            PageView.builder(
              controller: _imagePageController,
              itemCount: urls.length,
              onPageChanged: (i) => setState(() => _imagePageIndex = i),
              itemBuilder: (context, index) {
                return GestureDetector(
                  onTap:
                      () => openFullScreenImages(
                        context,
                        urls,
                        initialIndex: index,
                      ),
                  child: OptimizedNetworkImage(
                    imageUrl: urls[index],
                    height: 190,
                    fit: BoxFit.cover,
                    cacheWidth: 400,
                    cacheHeight: 380,
                    borderRadius: BorderRadius.circular(16),
                  ),
                );
              },
            ),
            if (urls.length > 1)
              Positioned(
                left: 0,
                right: 0,
                bottom: 8,
                child: Center(
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: List.generate(
                      urls.length,
                      (i) => Container(
                        margin: const EdgeInsets.symmetric(horizontal: 3),
                        width: 6,
                        height: 6,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color:
                              _imagePageIndex == i
                                  ? const Color(0xFF20BF6B)
                                  : Colors.grey.shade400,
                        ),
                      ),
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildActionButton() {
    final currentUser = FirestoreService.auth.currentUser;
    if (_isOwner) {
      return const SizedBox.shrink();
    }
    if (currentUser == null) return const SizedBox.shrink();
    return StreamBuilder<Map<String, dynamic>?>(
      stream: TasksService.getMyVolunteerStatusStream(
        widget.task.id,
        currentUser.uid,
      ),
      builder: (context, statusSnap) {
        final isDark = Theme.of(context).brightness == Brightness.dark;
        final myStatus = statusSnap.data;
        final status = myStatus?['status'] as String?;
        // Default: Volunteer button (only when task open and not volunteered/rejected)
        if (status == null || status == 'rejected') {
          if (widget.task.status != TaskStatus.open)
            return const SizedBox.shrink();
          return SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              onPressed: _isVolunteering ? null : _handleVolunteer,
              icon:
                  _isVolunteering
                      ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                      : const Icon(
                        Icons.favorite_border,
                        size: 18,
                        color: Color(0xFF4C4C4C),
                      ),
              label: Text(
                _isVolunteering ? 'Volunteering...' : 'Volunteer',
                style: TextStyle(
                  fontSize: 14,
                  color: isDark ? Colors.white : const Color(0xFF4C4C4C),
                  fontWeight: FontWeight.w600,
                ),
              ),
              style: OutlinedButton.styleFrom(
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 14,
                ),
                minimumSize: const Size(0, 48),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
                side: BorderSide(
                  color: isDark ? Colors.grey.shade700 : Colors.grey.shade300,
                  width: 1,
                ),
                backgroundColor:
                    isDark ? const Color(0xFF2C2C2C) : Colors.white,
              ),
            ),
          );
        }
        // Pending: Cancel button
        if (status == 'pending') {
          return SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              onPressed: _isCancelling ? null : _handleCancelVolunteer,
              icon:
                  _isCancelling
                      ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                      : const Icon(
                        Icons.close,
                        size: 18,
                        color: Color(0xFF4C4C4C),
                      ),
              label: Text(
                _isCancelling ? 'Cancelling...' : 'Cancel',
                style: TextStyle(
                  fontSize: 14,
                  color: isDark ? Colors.white : const Color(0xFF4C4C4C),
                  fontWeight: FontWeight.w600,
                ),
              ),
              style: OutlinedButton.styleFrom(
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 14,
                ),
                minimumSize: const Size(0, 48),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
                side: BorderSide(
                  color: isDark ? Colors.grey.shade700 : Colors.grey.shade300,
                  width: 1,
                ),
                backgroundColor:
                    isDark ? const Color(0xFF2C2C2C) : Colors.white,
              ),
            ),
          );
        }
        // Approved: Message icon with optional unread badge
        if (status == 'accepted') {
          return StreamBuilder<int>(
            stream: TaskChatService.getUnreadCountStream(
              widget.task.id,
              currentUser.uid,
            ),
            builder: (context, unreadSnap) {
              final unreadCount = unreadSnap.data ?? 0;
              return SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  onPressed: _openTaskChat,
                  icon: Stack(
                    clipBehavior: Clip.none,
                    children: [
                      Icon(
                        Icons.message_outlined,
                        size: 20,
                        color: isDark ? Colors.white : const Color(0xFF4C4C4C),
                      ),
                      if (unreadCount > 0)
                        Positioned(
                          right: -6,
                          top: -6,
                          child: Container(
                            padding: const EdgeInsets.all(4),
                            decoration: const BoxDecoration(
                              color: Colors.red,
                              shape: BoxShape.circle,
                            ),
                            constraints: const BoxConstraints(
                              minWidth: 16,
                              minHeight: 16,
                            ),
                            child: Text(
                              unreadCount > 99 ? '99+' : '$unreadCount',
                              style: const TextStyle(
                                fontSize: 10,
                                color: Colors.white,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                        ),
                    ],
                  ),
                  label: Text(
                    'Message',
                    style: TextStyle(
                      fontSize: 14,
                      color: isDark ? Colors.white : const Color(0xFF4C4C4C),
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 14,
                    ),
                    minimumSize: const Size(0, 48),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                    side: BorderSide(
                      color:
                          isDark ? Colors.grey.shade700 : Colors.grey.shade300,
                      width: 1,
                    ),
                    backgroundColor:
                        isDark ? const Color(0xFF2C2C2C) : Colors.white,
                  ),
                ),
              );
            },
          );
        }
        return const SizedBox.shrink();
      },
    );
  }

  Widget _buildSectionHeader(String text) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Text(
      text,
      style: TextStyle(
        fontSize: 14,
        fontWeight: FontWeight.w700,
        color: isDark ? Colors.white : Colors.black87,
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
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E1E1E) : Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color:
                isDark
                    ? Colors.black.withOpacity(0.3)
                    : Colors.black.withOpacity(0.06),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  'List of Volunteers',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                    color: isDark ? Colors.white : Colors.black87,
                  ),
                ),
              ),
              if (_isOwner)
                IconButton(
                  onPressed:
                      () => setState(
                        () =>
                            _isEditingConfirmedVolunteer =
                                !_isEditingConfirmedVolunteer,
                      ),
                  icon: Icon(
                    _isEditingConfirmedVolunteer
                        ? Icons.close
                        : Icons.edit_outlined,
                    color: isDark ? Colors.white : const Color(0xFF4C4C4C),
                    size: 20,
                  ),
                  tooltip: _isEditingConfirmedVolunteer ? 'Done' : 'Edit',
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(
                    minWidth: 40,
                    minHeight: 40,
                  ),
                ),
            ],
          ),
          const SizedBox(height: 16),
          // Volunteer List from Firebase
          StreamBuilder<List<Map<String, dynamic>>>(
            stream: TasksService.getVolunteersStream(widget.task.id),
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const Center(child: CircularProgressIndicator());
              }

              if (snapshot.hasError) {
                return Text('Error: ${snapshot.error}');
              }

              final volunteers = snapshot.data ?? [];

              if (volunteers.isEmpty) {
                return Padding(
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  child: Text(
                    'No volunteers yet',
                    style: TextStyle(fontSize: 14, color: Colors.grey.shade600),
                  ),
                );
              }

              return Column(
                children:
                    volunteers.asMap().entries.map((entry) {
                      final index = entry.key;
                      final volunteer = entry.value;
                      return Padding(
                        padding: EdgeInsets.only(
                          bottom: index < volunteers.length - 1 ? 12 : 0,
                        ),
                        child: _buildVolunteerItem(volunteer),
                      );
                    }).toList(),
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _buildVolunteerItem(Map<String, dynamic> volunteer) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    final volunteerName = volunteer['volunteerName'] as String? ?? 'Unknown';
    final volunteerId = volunteer['volunteerId'] as String?;
    final status = volunteer['status'] as String? ?? 'pending';
    final volunteerDocId = volunteer['volunteerDocId'] as String? ?? '';
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
      decoration: BoxDecoration(
        color:
            status == 'accepted'
                ? (isDark ? const Color(0xFF1B3B24) : Colors.green.shade50)
                : (isDark ? const Color(0xFF2C2C2C) : Colors.grey.shade100),
        borderRadius: BorderRadius.circular(14),
        border:
            status == 'accepted'
                ? Border.all(
                  color:
                      isDark ? const Color(0xFF20BF6B) : Colors.green.shade200,
                )
                : null,
      ),
      child: Row(
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color:
                  status == 'accepted'
                      ? (isDark
                          ? const Color(0xFF20BF6B).withOpacity(0.2)
                          : Colors.green.shade200)
                      : (isDark
                          ? const Color(0xFF4C4C4C)
                          : Colors.grey.shade200),
              shape: BoxShape.circle,
            ),
            child: Icon(
              status == 'accepted' ? Icons.check_circle : Icons.person_outline,
              size: 20,
              color:
                  status == 'accepted'
                      ? (isDark
                          ? const Color(0xFF20BF6B)
                          : Colors.green.shade700)
                      : (isDark
                          ? Colors.grey.shade400
                          : const Color(0xFF6E6E6E)),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  volunteerName,
                  style: TextStyle(
                    fontSize: 14,
                    color: isDark ? Colors.white : Colors.black87,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                if (volunteerId != null && volunteerId.isNotEmpty)
                  FutureBuilder<String?>(
                    future: _getVolunteerPhone(volunteerId),
                    builder: (context, snap) {
                      final phone = snap.data;
                      if (phone == null || phone.isEmpty)
                        return const SizedBox.shrink();
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
                if (status == 'accepted')
                  Text(
                    'Accepted',
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.green.shade700,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
              ],
            ),
          ),
          if (_isOwner && _isEditingConfirmedVolunteer && status == 'accepted')
            IconButton(
              onPressed:
                  volunteerDocId.isEmpty
                      ? null
                      : () => _confirmRemoveAcceptedVolunteer(
                        volunteerDocId,
                        volunteerName,
                      ),
              icon: Icon(Icons.close, color: Colors.red.shade700, size: 20),
              tooltip: 'Remove volunteer',
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints(minWidth: 40, minHeight: 40),
            ),
          if (_isOwner &&
              !_isEditingConfirmedVolunteer &&
              status == 'accepted' &&
              volunteerId != null &&
              volunteerId.isNotEmpty)
            StreamBuilder<int>(
              stream: TaskChatService.getUnreadCountStream(
                widget.task.id,
                FirestoreService.auth.currentUser?.uid ?? '',
              ),
              builder: (context, unreadSnap) {
                final unreadCount = unreadSnap.data ?? 0;
                return Stack(
                  clipBehavior: Clip.none,
                  children: [
                    IconButton(
                      onPressed:
                          () => _openChatWithVolunteer(
                            volunteerId,
                            volunteerName,
                          ),
                      icon: const Icon(
                        Icons.message_outlined,
                        size: 20,
                        color: Color(0xFF4C4C4C),
                      ),
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(
                        minWidth: 40,
                        minHeight: 40,
                      ),
                    ),
                    if (unreadCount > 0)
                      Positioned(
                        right: 2,
                        top: 2,
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
      final doc =
          await FirestoreService.instance
              .collection('users')
              .doc(volunteerId)
              .get();
      return doc.data()?['phoneNumber'] as String?;
    } catch (_) {
      return null;
    }
  }
}
