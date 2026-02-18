import 'package:cloud_firestore/cloud_firestore.dart';

class ProductModel {
  final String id;
  final String sellerId;
  final String sellerName;
  final String title;
  final String description;
  final double price;
  final List<String> imageUrls;
  final String category;
  final DateTime createdAt;
  final DateTime? updatedAt;
  final bool isAvailable;
  final String location;
  final String contactNumber;
  final int messagesCount;
  /// Gatekeeper: Pending (awaiting admin approval) or Approved (visible on feed/market).
  final String status;

  ProductModel({
    required this.id,
    required this.sellerId,
    required this.sellerName,
    required this.title,
    required this.description,
    required this.price,
    this.imageUrls = const [],
    this.category = 'General',
    required this.createdAt,
    this.updatedAt,
    this.isAvailable = true,
    this.location = 'Location not specified',
    this.contactNumber = '',
    this.messagesCount = 0,
    this.status = 'Pending',
  });

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'sellerId': sellerId,
      'sellerName': sellerName,
      'title': title,
      'description': description,
      'price': price,
      'imageUrls': imageUrls,
      'category': category,
      'createdAt': Timestamp.fromDate(createdAt),
      'updatedAt': updatedAt != null ? Timestamp.fromDate(updatedAt!) : null,
      'isAvailable': isAvailable,
      'location': location,
      'contactNumber': contactNumber,
      'messagesCount': messagesCount,
      'status': status,
    };
  }

  factory ProductModel.fromJson(Map<String, dynamic> json) {
    return ProductModel(
      id: json['id'] as String? ?? '',
      sellerId: json['sellerId'] as String? ?? '',
      sellerName: json['sellerName'] as String? ?? '',
      title: json['title'] as String? ?? '',
      description: json['description'] as String? ?? '',
      price: (json['price'] as num?)?.toDouble() ?? 0.0,
      imageUrls: (json['imageUrls'] as List<dynamic>?)
              ?.map((e) => e as String)
              .toList() ??
          [],
      category: json['category'] as String? ?? 'General',
      createdAt: _parseTimestamp(json['createdAt']),
      updatedAt: json['updatedAt'] != null ? _parseTimestamp(json['updatedAt']) : null,
      isAvailable: json['isAvailable'] as bool? ?? true,
      location: json['location'] as String? ?? 'Location not specified',
      contactNumber: json['contactNumber'] as String? ?? '',
      messagesCount: (json['messagesCount'] as num?)?.toInt() ?? 0,
      status: json['status'] as String? ?? 'Approved',
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

  // Factory method for Firestore documents (missing status => Approved for backward compatibility)
  factory ProductModel.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return ProductModel.fromJson({
      ...data,
      'id': doc.id,
      'status': data['status'] as String? ?? 'Approved',
    });
  }
}

