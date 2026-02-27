import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/post_model.dart';
import '../models/product_model.dart';
import '../models/task_model.dart';
import '../services/posts_service.dart';
import '../services/products_service.dart';
import '../services/tasks_service.dart';
import '../services/announcements_service.dart';
import '../services/firestore_service.dart';
import '../widgets/post_card.dart';
import '../widgets/product_card.dart';
import '../widgets/errand_job_card.dart';
import '../widgets/announcement_card.dart';
import 'post_detail_screen.dart';
import 'product_detail_screen.dart';
import 'task_detail_screen.dart';
import 'task_edit_screen.dart';
import 'announcement_detail_screen.dart';

enum SearchMode {
  home,
  posts,
  products,
  tasks,
  announcements,
  myProducts,
  myTasks,
}

class SearchScreen extends StatefulWidget {
  final SearchMode mode;

  const SearchScreen({super.key, required this.mode});

  @override
  State<SearchScreen> createState() => _SearchScreenState();
}

class _SearchScreenState extends State<SearchScreen> {
  final TextEditingController _queryController = TextEditingController();
  final FocusNode _focusNode = FocusNode();
  /// Only set after user presses search icon or Enter; null = not searched yet.
  String? _searchQuery;
  static const int _maxRecentSearches = 10;
  List<String> _recentSearches = [];
  
  // Pagination variables
  static const int _initialPageSize = 20;
  static const int _loadMorePageSize = 20;
  int _productsDisplayCount = _initialPageSize;
  int _tasksDisplayCount = _initialPageSize;
  int _postsDisplayCount = _initialPageSize;
  int _announcementsDisplayCount = _initialPageSize;
  
  // Home search pagination
  int _homeAnnouncementsDisplayCount = _initialPageSize;
  int _homePostsDisplayCount = _initialPageSize;
  int _homeTasksDisplayCount = _initialPageSize;
  int _homeProductsDisplayCount = _initialPageSize;
  
  final ScrollController _productsScrollController = ScrollController();
  final ScrollController _tasksScrollController = ScrollController();
  final ScrollController _postsScrollController = ScrollController();
  final ScrollController _announcementsScrollController = ScrollController();
  final ScrollController _homeScrollController = ScrollController();

  String get _recentStorageKey => 'recent_searches_${widget.mode.name}';

  @override
  void initState() {
    super.initState();
    _focusNode.requestFocus();
    _loadRecentSearches();
    _productsScrollController.addListener(_onProductsScroll);
    _tasksScrollController.addListener(_onTasksScroll);
    _postsScrollController.addListener(_onPostsScroll);
    _announcementsScrollController.addListener(_onAnnouncementsScroll);
    _homeScrollController.addListener(_onHomeScroll);
  }

  @override
  void dispose() {
    _queryController.dispose();
    _focusNode.dispose();
    _productsScrollController.removeListener(_onProductsScroll);
    _tasksScrollController.removeListener(_onTasksScroll);
    _postsScrollController.removeListener(_onPostsScroll);
    _announcementsScrollController.removeListener(_onAnnouncementsScroll);
    _homeScrollController.removeListener(_onHomeScroll);
    _productsScrollController.dispose();
    _tasksScrollController.dispose();
    _postsScrollController.dispose();
    _announcementsScrollController.dispose();
    _homeScrollController.dispose();
    super.dispose();
  }

