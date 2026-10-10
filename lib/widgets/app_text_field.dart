import 'package:flutter/material.dart';
import '../theme.dart';

class AppTextField extends StatelessWidget {
  const AppTextField({
    super.key,
    required this.label,
    required this.hint,
    required this.icon,
    required this.controller,
    this.error,
    this.obscure = false,
    this.keyboardType,
    this.textInputAction,
    this.trailing,
    this.onChanged,
    this.onSubmitted,
  });

  final String label;
  final String hint;
  final IconData icon;
  final TextEditingController controller;
  final String? error;
  final bool obscure;
  final TextInputType? keyboardType;
  final TextInputAction? textInputAction;
  final Widget? trailing;
  final ValueChanged<String>? onChanged;
  final ValueChanged<String>? onSubmitted;

  @override
  Widget build(BuildContext context) {
    final hasError = error != null;
    final borderColor = hasError ? AppColors.danger : AppColors.border;

    OutlineInputBorder border(Color c) => OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: c),
        );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label,
            style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500)),
        const SizedBox(height: 8),
        TextField(
          controller: controller,
          obscureText: obscure,
          keyboardType: keyboardType,
          textInputAction: textInputAction,
          onChanged: onChanged,
          onSubmitted: onSubmitted,
          style: const TextStyle(fontSize: 14),
          decoration: InputDecoration(
            hintText: hint,
            hintStyle: const TextStyle(color: Color(0xFF9AA7B8), fontSize: 14),
            prefixIcon: Icon(icon, size: 19, color: const Color(0xFF71839A)),
            suffixIcon: trailing,
            contentPadding: const EdgeInsets.symmetric(vertical: 16),
            enabledBorder: border(borderColor),
            focusedBorder: border(hasError ? AppColors.danger : AppColors.blue),
          ),
        ),
        if (hasError)
          Padding(
            padding: const EdgeInsets.only(top: 6),
            child: Text(error!,
                style: const TextStyle(
                    color: AppColors.danger, fontSize: 11, fontWeight: FontWeight.w500)),
          ),
      ],
    );
  }
}
