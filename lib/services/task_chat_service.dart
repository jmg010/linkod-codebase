import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/task_chat_message_model.dart';
import 'firestore_service.dart';
import 'tasks_service.dart';

/// Chat between task owner and approved volunteer only.
/// Paths: tasks/{taskId}/chat_messages/{messageId}, tasks/{taskId}/chat_read/{userId}.
class TaskChatService {
  static DocumentReference<Map<String, dynamic>> _taskRef(String taskId) =>
      FirestoreService.instance.collection('tasks').doc(taskId);

  static CollectionReference<Map<String, dynamic>> _messagesRef(
    String taskId,
  ) => _taskRef(taskId).collection('chat_messages');

  static DocumentReference<Map<String, dynamic>> _readDoc(
    String taskId,
    String userId,
  ) => _taskRef(taskId).collection('chat_read').doc(userId);

  /// Stream of messages for this task chat (owner + approved volunteer only).
  static Stream<List<TaskChatMessageModel>> getMessagesStream(String taskId) {
    return _messagesRef(
      taskId,
    ).orderBy('createdAt', descending: false).snapshots().map((snapshot) {
      return snapshot.docs.map((doc) {
        final data = doc.data();
        return TaskChatMessageModel.fromMap({
          ...data,
          'createdAt': FirestoreService.parseTimestamp(data['createdAt']),
        }, id: doc.id);
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

    // Notify the other chat participant about new chat messages (Firestore-only).
    try {
      final taskSnap = await _taskRef(taskId).get();
      final taskData = taskSnap.data();
      final requesterId = taskData?['requesterId'] as String?;
      final assignedTo = taskData?['assignedTo'] as String?;

      String? receiverId;
      if (requesterId != null && requesterId.isNotEmpty) {
        receiverId = senderId == requesterId ? assignedTo : requesterId;
      }

      if (receiverId != null &&
          receiverId.isNotEmpty &&
          receiverId != senderId) {
        // Idempotent notification key: same messageId + receiver should create only once.
        final notifDocId = 'task_chat_${taskId}_${docRef.id}_${receiverId}';
        final notifRef = FirestoreService.instance
            .collection('notifications')
            .doc(notifDocId);
        final userRef = FirestoreService.instance
            .collection('users')
            .doc(receiverId);

        await FirestoreService.instance.runTransaction((tx) async {
          final existing = await tx.get(notifRef);
          if (existing.exists) return;

          tx.set(notifRef, {
            'userId': receiverId,
            'senderId': senderId,
            'type': 'task_chat_message',
            'taskId': taskId,
            'messageId': docRef.id,
            'isRead': false,
            'message': '$senderName sent you a message in your errand chat',
            'createdAt': FieldValue.serverTimestamp(),
          });
          tx.set(userRef, {
            'unreadNotificationCount': FieldValue.increment(1),
          }, SetOptions(merge: true));
        });
      }
    } catch (e) {
      print('FAILED to create task chat notification for task $taskId: $e');
    }

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
        final data = readSnap.data();
        final lastReadAt =
            data?['lastReadAt'] != null
                ? (data!['lastReadAt'] as Timestamp).toDate()
                : DateTime(1970);
        return messages
            .where(
              (m) =>
                  m.senderId != currentUserId &&
                  m.createdAt.isAfter(lastReadAt),
            )
            .length;
      });
    });
  }

