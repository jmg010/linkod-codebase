import 'package:cloud_firestore/cloud_firestore.dart';

class ProductModel {
  final String id;
  final String sellerId;
  final String sellerName;
  final String title;
  final String description;
  final double price;
  /// Pricing unit (e.g. kg, pcs, piece, bunch, sack). Null = legacy, display may infer from category.
  final String? priceUnit;
  final List<String> imageUrls;
  final String category;
  final DateTime createdAt;
  final DateTime? updatedAt;
  final bool isAvailable;
  final String location;
  final String contactNumber;
  /// Vendor-controlled visibility for residents.
  final bool showLocationToResidents;
  /// Vendor-controlled visibility for residents.
  final bool showContactToResidents;
  final int messagesCount;
  final int viewCount;
  /// Gatekeeper: Pending (awaiting admin approval) or Approved (visible on feed/market).
  final String status;

  ProductModel({
    required this.id,
    required this.sellerId,
    required this.sellerName,
    required this.title,
    required this.description,
    required this.price,
    this.priceUnit,
    this.imageUrls = const [],
    this.category = 'General',
    required this.createdAt,
    this.updatedAt,
    this.isAvailable = true,
    this.location = 'Location not specified',
    this.contactNumber = '',
    this.showLocationToResidents = true,
    this.showContactToResidents = true,
    this.messagesCount = 0,
    this.viewCount = 0,
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
      'priceUnit': priceUnit,
      'imageUrls': imageUrls,
      'category': category,
      'createdAt': Timestamp.fromDate(createdAt),
      'updatedAt': updatedAt != null ? Timestamp.fromDate(updatedAt!) : null,
      'isAvailable': isAvailable,
      'location': location,
      'contactNumber': contactNumber,
      'showLocationToResidents': showLocationToResidents,
      'showContactToResidents': showContactToResidents,
      'messagesCount': messagesCount,
      'viewCount': viewCount,
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
      priceUnit: json['priceUnit'] as String?,
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
        showLocationToResidents:
          json['showLocationToResidents'] as bool? ?? true,
        showContactToResidents: json['showContactToResidents'] as bool? ?? true,
      messagesCount: (json['messagesCount'] as num?)?.toInt() ?? 0,
      viewCount: (json['viewCount'] as num?)?.toInt() ?? 0,
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

