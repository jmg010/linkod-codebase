import 'package:flutter/material.dart';
import '../models/post_model.dart';
import '../services/posts_service.dart';
import '../services/firestore_service.dart';
import '../services/current_post_tracker.dart';
import '../widgets/post_card.dart';

/// Shows a single post by ID. Used when user opens the app from a push
/// notification (data payload postId) or from in-app navigation.
class PostDetailScreen extends StatefulWidget {
  final String postId;
  final bool openCommentsOnLoad;
  final String? initialCommentId;

  const PostDetailScreen({
    super.key,
    required this.postId,
    this.openCommentsOnLoad = false,
    this.initialCommentId,
  });

  @override
  State<PostDetailScreen> createState() => _PostDetailScreenState();
}

class _PostDetailScreenState extends State<PostDetailScreen> {
  PostModel? _post;
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
    CurrentPostTracker.currentPostId.value = widget.postId;
  }

  @override
  void dispose() {
    if (CurrentPostTracker.currentPostId.value == widget.postId) {
      CurrentPostTracker.currentPostId.value = null;
    }
    super.dispose();
  }

  Future<void> _load() async {
    try {
      final p = await PostsService.getPostById(widget.postId);
      if (!mounted) return;
      setState(() {
        _post = p;
        _loading = false;
        _error = p == null ? 'Post not found' : null;
      });
      // Mark comments as read when post owner opens the post so the red indicator clears.
      final uid = FirestoreService.auth.currentUser?.uid;
      if (uid != null && p != null && p.userId == uid) {
        PostsService.markPostCommentsAsRead(widget.postId, uid);
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _loading = false;
          _error = e.toString();
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: isDark ? const Color(0xFF121212) : Colors.grey.shade100,
      appBar: AppBar(
        title: Text(
          'Post',
          style: TextStyle(color: isDark ? Colors.white : Colors.black87),
        ),
        backgroundColor: isDark ? const Color(0xFF1E1E1E) : Colors.white,
        iconTheme: IconThemeData(color: isDark ? Colors.white : Colors.black87),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.of(context).pop(),
        ),
      ),
      body:
          _loading
              ? const Center(child: CircularProgressIndicator())
              : _error != null
              ? Center(
                child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.error_outline,
                        size: 64,
                        color: isDark ? Colors.grey[600] : Colors.grey[400],
                      ),
                      const SizedBox(height: 16),
                      Text(
                        _error!,
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 16,
                          color: isDark ? Colors.grey[400] : Colors.grey[600],
                        ),
                      ),
                    ],
                  ),
                ),
              )
              : _post == null
              ? const SizedBox.shrink()
              : SingleChildScrollView(
                child: PostCard(
                  post: _post!,
                  openCommentsOnLoad: widget.openCommentsOnLoad,
                  initialCommentId: widget.initialCommentId,
                ),
              ),
    );
  }
}
