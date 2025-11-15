import 'package:flutter/material.dart';
import '../models/post_model.dart';
import '../widgets/post_card.dart';

class AnnouncementsScreen extends StatefulWidget {
  const AnnouncementsScreen({super.key});

  @override
  State<AnnouncementsScreen> createState() => AnnouncementsScreenState();
}

class AnnouncementsScreenState extends State<AnnouncementsScreen> {
  final List<PostModel> _posts = [
    PostModel(
      id: '1',
      userId: 'official1',
      userName: 'Barangay Official',
      title: 'Health Check-up Schedule',
      content:
          'Free health check-up for all residents will be held on Saturday, 10 AM at the Barangay Hall. Please bring your health cards.',
      category: PostCategory.health,
      createdAt: DateTime.now().subtract(const Duration(hours: 2)),
      likesCount: 15,
      commentsCount: 5,
    ),
    PostModel(
      id: '2',
      userId: 'official1',
      userName: 'Barangay Official',
      title: 'Livelihood Training Program',
      content:
          'We are offering free livelihood training programs for interested residents. Topics include: cooking, sewing, and basic computer skills. Registration starts next week.',
      category: PostCategory.livelihood,
      createdAt: DateTime.now().subtract(const Duration(days: 1)),
      likesCount: 32,
      commentsCount: 12,
    ),
    PostModel(
      id: '3',
      userId: 'official1',
      userName: 'Barangay Official',
      title: 'Youth Basketball Tournament',
      content:
          'Calling all youth! Join our annual basketball tournament. Registration is now open. Games will start next month. See you there!',
      category: PostCategory.youthActivity,
      createdAt: DateTime.now().subtract(const Duration(days: 3)),
      likesCount: 48,
      commentsCount: 8,
    ),
    PostModel(
      id: '4',
      userId: 'official1',
      userName: 'Barangay Official',
      title: 'Vaccination Drive',
      content:
          'COVID-19 vaccination drive will be conducted this weekend. All eligible residents are encouraged to participate. Please bring valid ID.',
      category: PostCategory.health,
      createdAt: DateTime.now().subtract(const Duration(days: 5)),
      likesCount: 67,
      commentsCount: 23,
    ),
  ];

  void addPost(PostModel post) {
    setState(() {
      _posts.insert(0, post); // Add to the top of the list
    });
  }

  @override
  Widget build(BuildContext context) {
    if (_posts.isEmpty) {
      return Scaffold(
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                Icons.campaign,
                size: 64,
                color: Colors.grey[400],
              ),
              const SizedBox(height: 16),
              Text(
                'No announcements yet',
                style: TextStyle(
                  fontSize: 18,
                  color: Colors.grey[600],
                ),
              ),
            ],
          ),
        ),
      );
    }

    return Scaffold(
      backgroundColor: Colors.grey.shade100,
      body: ListView.builder(
        itemCount: _posts.length,
        padding: const EdgeInsets.symmetric(vertical: 12),
        itemBuilder: (context, index) {
          return PostCard(post: _posts[index]);
        },
      ),
    );
  }
}
