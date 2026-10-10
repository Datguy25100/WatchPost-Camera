import 'package:flutter/material.dart';
import '../format.dart';
import '../models.dart';
import '../theme.dart';
import 'asset_thumb.dart';
import 'name_chip.dart';
import 'tag_chips.dart';

class AlertCard extends StatelessWidget {
  const AlertCard({super.key, required this.alert, required this.onTap});

  final AlertModel alert;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppColors.surface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: const BorderSide(color: AppColors.border),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(10),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              AssetThumb(alert.image, width: 68, height: 74),
              const SizedBox(width: 13),
              Expanded(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(minHeight: 74),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        describeAlert(alert),
                        maxLines: 3,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                            fontSize: 13, fontWeight: FontWeight.w500, height: 1.45),
                      ),
                      const SizedBox(height: 8),
                      NameChip(alert.personName, relation: alert.relation),
                      if (alert.tags.isNotEmpty) ...[
                        const SizedBox(height: 6),
                        TagChips(alert.tags, max: 4),
                      ],
                    ],
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(formatTime(alert.time),
                      style: const TextStyle(fontSize: 10, color: AppColors.muted)),
                  const SizedBox(height: 8),
                  if (!alert.seen)
                    Container(
                      width: 8,
                      height: 8,
                      decoration: const BoxDecoration(
                          color: AppColors.blue, shape: BoxShape.circle),
                    ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
