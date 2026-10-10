import 'package:flutter/material.dart';
import '../theme.dart';

class PageHeader extends StatelessWidget {
  const PageHeader({super.key, required this.title, this.subtitle, this.actions = const []});

  final String title;
  final String? subtitle;
  final List<Widget> actions;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 52,
      child: Row(
        children: [
          Expanded(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title,
                    style: const TextStyle(
                        fontSize: 27, fontWeight: FontWeight.w700, letterSpacing: -0.7)),
                if (subtitle != null)
                  Text(subtitle!,
                      style: const TextStyle(fontSize: 12, color: AppColors.muted)),
              ],
            ),
          ),
          ...actions,
        ],
      ),
    );
  }
}

/// Small round icon button used in headers (add, sign out).
class RoundIconButton extends StatelessWidget {
  const RoundIconButton({
    super.key,
    required this.icon,
    required this.tooltip,
    required this.onPressed,
    this.filled = false,
  });

  final IconData icon;
  final String tooltip;
  final VoidCallback onPressed;
  final bool filled;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(left: 10),
      child: Tooltip(
        message: tooltip,
        child: InkResponse(
          onTap: onPressed,
          child: Container(
            width: 38,
            height: 38,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: filled ? AppColors.blue : Colors.white,
              border: filled ? null : Border.all(color: AppColors.border),
            ),
            child: Icon(icon,
                size: filled ? 22 : 19,
                color: filled ? Colors.white : AppColors.muted),
          ),
        ),
      ),
    );
  }
}
