import '../models/post_model.dart';
import '../models/product_model.dart';
import '../models/task_model.dart';
import '../widgets/errand_job_card.dart';

/// Centralized dummy data service for the app
/// All screens should use this service to ensure data consistency
class DummyDataService {
  // Singleton pattern
  static final DummyDataService _instance = DummyDataService._internal();
  factory DummyDataService() => _instance;

  // Base date for consistent timestamps
  final DateTime _baseDate = DateTime(2025, 11, 24, 16, 50);

  // Mutable data lists
  final List<Map<String, dynamic>> _announcementsList = [];
  final List<ProductModel> _productsList = [];
  final List<TaskModel> _tasksList = [];
  
  // User profile data
  String? _currentUserProfileImagePath;

  // Initialize data
  DummyDataService._internal() {
    _initializeData();
  }

  void _initializeData() {
    // Initialize announcements
    _announcementsList.addAll([
      {
        'id': 'announcement-1',
        'title': 'Health Check-up Schedule',
        'description':
            'Free health check-up for all residents will be held on Saturday, 10 AM at the Barangay Hall. Please bring your health cards.',
        'postedBy': 'Barangay Official',
        'date': _baseDate.subtract(const Duration(days: 1)),
        'category': 'Health',
        'unreadCount': 21,
        'viewCount': 21,
        'isRead': false,
      },
      {
        'id': 'announcement-2',
        'title': 'Livelihood Training Program',
        'description':
            'Free livelihood training program for all residents. Learn new skills and start your own business. Registration starts next week.',
        'postedBy': 'Barangay Official',
        'date': _baseDate.subtract(const Duration(days: 2)),
        'category': 'Livelihood',
        'unreadCount': 0,
        'viewCount': 15,
        'isRead': true,
      },
    ]);

    // Initialize products
    _productsList.addAll([
      ProductModel(
        id: 'product-1',
        sellerId: 'vendor1',
        sellerName: 'Juan Dela Cruz',
        title: 'Fresh Eggplants',
        description: 'Fresh eggplants available for sale',
        price: 50.00,
        category: 'Food',
        createdAt: _baseDate.subtract(const Duration(days: 1)),
        isAvailable: true,
        imageUrls: const [
          'https://images.unsplash.com/photo-1514996937319-344454492b37',
        ],
      ),
      ProductModel(
        id: 'product-2',
        sellerId: 'vendor1',
        sellerName: 'Maria\'s Store',
        title: 'Fresh Vegetables Bundle',
        description:
            'Fresh vegetables from local farms. Includes tomatoes, onions, and leafy greens.',
        price: 150.00,
        category: 'Food',
        createdAt: _baseDate.subtract(const Duration(hours: 5)),
        isAvailable: true,
        location: 'Purok 4 Kidid sa daycare center',
        contactNumber: '0978192739813',
        imageUrls: const [
          'https://images.unsplash.com/photo-1514996937319-344454492b37',
        ],
      ),
      ProductModel(
        id: 'product-3',
        sellerId: 'vendor2',
        sellerName: 'Juan\'s Crafts',
        title: 'Handmade Woven Basket',
        description:
            'Beautiful handwoven basket perfect for storage or decoration. Made with natural materials.',
        price: 350.00,
        category: 'Handicrafts',
        createdAt: _baseDate.subtract(const Duration(days: 1)),
        isAvailable: true,
        imageUrls: const [
          'https://images.unsplash.com/photo-1523419409543-0c1df022bdd1',
        ],
      ),
      ProductModel(
        id: 'product-4',
        sellerId: 'vendor3',
        sellerName: 'Lola\'s Kitchen',
        title: 'Homemade Ube Jam',
        description:
            'Delicious homemade ube jam made with fresh ingredients. Perfect for breakfast or snacks.',
        price: 120.00,
        category: 'Food',
        createdAt: _baseDate.subtract(const Duration(days: 2)),
        isAvailable: true,
        imageUrls: const [
          'https://images.unsplash.com/photo-1509440159596-0249088772ff',
        ],
      ),
      ProductModel(
        id: 'product-5',
        sellerId: 'vendor1',
        sellerName: 'Maria\'s Store',
        title: 'Organic Rice (5kg)',
        description: 'Premium organic rice grown locally. Healthy and nutritious.',
        price: 280.00,
        category: 'Food',
        createdAt: _baseDate.subtract(const Duration(days: 3)),
        isAvailable: true,
        imageUrls: const [
          'https://images.unsplash.com/photo-1509440159596-0249088772ff',
        ],
      ),
      ProductModel(
        id: 'product-6',
        sellerId: 'vendor4',
        sellerName: 'Artisan Pottery',
        title: 'Ceramic Plant Pot',
        description: 'Beautiful ceramic pot for your plants. Handcrafted with care.',
        price: 450.00,
        category: 'Handicrafts',
        createdAt: _baseDate.subtract(const Duration(days: 4)),
        isAvailable: true,
        imageUrls: const [
          'https://images.unsplash.com/photo-1457574173809-67cf0d13aa74',
        ],
      ),
      ProductModel(
        id: 'product-7',
        sellerId: 'vendor2',
        sellerName: 'Juan\'s Crafts',
        title: 'Bamboo Placemats Set',
        description: 'Set of 4 eco-friendly bamboo placemats. Perfect for dining.',
        price: 200.00,
        category: 'Home',
        createdAt: _baseDate.subtract(const Duration(days: 5)),
        isAvailable: true,
        imageUrls: const [
          'https://images.unsplash.com/photo-1616628182501-a3d1e70f3f65',
        ],
      ),
      ProductModel(
        id: 'product-8',
        sellerId: 'vendor5',
        sellerName: 'Local Honey Farm',
        title: 'Pure Honey (500ml)',
        description: '100% pure local honey. Natural and unprocessed.',
        price: 380.00,
        category: 'Food',
        createdAt: _baseDate.subtract(const Duration(days: 6)),
        isAvailable: true,
        imageUrls: const [
          'https://images.unsplash.com/photo-1514996937319-344454492b37',
        ],
      ),
      ProductModel(
        id: 'product-9',
        sellerId: 'vendor3',
        sellerName: 'Lola\'s Kitchen',
        title: 'Coconut Oil (1L)',
        description: 'Cold-pressed virgin coconut oil. Great for cooking and skincare.',
        price: 250.00,
        category: 'Food',
        createdAt: _baseDate.subtract(const Duration(days: 7)),
        isAvailable: false,
        imageUrls: const [
          'https://images.unsplash.com/photo-1483478550801-ceba5fe50e8e',
        ],
      ),
      // My products
      ProductModel(
        id: 'my-product-1',
        sellerId: 'me',
        sellerName: 'You',
        title: 'Available napud atong talong',
        description: 'Freshly harvested talong ready for pickup.',
        price: 50,
        category: 'Food',
        createdAt: _baseDate,
        location: 'Purok 3, Kidid',
        contactNumber: '0917 000 1111',
        imageUrls: const [
          'https://images.unsplash.com/photo-1506806732259-39c2d0268443',
        ],
      ),
      ProductModel(
        id: 'my-product-2',
        sellerId: 'me',
        sellerName: 'You',
        title: 'Available atong Kwek2',
        description: 'Bag-o lang luto nga kwek-kwek para sa tanan.',
        price: 20,
        category: 'Food',
        createdAt: _baseDate,
        location: 'Purok 2, Gym',
        contactNumber: '0917 000 2222',
        imageUrls: const [
          'https://images.unsplash.com/photo-1504674900247-0877df9cc836',
        ],
      ),
    ]);

    // Initialize tasks
    _tasksList.addAll([
      TaskModel(
        id: 'task-1',
        title: 'Kinahanglan og mo alsag bugas',
        description:
            'I need help carrying 10 sacks of rice from the truck to my storage. The truck will arrive tomorrow morning at 8 AM. Looking for 2-3 strong volunteers.',
        requesterName: 'Maria Santos',
        createdAt: _baseDate.subtract(const Duration(hours: 3)),
        status: TaskStatus.open,
        priority: TaskPriority.medium,
      ),
      TaskModel(
        id: 'task-2',
        title: 'Hanap kog maka tutor sakong anak',
        description:
            'My daughter needs help with Math and Science subjects. Grade 6 level. Looking for someone who can tutor 2-3 times a week in the afternoon.',
        requesterName: 'Jason Kurada',
        createdAt: _baseDate,
        status: TaskStatus.ongoing,
        assignedTo: 'Ana Garcia',
        priority: TaskPriority.high,
      ),
      TaskModel(
        id: 'task-3',
        title: 'Kinahanglan kog manlilugay',
        description:
            'Kinahanglan ko manglimpyo kay mag padag akoa, kinahanglan ko 3 ka tao.',
        requesterName: 'Maria Otakan',
        createdAt: _baseDate,
        status: TaskStatus.completed,
        assignedTo: 'Barangay Youth',
        priority: TaskPriority.low,
      ),
      // Note: task-2 in home feed uses 'Juan Dela Cruz' as requester
      // This is a duplicate for the feed
      TaskModel(
        id: 'task-2-feed',
        title: 'Looking for Tutor',
        description:
            'My daughter needs help with Math and Science subjects. Grade 6 level. Looking for someone who can tutor 2-3 times a week in the afternoon.',
        requesterName: 'Juan Dela Cruz',
        createdAt: _baseDate.subtract(const Duration(days: 1)),
        status: TaskStatus.ongoing,
        assignedTo: 'Ana Garcia',
        priority: TaskPriority.high,
      ),
      // Juan Dela Cruz's posts for "My post" screen
      TaskModel(
        id: 'task-4',
        title: 'Magpa buak og lugit ng lubi',
        description:
            'Nanginahanglan kog 1 ka tao na mo buak, og 3 ka taon na mo lugit. Karong sabado ko magpa trabaho',
        requesterName: 'Juan Dela Cruz',
        createdAt: _baseDate,
        status: TaskStatus.open,
        priority: TaskPriority.medium,
      ),
      TaskModel(
        id: 'task-5',
        title: 'Hanap kog maka Dag ug niyug',
        description: 'Magpakopras ko karung Sabado, need nako og 3 ka menadadag.',
        requesterName: 'Juan Dela Cruz',
        createdAt: _baseDate,
        status: TaskStatus.ongoing,
        assignedTo: 'Ana Garcia',
        priority: TaskPriority.medium,
      ),
      TaskModel(
        id: 'task-6',
        title: 'Nag hanap kog mo garas',
        description: 'Nag hanap kog mo garas sa bukid, libri kaon. Pacquiao akong gusto.',
        requesterName: 'Juan Dela Cruz',
        createdAt: _baseDate,
        status: TaskStatus.completed,
        assignedTo: 'Clinch Lansaderas',
        priority: TaskPriority.low,
      ),
    ]);
  }

