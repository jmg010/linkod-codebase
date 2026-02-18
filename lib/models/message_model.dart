import 'package:cloud_firestore/cloud_firestore.dart';

/// Message in a product's messages subcollection. Supports top-level and replies via [parentId].
class MessageModel {
  final String id;
  final String senderId;
  final String senderName;
  final String message;
  final bool isSeller;
  final DateTime createdAt;
  /// If non-null, this message is a reply to the message with this ID.
  final String? parentId;

  MessageModel({
    required this.id,
    required this.senderId,
    required this.senderName,
    required this.message,
    required this.isSeller,
    required this.createdAt,
    this.parentId,
  });

  Map<String, dynamic> toMap() {
    return {
      'senderId': senderId,
      'senderName': senderName,
      'message': message,
      'isSeller': isSeller,
      'createdAt': Timestamp.fromDate(createdAt),
      if (parentId != null) 'parentId': parentId,
    };
  }

  factory MessageModel.fromMap(Map<String, dynamic> map, {String? id}) {
    final docId = id ?? map['messageId'] as String? ?? '';
    return MessageModel(
      id: docId,
      senderId: map['senderId'] as String? ?? '',
      senderName: map['senderName'] as String? ?? 'Unknown',
      message: map['message'] as String? ?? '',
      isSeller: map['isSeller'] as bool? ?? false,
      createdAt: _parseTimestamp(map['createdAt']),
      parentId: map['parentId'] as String?,
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
