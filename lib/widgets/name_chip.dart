import 'package:flutter/material.dart';
import '../theme.dart';

class NameChip extends StatelessWidget {
  const NameChip(this.name, {super.key, this.relation});
  final String name;

  /// Shown after the name for saved people, e.g. "Ada · wife".
  final String? relation;

  @override
  Widget build(BuildContext context) {
    final unknown = name == 'Unknown';
    final rel = relation?.trim() ?? '';
    return Container(
      height: 24,
      padding: const EdgeInsets.symmetric(horizontal: 9),
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: unknown ? AppColors.amberBg : AppColors.greenBg,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        !unknown && rel.isNotEmpty ? '$name · $rel' : name,
        style: TextStyle(
          fontSize: 10,
          fontWeight: FontWeight.w700,
          color: unknown ? AppColors.amber : AppColors.green,
        ),
      ),
    );
  }
}
