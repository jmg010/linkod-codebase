class TaskModel {
  final String id;
  final String title;
  final String description;
  final String requesterName;
  final String? assignedTo;
  final String? assignedByName;
  final DateTime createdAt;
  final DateTime? dueDate;
  final TaskStatus status;
  final TaskPriority priority;

  TaskModel({
    required this.id,
    required this.title,
    required this.description,
    required this.requesterName,
    this.assignedTo,
    this.assignedByName,
    required this.createdAt,
    this.dueDate,
    this.status = TaskStatus.open,
    this.priority = TaskPriority.medium,
  });

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'title': title,
      'description': description,
      'requesterName': requesterName,
      'assignedTo': assignedTo,
      'assignedByName': assignedByName,
      'createdAt': createdAt.toIso8601String(),
      'dueDate': dueDate?.toIso8601String(),
      'status': status.name,
      'priority': priority.name,
    };
  }

  factory TaskModel.fromJson(Map<String, dynamic> json) {
    return TaskModel(
      id: json['id'] as String,
      title: json['title'] as String,
      description: json['description'] as String,
      requesterName: json['requesterName'] as String,
      assignedTo: json['assignedTo'] as String?,
      assignedByName: json['assignedByName'] as String?,
      createdAt: DateTime.parse(json['createdAt'] as String),
      dueDate: json['dueDate'] != null
          ? DateTime.parse(json['dueDate'] as String)
          : null,
      status: TaskStatus.values.firstWhere(
        (e) => e.name == json['status'],
        orElse: () => TaskStatus.open,
      ),
      priority: TaskPriority.values.firstWhere(
        (e) => e.name == json['priority'],
        orElse: () => TaskPriority.medium,
      ),
    );
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
