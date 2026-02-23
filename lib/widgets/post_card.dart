import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../models/post_model.dart';
import '../ui_constants.dart';
import '../services/posts_service.dart';
import '../services/firestore_service.dart';
import '../screens/post_detail_screen.dart';

class PostCard extends StatefulWidget {
  final PostModel post;

  const PostCard({
    super.key,
    required this.post,
  });

  @override
  State<PostCard> createState() => _PostCardState();
}

class _PostCardState extends State<PostCard> {
  bool _isExpanded = false;
  bool _isLiked = false;
  bool _isLiking = false;
  final TextEditingController _commentController = TextEditingController();

  bool get _isLongContent => widget.post.content.trim().length > 180;

  @override
  void initState() {
    super.initState();
    _checkLikeStatus();
  }

  @override
  void dispose() {
    _commentController.dispose();
    super.dispose();
  }

  Future<void> _checkLikeStatus() async {
    final currentUser = FirestoreService.auth.currentUser;
    if (currentUser == null) return;

    try {
      final hasLiked = await PostsService.hasUserLikedPost(widget.post.id, currentUser.uid);
      setState(() {
        _isLiked = hasLiked;
      });
    } catch (e) {
      debugPrint('Error checking like status: $e');
    }
  }

  Future<void> _handleLike() async {
    final currentUser = FirestoreService.auth.currentUser;
    if (currentUser == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please log in to like posts')),
      );
      return;
    }

    setState(() => _isLiking = true);

    try {
      // Get user name
      final userDoc = await FirestoreService.instance
          .collection('users')
          .doc(currentUser.uid)
          .get();
      
      final userName = userDoc.data()?['fullName'] as String? ?? 'User';

      await PostsService.likePost(widget.post.id, currentUser.uid, userName);
      
      setState(() {
        _isLiked = !_isLiked;
        _isLiking = false;
      });
    } catch (e) {
      setState(() => _isLiking = false);
      debugPrint('Error liking post: $e');
    }
  }

  void _handleComment() {
    final currentUser = FirestoreService.auth.currentUser;
    if (currentUser == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please log in to comment')),
      );
      return;
    }

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => _CommentSheet(
        postId: widget.post.id,
        commentController: _commentController,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final post = widget.post;
    final textTheme = Theme.of(context).textTheme;
    final currentUserId = FirestoreService.auth.currentUser?.uid;
    final isOwner = currentUserId != null && post.userId == currentUserId;

    final cardContent = InkWell(
      onTap: () {
        Navigator.of(context).push(
          MaterialPageRoute(
            builder: (_) => PostDetailScreen(postId: post.id),
          ),
        );
      },
      child: Card(
      margin: const EdgeInsets.symmetric(horizontal: kPaddingSmall, vertical: kPaddingSmall / 2),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(kPaddingLarge, kPaddingLarge, kPaddingLarge, 0),
            child: _PostHeader(post: post),
          ),
          // Post type tag
          Padding(
            padding: const EdgeInsets.fromLTRB(kPaddingLarge, kPaddingSmall, kPaddingLarge, 0),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: Colors.blue.shade400,
                borderRadius: BorderRadius.circular(18),
              ),
              child: Text(
                'Post',
                style: const TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  color: Colors.white,
                ),
              ),
            ),
          ),
          if (post.title.isNotEmpty)
            Padding(
              padding: const EdgeInsets.fromLTRB(kPaddingLarge, kPaddingMedium, kPaddingLarge, 0),
              child: Text(
                post.title,
                style: kHeadlineSmall,
              ),
            ),
          Padding(
            padding: const EdgeInsets.fromLTRB(kPaddingLarge, kPaddingMedium, kPaddingLarge, 0),
            child: _buildContent(textTheme),
          ),
          if (post.imageUrls.isNotEmpty) ...[
            const SizedBox(height: 8),
            _PostMedia(imageUrls: post.imageUrls),
          ],
          Padding(
            padding: const EdgeInsets.fromLTRB(kPaddingLarge, kPaddingLarge, kPaddingLarge, 0),
            child: _ReactionSummary(post: post),
          ),
          const SizedBox(height: kPaddingSmall),
          const Divider(height: 1, color: Color(0xFFE0E0E0)),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: kPaddingSmall),
            child: Row(
              children: [
                _ActionButton(
                  icon: _isLiked ? Icons.thumb_up : Icons.thumb_up_alt_outlined,
                  label: 'Like',
                  isActive: _isLiked,
                  onTap: _isLiking ? null : _handleLike,
                ),
                _ActionButton(
                  icon: Icons.mode_comment_outlined,
                  label: 'Comment',
                  onTap: _handleComment,
                ),
                _ActionButton(
                  icon: Icons.share_outlined,
                  label: 'Share',
                  onTap: () {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Share feature coming soon')),
                    );
                  },
                ),
              ],
            ),
          ),
          const SizedBox(height: kPaddingSmall),
        ],
      ),
      ),
    );

    if (!isOwner) return cardContent;

    return StreamBuilder<int>(
      stream: PostsService.getUnreadCommentsCountForPostStream(post.id, post.userId),
      builder: (context, snap) {
        final hasUnread = (snap.data ?? 0) > 0;
        return Stack(
          clipBehavior: Clip.none,
          children: [
            cardContent,
            if (hasUnread)
              Positioned(
                right: 12,
                top: 12,
                child: Container(
                  width: 10,
                  height: 10,
                  decoration: const BoxDecoration(
                    color: Colors.red,
                    shape: BoxShape.circle,
                  ),
                ),
              ),
          ],
        );
      },
    );
  }

  Widget _buildContent(TextTheme textTheme) {
    final content = widget.post.content.trim();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          content,
          maxLines: _isExpanded ? null : 3,
          overflow: _isExpanded ? TextOverflow.visible : TextOverflow.ellipsis,
          style: textTheme.bodyMedium?.copyWith(color: Colors.black87),
        ),
        if (_isLongContent)
          TextButton(
            onPressed: () => setState(() => _isExpanded = !_isExpanded),
            style: TextButton.styleFrom(
              padding: EdgeInsets.zero,
              minimumSize: const Size(0, 28),
              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
            ),
            child: Text(_isExpanded ? 'See less' : 'See more'),
          ),
      ],
    );
  }
}