  // Announcements data (sorted by date, newest first)
  List<Map<String, dynamic>> get announcements {
    final sorted = List<Map<String, dynamic>>.from(_announcementsList);
    sorted.sort((a, b) {
      final dateA = a['date'] as DateTime? ?? DateTime.now();
      final dateB = b['date'] as DateTime? ?? DateTime.now();
      return dateB.compareTo(dateA);
    });
    return sorted;
  }

  // Products data (sorted by date, newest first)
  List<ProductModel> get products {
    final sorted = List<ProductModel>.from(_productsList);
    sorted.sort((a, b) => b.createdAt.compareTo(a.createdAt));
    return sorted;
  }

  // Tasks data (sorted by date, newest first)
  List<TaskModel> get tasks {
    final sorted = List<TaskModel>.from(_tasksList);
    sorted.sort((a, b) => b.createdAt.compareTo(a.createdAt));
    return sorted;
  }

  // Home feed data (mixed: announcements, requests, products)
  // This dynamically builds the feed from the actual data
  List<Map<String, dynamic>> get homeFeed {
    final feed = <Map<String, dynamic>>[];
    
    // Add announcements
    for (final announcement in _announcementsList) {
      feed.add({
        'type': 'announcement',
        ...announcement,
      });
    }
    
    // Add tasks (as requests)
    for (final task in _tasksList) {
      if (task.id == 'task-2-feed' || task.id == 'task-1') {
        feed.add({
          'type': 'request',
          'id': task.id,
          'title': task.id == 'task-1' 
              ? 'Need help carrying rice sacks'
              : task.title,
          'description': task.description,
          'postedBy': task.requesterName,
          'date': task.createdAt,
          'status': _mapTaskStatusToErrandStatus(task.status),
          'statusLabel': task.status.displayName,
          'volunteerName': task.assignedTo,
        });
      }
    }
    
    // Add first product
    if (_productsList.isNotEmpty) {
      feed.add({
        'type': 'product',
        'id': _productsList.first.id,
        'product': _productsList.first,
      });
    }
    
    // Sort by date (newest first)
    feed.sort((a, b) {
      final dateA = a['date'] as DateTime? ?? DateTime.now();
      final dateB = b['date'] as DateTime? ?? DateTime.now();
      return dateB.compareTo(dateA);
    });
    
    return feed;
  }
  
