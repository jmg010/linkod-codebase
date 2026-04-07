import 'package:flutter/material.dart';
import 'package:rxdart/rxdart.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:async';
import 'package:visibility_detector/visibility_detector.dart';
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
import 'product_detail_screen.dart';
import 'task_detail_screen.dart';
import 'task_edit_screen.dart';

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
  final Set<String> _searchAutoViewedProductIds = <String>{};
  final Set<String> _searchAutoViewedTaskIds = <String>{};

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

  late final Stream<List<PostModel>> _postsStream;
  late final Stream<List<ProductModel>> _productsStream;
  late final Stream<List<TaskModel>> _tasksStream;
  late final Stream<List<Map<String, dynamic>>> _announcementsStream;

  Stream<Map<String, dynamic>>? _homeCombinedStream;
  String? _homeCombinedQuery;
  String? _homeCombinedUserId;

  Stream<List<ProductModel>>? _myProductsStream;
  String? _myProductsStreamUid;
  Stream<List<TaskModel>>? _myTasksStream;
  String? _myTasksStreamUid;

  String get _recentStorageKey => 'recent_searches_${widget.mode.name}';

  @override
  void initState() {
    super.initState();
    _focusNode.requestFocus();
    _postsStream = PostsService.getPostsStream();
    _productsStream = ProductsService.getProductsStream();
    _tasksStream = TasksService.getTasksStream();
    _announcementsStream = AnnouncementsService.getAnnouncementsStream();
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
      _productsDisplayCount = _initialPageSize;
      _tasksDisplayCount = _initialPageSize;
      _postsDisplayCount = _initialPageSize;
      _announcementsDisplayCount = _initialPageSize;
      _homeAnnouncementsDisplayCount = _initialPageSize;
      _homePostsDisplayCount = _initialPageSize;
      _homeTasksDisplayCount = _initialPageSize;
      _homeProductsDisplayCount = _initialPageSize;
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
      _productsDisplayCount = _initialPageSize;
      _tasksDisplayCount = _initialPageSize;
      _postsDisplayCount = _initialPageSize;
      _announcementsDisplayCount = _initialPageSize;
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
    if (!mounted) return;
    setState(() {
      _productsDisplayCount += _loadMorePageSize;
    });
  }

  void _loadMoreTasks() {
    if (!mounted) return;
    setState(() {
      _tasksDisplayCount += _loadMorePageSize;
    });
  }

  void _loadMorePosts() {
    if (!mounted) return;
    setState(() {
      _postsDisplayCount += _loadMorePageSize;
    });
  }

  void _loadMoreAnnouncements() {
    if (!mounted) return;
    setState(() {
      _announcementsDisplayCount += _loadMorePageSize;
    });
  }

  void _loadMoreHomeResults() {
    if (!mounted) return;
    setState(() {
      _homeAnnouncementsDisplayCount += _loadMorePageSize;
      _homePostsDisplayCount += _loadMorePageSize;
      _homeTasksDisplayCount += _loadMorePageSize;
      _homeProductsDisplayCount += _loadMorePageSize;
    });
  }

  Future<void> _markSearchProductAsViewedIfNeeded(
    ProductModel product,
    String currentUserId,
  ) async {
    if (product.id.isEmpty || product.sellerId == currentUserId) return;
    if (_searchAutoViewedProductIds.contains(product.id)) return;

    _searchAutoViewedProductIds.add(product.id);
    try {
      await ProductsService.markAsViewed(product.id, currentUserId);
    } catch (_) {
      _searchAutoViewedProductIds.remove(product.id);
    }
  }

  Future<void> _markSearchTaskAsViewedIfNeeded(
    TaskModel task,
    String currentUserId,
  ) async {
    if (task.id.isEmpty || task.requesterId == currentUserId) return;
    if (_searchAutoViewedTaskIds.contains(task.id)) return;

    _searchAutoViewedTaskIds.add(task.id);
    try {
      await TasksService.markAsViewed(task.id, currentUserId);
    } catch (_) {
      _searchAutoViewedTaskIds.remove(task.id);
    }
  }

  Widget _withSearchProductViewTracking({
    required ProductModel product,
    required String? currentUserId,
    required Widget child,
  }) {
    if (currentUserId == null || product.sellerId == currentUserId) {
      return child;
    }

    return VisibilityDetector(
      key: Key('search-product-visibility-${widget.mode.name}-${product.id}'),
      onVisibilityChanged: (info) {
        if (info.visibleFraction >= 0.6) {
          unawaited(_markSearchProductAsViewedIfNeeded(product, currentUserId));
        }
      },
      child: child,
    );
  }

  Widget _withSearchTaskViewTracking({
    required TaskModel task,
    required String? currentUserId,
    required Widget child,
  }) {
    if (currentUserId == null || task.requesterId == currentUserId) {
      return child;
    }

    return VisibilityDetector(
      key: Key('search-task-visibility-${widget.mode.name}-${task.id}'),
      onVisibilityChanged: (info) {
        if (info.visibleFraction >= 0.6) {
          unawaited(_markSearchTaskAsViewedIfNeeded(task, currentUserId));
        }
      },
      child: child,
    );
  }

  String _normalizeSearchText(String input) {
    return input
        .toLowerCase()
        .replaceAll(RegExp(r'[^a-z0-9\s]'), ' ')
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim();
  }

  List<String> _queryTokens(String query) {
    return _normalizeSearchText(query)
        .split(' ')
        .where((token) => token.length >= 2)
        .toList(growable: false);
  }

  int _levenshteinDistance(String a, String b) {
    if (a == b) return 0;
    if (a.isEmpty) return b.length;
    if (b.isEmpty) return a.length;

    final prev = List<int>.generate(b.length + 1, (i) => i);
    final curr = List<int>.filled(b.length + 1, 0);

    for (var i = 1; i <= a.length; i++) {
      curr[0] = i;
      for (var j = 1; j <= b.length; j++) {
        final cost = a.codeUnitAt(i - 1) == b.codeUnitAt(j - 1) ? 0 : 1;
        curr[j] = [
          curr[j - 1] + 1,
          prev[j] + 1,
          prev[j - 1] + cost,
        ].reduce((x, y) => x < y ? x : y);
      }
      for (var j = 0; j <= b.length; j++) {
        prev[j] = curr[j];
      }
    }

    return prev[b.length];
  }

  bool _isCloseWordMatch(String token, String word) {
    if (word.contains(token)) return true;
    if ((token.length - word.length).abs() > 2) return false;
    final maxDistance = token.length <= 4 ? 1 : 2;
    return _levenshteinDistance(token, word) <= maxDistance;
  }

  int _searchScore(String query, List<String> fields) {
    final normalizedQuery = _normalizeSearchText(query);
    if (normalizedQuery.isEmpty) return 1;

    final normalizedText = _normalizeSearchText(
      fields.where((field) => field.isNotEmpty).join(' '),
    );
    if (normalizedText.isEmpty) return 0;

    var score = 0;
    if (normalizedText.contains(normalizedQuery)) {
      score += 100;
    }

    final tokens = _queryTokens(normalizedQuery);
    if (tokens.isEmpty) {
      return score;
    }

    final words =
        normalizedText
            .split(' ')
            .where((word) => word.isNotEmpty)
            .toList(growable: false);
    var matchedTokens = 0;

    for (final token in tokens) {
      var matched = false;
      for (final word in words) {
        if (word == token) {
          score += 25;
          matched = true;
          break;
        }
        if (word.startsWith(token) ||
            (word.length >= 3 && token.startsWith(word))) {
          score += 15;
          matched = true;
          break;
        }
        if (_isCloseWordMatch(token, word)) {
          score += 8;
          matched = true;
          break;
        }
      }
      if (matched) {
        matchedTokens++;
      }
    }

    if (matchedTokens == 0) return 0;
    return score + (matchedTokens * 10);
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

  /// Helper method to check if search query matches a category
  bool _isCategorySearch(String queryLower, String category) {
    // Direct category name match
    if (queryLower.contains(category.toLowerCase())) return true;

    // Category-specific keyword matching
    switch (category) {
      case 'Clothing & Accessories':
        return queryLower.contains('clothing') ||
            queryLower.contains('clothes') ||
            queryLower.contains('dress') ||
            queryLower.contains('shirt') ||
            queryLower.contains('pants') ||
            queryLower.contains('accessories') ||
            queryLower.contains('fashion') ||
            queryLower.contains('wear');

      case 'Food and Beverage':
        return queryLower.contains('food') ||
            queryLower.contains('foods') ||
            queryLower.contains('eat') ||
            queryLower.contains('drink') ||
            queryLower.contains('beverage') ||
            queryLower.contains('snack') ||
            queryLower.contains('meal') ||
            queryLower.contains('cooking') ||
            queryLower.contains('edible');

      case 'Household & Living':
        return queryLower.contains('household') ||
            queryLower.contains('home') ||
            queryLower.contains('house') ||
            queryLower.contains('furniture') ||
            queryLower.contains('kitchen') ||
            queryLower.contains('living') ||
            queryLower.contains('decor') ||
            queryLower.contains('appliances') ||
            queryLower.contains('gadget') ||
            queryLower.contains('gadgets') ||
            queryLower.contains('electronics') ||
            queryLower.contains('device') ||
            queryLower.contains('devices') ||
            queryLower.contains('tech') ||
            queryLower.contains('technology') ||
            queryLower.contains('phone') ||
            queryLower.contains('computer') ||
            queryLower.contains('laptop') ||
            queryLower.contains('tablet') ||
            queryLower.contains('camera') ||
            queryLower.contains('speaker') ||
            queryLower.contains('headphone') ||
            queryLower.contains('charger') ||
            queryLower.contains('cable');

      case 'Health & Wellness':
        return queryLower.contains('health') ||
            queryLower.contains('medicine') ||
            queryLower.contains('wellness') ||
            queryLower.contains('medical') ||
            queryLower.contains('fitness') ||
            queryLower.contains('vitamin') ||
            queryLower.contains('supplement') ||
            queryLower.contains('hospital');

      case 'Vehicles & Transport':
        return queryLower.contains('vehicle') ||
            queryLower.contains('car') ||
            queryLower.contains('motorcycle') ||
            queryLower.contains('bike') ||
            queryLower.contains('transport') ||
            queryLower.contains('automobile') ||
            queryLower.contains('ride') ||
            queryLower.contains('drive');

      case 'Others':
        return false; // No specific keywords for "Others"

      default:
        return false;
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: isDark ? const Color(0xFF121212) : Colors.grey.shade100,
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              color: isDark ? const Color(0xFF1E1E1E) : Colors.white,
              padding: const EdgeInsets.fromLTRB(12, 8, 16, 12),
              child: Row(
                children: [
                  IconButton(
                    icon: const Icon(Icons.arrow_back_ios_new, size: 20),
                    onPressed: () => Navigator.of(context).pop(),
                    padding: EdgeInsets.zero,
                    splashRadius: 22,
                    color: isDark ? Colors.white : Colors.black87,
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
                          color:
                              isDark
                                  ? Colors.grey.shade400
                                  : Colors.grey.shade600,
                        ),
                        border: InputBorder.none,
                        contentPadding: const EdgeInsets.symmetric(
                          vertical: 12,
                          horizontal: 4,
                        ),
                      ),
                      style: TextStyle(
                        fontSize: 16,
                        color: isDark ? Colors.white : Colors.black87,
                      ),
                    ),
                  ),
                  IconButton(
                    icon: Icon(
                      Icons.search,
                      color:
                          isDark
                              ? Colors.grey.shade300
                              : const Color(0xFF6E6E6E),
                      size: 26,
                    ),
                    onPressed: _runSearch,
                    splashRadius: 22,
                  ),
                ],
              ),
            ),
            Expanded(child: _buildBody()),
          ],
        ),
      ),
    );
  }

  Widget _buildBody() {
    final isDark = Theme.of(context).brightness == Brightness.dark;

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
                    style: TextStyle(
                      fontSize: 16,
                      color:
                          isDark ? Colors.grey.shade400 : Colors.grey.shade600,
                    ),
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
                color: isDark ? Colors.grey.shade400 : Colors.grey.shade700,
              ),
            ),
            const SizedBox(height: 10),
            ..._recentSearches.map(
              (term) => Material(
                color: Colors.transparent,
                child: InkWell(
                  onTap: () => _applyRecentSearch(term),
                  borderRadius: BorderRadius.circular(12),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                      vertical: 14,
                      horizontal: 4,
                    ),
                    child: Row(
                      children: [
                        Icon(
                          Icons.history,
                          size: 20,
                          color: Colors.grey.shade600,
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            term,
                            style: TextStyle(
                              fontSize: 15,
                              color: isDark ? Colors.white : Colors.black87,
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
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

  Future<Map<String, dynamic>> _fetchHomeSearchResults(
    String queryLower,
    String? currentUserId,
  ) async {
    try {
      final results = await Future.wait([
        AnnouncementsService.getAnnouncementsStream().first,
        PostsService.getPostsStream().first,
        TasksService.getTasksStream().first,
        ProductsService.getProductsStream().first,
      ]);
      final announcements =
          results[0] is List<Map<String, dynamic>>
              ? results[0] as List<Map<String, dynamic>>
              : <Map<String, dynamic>>[];
      final posts =
          results[1] is List<PostModel>
              ? results[1] as List<PostModel>
              : <PostModel>[];
      final tasks =
          results[2] is List<TaskModel>
              ? results[2] as List<TaskModel>
              : <TaskModel>[];
      final products =
          results[3] is List<ProductModel>
              ? results[3] as List<ProductModel>
              : <ProductModel>[];

      final filterAnn =
          queryLower.isEmpty
              ? announcements
              : announcements.where((a) {
                final title = (a['title'] as String? ?? '').toLowerCase();
                final content =
                    (a['content'] as String? ??
                            a['description'] as String? ??
                            '')
                        .toLowerCase();
                return title.contains(queryLower) ||
                    content.contains(queryLower);
              }).toList();

      final filterPosts =
          queryLower.isEmpty
              ? posts
              : posts
                  .where(
                    (p) =>
                        p.title.toLowerCase().contains(queryLower) ||
                        p.content.toLowerCase().contains(queryLower),
                  )
                  .toList();

      final nonCompleted =
          tasks.where((t) => t.status != TaskStatus.completed).toList();
      final feedTasks =
          currentUserId != null
              ? nonCompleted
                  .where((t) => t.requesterId != currentUserId)
                  .toList()
              : nonCompleted;
      final filterTasks =
          queryLower.isEmpty
              ? feedTasks
              : feedTasks
                  .where(
                    (t) =>
                        t.title.toLowerCase().contains(queryLower) ||
                        t.description.toLowerCase().contains(queryLower),
                  )
                  .toList();

      final feedProducts =
          currentUserId != null
              ? products.where((p) => p.sellerId != currentUserId).toList()
              : products;
      final filterProducts =
          queryLower.isEmpty
              ? feedProducts
              : feedProducts
                  .where(
                    (p) =>
                        p.title.toLowerCase().contains(queryLower) ||
                        p.description.toLowerCase().contains(queryLower),
                  )
                  .toList();

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
    final isDark = Theme.of(context).brightness == Brightness.dark;

    final query = _searchQuery ?? '';
    final queryLower = query.toLowerCase();
    final currentUserId = FirestoreService.currentUserId;

    // If no search query, show recent searches or empty state
    if (queryLower.isEmpty) {
      return _buildRecentSearches();
    }

    // Use a single combined stream to avoid rebuilds that reset scroll position
    return StreamBuilder<Map<String, dynamic>>(
      stream: _getCombinedHomeSearchStream(queryLower, currentUserId),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }

        final data = snapshot.data ?? {};
        final announcements =
            data['announcements'] as List<Map<String, dynamic>>? ?? [];
        final posts = data['posts'] as List<PostModel>? ?? [];
        final tasks = data['tasks'] as List<TaskModel>? ?? [];
        final products = data['products'] as List<ProductModel>? ?? [];

        final totalResults =
            announcements.length +
            posts.length +
            tasks.length +
            products.length;

        // Show unified empty state if no results
        if (totalResults == 0) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.search_off, size: 64, color: Colors.grey.shade400),
                const SizedBox(height: 16),
                Text(
                  'No results for "$query"',
                  style: TextStyle(
                    fontSize: 16,
                    color: isDark ? Colors.grey.shade300 : Colors.grey.shade600,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 8),
                Text(
                  'Try searching for announcements, posts,\nproducts, or errands',
                  style: TextStyle(
                    fontSize: 14,
                    color: isDark ? Colors.grey.shade400 : Colors.grey.shade500,
                  ),
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          );
        }

        return CustomScrollView(
          key: const PageStorageKey('search_home_results'),
          controller: _homeScrollController,
          physics: const BouncingScrollPhysics(),
          slivers: [
            // Announcements Section
            if (announcements.isNotEmpty)
              SliverToBoxAdapter(
                child: _buildHomeAnnouncementsSectionFromData(
                  announcements,
                  queryLower,
                ),
              ),
            // Posts Section
            if (posts.isNotEmpty)
              SliverToBoxAdapter(
                child: _buildHomePostsSectionFromData(posts, queryLower),
              ),
            // Tasks Section
            if (tasks.isNotEmpty)
              SliverToBoxAdapter(
                child: _buildHomeTasksSectionFromData(
                  tasks,
                  queryLower,
                  currentUserId,
                ),
              ),
            // Products Section
            if (products.isNotEmpty)
              SliverToBoxAdapter(
                child: _buildHomeProductsSectionFromData(
                  products,
                  queryLower,
                  currentUserId,
                ),
              ),
            // Bottom padding
            SliverToBoxAdapter(child: _buildHomeLoadMoreIndicator()),
          ],
        );
      },
    );
  }

  /// Combined stream that emits all search results at once - preserves scroll position
  Stream<Map<String, dynamic>> _getCombinedHomeSearchStream(
    String queryLower,
    String? currentUserId,
  ) {
    if (_homeCombinedStream != null &&
        _homeCombinedQuery == queryLower &&
        _homeCombinedUserId == currentUserId) {
      return _homeCombinedStream!;
    }

    _homeCombinedQuery = queryLower;
    _homeCombinedUserId = currentUserId;

    _homeCombinedStream = Rx.combineLatest4(
      _announcementsStream,
      _postsStream,
      _tasksStream,
      _productsStream,
      (
        List<Map<String, dynamic>> announcements,
        List<PostModel> posts,
        List<TaskModel> tasks,
        List<ProductModel> products,
      ) {
        // Filter announcements with tolerant matching and relevance sorting
        final filteredAnnouncements =
            announcements
                .map((a) {
                  final score = _searchScore(queryLower, [
                    a['title'] as String? ?? '',
                    a['content'] as String? ?? a['description'] as String? ?? '',
                    a['postedBy'] as String? ?? '',
                  ]);
                  return MapEntry(a, score);
                })
                .where((entry) => scoreOrAll(queryLower, entry.value))
                .toList()
              ..sort((a, b) => b.value.compareTo(a.value));

        // Filter posts with tolerant matching and relevance sorting
        final filteredPosts =
            posts
                .map((p) {
                  final score = _searchScore(queryLower, [
                    p.title,
                    p.content,
                    p.userName,
                  ]);
                  return MapEntry(p, score);
                })
                .where((entry) => scoreOrAll(queryLower, entry.value))
                .toList()
              ..sort((a, b) => b.value.compareTo(a.value));

        // Filter tasks
        final nonCompleted =
            tasks.where((t) => t.status != TaskStatus.completed).toList();
        final feedTasks =
            currentUserId != null
                ? nonCompleted
                    .where((t) => t.requesterId != currentUserId)
                    .toList()
                : nonCompleted;
        final filteredTasks =
            feedTasks
                .map((t) {
                  final score = _searchScore(queryLower, [
                    t.title,
                    t.description,
                    t.requesterName,
                  ]);
                  return MapEntry(t, score);
                })
                .where((entry) => scoreOrAll(queryLower, entry.value))
                .toList()
              ..sort((a, b) => b.value.compareTo(a.value));

        // Filter products
        final feedProducts =
            currentUserId != null
                ? products.where((p) => p.sellerId != currentUserId).toList()
                : products;
        final filteredProducts =
            feedProducts
                .map((p) {
                  var score = _searchScore(queryLower, [
                    p.title,
                    p.description,
                    p.sellerName,
                    p.category,
                  ]);
                  if (_isCategorySearch(queryLower, p.category)) {
                    score += 20;
                  }
                  return MapEntry(p, score);
                })
                .where((entry) => scoreOrAll(queryLower, entry.value))
                .toList()
              ..sort((a, b) => b.value.compareTo(a.value));

        return {
          'announcements': filteredAnnouncements.map((e) => e.key).toList(),
          'posts': filteredPosts.map((e) => e.key).toList(),
          'tasks': filteredTasks.map((e) => e.key).toList(),
          'products': filteredProducts.map((e) => e.key).toList(),
        };
      },
    );

    return _homeCombinedStream!;
  }

  Stream<List<ProductModel>> _getMyProductsStream(String currentUserId) {
    if (_myProductsStream == null || _myProductsStreamUid != currentUserId) {
      _myProductsStreamUid = currentUserId;
      _myProductsStream = ProductsService.getSellerProductsStream(currentUserId);
    }
    return _myProductsStream!;
  }

  Stream<List<TaskModel>> _getMyTasksStream(String currentUserId) {
    if (_myTasksStream == null || _myTasksStreamUid != currentUserId) {
      _myTasksStreamUid = currentUserId;
      _myTasksStream = TasksService.getRequesterTasksStream(currentUserId);
    }
    return _myTasksStream!;
  }

  bool scoreOrAll(String queryLower, int score) {
    return queryLower.isEmpty || score > 0;
  }

  Widget _buildHomeAnnouncementsSectionFromData(
    List<Map<String, dynamic>> announcements,
    String queryLower,
  ) {
    final visibleCount = _homeAnnouncementsDisplayCount.clamp(
      0,
      announcements.length,
    );
    final showLoadMore = visibleCount < announcements.length;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: _sectionHeader('Announcements'),
        ),
        ...announcements
            .take(visibleCount)
            .map(
              (a) => Padding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                child: _announcementCardFromMap(a),
              ),
            ),
        if (showLoadMore)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 16),
            child: Center(
              child: GestureDetector(
                onTap: () {
                  if (!mounted) return;
                  setState(() {
                    _homeAnnouncementsDisplayCount += _loadMorePageSize;
                  });
                },
                child: Text(
                  'Load more',
                  style: TextStyle(
                    fontSize: 14,
                    color: const Color(0xFF00A651),
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ),
          ),
        const SizedBox(height: 20),
      ],
    );
  }

  Widget _buildHomePostsSectionFromData(
    List<PostModel> posts,
    String queryLower,
  ) {
    final visibleCount = _homePostsDisplayCount.clamp(0, posts.length);
    final showLoadMore = visibleCount < posts.length;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _sectionHeader('Posts'),
        ...posts
            .take(visibleCount)
            .map(
              (post) => Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: PostCard(post: post),
              ),
            ),
        if (showLoadMore)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 16),
            child: Center(
              child: GestureDetector(
                onTap: () {
                  if (!mounted) return;
                  setState(() {
                    _homePostsDisplayCount += _loadMorePageSize;
                  });
                },
                child: Text(
                  'Load more',
                  style: TextStyle(
                    fontSize: 14,
                    color: const Color(0xFF00A651),
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ),
          ),
        const SizedBox(height: 20),
      ],
    );
  }

  Widget _buildHomeTasksSectionFromData(
    List<TaskModel> tasks,
    String queryLower,
    String? currentUserId,
  ) {
    final visibleCount = _homeTasksDisplayCount.clamp(0, tasks.length);
    final showLoadMore = visibleCount < tasks.length;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _sectionHeader('Errands / Jobs'),
        ...tasks.take(visibleCount).map((task) {
          final isOwner =
              currentUserId != null && task.requesterId == currentUserId;
          return Padding(
            padding: const EdgeInsets.only(bottom: 16),
            child: _withSearchTaskViewTracking(
              task: task,
              currentUserId: currentUserId,
              child: ErrandJobCard(
                title: task.title,
                description: task.description,
                postedBy: task.requesterName,
                date: task.createdAt,
                taskId: task.id,
                viewCount: task.viewCount,
                imageUrls: task.imageUrls,
                status: _mapTaskStatus(task.status),
                statusLabel: task.status.displayName,
                volunteerName: task.assignedByName,
                showTag: true,
                viewButtonLabel: isOwner ? 'Edit' : 'View',
                viewButtonIcon:
                    isOwner ? Icons.edit_outlined : Icons.visibility_outlined,
                onViewPressed: () {
                  Navigator.of(context).push(
                    MaterialPageRoute(
                      builder:
                          (_) =>
                              isOwner
                                  ? TaskEditScreen(task: task)
                                  : TaskDetailScreen(task: task),
                    ),
                  );
                },
              ),
            ),
          );
        }),
        if (showLoadMore)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 16),
            child: Center(
              child: GestureDetector(
                onTap: () {
                  if (!mounted) return;
                  setState(() {
                    _homeTasksDisplayCount += _loadMorePageSize;
                  });
                },
                child: Text(
                  'Load more',
                  style: TextStyle(
                    fontSize: 14,
                    color: const Color(0xFF00A651),
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ),
          ),
        const SizedBox(height: 20),
      ],
    );
  }

  Widget _buildHomeProductsSectionFromData(
    List<ProductModel> products,
    String queryLower,
    String? currentUserId,
  ) {
    final visibleCount = _homeProductsDisplayCount.clamp(0, products.length);
    final showLoadMore = visibleCount < products.length;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _sectionHeader('Marketplace'),
        ...products
            .take(visibleCount)
            .map(
              (product) => Padding(
                padding: const EdgeInsets.only(bottom: 16),
                child: _withSearchProductViewTracking(
                  product: product,
                  currentUserId: currentUserId,
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
                ),
              ),
            ),
        if (showLoadMore)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 16),
            child: Center(
              child: GestureDetector(
                onTap: () {
                  if (!mounted) return;
                  setState(() {
                    _homeProductsDisplayCount += _loadMorePageSize;
                  });
                },
                child: Text(
                  'Load more',
                  style: TextStyle(
                    fontSize: 14,
                    color: const Color(0xFF00A651),
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ),
          ),
        const SizedBox(height: 24),
      ],
    );
  }

  /// Count results across all sections to determine if we should show empty state
  Future<Map<String, int>> _countHomeSearchResults(
    String queryLower,
    String? currentUserId,
  ) async {
    try {
      final results = await Future.wait([
        AnnouncementsService.getAnnouncementsStream().first,
        PostsService.getPostsStream().first,
        TasksService.getTasksStream().first,
        ProductsService.getProductsStream().first,
      ]);

      final announcements =
          results[0] is List<Map<String, dynamic>>
              ? results[0] as List<Map<String, dynamic>>
              : <Map<String, dynamic>>[];
      final posts =
          results[1] is List<PostModel>
              ? results[1] as List<PostModel>
              : <PostModel>[];
      final tasks =
          results[2] is List<TaskModel>
              ? results[2] as List<TaskModel>
              : <TaskModel>[];
      final products =
          results[3] is List<ProductModel>
              ? results[3] as List<ProductModel>
              : <ProductModel>[];

      // Count announcements
      final annCount =
          announcements.where((a) {
            final title = (a['title'] as String? ?? '').toLowerCase();
            final content =
                (a['content'] as String? ?? a['description'] as String? ?? '')
                    .toLowerCase();
            final postedBy = (a['postedBy'] as String? ?? '').toLowerCase();
            return title.contains(queryLower) ||
                content.contains(queryLower) ||
                postedBy.contains(queryLower);
          }).length;

      // Count posts
      final postsCount =
          posts
              .where(
                (p) =>
                    p.title.toLowerCase().contains(queryLower) ||
                    p.content.toLowerCase().contains(queryLower) ||
                    p.userName.toLowerCase().contains(queryLower),
              )
              .length;

      // Count tasks
      final nonCompleted =
          tasks.where((t) => t.status != TaskStatus.completed).toList();
      final feedTasks =
          currentUserId != null
              ? nonCompleted
                  .where((t) => t.requesterId != currentUserId)
                  .toList()
              : nonCompleted;
      final tasksCount =
          feedTasks
              .where(
                (t) =>
                    t.title.toLowerCase().contains(queryLower) ||
                    t.description.toLowerCase().contains(queryLower) ||
                    t.requesterName.toLowerCase().contains(queryLower),
              )
              .length;

      // Count products
      final feedProducts =
          currentUserId != null
              ? products.where((p) => p.sellerId != currentUserId).toList()
              : products;
      final productsCount =
          feedProducts.where((p) {
            // Check if search query matches this product's category
            final isCategoryMatch = _isCategorySearch(queryLower, p.category);

            // Match by title, description, seller name, or category
            final textMatch =
                p.title.toLowerCase().contains(queryLower) ||
                p.description.toLowerCase().contains(queryLower) ||
                p.sellerName.toLowerCase().contains(queryLower);

            return textMatch || isCategoryMatch;
          }).length;

      return {
        'announcements': annCount,
        'posts': postsCount,
        'tasks': tasksCount,
        'products': productsCount,
      };
    } catch (_) {
      return {'announcements': 0, 'posts': 0, 'tasks': 0, 'products': 0};
    }
  }

  Widget _buildHomeAnnouncementsSection(
    String queryLower,
    String? currentUserId,
  ) {
    return StreamBuilder<List<Map<String, dynamic>>>(
      stream: AnnouncementsService.getAnnouncementsStream(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const SizedBox(
            height: 100,
            child: Center(child: CircularProgressIndicator()),
          );
        }

        final announcements = snapshot.data ?? [];
        final filtered =
            announcements.where((a) {
              final title = (a['title'] as String? ?? '').toLowerCase();
              final content =
                  (a['content'] as String? ?? a['description'] as String? ?? '')
                      .toLowerCase();
              final postedBy = (a['postedBy'] as String? ?? '').toLowerCase();
              return title.contains(queryLower) ||
                  content.contains(queryLower) ||
                  postedBy.contains(queryLower);
            }).toList();

        final visibleCount = _homeAnnouncementsDisplayCount.clamp(
          0,
          filtered.length,
        );
        final showLoadMore = visibleCount < filtered.length;

        if (filtered.isEmpty) return const SizedBox.shrink();

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: _sectionHeader('Announcements'),
            ),
            ...filtered
                .take(visibleCount)
                .map(
                  (a) => Padding(
                    padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                    child: _announcementCardFromMap(a),
                  ),
                ),
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
      stream: _postsStream,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const SizedBox(
            height: 100,
            child: Center(child: CircularProgressIndicator()),
          );
        }

        final posts = snapshot.data ?? [];
        final filtered =
            posts
                .where(
                  (p) =>
                      p.title.toLowerCase().contains(queryLower) ||
                      p.content.toLowerCase().contains(queryLower) ||
                      p.userName.toLowerCase().contains(queryLower),
                )
                .toList();

        final visibleCount = _homePostsDisplayCount.clamp(0, filtered.length);
        final showLoadMore = visibleCount < filtered.length;

        if (filtered.isEmpty) return const SizedBox.shrink();

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _sectionHeader('Posts'),
            ...filtered
                .take(visibleCount)
                .map(
                  (post) => Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: PostCard(post: post),
                  ),
                ),
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
          return const SizedBox(
            height: 100,
            child: Center(child: CircularProgressIndicator()),
          );
        }

        final tasks = snapshot.data ?? [];
        final nonCompleted =
            tasks.where((t) => t.status != TaskStatus.completed).toList();
        final feedTasks =
            currentUserId != null
                ? nonCompleted
                    .where((t) => t.requesterId != currentUserId)
                    .toList()
                : nonCompleted;
        final filtered =
            feedTasks
                .where(
                  (t) =>
                      t.title.toLowerCase().contains(queryLower) ||
                      t.description.toLowerCase().contains(queryLower) ||
                      t.requesterName.toLowerCase().contains(queryLower),
                )
                .toList();

        final visibleCount = _homeTasksDisplayCount.clamp(0, filtered.length);
        final showLoadMore = visibleCount < filtered.length;

        if (filtered.isEmpty) return const SizedBox.shrink();

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _sectionHeader('Errands / Jobs'),
            ...filtered.take(visibleCount).map((task) {
              final isOwner =
                  currentUserId != null && task.requesterId == currentUserId;
              return Padding(
                padding: const EdgeInsets.only(bottom: 16),
                child: _withSearchTaskViewTracking(
                  task: task,
                  currentUserId: currentUserId,
                  child: ErrandJobCard(
                    title: task.title,
                    description: task.description,
                    postedBy: task.requesterName,
                    date: task.createdAt,
                    taskId: task.id,
                    viewCount: task.viewCount,
                    imageUrls: task.imageUrls,
                    status: _mapTaskStatus(task.status),
                    statusLabel: task.status.displayName,
                    volunteerName: task.assignedByName,
                    showTag: true,
                    viewButtonLabel: isOwner ? 'Edit' : 'View',
                    viewButtonIcon:
                        isOwner
                            ? Icons.edit_outlined
                            : Icons.visibility_outlined,
                    onViewPressed: () {
                      Navigator.of(context).push(
                        MaterialPageRoute(
                          builder:
                              (_) =>
                                  isOwner
                                      ? TaskEditScreen(task: task)
                                      : TaskDetailScreen(task: task),
                        ),
                      );
                    },
                  ),
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
          return const SizedBox(
            height: 100,
            child: Center(child: CircularProgressIndicator()),
          );
        }

        final products = snapshot.data ?? [];
        final feedProducts =
            currentUserId != null
                ? products.where((p) => p.sellerId != currentUserId).toList()
                : products;
        final filtered =
            feedProducts.where((p) {
              // Check if search query matches this product's category
              final isCategoryMatch = _isCategorySearch(queryLower, p.category);

              // Match by title, description, seller name, or category
              final textMatch =
                  p.title.toLowerCase().contains(queryLower) ||
                  p.description.toLowerCase().contains(queryLower) ||
                  p.sellerName.toLowerCase().contains(queryLower);

              return textMatch || isCategoryMatch;
            }).toList();

        final visibleCount = _homeProductsDisplayCount.clamp(
          0,
          filtered.length,
        );
        final showLoadMore = visibleCount < filtered.length;

        if (filtered.isEmpty) return const SizedBox.shrink();

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _sectionHeader('Marketplace'),
            ...filtered
                .take(visibleCount)
                .map(
                  (product) => Padding(
                    padding: const EdgeInsets.only(bottom: 16),
                    child: _withSearchProductViewTracking(
                      product: product,
                      currentUserId: currentUserId,
                      child: ProductCard(
                        product: product,
                        showTag: true,
                        onInteract: () {
                          Navigator.of(context).push(
                            MaterialPageRoute(
                              builder:
                                  (_) => ProductDetailScreen(product: product),
                            ),
                          );
                        },
                      ),
                    ),
                  ),
                ),
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
    final description =
        a['content'] as String? ?? a['description'] as String? ?? '';
    final postedBy = a['postedBy'] as String? ?? 'Barangay Official';
    final postedByPosition = a['postedByPosition'] as String?;
    final date =
        a['date'] as DateTime? ?? a['createdAt'] as DateTime? ?? DateTime.now();
    final category = a['category'] as String?;
    final viewCount = a['viewCount'] as int? ?? 0;
    final imageUrlsRaw = a['imageUrls'] as List<dynamic>?;
    final imageUrls = imageUrlsRaw?.whereType<String>().toList();
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
      imageUrls: imageUrls?.isNotEmpty == true ? imageUrls : null,
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
        final filtered =
            queryLower.isEmpty
                ? allPosts
                : (allPosts
                      .map((p) {
                        final score = _searchScore(queryLower, [
                          p.title,
                          p.content,
                          p.userName,
                        ]);
                        return MapEntry(p, score);
                      })
                      .where((entry) => entry.value > 0)
                      .toList()
                    ..sort((a, b) => b.value.compareTo(a.value)))
                    .map((entry) => entry.key)
                    .toList();

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
          key: const PageStorageKey('search_posts_results'),
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
          physics: const BouncingScrollPhysics(),
          itemCount: filtered.length,
          itemBuilder: (context, index) {
            final post = filtered[index];
            return Padding(
              padding: EdgeInsets.only(
                bottom: index < filtered.length - 1 ? 12 : 0,
              ),
              child: PostCard(post: post),
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
      stream: _productsStream,
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
        final feedProducts =
            currentUserId != null
                ? allProducts.where((p) => p.sellerId != currentUserId).toList()
                : allProducts;
        final filtered =
            queryLower.isEmpty
                ? feedProducts
                : (feedProducts
                      .map((p) {
                        var score = _searchScore(queryLower, [
                          p.title,
                          p.description,
                          p.sellerName,
                          p.category,
                        ]);
                        if (_isCategorySearch(queryLower, p.category)) {
                          score += 20;
                        }
                        return MapEntry(p, score);
                      })
                      .where((entry) => entry.value > 0)
                      .toList()
                    ..sort((a, b) => b.value.compareTo(a.value)))
                    .map((entry) => entry.key)
                    .toList();

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
          key: const PageStorageKey('search_products_results'),
          controller: _productsScrollController,
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
          physics: const BouncingScrollPhysics(),
          itemCount: visibleCount + (showLoadMore ? 1 : 0),
          itemBuilder: (context, index) {
            if (index < visibleCount) {
              final product = filtered[index];
              return Padding(
                padding: EdgeInsets.only(
                  bottom: index < visibleCount - 1 ? 16 : 0,
                ),
                child: _withSearchProductViewTracking(
                  product: product,
                  currentUserId: currentUserId,
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
                ),
              );
            } else {
              // Load more indicator
              return Padding(
                padding: const EdgeInsets.symmetric(vertical: 16),
                child: Center(child: CircularProgressIndicator()),
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
      stream: _tasksStream,
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
        final nonCompleted =
            allTasks.where((t) => t.status != TaskStatus.completed).toList();
        final feedTasks =
            currentUserId != null
                ? nonCompleted
                    .where((t) => t.requesterId != currentUserId)
                    .toList()
                : nonCompleted;
        final filtered =
            queryLower.isEmpty
                ? feedTasks
                : (feedTasks
                      .map((t) {
                        final score = _searchScore(queryLower, [
                          t.title,
                          t.description,
                          t.requesterName,
                        ]);
                        return MapEntry(t, score);
                      })
                      .where((entry) => entry.value > 0)
                      .toList()
                    ..sort((a, b) => b.value.compareTo(a.value)))
                    .map((entry) => entry.key)
                    .toList();

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
          key: const PageStorageKey('search_tasks_results'),
          controller: _tasksScrollController,
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
          physics: const BouncingScrollPhysics(),
          itemCount: visibleCount + (showLoadMore ? 1 : 0),
          itemBuilder: (context, index) {
            if (index < visibleCount) {
              final task = filtered[index];
              final isOwner =
                  currentUserId != null && task.requesterId == currentUserId;
              return Padding(
                padding: EdgeInsets.only(
                  bottom: index < visibleCount - 1 ? 16 : 0,
                ),
                child: _withSearchTaskViewTracking(
                  task: task,
                  currentUserId: currentUserId,
                  child: ErrandJobCard(
                    title: task.title,
                    description: task.description,
                    postedBy: task.requesterName,
                    date: task.createdAt,
                    taskId: task.id,
                    viewCount: task.viewCount,
                    imageUrls: task.imageUrls,
                    status: _mapTaskStatus(task.status),
                    statusLabel: task.status.displayName,
                    volunteerName: task.assignedByName,
                    showTag: true,
                    viewButtonLabel: isOwner ? 'Edit' : 'View',
                    viewButtonIcon:
                        isOwner
                            ? Icons.edit_outlined
                            : Icons.visibility_outlined,
                    onViewPressed: () {
                      Navigator.of(context).push(
                        MaterialPageRoute(
                          builder:
                              (_) =>
                                  isOwner
                                      ? TaskEditScreen(task: task)
                                      : TaskDetailScreen(task: task),
                        ),
                      );
                    },
                  ),
                ),
              );
            } else {
              // Load more indicator
              return Padding(
                padding: const EdgeInsets.symmetric(vertical: 16),
                child: Center(child: CircularProgressIndicator()),
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
      stream: _announcementsStream,
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
        final filtered =
            queryLower.isEmpty
                ? all
                : ((all
                          .map((a) {
                            final score = _searchScore(queryLower, [
                              a['title'] as String? ?? '',
                              a['content'] as String? ??
                                  a['description'] as String? ??
                                  '',
                              a['postedBy'] as String? ?? '',
                            ]);
                            return MapEntry(a, score);
                          })
                          .where((entry) => entry.value > 0)
                          .toList()
                        ..sort((a, b) => b.value.compareTo(a.value)))
                    .map((entry) => entry.key)
                      .toList());

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

        final visibleCount = _announcementsDisplayCount.clamp(
          0,
          filtered.length,
        );
        final showLoadMore = visibleCount < filtered.length;

        return ListView.builder(
          key: const PageStorageKey('search_announcements_results'),
          controller: _announcementsScrollController,
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
          physics: const BouncingScrollPhysics(),
          itemCount: visibleCount + (showLoadMore ? 1 : 0),
          itemBuilder: (context, index) {
            if (index < visibleCount) {
              final a = filtered[index];
              final id = a['id'] as String? ?? '';
              final title = a['title'] as String? ?? '';
              final description =
                  a['content'] as String? ?? a['description'] as String? ?? '';
              final postedBy = a['postedBy'] as String? ?? 'Barangay Official';
              final postedByPosition = a['postedByPosition'] as String?;
              final date =
                  a['date'] as DateTime? ??
                  a['createdAt'] as DateTime? ??
                  DateTime.now();
              final category = a['category'] as String?;
              final viewCount = a['viewCount'] as int? ?? 0;
              final imageUrlsRaw = a['imageUrls'] as List<dynamic>?;
              final imageUrls = imageUrlsRaw?.whereType<String>().toList();
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
                  imageUrls: imageUrls?.isNotEmpty == true ? imageUrls : null,
                  onMarkAsReadPressed: () {},
                ),
              );
            } else {
              // Load more indicator
              return Padding(
                padding: const EdgeInsets.symmetric(vertical: 16),
                child: Center(child: CircularProgressIndicator()),
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
      stream: _getMyProductsStream(currentUserId),
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
        final filtered =
            queryLower.isEmpty
                ? all
                : (all
                      .map((p) {
                        var score = _searchScore(queryLower, [
                          p.title,
                          p.description,
                          p.category,
                        ]);
                        if (_isCategorySearch(queryLower, p.category)) {
                          score += 20;
                        }
                        return MapEntry(p, score);
                      })
                      .where((entry) => entry.value > 0)
                      .toList()
                    ..sort((a, b) => b.value.compareTo(a.value)))
                    .map((entry) => entry.key)
                    .toList();

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
          physics: const BouncingScrollPhysics(),
          itemCount: filtered.length,
          itemBuilder: (context, index) {
            final product = filtered[index];
            return Padding(
              padding: EdgeInsets.only(
                bottom: index < filtered.length - 1 ? 16 : 0,
              ),
              child: _withSearchProductViewTracking(
                product: product,
                currentUserId: currentUserId,
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
      stream: _getMyTasksStream(currentUserId),
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
        final filtered =
            queryLower.isEmpty
                ? all
                : (all
                      .map((t) {
                        final score = _searchScore(queryLower, [
                          t.title,
                          t.description,
                        ]);
                        return MapEntry(t, score);
                      })
                      .where((entry) => entry.value > 0)
                      .toList()
                    ..sort((a, b) => b.value.compareTo(a.value)))
                    .map((entry) => entry.key)
                    .toList();

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
          physics: const BouncingScrollPhysics(),
          itemCount: filtered.length,
          itemBuilder: (context, index) {
            final task = filtered[index];
            return Padding(
              padding: EdgeInsets.only(
                bottom: index < filtered.length - 1 ? 16 : 0,
              ),
              child: _withSearchTaskViewTracking(
                task: task,
                currentUserId: currentUserId,
                child: ErrandJobCard(
                  title: task.title,
                  description: task.description,
                  postedBy: task.requesterName,
                  date: task.createdAt,
                  taskId: task.id,
                  viewCount: task.viewCount,
                  imageUrls: task.imageUrls,
                  status: _mapTaskStatus(task.status),
                  statusLabel: task.status.displayName,
                  volunteerName: task.assignedByName,
                  showTag: true,
                  viewButtonLabel: 'Edit',
                  viewButtonIcon: Icons.edit_outlined,
                  onViewPressed: () {
                    Navigator.of(context).push(
                      MaterialPageRoute(
                        builder:
                            (_) => TaskEditScreen(
                              task: task,
                              contactNumber: task.contactNumber ?? '',
                            ),
                      ),
                    );
                  },
                ),
              ),
            );
          },
        );
      },
    );
  }
}
