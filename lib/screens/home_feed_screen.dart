import 'package:flutter/material.dart';
import '../widgets/announcement_card.dart';
import '../widgets/errand_job_card.dart';
import '../widgets/product_card.dart';
import '../models/product_model.dart';

class HomeFeedScreen extends StatefulWidget {
  const HomeFeedScreen({super.key});

  @override
  State<HomeFeedScreen> createState() => _HomeFeedScreenState();
}

class _HomeFeedScreenState extends State<HomeFeedScreen> {
  // Mixed feed: Announcements, Errands/Jobs, and Products
  final List<Map<String, dynamic>> _feed = [
    {
      'type': 'announcement',
      'title': 'Health Check-up Schedule',
      'description':
          'Free health check-up for all residents will be held on Saturday, 10 AM at the Barangay Hall. Please bring your health cards.',
      'postedBy': 'Barangay Official',
      'date': DateTime.now().subtract(const Duration(days: 1)),
      'category': 'Health',
      'unreadCount': 21,
      'isRead': false,
    },
    {
      'type': 'request',
      'title': 'Need help carrying rice sacks',
      'description':
          'I need help carrying 10 sacks of rice from the truck to my storage. The truck will arrive tomorrow morning at 8 AM. Looking for 2-3 strong volunteers.',
      'postedBy': 'Maria Santos',
      'date': DateTime.now().subtract(const Duration(hours: 3)),
      'status': ErrandJobStatus.open,
      'statusLabel': 'Open',
    },
    {
      'type': 'product',
      'product': ProductModel(
        id: '1',
        sellerId: 'vendor1',
        sellerName: 'Juan Dela Cruz',
        title: 'Fresh Eggplants',
        description: 'Fresh eggplants available for sale',
        price: 50.00,
        category: 'Food',
        createdAt: DateTime.now().subtract(const Duration(days: 1)),
        isAvailable: true,
        imageUrls: const [
          'https://images.unsplash.com/photo-1514996937319-344454492b37',
        ],
      ),
    },
    {
      'type': 'announcement',
      'title': 'Livelihood Training Program',
      'description':
          'Free livelihood training program for all residents. Learn new skills and start your own business. Registration starts next week.',
      'postedBy': 'Barangay Official',
      'date': DateTime.now().subtract(const Duration(days: 2)),
      'category': 'Livelihood',
      'unreadCount': 15,
      'isRead': true,
    },
    {
      'type': 'request',
      'title': 'Looking for Tutor',
      'description':
          'My daughter needs help with Math and Science subjects. Grade 6 level. Looking for someone who can tutor 2-3 times a week in the afternoon.',
      'postedBy': 'Juan Dela Cruz',
      'date': DateTime.now().subtract(const Duration(days: 1)),
      'status': ErrandJobStatus.ongoing,
      'statusLabel': 'Ongoing',
      'volunteerName': 'Ana Garcia',
    },
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey.shade100,
      body: SafeArea(
        child: Column(
          children: [
            // Title and Search icon row
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    'Home',
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: Colors.black87,
                    ),
                  ),
                  IconButton(
                    icon: Icon(Icons.search, color: Colors.grey.shade800),
                    onPressed: () {
                      debugPrint('Search pressed');
                    },
                  ),
                ],
              ),
            ),
            
            const SizedBox(height: 8),
            
            // Mixed feed list
            Expanded(
              child: _feed.isEmpty
                  ? Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.home, size: 64, color: Colors.grey[400]),
                          const SizedBox(height: 16),
                          Text(
                            'No posts yet',
                            style: TextStyle(fontSize: 18, color: Colors.grey[600]),
                          ),
                        ],
                      ),
                    )
                  : Scrollbar(
                      thumbVisibility: false,
                      child: ListView.separated(
                        padding: const EdgeInsets.symmetric(vertical: 8),
                        physics: const ClampingScrollPhysics(),
                        itemCount: _feed.length,
                        separatorBuilder: (context, index) => const SizedBox(height: 0),
                        itemBuilder: (context, index) {
                          final item = _feed[index];
                          final type = item['type'] as String;
                          
                          if (type == 'announcement') {
                            return AnnouncementCard(
                              title: item['title'] as String,
                              description: item['description'] as String,
                              postedBy: item['postedBy'] as String,
                              date: item['date'] as DateTime,
                              category: item['category'] as String?,
                              unreadCount: item['unreadCount'] as int?,
                              isRead: item['isRead'] as bool? ?? false,
                              onMarkAsReadPressed: () {
                                setState(() {
                                  item['isRead'] = true;
                                });
                                debugPrint('Mark as read pressed for: ${item['title']}');
                              },
                            );
                          } else if (type == 'request') {
                            return ErrandJobCard(
                              title: item['title'] as String,
                              description: item['description'] as String,
                              postedBy: item['postedBy'] as String,
                              date: item['date'] as DateTime,
                              status: item['status'] as ErrandJobStatus?,
                              statusLabel: item['statusLabel'] as String?,
                              volunteerName: item['volunteerName'] as String?,
                              onViewPressed: () {
                                debugPrint('View pressed for: ${item['title']}');
                              },
                              onVolunteerPressed: item['volunteerName'] == null
                                  ? () {
                                      debugPrint('Volunteer pressed for: ${item['title']}');
                                    }
                                  : null,
                            );
                          } else if (type == 'product') {
                            return ProductCard(product: item['product'] as ProductModel);
                          }
                          return const SizedBox.shrink();
                        },
                      ),
                    ),
            ),
          ],
        ),
      ),
    );
  }
}