  ErrandJobStatus _mapTaskStatusToErrandStatus(TaskStatus status) {
    switch (status) {
      case TaskStatus.open:
        return ErrandJobStatus.open;
      case TaskStatus.ongoing:
        return ErrandJobStatus.ongoing;
      case TaskStatus.completed:
        return ErrandJobStatus.completed;
    }
  }

  // Helper methods to add new items
  void addAnnouncement(Map<String, dynamic> announcement) {
    _announcementsList.insert(0, announcement);
    // Also add to home feed if needed
  }

  void addProduct(ProductModel product) {
    _productsList.insert(0, product);
  }

  void addTask(TaskModel task) {
    _tasksList.insert(0, task);
  }

  // Mark announcement as read
  void markAnnouncementAsRead(String announcementId) {
    final announcement = _announcementsList.firstWhere(
      (a) => a['id'] == announcementId,
      orElse: () => {},
    );
    if (announcement.isNotEmpty) {
      announcement['isRead'] = true;
      // Preserve view count (don't reset it), only reset unread count
      final currentViewCount = announcement['viewCount'] as int?;
      if (currentViewCount == null) {
        // If viewCount doesn't exist, use unreadCount as the initial viewCount
        final unreadCount = announcement['unreadCount'] as int? ?? 0;
        announcement['viewCount'] = unreadCount;
      }
      // Always reset unreadCount to 0 when marked as read
      announcement['unreadCount'] = 0;
    }
  }

