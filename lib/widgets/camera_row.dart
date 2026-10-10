import 'package:flutter/material.dart';
import '../format.dart';
import '../models.dart';
import '../theme.dart';
import 'asset_thumb.dart';

class CameraRow extends StatelessWidget {
  const CameraRow({
    super.key,
    required this.camera,
    required this.onToggle,
    required this.onRemove,
    required this.onTap,
  });

  final CameraModel camera;
  final VoidCallback onToggle;
  final VoidCallback onRemove;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final hasAddress = camera.source.trim().isNotEmpty;
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.border),
      ),
      child: Row(
        children: [
          AssetThumb(camera.image,
              width: 66, height: 68, grayscale: !camera.enabled),
          const SizedBox(width: 13),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(camera.name,
                    style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600)),
                const SizedBox(height: 6),
                Row(
                  children: [
                    const Icon(Icons.place_outlined, size: 14, color: AppColors.muted),
                    const SizedBox(width: 5),
                    Flexible(
                      child: Text(camera.location,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(fontSize: 11, color: AppColors.muted)),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Row(
                  children: [
                    Icon(hasAddress ? Icons.lan_outlined : Icons.warning_amber_rounded,
                        size: 14,
                        color: hasAddress ? AppColors.muted : AppColors.amber),
                    const SizedBox(width: 5),
                    Flexible(
                      child: Text(
                          hasAddress ? maskAddress(camera.source) : 'No address yet - tap to set',
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                              fontSize: 11,
                              color: hasAddress ? AppColors.muted : AppColors.amber)),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                GestureDetector(
                  onTap: onRemove,
                  child: const Text('Remove',
                      style: TextStyle(fontSize: 11, color: AppColors.danger)),
                ),
              ],
            ),
          ),
          Switch(
            value: camera.enabled,
            onChanged: (_) => onToggle(),
            activeColor: Colors.white,
            activeTrackColor: AppColors.blue,
          ),
        ],
      ),
      ),
    );
  }
}
