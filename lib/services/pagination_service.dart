import 'package:flutter/material.dart';

/// A reusable pagination service for efficient scrolling with data culling
class PaginationService<T> {
  final List<T> allItems;
  final int initialPageSize;
  final int loadMorePageSize;
  final double scrollThreshold;

  int _displayCount;
  final ScrollController _scrollController;
  VoidCallback? _onLoadMore;

  PaginationService({
    required this.allItems,
    this.initialPageSize = 15,
    this.loadMorePageSize = 15,
    this.scrollThreshold = 200.0,
  }) : _displayCount = initialPageSize,
       _scrollController = ScrollController() {
    _scrollController.addListener(_onScroll);
  }

  /// Get the current display count
  int get displayCount => _displayCount;

  /// Get the total number of items
  int get totalCount => allItems.length;

  /// Get the scroll controller for the ListView
  ScrollController get scrollController => _scrollController;

  /// Get the currently visible items
  List<T> get visibleItems {
    final count = _displayCount.clamp(0, allItems.length);
    return allItems.take(count).toList();
  }

  /// Check if there are more items to load
  bool get hasMore => _displayCount < allItems.length;

  /// Check if load more button should be shown
  bool get showLoadMore => hasMore;

  /// Set the callback for loading more data
  void setOnLoadMore(VoidCallback callback) {
    _onLoadMore = callback;
  }

  /// Load more items
  void loadMore() {
    if (!hasMore) return;
    
    setState(() {
      _displayCount = (_displayCount + loadMorePageSize).clamp(0, allItems.length);
    });
    
    _onLoadMore?.call();
  }

  /// Reset pagination to initial state
  void reset() {
    setState(() {
      _displayCount = initialPageSize;
    });
  }

  /// Update the items list and reset pagination
  void updateItems(List<T> newItems) {
    // This would be called from the widget's setState
    // The actual state update needs to happen in the widget
  }

  /// Handle scroll events
  void _onScroll() {
    if (!_scrollController.hasClients) return;
    
    final maxScroll = _scrollController.position.maxScrollExtent;
    final currentScroll = _scrollController.position.pixels;
    
    if (maxScroll - currentScroll < scrollThreshold) {
      loadMore();
    }
  }

  /// Dispose the controller
  void dispose() {
    _scrollController.dispose();
  }

  /// This method should be called from the widget's setState
  void setState(VoidCallback fn) {
    fn();
  }
}

/// A widget that provides pagination functionality
class PaginatedListView<T> extends StatefulWidget {
  final List<T> items;
  final Widget Function(BuildContext context, T item, int index) itemBuilder;
  final int initialPageSize;
  final int loadMorePageSize;
  final double scrollThreshold;
  final EdgeInsets? padding;
  final ScrollPhysics? physics;
  final Widget? emptyWidget;
  final Widget? loadingWidget;
  final VoidCallback? onLoadMore;

  const PaginatedListView({
    super.key,
    required this.items,
    required this.itemBuilder,
    this.initialPageSize = 15,
    this.loadMorePageSize = 15,
    this.scrollThreshold = 200.0,
    this.padding,
    this.physics,
    this.emptyWidget,
    this.loadingWidget,
    this.onLoadMore,
  });

  @override
  State<PaginatedListView<T>> createState() => _PaginatedListViewState<T>();
}

class _PaginatedListViewState<T> extends State<PaginatedListView<T>> {
  late PaginationService<T> _paginationService;

  @override
  void initState() {
    super.initState();
    _paginationService = PaginationService<T>(
      allItems: widget.items,
      initialPageSize: widget.initialPageSize,
      loadMorePageSize: widget.loadMorePageSize,
      scrollThreshold: widget.scrollThreshold,
    );
    _paginationService.setOnLoadMore(widget.onLoadMore ?? () {});
  }

  @override
  void didUpdateWidget(PaginatedListView<T> oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.items != widget.items) {
      setState(() {
        _paginationService = PaginationService<T>(
          allItems: widget.items,
          initialPageSize: widget.initialPageSize,
          loadMorePageSize: widget.loadMorePageSize,
          scrollThreshold: widget.scrollThreshold,
        );
        _paginationService.setOnLoadMore(widget.onLoadMore ?? () {});
      });
    }
  }

  @override
  void dispose() {
    _paginationService.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (widget.items.isEmpty) {
      return widget.emptyWidget ?? const SizedBox.shrink();
    }

    final visibleItems = _paginationService.visibleItems;
    final showLoadMore = _paginationService.showLoadMore;

    return ListView.builder(
      controller: _paginationService.scrollController,
      padding: widget.padding,
      physics: widget.physics ?? const ClampingScrollPhysics(),
      itemCount: visibleItems.length + (showLoadMore ? 1 : 0),
      itemBuilder: (context, index) {
        if (index < visibleItems.length) {
          return widget.itemBuilder(context, visibleItems[index], index);
        } else {
          // Load more indicator
          return widget.loadingWidget ?? 
                 Padding(
                   padding: const EdgeInsets.symmetric(vertical: 16),
                   child: Center(
                     child: widget.loadingWidget ?? 
                            const CircularProgressIndicator(),
                   ),
                 );
        }
      },
    );
  }
}