class _PostHeader extends StatelessWidget {
  final PostModel post;

  const _PostHeader({required this.post});

  @override
  Widget build(BuildContext context) {
    final initial = post.userName.isNotEmpty ? post.userName[0].toUpperCase() : 'U';
    final timestamp = _formatDate(post.createdAt);

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        CircleAvatar(
          radius: kAvatarSize / 2,
          backgroundColor: kFacebookBlue,
          child: Text(
            initial,
            style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700),
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                post.userName,
                style: kHeadlineSmall,
              ),
              const SizedBox(height: 2),
              Row(
                children: [
                  Flexible(
                    child: Text(
                      'Barangay Cagbaoto',
                      overflow: TextOverflow.ellipsis,
                      style: kBodyText.copyWith(color: Colors.grey.shade600, fontSize: 12),
                    ),
                  ),
                  const SizedBox(width: 4),
                  const Icon(Icons.circle, size: 3, color: Colors.grey),
                  const SizedBox(width: 4),
                  Text(
                    timestamp,
                    style: kBodyText.copyWith(color: Colors.grey.shade600, fontSize: 12),
                  ),
                ],
              ),
            ],
          ),
        ),
        IconButton(
          icon: const Icon(Icons.more_horiz, color: Colors.black54),
          tooltip: 'More options',
          onPressed: () {},
        ),
      ],
    );
  }
}

class _PostMedia extends StatelessWidget {
  final List<String> imageUrls;

  const _PostMedia({required this.imageUrls});

  @override
  Widget build(BuildContext context) {
    if (imageUrls.length == 1) {
      return AspectRatio(
        aspectRatio: 16 / 9,
        child: Image.network(
          imageUrls.first,
          fit: BoxFit.cover,
          errorBuilder: (context, error, stackTrace) => Container(
            color: Colors.grey.shade300,
            child: const Icon(Icons.image_not_supported),
          ),
        ),
      );
    }

    final displayed = imageUrls.take(6).toList();
    return SizedBox(
      height: 240,
      child: GridView.builder(
        physics: const NeverScrollableScrollPhysics(),
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 3,
          crossAxisSpacing: 2,
          mainAxisSpacing: 2,
        ),
        itemCount: displayed.length,
        itemBuilder: (context, index) {
          final url = displayed[index];
          final isLast = index == displayed.length - 1 && imageUrls.length > displayed.length;
          return Stack(
            fit: StackFit.expand,
            children: [
              Image.network(
                url,
                fit: BoxFit.cover,
                errorBuilder: (context, error, stackTrace) => Container(
                  color: Colors.grey.shade300,
                  child: const Icon(Icons.image_not_supported),
                ),
              ),
              if (isLast)
                Container(
                  color: Colors.black38,
                  alignment: Alignment.center,
                  child: Text(
                    '+${imageUrls.length - displayed.length}',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
            ],
          );
        },
      ),
    );
  }
}

class _ReactionSummary extends StatelessWidget {
  final PostModel post;

  const _ReactionSummary({required this.post});

