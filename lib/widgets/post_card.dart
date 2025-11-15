import 'package:flutter/material.dart';
import '../models/post_model.dart';
import '../ui_constants.dart';

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

  bool get _isLongContent => widget.post.content.trim().length > 180;

  @override
  Widget build(BuildContext context) {
    final post = widget.post;
    final textTheme = Theme.of(context).textTheme;

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: kPaddingSmall, vertical: kPaddingSmall / 2),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(kPaddingLarge, kPaddingLarge, kPaddingLarge, 0),
            child: _PostHeader(post: post),
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
                  icon: Icons.thumb_up_alt_outlined,
                  label: 'Like',
                  onTap: () {},
                ),
                _ActionButton(
                  icon: Icons.mode_comment_outlined,
                  label: 'Comment',
                  onTap: () {},
                ),
                _ActionButton(
                  icon: Icons.share_outlined,
                  label: 'Share',
                  onTap: () {},
                ),
              ],
            ),
          ),
          const SizedBox(height: kPaddingSmall),
        ],
      ),
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
  final VoidCallback onTap;

  const _ActionButton({
    required this.icon,
    required this.label,
    required this.onTap,
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
              Icon(icon, size: 18, color: Colors.grey.shade700),
              const SizedBox(width: kPaddingSmall),
              Text(
                label,
                style: kBodyText.copyWith(
                  color: Colors.grey.shade700,
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
