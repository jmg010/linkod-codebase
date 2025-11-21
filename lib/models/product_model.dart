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
  final bool isAvailable;
  final String location;
  final String contactNumber;

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
    this.isAvailable = true,
    this.location = 'Location not specified',
    this.contactNumber = '',
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
      'createdAt': createdAt.toIso8601String(),
      'isAvailable': isAvailable,
      'location': location,
      'contactNumber': contactNumber,
    };
  }

  factory ProductModel.fromJson(Map<String, dynamic> json) {
    return ProductModel(
      id: json['id'] as String,
      sellerId: json['sellerId'] as String,
      sellerName: json['sellerName'] as String,
      title: json['title'] as String,
      description: json['description'] as String,
      price: (json['price'] as num).toDouble(),
      imageUrls: (json['imageUrls'] as List<dynamic>?)
              ?.map((e) => e as String)
              .toList() ??
          [],
      category: json['category'] as String? ?? 'General',
      createdAt: DateTime.parse(json['createdAt'] as String),
      isAvailable: json['isAvailable'] as bool? ?? true,
      location: json['location'] as String? ?? 'Location not specified',
      contactNumber: json['contactNumber'] as String? ?? '',
    );
  }
}