  @override
  Widget build(BuildContext context) {
    final textStyle = kBodyText.copyWith(color: Colors.grey.shade600, fontSize: 12);

    return Row(
      children: [
        if (post.likesCount > 0)
          Row(
            children: [
              Container(
                height: 18,
                width: 18,
                decoration: const BoxDecoration(
                  color: kFacebookBlue,
                  shape: BoxShape.circle,
                ),
                alignment: Alignment.center,
                child: const Icon(Icons.thumb_up, size: 10, color: Colors.white),
              ),
              const SizedBox(width: 6),
              Text('${post.likesCount}', style: textStyle),
            ],
          ),
        const Spacer(),
        Text('${post.commentsCount} comments', style: textStyle),
        const SizedBox(width: 12),
        Text('${post.commentsCount ~/ 2 + 1} shares', style: textStyle),
      ],
    );
  }
}

class _ActionButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback? onTap;
  final bool isActive;

  const _ActionButton({
    required this.icon,
    required this.label,
    this.onTap,
    this.isActive = false,
  });

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: kPaddingMedium),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                icon,
                size: 18,
                color: isActive ? kFacebookBlue : Colors.grey.shade700,
              ),
              const SizedBox(width: kPaddingSmall),
              Text(
                label,
                style: kBodyText.copyWith(
                  color: isActive ? kFacebookBlue : Colors.grey.shade700,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

String _formatDate(DateTime date) {
  final now = DateTime.now();
  final difference = now.difference(date);

  if (difference.inDays == 0) {
    if (difference.inHours == 0) {
      return '${difference.inMinutes}m ago';
    }
    return '${difference.inHours}h ago';
  } else if (difference.inDays < 7) {
    return '${difference.inDays}d ago';
  } else {
    return '${date.day}/${date.month}/${date.year}';
  }
}

class _CommentSheet extends StatefulWidget {
  final String postId;
  final TextEditingController commentController;

  const _CommentSheet({
    required this.postId,
    required this.commentController,
  });

  @override
  State<_CommentSheet> createState() => _CommentSheetState();
}

class _CommentSheetState extends State<_CommentSheet> {
  bool _isPosting = false;

  Future<void> _postComment() async {
    if (widget.commentController.text.trim().isEmpty) return;

    final currentUser = FirestoreService.auth.currentUser;
    if (currentUser == null) return;

    setState(() => _isPosting = true);

    try {
      // Get user name
      final userDoc = await FirestoreService.instance
          .collection('users')
          .doc(currentUser.uid)
          .get();
      
      final userName = userDoc.data()?['fullName'] as String? ?? 'User';

      await PostsService.addComment(
        widget.postId,
        currentUser.uid,
        userName,
        widget.commentController.text.trim(),
      );

      widget.commentController.clear();
      setState(() => _isPosting = false);
      
      if (mounted) {
        Navigator.of(context).pop();
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Comment posted')),
        );
      }
    } catch (e) {
      setState(() => _isPosting = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: ${e.toString()}')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      height: MediaQuery.of(context).size.height * 0.7,
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.only(
          topLeft: Radius.circular(20),
          topRight: Radius.circular(20),
        ),
      ),
      child: Column(
        children: [
          // Handle bar
          Container(
            margin: const EdgeInsets.only(top: 12),
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: Colors.grey.shade300,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          // Title
          Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                const Text(
                  'Comments',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const Spacer(),
                IconButton(
                  icon: const Icon(Icons.close),
                  onPressed: () => Navigator.of(context).pop(),
                ),
              ],
            ),
          ),
          const Divider(height: 1),
          // Comments list
          Expanded(
            child: StreamBuilder<List<Map<String, dynamic>>>(
              stream: PostsService.getCommentsStream(widget.postId),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }

                if (snapshot.hasError) {
                  return Center(child: Text('Error: ${snapshot.error}'));
                }

                final comments = snapshot.data ?? [];

                if (comments.isEmpty) {
                  return Center(
                    child: Text(
                      'No comments yet',
                      style: TextStyle(color: Colors.grey.shade600),
                    ),
                  );
                }

                return ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: comments.length,
                  itemBuilder: (context, index) {
                    final comment = comments[index];
                    return Padding(
                      padding: const EdgeInsets.only(bottom: 16),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          CircleAvatar(
                            radius: 16,
                            backgroundColor: kFacebookBlue,
                            child: Text(
                              (comment['userName'] as String? ?? 'U')[0].toUpperCase(),
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 12,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  comment['userName'] as String? ?? 'Unknown',
                                  style: const TextStyle(
                                    fontWeight: FontWeight.w600,
                                    fontSize: 14,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  comment['content'] as String? ?? '',
                                  style: const TextStyle(fontSize: 14),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    );
                  },
                );
              },
            ),
          ),
          // Comment input
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white,
              border: Border(
                top: BorderSide(color: Colors.grey.shade200),
              ),
            ),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: widget.commentController,
                    decoration: InputDecoration(
                      hintText: 'Write a comment...',
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(24),
                        borderSide: BorderSide(color: Colors.grey.shade300),
                      ),
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 8,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                IconButton(
                  onPressed: _isPosting ? null : _postComment,
                  icon: _isPosting
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.send, color: kFacebookBlue),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
