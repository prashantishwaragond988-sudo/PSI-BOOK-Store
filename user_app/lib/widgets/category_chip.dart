import 'package:flutter/material.dart';
import 'glass_container.dart';

class CategoryChip extends StatelessWidget {
  const CategoryChip({
    super.key,
    required this.label,
    required this.icon,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final IconData icon;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final colors = const [
      Color(0xFF6C63FF),
      Color(0xFF00D4FF),
    ];
    final baseColor = isDark ? Colors.white.withOpacity(0.08) : Colors.black12;
    final textColor = selected
        ? Colors.white
        : (isDark ? Colors.white : Colors.black87);
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        transform: Matrix4.identity()..scale(selected ? 1.05 : 1.0),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          gradient: selected ? LinearGradient(colors: colors) : null,
          color: selected ? null : baseColor,
          borderRadius: BorderRadius.circular(18),
          border: selected
              ? null
              : Border.all(
                  color: Colors.white.withOpacity(isDark ? 0.2 : 0.08),
                ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(selected ? 0.20 : 0.08),
              blurRadius: selected ? 18 : 10,
              offset: const Offset(0, 8),
            )
          ],
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: LinearGradient(colors: colors),
              ),
              child: Icon(icon, color: Colors.white, size: 18),
            ),
            const SizedBox(width: 8),
            Text(
              label,
              style: TextStyle(
                color: textColor,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
