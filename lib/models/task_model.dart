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
  /// Number of volunteers currently in "pending" status. Used for errand badge counts.
  final int pendingVolunteersCount;
  final bool isActive;
  /// Gatekeeper: Pending (awaiting admin) or Approved (visible on feed).
  final String approvalStatus;
  /// Task category for filtering (e.g. General, Labor, Tutoring).
  final String? category;
  /// Optional image URLs for the errand post (owner-attached).
  final List<String> imageUrls;
  /// Optional location/purok (e.g. "Purok Uno") for Barangay Cagbaoto.
  final String? location;

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
    this.pendingVolunteersCount = 0,
    this.isActive = true,
    this.approvalStatus = 'Pending',
    this.category,
    this.imageUrls = const [],
    this.location,
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
      'pendingVolunteersCount': pendingVolunteersCount,
      'isActive': isActive,
      'approvalStatus': approvalStatus,
      'category': category,
      'imageUrls': imageUrls,
      'location': location,
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
      pendingVolunteersCount:
          (json['pendingVolunteersCount'] as num?)?.toInt() ?? 0,
      isActive: json['isActive'] as bool? ?? true,
      approvalStatus: json['approvalStatus'] as String? ?? 'Approved',
      category: json['category'] as String?,
      imageUrls: _parseStringList(json['imageUrls']),
      location: json['location'] as String?,
    );
  }

  static List<String> _parseStringList(dynamic value) {
    if (value == null) return [];
    if (value is! List) return [];
    return value
        .map((e) => e?.toString().trim())
        .whereType<String>()
        .where((s) => s.isNotEmpty)
        .toList();
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
      'imageUrls': data['imageUrls'],
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
