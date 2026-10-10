import 'package:flutter/material.dart';
import '../theme.dart';

/// Small grey pills for the AI tags on an alert ("person", "shopping bags").
class TagChips extends StatelessWidget {
  const TagChips(this.tags, {super.key, this.max = 6});
  final List<String> tags;
  final int max;

  @override
  Widget build(BuildContext context) {
    if (tags.isEmpty) return const SizedBox.shrink();
    return Wrap(
      spacing: 6,
      runSpacing: 6,
      children: [
        for (final t in tags.take(max))
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
            decoration: BoxDecoration(
              color: AppColors.tint,
              borderRadius: BorderRadius.circular(999),
            ),
            child: Text('#$t',
                style: const TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w600,
                    color: AppColors.blue)),
          ),
      ],
    );
  }
}
