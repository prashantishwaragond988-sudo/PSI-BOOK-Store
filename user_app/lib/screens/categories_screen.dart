import 'package:flutter/material.dart';
import '../widgets/category_chip.dart';

class CategoriesScreen extends StatelessWidget {
  const CategoriesScreen({super.key});

  @override
  Widget build(BuildContext context) {
    const cats = [
      {"label": "All", "icon": Icons.auto_awesome},
      {"label": "Fiction", "icon": Icons.menu_book_rounded},
      {"label": "Self Help", "icon": Icons.self_improvement},
      {"label": "Education", "icon": Icons.school},
      {"label": "Business", "icon": Icons.business_center},
      {"label": "Comics", "icon": Icons.theater_comedy},
    ];
    return Container(
      color: const Color(0xFF0F172A),
      child: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Wrap(
            spacing: 12,
            runSpacing: 12,
            children: cats
                .map((c) => CategoryChip(
                      label: c["label"] as String,
                      icon: c["icon"] as IconData,
                      selected: false,
                      onTap: () {},
                    ))
                .toList(),
          ),
        ),
      ),
    );
  }
}
