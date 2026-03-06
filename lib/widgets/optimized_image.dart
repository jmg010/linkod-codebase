import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';

/// Network image with disk cache (download once, reuse from app cache), optional
/// decode dimensions for memory, and tap-to-fullscreen.
class OptimizedNetworkImage extends StatelessWidget {
  const OptimizedNetworkImage({
    super.key,
    required this.imageUrl,
    this.width,
    this.height,
    this.fit = BoxFit.cover,
    this.cacheWidth,
    this.cacheHeight,
    this.borderRadius,
    this.placeholder,
    this.errorWidget,
    this.onTap,
  });

  final String imageUrl;
  final double? width;
  final double? height;
  final BoxFit fit;
  /// Decode at this width (pixels) to reduce memory. Omit for full resolution.
  final int? cacheWidth;
  /// Decode at this height (pixels). Omit for full resolution.
  final int? cacheHeight;
  final BorderRadius? borderRadius;
  final Widget? placeholder;
  final Widget? errorWidget;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    Widget child = CachedNetworkImage(
      imageUrl: imageUrl,
      width: width,
      height: height,
      fit: fit,
      memCacheWidth: cacheWidth,
      memCacheHeight: cacheHeight,
      placeholder: (_, __) => SizedBox(
        width: width,
        height: height,
        child: placeholder ??
            Container(
              color: Colors.grey.shade200,
              alignment: Alignment.center,
              child: const SizedBox(
                width: 24,
                height: 24,
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
            ),
      ),
      errorWidget: (_, __, ___) => SizedBox(
        width: width,
        height: height,
        child: errorWidget ??
            Container(
              color: Colors.grey.shade300,
              alignment: Alignment.center,
              child: Icon(Icons.image_not_supported_outlined,
                  size: 40, color: Colors.grey.shade600),
            ),
      ),
    );
    if (borderRadius != null) {
      child = ClipRRect(borderRadius: borderRadius!, child: child);
    }
    if (onTap != null) {
      child = GestureDetector(
        onTap: onTap,
        child: child,
      );
    }
    return child;
  }
}

/// Opens a full-screen view of one or more image URLs (swipe for multiple).
void openFullScreenImage(BuildContext context, String imageUrl) {
  openFullScreenImages(context, [imageUrl], initialIndex: 0);
}

void openFullScreenImages(
  BuildContext context,
  List<String> imageUrls, {
  int initialIndex = 0,
}) {
  if (imageUrls.isEmpty) return;
  Navigator.of(context).push(
    MaterialPageRoute<void>(
      fullscreenDialog: true,
      builder: (context) => FullScreenImageScreen(
        imageUrls: imageUrls,
        initialIndex: initialIndex.clamp(0, imageUrls.length - 1),
      ),
    ),
  );
}

/// Full-screen image viewer (Facebook-style on mobile): tap or swipe down to close.
/// Decodes at ~2x screen size to save memory.
class FullScreenImageScreen extends StatefulWidget {
  const FullScreenImageScreen({
    super.key,
    required this.imageUrls,
    this.initialIndex = 0,
  });

  final List<String> imageUrls;
  final int initialIndex;

  @override
  State<FullScreenImageScreen> createState() => _FullScreenImageScreenState();
}

class _FullScreenImageScreenState extends State<FullScreenImageScreen> {
  late PageController _pageController;
  late int _currentIndex;
  bool _showControls = true;

  @override
  void initState() {
    super.initState();
    _pageController = PageController(initialPage: widget.initialIndex);
    _currentIndex = widget.initialIndex;
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  void _close() => Navigator.of(context).pop();

  @override
  Widget build(BuildContext context) {
    final imageUrls = widget.imageUrls;
    final size = MediaQuery.sizeOf(context);
    final pixelRatio = MediaQuery.of(context).devicePixelRatio.clamp(1.0, 3.0);
    final cacheW = (size.width * pixelRatio).toInt().clamp(1, 1200);
    final cacheH = (size.height * pixelRatio).toInt().clamp(1, 1600);

    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        children: [
          PageView.builder(
            controller: _pageController,
            itemCount: imageUrls.length,
            onPageChanged: (index) => setState(() => _currentIndex = index),
            itemBuilder: (context, index) {
              return GestureDetector(
                onTap: () => setState(() => _showControls = !_showControls),
                onVerticalDragEnd: (details) {
                  if (details.primaryVelocity != null && details.primaryVelocity! > 200) {
                    _close();
                  }
                },
                child: InteractiveViewer(
                  minScale: 0.5,
                  maxScale: 4,
                  child: Center(
                    child: Image.network(
                      imageUrls[index],
                      fit: BoxFit.contain,
                      cacheWidth: cacheW,
                      cacheHeight: cacheH,
                      loadingBuilder: (context, child, loadingProgress) {
                        if (loadingProgress == null) return child;
                        return const Center(
                          child: SizedBox(
                            width: 32,
                            height: 32,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Colors.white54,
                            ),
                          ),
                        );
                      },
                      errorBuilder: (_, __, ___) => const Center(
                        child: Icon(
                          Icons.image_not_supported,
                          color: Colors.white54,
                          size: 48,
                        ),
                      ),
                    ),
                  ),
                ),
              );
            },
          ),
          if (_showControls) ...[
            SafeArea(
              child: Align(
                alignment: Alignment.topLeft,
                child: IconButton(
                  icon: const Icon(Icons.close, color: Colors.white, size: 28),
                  onPressed: _close,
                ),
              ),
            ),
            if (imageUrls.length > 1)
              SafeArea(
                child: Align(
                  alignment: Alignment.bottomCenter,
                  child: Padding(
                    padding: const EdgeInsets.only(bottom: 16),
                    child: Text(
                      '${_currentIndex + 1} / ${imageUrls.length}',
                      style: const TextStyle(
                        color: Colors.white70,
                        fontSize: 14,
                      ),
                    ),
                  ),
                ),
              ),
          ],
        ],
      ),
    );
  }
}
