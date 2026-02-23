import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../models/post_model.dart';
import '../services/posts_service.dart';
import '../services/firestore_service.dart';
import '../widgets/post_card.dart';
import '../ui_constants.dart';

/// Shows a single post by ID. Used when user opens the app from a push
/// notification (data payload postId) or from in-app navigation.
class PostDetailScreen extends StatefulWidget {
  final String postId;

  const PostDetailScreen({
    super.key,
    required this.postId,
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
      if (p != null) {
        final uid = FirestoreService.auth.currentUser?.uid;
        if (uid != null && p.userId == uid) {
          PostsService.markPostCommentsAsRead(widget.postId, uid);
        }
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
    return Scaffold(
      backgroundColor: Colors.grey.shade100,
      appBar: AppBar(
        title: const Text('Post'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.of(context).pop(),
        ),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
              ? Center(
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.error_outline, size: 64, color: Colors.grey[400]),
                        const SizedBox(height: 16),
                        Text(
                          _error!,
                          textAlign: TextAlign.center,
                          style: TextStyle(fontSize: 16, color: Colors.grey[600]),
                        ),
                      ],
                    ),
                  ),
                )
              : _post == null
                  ? const SizedBox.shrink()
                  : SingleChildScrollView(
                      child: PostCard(post: _post!),
                    ),
    );
  }
}
