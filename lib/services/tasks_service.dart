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

  /// Reject a volunteer
  static Future<void> rejectVolunteer(String taskId, String volunteerDocId) async {
    await _tasksCollection
        .doc(taskId)
        .collection('volunteers')
        .doc(volunteerDocId)
        .update({
      'status': 'rejected',
    });
  }
}