  /// Total unread task chat count for this user (across all tasks where they are requester or assigned).
  /// Reactive: updates when any task's unread count changes (e.g. after markChatRead).
  static Stream<int> getTotalUnreadForUserStream(String uid) {
    final controller = StreamController<int>.broadcast();
    final Map<String, int> unreadByTask = {};
    final Map<String, StreamSubscription<int>> taskSubs = {};
    List<String> currentTaskIds = [];

    void emitSum() {
      if (!controller.isClosed) {
        final sum = currentTaskIds.fold<int>(
          0,
          (s, id) => s + (unreadByTask[id] ?? 0),
        );
        controller.add(sum);
      }
    }

    void setTaskIds(List<String> ids) {
      final newSet = ids.toSet();
      for (final id in taskSubs.keys.toList()) {
        if (!newSet.contains(id)) {
          taskSubs[id]?.cancel();
          taskSubs.remove(id);
          unreadByTask.remove(id);
        }
      }
      currentTaskIds = newSet.toList();
      for (final id in newSet) {
        if (taskSubs.containsKey(id)) continue;
        final sub = getUnreadCountStream(id, uid).listen((count) {
          unreadByTask[id] = count;
          emitSum();
        });
        taskSubs[id] = sub;
      }
      emitSum();
    }

    StreamSubscription? reqSub;
    StreamSubscription? assSub;

    reqSub = TasksService.getRequesterTasksStream(uid).listen((rList) {
      TasksService.getAssignedTasksStream(uid).first.then((aList) {
        final ids = [...rList.map((t) => t.id), ...aList.map((t) => t.id)];
        setTaskIds(ids);
      });
    });
    assSub = TasksService.getAssignedTasksStream(uid).listen((aList) {
      TasksService.getRequesterTasksStream(uid).first.then((rList) {
        final ids = [...rList.map((t) => t.id), ...aList.map((t) => t.id)];
        setTaskIds(ids);
      });
    });

    controller.onListen = () {
      if (!controller.isClosed) emitSum();
    };
    // Do not cancel source when last listener cancels so badge stays correct when returning to screen.
    controller.onCancel = () {};

    return controller.stream;
  }

  /// Total unread for tasks where user is the REQUESTER (for MY POSTS tab badge)
  static Stream<int> getTotalUnreadForRequesterStream(String uid) {
    final controller = StreamController<int>.broadcast();
    final Map<String, int> unreadByTask = {};
    final Map<String, StreamSubscription<int>> taskSubs = {};
    List<String> currentTaskIds = [];

    void emitSum() {
      if (!controller.isClosed) {
        final sum = currentTaskIds.fold<int>(
          0,
          (s, id) => s + (unreadByTask[id] ?? 0),
        );
        controller.add(sum);
      }
    }

    void setTaskIds(List<String> ids) {
      final newSet = ids.toSet();
      for (final id in taskSubs.keys.toList()) {
        if (!newSet.contains(id)) {
          taskSubs[id]?.cancel();
          taskSubs.remove(id);
          unreadByTask.remove(id);
        }
      }
      currentTaskIds = newSet.toList();
      for (final id in newSet) {
        if (taskSubs.containsKey(id)) continue;
        final sub = getUnreadCountStream(id, uid).listen((count) {
          unreadByTask[id] = count;
          emitSum();
        });
        taskSubs[id] = sub;
      }
      emitSum();
    }

    final reqSub = TasksService.getRequesterTasksStream(uid).listen((rList) {
      setTaskIds(rList.map((t) => t.id).toList());
    });

    controller.onListen = () {
      if (!controller.isClosed) emitSum();
    };
    controller.onCancel = () {
      reqSub.cancel();
      for (final s in taskSubs.values) {
        s.cancel();
      }
    };

    return controller.stream;
  }

  /// Total unread for tasks where user is ASSIGNED (for INTERACTED POSTS tab badge)
  static Stream<int> getTotalUnreadForAssignedStream(String uid) {
    final controller = StreamController<int>.broadcast();
    final Map<String, int> unreadByTask = {};
    final Map<String, StreamSubscription<int>> taskSubs = {};
    List<String> currentTaskIds = [];

    void emitSum() {
      if (!controller.isClosed) {
        final sum = currentTaskIds.fold<int>(
          0,
          (s, id) => s + (unreadByTask[id] ?? 0),
        );
        controller.add(sum);
      }
    }

    void setTaskIds(List<String> ids) {
      final newSet = ids.toSet();
      for (final id in taskSubs.keys.toList()) {
        if (!newSet.contains(id)) {
          taskSubs[id]?.cancel();
          taskSubs.remove(id);
          unreadByTask.remove(id);
        }
      }
      currentTaskIds = newSet.toList();
      for (final id in newSet) {
        if (taskSubs.containsKey(id)) continue;
        final sub = getUnreadCountStream(id, uid).listen((count) {
          unreadByTask[id] = count;
          emitSum();
        });
        taskSubs[id] = sub;
      }
      emitSum();
    }

    final assSub = TasksService.getAssignedTasksStream(uid).listen((aList) {
      setTaskIds(aList.map((t) => t.id).toList());
    });

    controller.onListen = () {
      if (!controller.isClosed) emitSum();
    };
    controller.onCancel = () {
      assSub.cancel();
      for (final s in taskSubs.values) {
        s.cancel();
      }
    };

    return controller.stream;
  }
}
