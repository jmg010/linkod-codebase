import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

/// Shows a preview of a picked image (XFile) in a fixed-size container.
/// Optional [onTap] to open full-size (bytes loaded in memory).
class XFilePreviewImage extends StatelessWidget {
  const XFilePreviewImage({
    super.key,
    required this.xFile,
    this.width = 120,
    this.height = 120,
    this.borderRadius,
    this.onRemove,
  });

  final XFile xFile;
  final double width;
  final double height;
  final BorderRadius? borderRadius;
  final VoidCallback? onRemove;

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<Uint8List>(
      future: xFile.readAsBytes(),
      builder: (context, snapshot) {
        if (snapshot.hasError || !snapshot.hasData) {
          return _container(
            context,
            child: Icon(
              Icons.broken_image_outlined,
              size: 32,
              color: Colors.grey.shade600,
            ),
          );
        }
        final bytes = snapshot.data!;
        Widget child = Image.memory(
          bytes,
          width: width,
          height: height,
          fit: BoxFit.cover,
        );
        if (borderRadius != null) {
          child = ClipRRect(borderRadius: borderRadius!, child: child);
        }
        child = GestureDetector(
          onTap: () => _showFullScreen(context, bytes),
          child: child,
        );
        return Stack(
          clipBehavior: Clip.none,
          children: [
            _container(context, child: child),
            if (onRemove != null)
              Positioned(
                top: -6,
                right: -6,
                child: Material(
                  color: Colors.red,
                  shape: const CircleBorder(),
                  child: InkWell(
                    onTap: onRemove,
                    customBorder: const CircleBorder(),
                    child: const Padding(
                      padding: EdgeInsets.all(6),
                      child: Icon(Icons.close, color: Colors.white, size: 18),
                    ),
                  ),
                ),
              ),
          ],
        );
      },
    );
  }

  Widget _container(BuildContext context, {required Widget child}) {
    return Container(
      width: width,
      height: height,
      decoration: BoxDecoration(
        color: Colors.grey.shade200,
        borderRadius: borderRadius ?? BorderRadius.circular(8),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: child,
    );
  }

  void _showFullScreen(BuildContext context, Uint8List bytes) {
    showDialog<void>(
      context: context,
      barrierColor: Colors.black,
      barrierDismissible: true,
      builder:
          (context) => GestureDetector(
            onTap: () => Navigator.of(context).pop(),
            behavior: HitTestBehavior.opaque,
            child: Dialog(
              backgroundColor: Colors.transparent,
              insetPadding: EdgeInsets.zero,
              child: Stack(
                fit: StackFit.expand,
                children: [
                  GestureDetector(
                    onTap: () => Navigator.of(context).pop(),
                    child: InteractiveViewer(
                      minScale: 0.5,
                      maxScale: 4,
                      child: Center(
                        child: Image.memory(bytes, fit: BoxFit.contain),
                      ),
                    ),
                  ),
                  SafeArea(
                    child: Align(
                      alignment: Alignment.topLeft,
                      child: IconButton(
                        icon: const Icon(
                          Icons.close,
                          color: Colors.white,
                          size: 28,
                        ),
                        onPressed: () => Navigator.of(context).pop(),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
    );
  }
}
