import 'package:flutter/material.dart';
import '../theme.dart';

enum AppButtonStyle { primary, danger, ghost }

class AppButton extends StatelessWidget {
  const AppButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.style = AppButtonStyle.primary,
    this.icon,
  });

  final String label;
  final VoidCallback? onPressed;
  final AppButtonStyle style;
  final IconData? icon;

  @override
  Widget build(BuildContext context) {
    final (bg, fg, side) = switch (style) {
      AppButtonStyle.primary => (AppColors.blue, Colors.white, AppColors.blue),
      AppButtonStyle.danger => (Colors.white, AppColors.danger, AppColors.danger),
      AppButtonStyle.ghost => (Colors.transparent, AppColors.muted, Colors.transparent),
    };

    return SizedBox(
      width: double.infinity,
      height: 50,
      child: TextButton(
        onPressed: onPressed,
        style: TextButton.styleFrom(
          backgroundColor: bg,
          foregroundColor: fg,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
            side: BorderSide(color: side),
          ),
          textStyle: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            if (icon != null) ...[Icon(icon, size: 19), const SizedBox(width: 9)],
            Text(label),
          ],
        ),
      ),
    );
  }
}
