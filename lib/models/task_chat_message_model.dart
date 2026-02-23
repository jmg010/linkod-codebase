import 'package:cloud_firestore/cloud_firestore.dart';

/// Message in a task's chat (owner <-> approved volunteer only).
class TaskChatMessageModel {
  final String id;
  final String senderId;
  final String senderName;
  final String text;
  final DateTime createdAt;

  TaskChatMessageModel({
    required this.id,
    required this.senderId,
    required this.senderName,
    required this.text,
    required this.createdAt,
  });

  factory TaskChatMessageModel.fromMap(Map<String, dynamic> map, {String? id}) {
    final docId = id ?? map['messageId'] as String? ?? '';
    return TaskChatMessageModel(
      id: docId,
      senderId: map['senderId'] as String? ?? '',
      senderName: map['senderName'] as String? ?? 'Unknown',
      text: map['text'] as String? ?? '',
      createdAt: _parseTimestamp(map['createdAt']),
    );
  }

  static DateTime _parseTimestamp(dynamic timestamp) {
    if (timestamp == null) return DateTime.now();
    if (timestamp is DateTime) return timestamp;
    if (timestamp is Timestamp) return timestamp.toDate();
    if (timestamp is String) {
      try {
        return DateTime.parse(timestamp);
      } catch (_) {
        return DateTime.now();
      }
    }
    return DateTime.now();
  }
}
