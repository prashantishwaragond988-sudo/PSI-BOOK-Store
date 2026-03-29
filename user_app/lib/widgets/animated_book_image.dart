import "dart:math" as math;

import "package:flutter/material.dart";

import "../utils/image_url.dart";

class AnimatedBookImage extends StatefulWidget {
  const AnimatedBookImage({
    super.key,
    required this.rawImage,
    required this.width,
    required this.height,
    this.radius = 12,
    this.fit = BoxFit.cover,
  });

  final String rawImage;
  final double width;
  final double height;
  final double radius;
  final BoxFit fit;

  @override
  State<AnimatedBookImage> createState() => _AnimatedBookImageState();
}

class _AnimatedBookImageState extends State<AnimatedBookImage> {
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    final url = resolveBookImageUrl(widget.rawImage);
    final asset = resolveBookImageAsset(widget.rawImage);

    final imageChild = url.isEmpty
        ? _assetFallback(asset)
        : Image.network(
            url,
            width: widget.width,
            height: widget.height,
            fit: widget.fit,
            filterQuality: FilterQuality.high,
            gaplessPlayback: true,
            frameBuilder: (context, child, frame, wasSynchronouslyLoaded) {
              if (wasSynchronouslyLoaded) {
                return child;
              }
              return AnimatedOpacity(
                duration: const Duration(milliseconds: 320),
                opacity: frame == null ? 0 : 1,
                child: child,
              );
            },
            loadingBuilder: (context, child, loadingProgress) {
              if (loadingProgress == null) {
                return child;
              }
              final total = loadingProgress.expectedTotalBytes;
              final loaded = loadingProgress.cumulativeBytesLoaded;
              final progress = total == null || total <= 0
                  ? null
                  : loaded / total;
              return Container(
                width: widget.width,
                height: widget.height,
                color: const Color(0xFFE7ECF8),
                alignment: Alignment.center,
                child: SizedBox(
                  width: 28,
                  height: 28,
                  child: CircularProgressIndicator(
                    value: progress,
                    strokeWidth: 2.6,
                  ),
                ),
              );
            },
            errorBuilder: (context, error, stackTrace) => _assetFallback(asset),
          );

    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTapDown: (_) => setState(() => _pressed = true),
      onTapCancel: () => setState(() => _pressed = false),
      onTapUp: (_) => setState(() => _pressed = false),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 170),
        curve: Curves.easeOutCubic,
        width: widget.width,
        height: widget.height,
        transformAlignment: Alignment.center,
        transform: Matrix4.identity()
          ..setEntry(3, 2, 0.0015)
          ..rotateX(_pressed ? 0.03 : 0)
          ..rotateY(_pressed ? -0.04 : 0)
          ..scale(_pressed ? 0.98 : 1.0),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(widget.radius),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(_pressed ? 0.18 : 0.12),
              blurRadius: _pressed ? 8 : 16,
              offset: Offset(0, _pressed ? 3 : 9),
              spreadRadius: -2,
            ),
            BoxShadow(
              color: Colors.blue.withOpacity(_pressed ? 0.05 : 0.08),
              blurRadius: 18,
              offset: const Offset(0, 12),
              spreadRadius: -8,
            ),
          ],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(widget.radius),
          child: Stack(
            fit: StackFit.expand,
            children: [
              imageChild,
              IgnorePointer(
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [
                        Colors.white.withOpacity(0.12),
                        Colors.transparent,
                        Colors.black.withOpacity(0.05),
                      ],
                      stops: const [0, 0.45, 1],
                      transform: GradientRotation(-math.pi / 8),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _assetFallback(String? asset) {
    if (asset != null && asset.isNotEmpty) {
      return Image.asset(
        asset,
        width: widget.width,
        height: widget.height,
        fit: widget.fit,
        filterQuality: FilterQuality.high,
        errorBuilder: (context, error, stackTrace) => _plainFallback(),
      );
    }
    return _plainFallback();
  }

  Widget _plainFallback() {
    return Container(
      width: widget.width,
      height: widget.height,
      color: const Color(0xFFE5E7EB),
      alignment: Alignment.center,
      child: const Icon(Icons.broken_image_outlined, color: Colors.black45),
    );
  }
}
