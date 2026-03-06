import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/task_model.dart';
import 'firestore_service.dart';
import 'task_chat_service.dart';

class TasksService {
  static final CollectionReference _tasksCollection =
      FirestoreService.instance.collection('tasks');

  // ==================== INTERACTED TASKS (Activity Log) ====================

  static final CollectionReference _interactionsCollection =
      FirestoreService.instance.collection('user_task_interactions');

  /// Record that a user has interacted with a task (called when volunteering or chatting)
  static Future<void> recordUserTaskInteraction(
    String userId,
    String taskId,
    String taskTitle,
    String requesterId,
    String requesterName,
  ) async {
    final interactionRef = _interactionsCollection.doc('${userId}_$taskId');
    await interactionRef.set({
      'userId': userId,
      'taskId': taskId,
      'taskTitle': taskTitle,
      'requesterId': requesterId,
      'requesterName': requesterName,
      'lastInteractedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
  }

  /// Get all tasks that a user has been ASSIGNED to (for INTERACTED POSTS tab)
  /// Matches the badge logic: getTotalUnreadForAssignedStream
  static Stream<List<MapEntry<TaskModel, int>>> getUserInteractedTasksStream(String userId) {
    final controller = StreamController<List<MapEntry<TaskModel, int>>>.broadcast();
    final Map<String, int> unreadByTask = {};
    final Map<String, StreamSubscription<int>> taskSubs = {};
    List<TaskModel> _currentTasks = [];

    void emitList() {
      if (!controller.isClosed) {
        final list = _currentTasks
            .map((t) => MapEntry(t, unreadByTask[t.id] ?? 0))
            .toList();
        controller.add(list);
      }
    }

    void setTasks(List<TaskModel> tasks) {
      final newIds = tasks.map((t) => t.id).toSet();
      for (final id in taskSubs.keys.toList()) {
        if (!newIds.contains(id)) {
          taskSubs[id]?.cancel();
          taskSubs.remove(id);
          unreadByTask.remove(id);
        }
      }
      _currentTasks = tasks;
      for (final t in tasks) {
        if (taskSubs.containsKey(t.id)) continue;
        unreadByTask[t.id] = 0;
        // Track unread chat messages for this assigned task
        final sub = TaskChatService.getUnreadCountStream(t.id, userId).listen((count) {
          unreadByTask[t.id] = count;
          emitList();
        });
        taskSubs[t.id] = sub;
      }
      emitList();
    }

    // Listen to assigned tasks (same as badge count)
    final tasksSub = getAssignedTasksStream(userId).listen((tasks) {
      setTasks(tasks);
    });

    controller.onListen = () {
      if (!controller.isClosed) emitList();
    };
    controller.onCancel = () {
      tasksSub.cancel();
      for (final s in taskSubs.values) {
        s.cancel();
      }
    };

    return controller.stream;
  }

  /// Combined total unread count for Post Activity (requester tasks + interacted tasks)
  /// This is used for the errands "My Post" button badge
  static Stream<int> getTotalPostActivityUnreadStream(String userId) {
    final controller = StreamController<int>.broadcast();
    int _requesterUnread = 0;
    int _interactedUnread = 0;

    void emitSum() {
      if (!controller.isClosed) {
        controller.add(_requesterUnread + _interactedUnread);
      }
    }

    // Listen to requester tasks unread (pending volunteers)
    final requesterSub = getRequesterTasksStream(userId).asyncMap((tasks) async {
      try {
        int total = 0;
        for (final t in tasks) {
          // Count pending volunteers + unread chat messages
          final chatUnread = await TaskChatService.getUnreadCountStream(t.id, userId).first;
          total += t.pendingVolunteersCount + chatUnread;
        }
        return total;
      } catch (_) {
        return 0;
      }
    }).listen((count) {
      _requesterUnread = count;
      emitSum();
    });

    // Listen to interacted tasks unread
    final interactedSub = TaskChatService.getTotalUnreadForUserStream(userId).listen((count) {
      _interactedUnread = count;
      emitSum();
    });

    controller.onListen = () {
      if (!controller.isClosed) emitSum();
    };
    controller.onCancel = () {
      requesterSub.cancel();
      interactedSub.cancel();
    };

    return controller.stream;
  }

  /// Helper to chunk list for Firestore 'whereIn' queries (max 10 items)
  static List<List<T>> _chunks<T>(List<T> list, int chunkSize) {
    final chunks = <List<T>>[];
    for (var i = 0; i < list.length; i += chunkSize) {
      chunks.add(list.sublist(i, i + chunkSize > list.length ? list.length : i + chunkSize));
    }
    return chunks;
  }

  /// Get all tasks (Gatekeeper: only Approved)
  static Stream<List<TaskModel>> getTasksStream() {
    return _tasksCollection
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map((snapshot) => snapshot.docs
            .map((doc) => TaskModel.fromFirestore(doc))
            .where((task) => task.isActive && task.approvalStatus == 'Approved')
            .toList());
  }

  /// Get tasks by status (Gatekeeper: only Approved)
  static Stream<List<TaskModel>> getTasksByStatusStream(String status) {
    return _tasksCollection
        .where('status', isEqualTo: status)
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map((snapshot) => snapshot.docs
            .map((doc) => TaskModel.fromFirestore(doc))
            .where((task) => task.isActive && task.approvalStatus == 'Approved')
            .toList());
  }

  /// Get tasks by requester
  static Stream<List<TaskModel>> getRequesterTasksStream(String requesterId) {
    return _tasksCollection
        .where('requesterId', isEqualTo: requesterId)
        .snapshots()
        .map((snapshot) {
          final tasks = snapshot.docs
              .map((doc) => TaskModel.fromFirestore(doc))
              .where((task) => task.isActive)
              .toList();
          tasks.sort((a, b) => b.createdAt.compareTo(a.createdAt));
          return tasks;
        });
  }

  /// Get tasks assigned to a user (Gatekeeper: only Approved)
  static Stream<List<TaskModel>> getAssignedTasksStream(String userId) {
    return _tasksCollection
        .where('assignedTo', isEqualTo: userId)
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map((snapshot) => snapshot.docs
            .map((doc) => TaskModel.fromFirestore(doc))
            .where((task) => task.isActive && task.approvalStatus == 'Approved')
            .toList());
  }

  /// Create a new task
  static Future<String> createTask(TaskModel task) async {
    final docRef = await _tasksCollection.add(task.toJson());
    return docRef.id;
  }

  /// Update a task
  static Future<void> updateTask(String taskId, Map<String, dynamic> updates) async {
    updates['updatedAt'] = FieldValue.serverTimestamp();
    await _tasksCollection.doc(taskId).update(updates);
  }

  /// Delete a task (soft delete by setting isActive to false)
  static Future<void> deleteTask(String taskId) async {
    await _tasksCollection.doc(taskId).update({
      'isActive': false,
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }

  /// Volunteer for a task
  static Future<void> volunteerForTask(
    String taskId,
    String volunteerId,
    String volunteerName,
  ) async {
    final taskRef = _tasksCollection.doc(taskId);
    final volunteersRef = taskRef.collection('volunteers');
    
    // Check if already volunteered
    final existingVolunteer = await volunteersRef.where('volunteerId', isEqualTo: volunteerId).get();
    if (existingVolunteer.docs.isNotEmpty) {
      throw Exception('You have already volunteered for this task');
    }
    
    // Add volunteer
    await volunteersRef.add({
      'volunteerId': volunteerId,
      'volunteerName': volunteerName,
      'volunteeredAt': FieldValue.serverTimestamp(),
      'status': 'pending',
    });
    
    // Increment volunteersCount and pendingVolunteersCount
    await taskRef.update({
      'volunteersCount': FieldValue.increment(1),
      'pendingVolunteersCount': FieldValue.increment(1),
      'updatedAt': FieldValue.serverTimestamp(),
    });

    // Create notification for task requester (client-side, Firestore only).
    try {
      final taskSnap = await _tasksCollection.doc(taskId).get();
      final taskData = taskSnap.data() as Map<String, dynamic>?;
      final requesterId = taskData?['requesterId'] as String?;
      final requesterName = taskData?['requesterName'] as String? ?? 'Unknown';
      final taskTitle = taskData?['title'] as String? ?? 'Unknown Task';
      
      // Record this interaction for the volunteer (for Activity Log)
      if (volunteerId.isNotEmpty) {
        await recordUserTaskInteraction(
          volunteerId,
          taskId,
          taskTitle,
          requesterId ?? '',
          requesterName,
        );
      }
      
      if (requesterId != null && requesterId != volunteerId) {
        final batch = FirestoreService.instance.batch();
        final notifRef =
            FirestoreService.instance.collection('notifications').doc();
        batch.set(notifRef, {
          'userId': requesterId,
          'senderId': volunteerId,
          'type': 'task_volunteer',
          'taskId': taskId,
          'isRead': false,
          'message': '$volunteerName volunteered for your errand',
          'createdAt': FieldValue.serverTimestamp(),
        });
        final userRef =
            FirestoreService.instance.collection('users').doc(requesterId);
        batch.set(
          userRef,
          {'unreadNotificationCount': FieldValue.increment(1)},
          SetOptions(merge: true),
        );
        await batch.commit();
      }
    } catch (e) {
      print('FAILED to create task volunteer notification for task $taskId: $e');
    }
  }

  /// Stream of current user's volunteer record for a task (if any). Map keys: volunteerDocId, status (pending|accepted|rejected).
  static Stream<Map<String, dynamic>?> getMyVolunteerStatusStream(String taskId, String userId) {
    return _tasksCollection
        .doc(taskId)
        .collection('volunteers')
        .where('volunteerId', isEqualTo: userId)
        .limit(1)
        .snapshots()
        .map((snapshot) {
          if (snapshot.docs.isEmpty) return null;
          final doc = snapshot.docs.first;
          final data = doc.data();
          return <String, dynamic>{
            'volunteerDocId': doc.id,
            'status': data['status'] as String? ?? 'pending',
            'volunteerId': data['volunteerId'],
            'volunteerName': data['volunteerName'],
          };
        });
  }

  /// Get volunteers for a task
  static Stream<List<Map<String, dynamic>>> getVolunteersStream(String taskId) {
    return _tasksCollection
        .doc(taskId)
        .collection('volunteers')
        .orderBy('volunteeredAt', descending: false)
        .snapshots()
        .map((snapshot) => snapshot.docs
            .map((doc) {
                  final data = doc.data() as Map<String, dynamic>;
                  return <String, dynamic>{
                    'volunteerDocId': doc.id,
                    ...data,
                    'volunteeredAt': FirestoreService.parseTimestamp(data['volunteeredAt']),
                    'acceptedAt': data['acceptedAt'] != null
                        ? FirestoreService.parseTimestamp(data['acceptedAt'])
                        : null,
                  };
                })
            .toList());
  }

  /// Accept a volunteer
  static Future<void> acceptVolunteer(
    String taskId,
    String volunteerDocId,
    String requesterId,
  ) async {
    final taskRef = _tasksCollection.doc(taskId);
    final volunteersRef = taskRef.collection('volunteers');
    final volunteerDoc = await volunteersRef.doc(volunteerDocId).get();
    
    if (!volunteerDoc.exists) {
      throw Exception('Volunteer not found');
    }
    
    final volunteerData = volunteerDoc.data() as Map<String, dynamic>;
    final volunteerId = volunteerData['volunteerId'] as String;
    final volunteerName = volunteerData['volunteerName'] as String;
    
    // Update volunteer status
    await volunteersRef.doc(volunteerDocId).update({
      'status': 'accepted',
      'acceptedAt': FieldValue.serverTimestamp(),
      'acceptedBy': requesterId,
    });
    
    // Update task with assigned volunteer and decrement pendingVolunteersCount
    await taskRef.update({
      'assignedTo': volunteerId,
      'assignedByName': volunteerName,
      'status': 'ongoing',
      'pendingVolunteersCount': FieldValue.increment(-1),
      'updatedAt': FieldValue.serverTimestamp(),
    });

    // Notify the volunteer that they were accepted (Firestore-only).
    try {
      final batch = FirestoreService.instance.batch();
      final notifRef =
          FirestoreService.instance.collection('notifications').doc();
      batch.set(notifRef, {
        'userId': volunteerId,
        'senderId': requesterId,
        'type': 'volunteer_accepted',
        'taskId': taskId,
        'isRead': false,
        'message': 'You were accepted as volunteer for an errand',
        'createdAt': FieldValue.serverTimestamp(),
      });
      final userRef =
          FirestoreService.instance.collection('users').doc(volunteerId);
      batch.set(
        userRef,
        {'unreadNotificationCount': FieldValue.increment(1)},
        SetOptions(merge: true),
      );
      await batch.commit();
    } catch (e) {
      print('FAILED to create volunteer_accepted notification for task $taskId: $e');
    }
  }

  /// Cancel own volunteer application (only while pending)
  static Future<void> cancelVolunteer(String taskId, String volunteerId) async {
    final taskRef = _tasksCollection.doc(taskId);
    final volunteersRef = taskRef.collection('volunteers');
    final query = await volunteersRef
        .where('volunteerId', isEqualTo: volunteerId)
        .limit(1)
        .get();
    if (query.docs.isEmpty) {
      throw Exception('No volunteer application found');
    }
    final doc = query.docs.first;
    final status = doc.data()['status'] as String? ?? 'pending';
    if (status != 'pending') {
      throw Exception('Only pending applications can be cancelled');
    }
    await volunteersRef.doc(doc.id).delete();
    await taskRef.update({
      'volunteersCount': FieldValue.increment(-1),
      'pendingVolunteersCount': FieldValue.increment(-1),
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }

  /// Reject a volunteer (owner only). If they were the accepted one, revert task.
  static Future<void> rejectVolunteer(String taskId, String volunteerDocId) async {
    final taskRef = _tasksCollection.doc(taskId);
    final volunteerDoc = await taskRef.collection('volunteers').doc(volunteerDocId).get();
    if (!volunteerDoc.exists) {
      throw Exception('Volunteer not found');
    }
    final data = volunteerDoc.data() as Map<String, dynamic>?;
    final volunteerId = data?['volunteerId'] as String?;
    final status = data?['status'] as String? ?? 'pending';
    final taskSnap = await taskRef.get();
    final taskData = taskSnap.data() as Map<String, dynamic>?;
    final assignedTo = taskData?['assignedTo'] as String?;

    // If this volunteer was the accepted one, fully unassign and remove their record
    // so they can volunteer again in the future.
    if (status == 'accepted') {
      await taskRef.collection('volunteers').doc(volunteerDocId).delete();
      await taskRef.update({
        'assignedTo': null,
        'assignedByName': null,
        'status': 'open',
        'volunteersCount': FieldValue.increment(-1),
        'updatedAt': FieldValue.serverTimestamp(),
      });
      return;
    }

    // For pending volunteers, delete their record so they can re-apply
    await taskRef.collection('volunteers').doc(volunteerDocId).delete();

    // Decrement counters for rejected pending volunteer
    await taskRef.update({
      'volunteersCount': FieldValue.increment(-1),
      'pendingVolunteersCount': FieldValue.increment(-1),
      'updatedAt': FieldValue.serverTimestamp(),
    });

    if (volunteerId != null && assignedTo == volunteerId) {
      await taskRef.update({
        'assignedTo': null,
        'assignedByName': null,
        'status': 'open',
        'updatedAt': FieldValue.serverTimestamp(),
      });
    }
  }
}
