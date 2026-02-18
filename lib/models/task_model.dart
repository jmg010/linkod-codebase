import 'package:cloud_firestore/cloud_firestore.dart';

class TaskModel {
  final String id;
  final String title;
  final String description;
  final String requesterName;
  final String requesterId;
  final String? assignedTo;
  final String? assignedByName;
  final DateTime createdAt;
  final DateTime? updatedAt;
  final DateTime? dueDate;
  final TaskStatus status;
  final TaskPriority priority;
  final String? contactNumber;
  final int volunteersCount;
  final bool isActive;
  /// Gatekeeper: Pending (awaiting admin) or Approved (visible on feed).
  final String approvalStatus;
  /// Task category for filtering (e.g. General, Labor, Tutoring).
  final String? category;

  TaskModel({
    required this.id,
    required this.title,
    required this.description,
    required this.requesterName,
    required this.requesterId,
    this.assignedTo,
    this.assignedByName,
    required this.createdAt,
    this.updatedAt,
    this.dueDate,
    this.status = TaskStatus.open,
    this.priority = TaskPriority.medium,
    this.contactNumber,
    this.volunteersCount = 0,
    this.isActive = true,
    this.approvalStatus = 'Pending',
    this.category,
  });

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'title': title,
      'description': description,
      'requesterName': requesterName,
      'requesterId': requesterId,
      'assignedTo': assignedTo,
      'assignedByName': assignedByName,
      'createdAt': Timestamp.fromDate(createdAt),
      'updatedAt': updatedAt != null ? Timestamp.fromDate(updatedAt!) : null,
      'dueDate': dueDate != null ? Timestamp.fromDate(dueDate!) : null,
      'status': status.name,
      'priority': priority.name,
      'contactNumber': contactNumber,
      'volunteersCount': volunteersCount,
      'isActive': isActive,
      'approvalStatus': approvalStatus,
      'category': category,
    };
  }

  factory TaskModel.fromJson(Map<String, dynamic> json) {
    return TaskModel(
      id: json['id'] as String? ?? '',
      title: json['title'] as String? ?? '',
      description: json['description'] as String? ?? '',
      requesterName: json['requesterName'] as String? ?? '',
      requesterId: json['requesterId'] as String? ?? '',
      assignedTo: json['assignedTo'] as String?,
      assignedByName: json['assignedByName'] as String?,
      createdAt: _parseTimestamp(json['createdAt']),
      updatedAt: json['updatedAt'] != null ? _parseTimestamp(json['updatedAt']) : null,
      dueDate: json['dueDate'] != null ? _parseTimestamp(json['dueDate']) : null,
      status: TaskStatus.values.firstWhere(
        (e) => e.name == json['status'],
        orElse: () => TaskStatus.open,
      ),
      priority: TaskPriority.values.firstWhere(
        (e) => e.name == json['priority'],
        orElse: () => TaskPriority.medium,
      ),
      contactNumber: json['contactNumber'] as String?,
      volunteersCount: (json['volunteersCount'] as num?)?.toInt() ?? 0,
      isActive: json['isActive'] as bool? ?? true,
      approvalStatus: json['approvalStatus'] as String? ?? 'Approved',
      category: json['category'] as String?,
    );
  }

  // Helper to parse Firestore Timestamp or ISO string
  static DateTime _parseTimestamp(dynamic timestamp) {
    if (timestamp == null) return DateTime.now();
    if (timestamp is DateTime) return timestamp;
    if (timestamp is Timestamp) return timestamp.toDate();
    if (timestamp is String) {
      try {
        return DateTime.parse(timestamp);
      } catch (e) {
        return DateTime.now();
      }
    }
    return DateTime.now();
  }

  // Factory method for Firestore documents (missing approvalStatus => Approved for backward compat)
  factory TaskModel.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return TaskModel.fromJson({
      ...data,
      'id': doc.id,
      'approvalStatus': data['approvalStatus'] as String? ?? 'Approved',
    });
  }
}

enum TaskStatus {
  open('Open'),
  ongoing('Ongoing'),
  completed('Completed');

  const TaskStatus(this.displayName);
  final String displayName;
}

enum TaskPriority {
  low,
  medium,
  high,
  urgent,
}