  // Volunteer for a task
  void volunteerForTask(String taskId, String volunteerName) {
    final taskIndex = _tasksList.indexWhere((t) => t.id == taskId);
    if (taskIndex != -1) {
      final task = _tasksList[taskIndex];
      // Create a new task with updated status and assignedTo
      _tasksList[taskIndex] = TaskModel(
        id: task.id,
        title: task.title,
        description: task.description,
        requesterName: task.requesterName,
        createdAt: task.createdAt,
        dueDate: task.dueDate,
        status: TaskStatus.ongoing,
        priority: task.priority,
        assignedTo: volunteerName,
        assignedByName: volunteerName,
      );
    }
  }

  // Get products by seller (sorted by date, newest first)
  List<ProductModel> getProductsBySeller(String sellerId) {
    final filtered = _productsList.where((p) => p.sellerId == sellerId).toList();
    filtered.sort((a, b) => b.createdAt.compareTo(a.createdAt));
    return filtered;
  }

  // Get tasks by requester (sorted by date, newest first)
  List<TaskModel> getTasksByRequester(String requesterName) {
    final filtered = _tasksList.where((t) => t.requesterName == requesterName).toList();
    filtered.sort((a, b) => b.createdAt.compareTo(a.createdAt));
    return filtered;
  }

  // Get task by id
  TaskModel? getTaskById(String taskId) {
    try {
      return _tasksList.firstWhere((t) => t.id == taskId);
    } catch (e) {
      return null;
    }
  }

  // Get current user's demographic categories (dummy - in real app this would come from auth/user service)
  List<String> getCurrentUserDemographics() {
    // For now, return a sample set of demographics
    // In a real app, this would be fetched from user profile/auth
    return ['Student', 'Youth', 'Parent'];
  }

  // Map announcement categories to demographic categories
  Map<String, List<String>> get _announcementToDemographicMap => {
    'Health': ['Senior', 'PWD', 'Parent', '4Ps'],
    'Livelihood': ['Farmer', 'Fisherman', 'Small Business Owner', 'Tricycle Driver', '4Ps'],
    'Youth Activity': ['Student', 'Youth'],
  };

  // Check if announcement is relevant for user's demographics
  bool isAnnouncementRelevantForUser(Map<String, dynamic> announcement, List<String> userDemographics) {
    final category = announcement['category'] as String?;
    if (category == null) return false;
    
    final relevantDemographics = _announcementToDemographicMap[category] ?? [];
    // Check if user has any of the relevant demographics
    return userDemographics.any((demo) => relevantDemographics.contains(demo));
  }

  // Profile image management
  String? getCurrentUserProfileImage() => _currentUserProfileImagePath;
  
  void setCurrentUserProfileImage(String? imagePath) {
    _currentUserProfileImagePath = imagePath;
  }

  // Update task status
  void updateTaskStatus(String taskId, TaskStatus newStatus) {
    final taskIndex = _tasksList.indexWhere((t) => t.id == taskId);
    if (taskIndex != -1) {
      final task = _tasksList[taskIndex];
      _tasksList[taskIndex] = TaskModel(
        id: task.id,
        title: task.title,
        description: task.description,
        requesterName: task.requesterName,
        createdAt: task.createdAt,
        dueDate: task.dueDate,
        status: newStatus,
        priority: task.priority,
        assignedTo: task.assignedTo,
        assignedByName: task.assignedByName,
      );
    }
  }
}

