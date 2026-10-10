import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import '../theme.dart';

/// Shows a bundled asset or, for http(s) URLs (camera snapshots), a network image.
class SmartImage extends StatelessWidget {
  const SmartImage(
    this.src, {
    super.key,
    this.width,
    this.height,
    this.fit = BoxFit.cover,
  });

  final String src;
  final double? width;
  final double? height;
  final BoxFit fit;

  @override
  Widget build(BuildContext context) {
    if (src.startsWith('data:image')) {
      final Uint8List bytes;
      try {
        bytes = base64Decode(src.substring(src.indexOf(',') + 1));
      } catch (_) {
        return _broken();
      }
      return Image.memory(bytes,
          width: width,
          height: height,
          fit: fit,
          gaplessPlayback: true,
          errorBuilder: (_, __, ___) => _broken());
    }
    if (src.startsWith('http')) {
      return Image.network(
        src,
        width: width,
        height: height,
        fit: fit,
        errorBuilder: (_, __, ___) => _broken(),
      );
    }
    return Image.asset(src,
        width: width,
        height: height,
        fit: fit,
        errorBuilder: (_, __, ___) => _broken());
  }

  Widget _broken() => Container(
        width: width,
        height: height,
        color: AppColors.tint,
        child: const Icon(Icons.broken_image_outlined, color: AppColors.muted),
      );
}
