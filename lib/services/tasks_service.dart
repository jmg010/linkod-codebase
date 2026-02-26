import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/task_model.dart';
import 'firestore_service.dart';

class TasksService {
  static final CollectionReference _tasksCollection =
      FirestoreService.instance.collection('tasks');

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
    final volunteersRef = _tasksCollection.doc(taskId).collection('volunteers');
    
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
    
    // Increment volunteersCount
    await _tasksCollection.doc(taskId).update({
      'volunteersCount': FieldValue.increment(1),
    });

    // Create notification for task requester (client-side, Firestore only).
    try {
      final taskSnap = await _tasksCollection.doc(taskId).get();
      final taskData = taskSnap.data() as Map<String, dynamic>?;
      final requesterId = taskData?['requesterId'] as String?;
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
    final volunteersRef = _tasksCollection.doc(taskId).collection('volunteers');
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
    
    // Update task with assigned volunteer
    await _tasksCollection.doc(taskId).update({
      'assignedTo': volunteerId,
      'assignedByName': volunteerName,
      'status': 'ongoing',
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }

  /// Cancel own volunteer application (only while pending)
  static Future<void> cancelVolunteer(String taskId, String volunteerId) async {
    final volunteersRef = _tasksCollection.doc(taskId).collection('volunteers');
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
    await _tasksCollection.doc(taskId).update({
      'volunteersCount': FieldValue.increment(-1),
    });
  }

  /// Reject a volunteer (owner only). If they were the accepted one, revert task.
  static Future<void> rejectVolunteer(String taskId, String volunteerDocId) async {
    final taskRef = _tasksCollection.doc(taskId);
    final volunteerDoc = await taskRef.collection('volunteers').doc(volunteerDocId).get();
    if (!volunteerDoc.exists) {
      throw Exception('Volunteer not found');
    }
    final volunteerId = volunteerDoc.data()?['volunteerId'] as String?;
    final taskSnap = await taskRef.get();
    final taskData = taskSnap.data() as Map<String, dynamic>?;
    final assignedTo = taskData?['assignedTo'] as String?;

    await taskRef.collection('volunteers').doc(volunteerDocId).update({
      'status': 'rejected',
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