  Future<void> _loadRecentSearches() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final list = prefs.getStringList(_recentStorageKey);
      if (mounted && list != null) {
        setState(() => _recentSearches = list);
      }
    } catch (_) {}
  }

  Future<void> _saveRecentSearches() async {
    if (_recentSearches.isEmpty) return;
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setStringList(_recentStorageKey, _recentSearches);
    } catch (_) {}
  }

  void _runSearch() {
    final query = _queryController.text.trim();
    setState(() {
      _searchQuery = query;
    });
    if (query.isNotEmpty) {
      _recentSearches = [query, ..._recentSearches.where((s) => s != query)];
      if (_recentSearches.length > _maxRecentSearches) {
        _recentSearches = _recentSearches.take(_maxRecentSearches).toList();
      }
      _saveRecentSearches();
    }
  }

  void _applyRecentSearch(String term) {
    _queryController.text = term;
    setState(() {
      _searchQuery = term;
      // Reset pagination when new search is applied
      _productsDisplayCount = _initialPageSize;
      _tasksDisplayCount = _initialPageSize;
      _postsDisplayCount = _initialPageSize;
      _announcementsDisplayCount = _initialPageSize;
      // Reset home search pagination
      _homeAnnouncementsDisplayCount = _initialPageSize;
      _homePostsDisplayCount = _initialPageSize;
      _homeTasksDisplayCount = _initialPageSize;
      _homeProductsDisplayCount = _initialPageSize;
    });
    _recentSearches = [term, ..._recentSearches.where((s) => s != term)];
    if (_recentSearches.length > _maxRecentSearches) {
      _recentSearches = _recentSearches.take(_maxRecentSearches).toList();
    }
    _saveRecentSearches();
  }

  // Scroll listeners for pagination
  void _onProductsScroll() {
    if (!_productsScrollController.hasClients) return;
    final maxScroll = _productsScrollController.position.maxScrollExtent;
    final currentScroll = _productsScrollController.position.pixels;
    if (maxScroll - currentScroll < 300) _loadMoreProducts();
  }

  void _onTasksScroll() {
    if (!_tasksScrollController.hasClients) return;
    final maxScroll = _tasksScrollController.position.maxScrollExtent;
    final currentScroll = _tasksScrollController.position.pixels;
    if (maxScroll - currentScroll < 300) _loadMoreTasks();
  }

  void _onPostsScroll() {
    if (!_postsScrollController.hasClients) return;
    final maxScroll = _postsScrollController.position.maxScrollExtent;
    final currentScroll = _postsScrollController.position.pixels;
    if (maxScroll - currentScroll < 300) _loadMorePosts();
  }

  void _onAnnouncementsScroll() {
    if (!_announcementsScrollController.hasClients) return;
    final maxScroll = _announcementsScrollController.position.maxScrollExtent;
    final currentScroll = _announcementsScrollController.position.pixels;
    if (maxScroll - currentScroll < 300) _loadMoreAnnouncements();
  }

  void _onHomeScroll() {
    if (!_homeScrollController.hasClients) return;
    final maxScroll = _homeScrollController.position.maxScrollExtent;
    final currentScroll = _homeScrollController.position.pixels;
    if (maxScroll - currentScroll < 300) _loadMoreHomeResults();
  }

  // Pagination methods
  void _loadMoreProducts() {
    setState(() {
      _productsDisplayCount += _loadMorePageSize;
    });
  }

  void _loadMoreTasks() {
    setState(() {
      _tasksDisplayCount += _loadMorePageSize;
    });
  }

  void _loadMorePosts() {
    setState(() {
      _postsDisplayCount += _loadMorePageSize;
    });
  }

  void _loadMoreAnnouncements() {
    setState(() {
      _announcementsDisplayCount += _loadMorePageSize;
    });
  }

  void _loadMoreHomeResults() {
    setState(() {
      _homeAnnouncementsDisplayCount += _loadMorePageSize;
      _homePostsDisplayCount += _loadMorePageSize;
      _homeTasksDisplayCount += _loadMorePageSize;
      _homeProductsDisplayCount += _loadMorePageSize;
    });
  }

  String get _hintText {
    switch (widget.mode) {
      case SearchMode.home:
        return 'Search announcements, products, errands...';
      case SearchMode.posts:
        return 'Search posts...';
      case SearchMode.products:
        return 'Search marketplace...';
      case SearchMode.tasks:
        return 'Search errands/jobs...';
      case SearchMode.announcements:
        return 'Search announcements...';
      case SearchMode.myProducts:
        return 'Search my products...';
      case SearchMode.myTasks:
        return 'Search my posts...';
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey.shade100,
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              color: Colors.white,
              padding: const EdgeInsets.fromLTRB(12, 8, 16, 12),
              child: Row(
                children: [
                  IconButton(
                    icon: const Icon(Icons.arrow_back_ios_new, size: 20),
                    onPressed: () => Navigator.of(context).pop(),
                    padding: EdgeInsets.zero,
                    splashRadius: 22,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: TextField(
                      controller: _queryController,
                      focusNode: _focusNode,
                      textInputAction: TextInputAction.search,
                      onSubmitted: (_) => _runSearch(),
                      decoration: InputDecoration(
                        hintText: _hintText,
                        hintStyle: TextStyle(
                          fontSize: 16,
                          color: Colors.grey.shade600,
                        ),
                        border: InputBorder.none,
                        contentPadding: const EdgeInsets.symmetric(
                          vertical: 12,
                          horizontal: 4,
                        ),
                      ),
                      style: const TextStyle(
                        fontSize: 16,
                        color: Colors.black87,
                      ),
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.search, color: Color(0xFF6E6E6E), size: 26),
                    onPressed: _runSearch,
                    splashRadius: 22,
                  ),
                ],
              ),
            ),
            Expanded(
              child: _buildBody(),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildBody() {
    if (_searchQuery == null) {
      return ListView(
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
        children: [
          if (_recentSearches.isEmpty) ...[
            const SizedBox(height: 24),
            Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.search, size: 64, color: Colors.grey.shade400),
                  const SizedBox(height: 16),
                  Text(
                    'Press the search icon or Enter to search',
                    style: TextStyle(fontSize: 16, color: Colors.grey.shade600),
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            ),
          ],
          if (_recentSearches.isNotEmpty) ...[
            const SizedBox(height: 12),
            Text(
              'Recent searches',
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: Colors.grey.shade700,
              ),
            ),
            const SizedBox(height: 10),
            ..._recentSearches.map((term) => Material(
                  color: Colors.transparent,
                  child: InkWell(
                    onTap: () => _applyRecentSearch(term),
                    borderRadius: BorderRadius.circular(12),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 4),
                      child: Row(
                        children: [
                          Icon(Icons.history, size: 20, color: Colors.grey.shade600),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Text(
                              term,
                              style: const TextStyle(fontSize: 15, color: Colors.black87),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                )),
          ],
        ],
      );
    }
    switch (widget.mode) {
      case SearchMode.home:
        return _buildHomeResults();
      case SearchMode.posts:
        return _buildPostsResults();
      case SearchMode.products:
        return _buildProductsResults();
      case SearchMode.tasks:
        return _buildTasksResults();
      case SearchMode.announcements:
        return _buildAnnouncementsResults();
      case SearchMode.myProducts:
        return _buildMyProductsResults();
      case SearchMode.myTasks:
        return _buildMyTasksResults();
    }
  }

  static ErrandJobStatus? _mapTaskStatus(TaskStatus status) {
    switch (status) {
      case TaskStatus.open:
        return ErrandJobStatus.open;
      case TaskStatus.ongoing:
        return ErrandJobStatus.ongoing;
      case TaskStatus.completed:
        return ErrandJobStatus.completed;
    }
  }

  Future<Map<String, dynamic>> _fetchHomeSearchResults(String queryLower, String? currentUserId) async {
    try {
      final results = await Future.wait([
        AnnouncementsService.getAnnouncementsStream().first,
        PostsService.getPostsStream().first,
        TasksService.getTasksStream().first,
        ProductsService.getProductsStream().first,
      ]);
      final announcements = results[0] is List<Map<String, dynamic>> ? results[0] as List<Map<String, dynamic>> : <Map<String, dynamic>>[];
      final posts = results[1] is List<PostModel> ? results[1] as List<PostModel> : <PostModel>[];
      final tasks = results[2] is List<TaskModel> ? results[2] as List<TaskModel> : <TaskModel>[];
      final products = results[3] is List<ProductModel> ? results[3] as List<ProductModel> : <ProductModel>[];

      final filterAnn = queryLower.isEmpty
          ? announcements
          : announcements.where((a) {
              final title = (a['title'] as String? ?? '').toLowerCase();
              final content = (a['content'] as String? ?? a['description'] as String? ?? '').toLowerCase();
              return title.contains(queryLower) || content.contains(queryLower);
            }).toList();

      final filterPosts = queryLower.isEmpty
          ? posts
          : posts.where((p) =>
              p.title.toLowerCase().contains(queryLower) ||
              p.content.toLowerCase().contains(queryLower)).toList();

      final nonCompleted = tasks.where((t) => t.status != TaskStatus.completed).toList();
      final feedTasks = currentUserId != null
          ? nonCompleted.where((t) => t.requesterId != currentUserId).toList()
          : nonCompleted;
      final filterTasks = queryLower.isEmpty
          ? feedTasks
          : feedTasks.where((t) =>
              t.title.toLowerCase().contains(queryLower) ||
              t.description.toLowerCase().contains(queryLower)).toList();

      final feedProducts = currentUserId != null
          ? products.where((p) => p.sellerId != currentUserId).toList()
          : products;
      final filterProducts = queryLower.isEmpty
          ? feedProducts
          : feedProducts.where((p) =>
              p.title.toLowerCase().contains(queryLower) ||
              p.description.toLowerCase().contains(queryLower)).toList();

      return <String, dynamic>{
        'announcements': filterAnn,
        'posts': filterPosts,
        'tasks': filterTasks,
        'products': filterProducts,
      };
    } catch (_) {
      return <String, dynamic>{
        'announcements': <Map<String, dynamic>>[],
        'posts': <PostModel>[],
        'tasks': <TaskModel>[],
        'products': <ProductModel>[],
      };
    }
  }

  Widget _buildHomeResults() {
    final query = _searchQuery ?? '';
    final queryLower = query.toLowerCase();
    final currentUserId = FirestoreService.currentUserId;

    // If no search query, show recent searches or empty state
    if (queryLower.isEmpty) {
      return _buildRecentSearches();
    }

    return CustomScrollView(
      controller: _homeScrollController,
      slivers: [
        // Announcements Section
        SliverToBoxAdapter(
          child: _buildHomeAnnouncementsSection(queryLower, currentUserId),
        ),
        // Posts Section
        SliverToBoxAdapter(
          child: _buildHomePostsSection(queryLower),
        ),
        // Tasks Section
        SliverToBoxAdapter(
          child: _buildHomeTasksSection(queryLower, currentUserId),
        ),
        // Products Section
        SliverToBoxAdapter(
          child: _buildHomeProductsSection(queryLower, currentUserId),
        ),
        // Load More Indicator
        SliverToBoxAdapter(
          child: _buildHomeLoadMoreIndicator(),
        ),
      ],
    );
  }

  Widget _buildHomeAnnouncementsSection(String queryLower, String? currentUserId) {
    return StreamBuilder<List<Map<String, dynamic>>>(
      stream: AnnouncementsService.getAnnouncementsStream(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const SizedBox(height: 100, child: Center(child: CircularProgressIndicator()));
        }
        
        final announcements = snapshot.data ?? [];
        final filtered = announcements.where((a) {
          final title = (a['title'] as String? ?? '').toLowerCase();
          final content = (a['content'] as String? ?? a['description'] as String? ?? '').toLowerCase();
          return title.contains(queryLower) || content.contains(queryLower);
        }).toList();

        final visibleCount = _homeAnnouncementsDisplayCount.clamp(0, filtered.length);
        final showLoadMore = visibleCount < filtered.length;

        if (filtered.isEmpty) return const SizedBox.shrink();

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _sectionHeader('Announcements'),
            ...filtered.take(visibleCount).map((a) => Padding(
              padding: const EdgeInsets.only(bottom: 16),
              child: _announcementCardFromMap(a),
            )),
            if (showLoadMore)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 16),
                child: Center(child: CircularProgressIndicator()),
              ),
            const SizedBox(height: 20),
          ],
        );
      },
    );
  }

  Widget _buildHomePostsSection(String queryLower) {
    return StreamBuilder<List<PostModel>>(
      stream: PostsService.getPostsStream(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const SizedBox(height: 100, child: Center(child: CircularProgressIndicator()));
        }
        
        final posts = snapshot.data ?? [];
        final filtered = posts.where((p) =>
          p.title.toLowerCase().contains(queryLower) ||
          p.content.toLowerCase().contains(queryLower)).toList();

        final visibleCount = _homePostsDisplayCount.clamp(0, filtered.length);
        final showLoadMore = visibleCount < filtered.length;

        if (filtered.isEmpty) return const SizedBox.shrink();

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _sectionHeader('Posts'),
            ...filtered.take(visibleCount).map((post) => Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: PostCard(post: post),
            )),
            if (showLoadMore)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 16),
                child: Center(child: CircularProgressIndicator()),
              ),
            const SizedBox(height: 20),
          ],
        );
      },
    );
  }

  Widget _buildHomeTasksSection(String queryLower, String? currentUserId) {
    return StreamBuilder<List<TaskModel>>(
      stream: TasksService.getTasksStream(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const SizedBox(height: 100, child: Center(child: CircularProgressIndicator()));
        }
        
        final tasks = snapshot.data ?? [];
        final nonCompleted = tasks.where((t) => t.status != TaskStatus.completed).toList();
        final feedTasks = currentUserId != null
            ? nonCompleted.where((t) => t.requesterId != currentUserId).toList()
            : nonCompleted;
        final filtered = feedTasks.where((t) =>
          t.title.toLowerCase().contains(queryLower) ||
          t.description.toLowerCase().contains(queryLower)).toList();

        final visibleCount = _homeTasksDisplayCount.clamp(0, filtered.length);
        final showLoadMore = visibleCount < filtered.length;

        if (filtered.isEmpty) return const SizedBox.shrink();

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _sectionHeader('Errands / Jobs'),
            ...filtered.take(visibleCount).map((task) {
              final isOwner = currentUserId != null && task.requesterId == currentUserId;
              return Padding(
                padding: const EdgeInsets.only(bottom: 16),
                child: ErrandJobCard(
                  title: task.title,
                  description: task.description,
                  postedBy: task.requesterName,
                  date: task.createdAt,
                  status: _mapTaskStatus(task.status),
                  statusLabel: task.status.displayName,
                  volunteerName: task.assignedByName,
                  showTag: true,
                  viewButtonLabel: isOwner ? 'Edit' : 'View',
                  viewButtonIcon: isOwner ? Icons.edit_outlined : Icons.visibility_outlined,
                  onViewPressed: () {
                    Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (_) => isOwner
                            ? TaskEditScreen(task: task)
                            : TaskDetailScreen(task: task),
                      ),
                    );
                  },
                ),
              );
            }),
            if (showLoadMore)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 16),
                child: Center(child: CircularProgressIndicator()),
              ),
            const SizedBox(height: 20),
          ],
        );
      },
    );
  }

  Widget _buildHomeProductsSection(String queryLower, String? currentUserId) {
    return StreamBuilder<List<ProductModel>>(
      stream: ProductsService.getProductsStream(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const SizedBox(height: 100, child: Center(child: CircularProgressIndicator()));
        }
        
        final products = snapshot.data ?? [];
        final feedProducts = currentUserId != null
            ? products.where((p) => p.sellerId != currentUserId).toList()
            : products;
        final filtered = feedProducts.where((p) =>
          p.title.toLowerCase().contains(queryLower) ||
          p.description.toLowerCase().contains(queryLower)).toList();

        final visibleCount = _homeProductsDisplayCount.clamp(0, filtered.length);
        final showLoadMore = visibleCount < filtered.length;

        if (filtered.isEmpty) return const SizedBox.shrink();

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _sectionHeader('Marketplace'),
            ...filtered.take(visibleCount).map((product) => Padding(
              padding: const EdgeInsets.only(bottom: 16),
              child: ProductCard(
                product: product,
                showTag: true,
                onInteract: () {
                  Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (_) => ProductDetailScreen(product: product),
                    ),
                  );
                },
              ),
            )),
            if (showLoadMore)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 16),
                child: Center(child: CircularProgressIndicator()),
              ),
            const SizedBox(height: 24),
          ],
        );
      },
    );
  }

  Widget _buildHomeLoadMoreIndicator() {
    return const SizedBox(height: 20);
  }

  Widget _buildRecentSearches() {
    if (_recentSearches.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.search, size: 64, color: Colors.grey.shade400),
            const SizedBox(height: 16),
            Text(
              'Search for announcements, products, errands...',
              style: TextStyle(fontSize: 16, color: Colors.grey.shade600),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
      itemCount: _recentSearches.length,
      itemBuilder: (context, index) {
        final term = _recentSearches[index];
        return ListTile(
          leading: const Icon(Icons.history, color: Colors.grey),
          title: Text(term),
          onTap: () => _applyRecentSearch(term),
          trailing: IconButton(
            icon: const Icon(Icons.clear, size: 20),
            onPressed: () => _removeRecentSearch(term),
          ),
        );
      },
    );
  }

  void _removeRecentSearch(String term) {
    setState(() {
      _recentSearches = _recentSearches.where((s) => s != term).toList();
    });
    _saveRecentSearches();
  }

  Widget _sectionHeader(String title) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Text(
        title,
        style: TextStyle(
          fontSize: 16,
          fontWeight: FontWeight.w700,
          color: Colors.grey.shade700,
        ),
      ),
    );
  }

  Widget _announcementCardFromMap(Map<String, dynamic> a) {
    final id = a['id'] as String? ?? '';
    final title = a['title'] as String? ?? '';
    final description = a['content'] as String? ?? a['description'] as String? ?? '';
    final postedBy = a['postedBy'] as String? ?? 'Barangay Official';
    final postedByPosition = a['postedByPosition'] as String?;
    final date = a['date'] as DateTime? ?? a['createdAt'] as DateTime? ?? DateTime.now();
    final category = a['category'] as String?;
    final viewCount = a['viewCount'] as int? ?? 0;
    return AnnouncementCard(
      title: title,
      description: description,
      postedBy: postedBy,
      postedByPosition: postedByPosition,
      date: date,
      category: category,
      unreadCount: viewCount,
      isRead: false,
      showTag: true,
      announcementId: id,
      onMarkAsReadPressed: () {},
    );
  }

  Widget _buildPostsResults() {
    final query = _searchQuery ?? '';
    final queryLower = query.toLowerCase();

    return StreamBuilder<List<PostModel>>(
      stream: PostsService.getPostsStream(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        if (snapshot.hasError) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.error_outline, size: 64, color: Colors.grey[400]),
                const SizedBox(height: 16),
                Text(
                  'Error loading posts',
                  style: TextStyle(fontSize: 16, color: Colors.grey[600]),
                ),
              ],
            ),
          );
        }

        final allPosts = snapshot.data ?? [];
        final filtered = queryLower.isEmpty
            ? allPosts
            : allPosts.where((p) {
                return p.title.toLowerCase().contains(queryLower) ||
                    p.content.toLowerCase().contains(queryLower);
              }).toList();

        if (filtered.isEmpty) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.search_off, size: 64, color: Colors.grey.shade400),
                const SizedBox(height: 16),
                Text(
                  queryLower.isEmpty
                      ? 'No posts'
                      : 'No posts match "${query.length > 30 ? "${query.substring(0, 27)}..." : query}"',
                  style: TextStyle(fontSize: 16, color: Colors.grey.shade600),
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          );
        }

        return ListView.builder(
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
          physics: const ClampingScrollPhysics(),
          itemCount: filtered.length,
          itemBuilder: (context, index) {
            final post = filtered[index];
            return Padding(
              padding: EdgeInsets.only(
                bottom: index < filtered.length - 1 ? 12 : 0,
              ),
              child: PostCard(
                post: post,
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildProductsResults() {
    final currentUserId = FirestoreService.currentUserId;
    final query = _searchQuery ?? '';
    final queryLower = query.toLowerCase();

    return StreamBuilder<List<ProductModel>>(
      stream: ProductsService.getProductsStream(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        if (snapshot.hasError) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.error_outline, size: 64, color: Colors.grey[400]),
                const SizedBox(height: 16),
                Text(
                  'Error loading products',
                  style: TextStyle(fontSize: 16, color: Colors.grey[600]),
                ),
              ],
            ),
          );
        }

        final allProducts = snapshot.data ?? [];
        final feedProducts = currentUserId != null
            ? allProducts.where((p) => p.sellerId != currentUserId).toList()
            : allProducts;
        final filtered = queryLower.isEmpty
            ? feedProducts
            : feedProducts.where((p) {
                return p.title.toLowerCase().contains(queryLower) ||
                    p.description.toLowerCase().contains(queryLower);
              }).toList();

        if (filtered.isEmpty) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.search_off, size: 64, color: Colors.grey.shade400),
                const SizedBox(height: 16),
                Text(
                  queryLower.isEmpty
                      ? 'No products'
                      : 'No products match "${query.length > 30 ? "${query.substring(0, 27)}..." : query}"',
                  style: TextStyle(fontSize: 16, color: Colors.grey.shade600),
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          );
        }

        final visibleCount = _productsDisplayCount.clamp(0, filtered.length);
        final showLoadMore = visibleCount < filtered.length;

        return ListView.builder(
          controller: _productsScrollController,
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
          physics: const ClampingScrollPhysics(),
          itemCount: visibleCount + (showLoadMore ? 1 : 0),
          itemBuilder: (context, index) {
            if (index < visibleCount) {
              final product = filtered[index];
              return Padding(
                padding: EdgeInsets.only(
                  bottom: index < visibleCount - 1 ? 16 : 0,
                ),
                child: ProductCard(
                  product: product,
                  showTag: true,
                  onInteract: () {
                    Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (_) => ProductDetailScreen(product: product),
                      ),
                    );
                  },
                ),
              );
            } else {
              // Load more indicator
              return Padding(
                padding: const EdgeInsets.symmetric(vertical: 16),
                child: Center(
                  child: CircularProgressIndicator(),
                ),
              );
            }
          },
        );
      },
    );
  }

  Widget _buildTasksResults() {
    final currentUserId = FirestoreService.currentUserId;
    final query = _searchQuery ?? '';
    final queryLower = query.toLowerCase();

    return StreamBuilder<List<TaskModel>>(
      stream: TasksService.getTasksStream(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        if (snapshot.hasError) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.error_outline, size: 64, color: Colors.grey[400]),
                const SizedBox(height: 16),
                Text(
                  'Error loading tasks',
                  style: TextStyle(fontSize: 16, color: Colors.grey[600]),
                ),
              ],
            ),
          );
        }

        final allTasks = snapshot.data ?? [];
        final nonCompleted = allTasks.where((t) => t.status != TaskStatus.completed).toList();
        final feedTasks = currentUserId != null
            ? nonCompleted.where((t) => t.requesterId != currentUserId).toList()
            : nonCompleted;
        final filtered = queryLower.isEmpty
            ? feedTasks
            : feedTasks.where((t) {
                return t.title.toLowerCase().contains(queryLower) ||
                    t.description.toLowerCase().contains(queryLower);
              }).toList();

        if (filtered.isEmpty) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.search_off, size: 64, color: Colors.grey.shade400),
                const SizedBox(height: 16),
                Text(
                  queryLower.isEmpty
                      ? 'No tasks'
                      : 'No tasks match "${query.length > 30 ? "${query.substring(0, 27)}..." : query}"',
                  style: TextStyle(fontSize: 16, color: Colors.grey.shade600),
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          );
        }

        final visibleCount = _tasksDisplayCount.clamp(0, filtered.length);
        final showLoadMore = visibleCount < filtered.length;

        return ListView.builder(
          controller: _tasksScrollController,
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
          physics: const ClampingScrollPhysics(),
          itemCount: visibleCount + (showLoadMore ? 1 : 0),
          itemBuilder: (context, index) {
            if (index < visibleCount) {
              final task = filtered[index];
              final isOwner = currentUserId != null && task.requesterId == currentUserId;
              return Padding(
                padding: EdgeInsets.only(
                  bottom: index < visibleCount - 1 ? 16 : 0,
                ),
                child: ErrandJobCard(
                  title: task.title,
                  description: task.description,
                  postedBy: task.requesterName,
                  date: task.createdAt,
                  status: _mapTaskStatus(task.status),
                  statusLabel: task.status.displayName,
                  volunteerName: task.assignedByName,
                  showTag: true,
                  viewButtonLabel: isOwner ? 'Edit' : 'View',
                  viewButtonIcon: isOwner ? Icons.edit_outlined : Icons.visibility_outlined,
                  onViewPressed: () {
                    Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (_) => isOwner
                            ? TaskEditScreen(task: task)
                            : TaskDetailScreen(task: task),
                      ),
                    );
                  },
                ),
              );
            } else {
              // Load more indicator
              return Padding(
                padding: const EdgeInsets.symmetric(vertical: 16),
                child: Center(
                  child: CircularProgressIndicator(),
                ),
              );
            }
          },
        );
      },
    );
  }

  Widget _buildAnnouncementsResults() {
    final query = _searchQuery ?? '';
    final queryLower = query.toLowerCase();

    return StreamBuilder<List<Map<String, dynamic>>>(
      stream: AnnouncementsService.getAnnouncementsStream(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        if (snapshot.hasError) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.error_outline, size: 64, color: Colors.grey[400]),
                const SizedBox(height: 16),
                Text(
                  'Error loading announcements',
                  style: TextStyle(fontSize: 16, color: Colors.grey[600]),
                ),
              ],
            ),
          );
        }

        final all = snapshot.data ?? [];
        final filtered = queryLower.isEmpty
            ? all
            : all.where((a) {
                final title = (a['title'] as String? ?? '').toLowerCase();
                final content = (a['content'] as String? ?? a['description'] as String? ?? '').toLowerCase();
                return title.contains(queryLower) || content.contains(queryLower);
              }).toList();

        if (filtered.isEmpty) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.search_off, size: 64, color: Colors.grey.shade400),
                const SizedBox(height: 16),
                Text(
                  queryLower.isEmpty
                      ? 'No announcements'
                      : 'No announcements match "${query.length > 30 ? "${query.substring(0, 27)}..." : query}"',
                  style: TextStyle(fontSize: 16, color: Colors.grey.shade600),
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          );
        }

        final visibleCount = _announcementsDisplayCount.clamp(0, filtered.length);
        final showLoadMore = visibleCount < filtered.length;

        return ListView.builder(
          controller: _announcementsScrollController,
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
          physics: const ClampingScrollPhysics(),
          itemCount: visibleCount + (showLoadMore ? 1 : 0),
          itemBuilder: (context, index) {
            if (index < visibleCount) {
              final a = filtered[index];
              final id = a['id'] as String? ?? '';
              final title = a['title'] as String? ?? '';
              final description = a['content'] as String? ?? a['description'] as String? ?? '';
              final postedBy = a['postedBy'] as String? ?? 'Barangay Official';
              final postedByPosition = a['postedByPosition'] as String?;
              final date = a['date'] as DateTime? ?? a['createdAt'] as DateTime? ?? DateTime.now();
              final category = a['category'] as String?;
              final viewCount = a['viewCount'] as int? ?? 0;
              return Padding(
                padding: EdgeInsets.only(
                  bottom: index < visibleCount - 1 ? 16 : 0,
                ),
                child: AnnouncementCard(
                  title: title,
                  description: description,
                  postedBy: postedBy,
                  postedByPosition: postedByPosition,
                  date: date,
                  category: category,
                  unreadCount: viewCount,
                  isRead: false,
                  showTag: true,
                  announcementId: id,
                  onMarkAsReadPressed: () {},
                ),
              );
            } else {
              // Load more indicator
              return Padding(
                padding: const EdgeInsets.symmetric(vertical: 16),
                child: Center(
                  child: CircularProgressIndicator(),
                ),
              );
            }
          },
        );
      },
    );
  }

  Widget _buildMyProductsResults() {
    final currentUserId = FirestoreService.currentUserId;
    final query = _searchQuery ?? '';
    final queryLower = query.toLowerCase();
    if (currentUserId == null) {
      return Center(
        child: Text(
          'Please log in to search your products',
          style: TextStyle(fontSize: 16, color: Colors.grey.shade600),
        ),
      );
    }

    return StreamBuilder<List<ProductModel>>(
      stream: ProductsService.getSellerProductsStream(currentUserId),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        if (snapshot.hasError) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.error_outline, size: 64, color: Colors.grey[400]),
                const SizedBox(height: 16),
                Text(
                  'Error loading products',
                  style: TextStyle(fontSize: 16, color: Colors.grey[600]),
                ),
              ],
            ),
          );
        }

        final all = snapshot.data ?? [];
        final filtered = queryLower.isEmpty
            ? all
            : all.where((p) =>
                p.title.toLowerCase().contains(queryLower) ||
                p.description.toLowerCase().contains(queryLower)).toList();

        if (filtered.isEmpty) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.search_off, size: 64, color: Colors.grey.shade400),
                const SizedBox(height: 16),
                Text(
                  queryLower.isEmpty
                      ? 'No products'
                      : 'No products match "${query.length > 30 ? "${query.substring(0, 27)}..." : query}"',
                  style: TextStyle(fontSize: 16, color: Colors.grey.shade600),
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          );
        }

        return ListView.builder(
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
          physics: const ClampingScrollPhysics(),
          itemCount: filtered.length,
          itemBuilder: (context, index) {
            final product = filtered[index];
            return Padding(
              padding: EdgeInsets.only(
                bottom: index < filtered.length - 1 ? 16 : 0,
              ),
              child: ProductCard(
                product: product,
                showTag: true,
                onInteract: () {
                  Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (_) => ProductDetailScreen(product: product),
                    ),
                  );
                },
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildMyTasksResults() {
    final currentUserId = FirestoreService.currentUserId;
    final query = _searchQuery ?? '';
    final queryLower = query.toLowerCase();
    if (currentUserId == null) {
      return Center(
        child: Text(
          'Please log in to search your posts',
          style: TextStyle(fontSize: 16, color: Colors.grey.shade600),
        ),
      );
    }

    return StreamBuilder<List<TaskModel>>(
      stream: TasksService.getRequesterTasksStream(currentUserId),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        if (snapshot.hasError) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.error_outline, size: 64, color: Colors.grey[400]),
                const SizedBox(height: 16),
                Text(
                  'Error loading posts',
                  style: TextStyle(fontSize: 16, color: Colors.grey[600]),
                ),
              ],
            ),
          );
        }

        final all = snapshot.data ?? [];
        final filtered = queryLower.isEmpty
            ? all
            : all.where((t) =>
                t.title.toLowerCase().contains(queryLower) ||
                t.description.toLowerCase().contains(queryLower)).toList();

        if (filtered.isEmpty) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.search_off, size: 64, color: Colors.grey.shade400),
                const SizedBox(height: 16),
                Text(
                  queryLower.isEmpty
                      ? 'No posts'
                      : 'No posts match "${query.length > 30 ? "${query.substring(0, 27)}..." : query}"',
                  style: TextStyle(fontSize: 16, color: Colors.grey.shade600),
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          );
        }

        return ListView.builder(
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
          physics: const ClampingScrollPhysics(),
          itemCount: filtered.length,
          itemBuilder: (context, index) {
            final task = filtered[index];
            return Padding(
              padding: EdgeInsets.only(
                bottom: index < filtered.length - 1 ? 16 : 0,
              ),
              child: ErrandJobCard(
                title: task.title,
                description: task.description,
                postedBy: task.requesterName,
                date: task.createdAt,
                status: _mapTaskStatus(task.status),
                statusLabel: task.status.displayName,
                volunteerName: task.assignedByName,
                showTag: true,
                viewButtonLabel: 'Edit',
                viewButtonIcon: Icons.edit_outlined,
                onViewPressed: () {
                  Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (_) => TaskEditScreen(
                        task: task,
                        contactNumber: task.contactNumber ?? '',
                      ),
                    ),
                  );
                },
              ),
            );
          },
        );
      },
    );
  }
}
