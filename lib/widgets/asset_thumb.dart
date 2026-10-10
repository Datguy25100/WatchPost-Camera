import 'package:flutter/material.dart';
import 'smart_image.dart';

/// Rounded asset image used by alert cards, camera rows and the image picker.
class AssetThumb extends StatelessWidget {
  const AssetThumb(
    this.asset, {
    super.key,
    required this.width,
    required this.height,
    this.radius = 8,
    this.grayscale = false,
  });

  final String asset;
  final double width;
  final double height;
  final double radius;
  final bool grayscale;

  static const _gray = ColorFilter.matrix(<double>[
    0.2126, 0.7152, 0.0722, 0, 0,
    0.2126, 0.7152, 0.0722, 0, 0,
    0.2126, 0.7152, 0.0722, 0, 0,
    0, 0, 0, 0.6, 0,
  ]);

  @override
  Widget build(BuildContext context) {
    Widget image = SmartImage(asset, width: width, height: height);
    if (grayscale) image = ColorFiltered(colorFilter: _gray, child: image);
    return ClipRRect(borderRadius: BorderRadius.circular(radius), child: image);
  }
}
