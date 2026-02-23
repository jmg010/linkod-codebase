import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/task_chat_message_model.dart';
import 'firestore_service.dart';

/// Chat between task owner and approved volunteer only.
/// Paths: tasks/{taskId}/chat_messages/{messageId}, tasks/{taskId}/chat_read/{userId}.
class TaskChatService {
  static DocumentReference<Map<String, dynamic>> _taskRef(String taskId) =>
      FirestoreService.instance.collection('tasks').doc(taskId);

  static CollectionReference<Map<String, dynamic>> _messagesRef(String taskId) =>
      _taskRef(taskId).collection('chat_messages');

  static DocumentReference<Map<String, dynamic>> _readDoc(String taskId, String userId) =>
      _taskRef(taskId).collection('chat_read').doc(userId);

  /// Stream of messages for this task chat (owner + approved volunteer only).
  static Stream<List<TaskChatMessageModel>> getMessagesStream(String taskId) {
    return _messagesRef(taskId)
        .orderBy('createdAt', descending: false)
        .snapshots()
        .map((snapshot) {
          return snapshot.docs.map((doc) {
            final data = doc.data() as Map<String, dynamic>;
            return TaskChatMessageModel.fromMap(
              {...data, 'createdAt': FirestoreService.parseTimestamp(data['createdAt'])},
              id: doc.id,
            );
          }).toList();
        });
  }

  /// Send a message. Caller must ensure user is owner or assigned volunteer.
  static Future<String> sendMessage(
    String taskId,
    String senderId,
    String senderName,
    String text,
  ) async {
    final docRef = await _messagesRef(taskId).add({
      'senderId': senderId,
      'senderName': senderName,
      'text': text.trim(),
      'createdAt': FieldValue.serverTimestamp(),
    });
    return docRef.id;
  }

  /// Mark chat as read by this user (updates lastReadAt).
  static Future<void> markChatRead(String taskId, String userId) async {
    await _readDoc(taskId, userId).set({
      'lastReadAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
  }

  /// Stream of unread count for the current user (messages from the other party after lastReadAt).
  /// Listens to both messages and read doc so the badge clears when user opens chat.
  static Stream<int> getUnreadCountStream(String taskId, String currentUserId) {
    return getMessagesStream(taskId).asyncExpand((messages) {
      return _readDoc(taskId, currentUserId).snapshots().map((readSnap) {
        final data = readSnap.data() as Map<String, dynamic>?;
        final lastReadAt = data?['lastReadAt'] != null
            ? (data!['lastReadAt'] as Timestamp).toDate()
            : DateTime(1970);
        return messages
            .where((m) => m.senderId != currentUserId && m.createdAt.isAfter(lastReadAt))
            .length;
      });
    });
  }
}
