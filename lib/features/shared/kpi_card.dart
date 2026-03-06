import 'package:flutter/material.dart';
import '../../core/theme/app_colors.dart';

class KpiCard extends StatelessWidget {
  final String title;
  final String value;
  final IconData icon;
  final Color? color;
  final String? subtitle;

  const KpiCard({
    super.key,
    required this.title,
    required this.value,
    required this.icon,
    this.color,
    this.subtitle,
  });

  @override
  Widget build(BuildContext context) {
    final c = color ?? AppColors.primary;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: c.withOpacity(0.1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(icon, color: c, size: 24),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(value,
                      style: TextStyle(
                          color: c,
                          fontSize: 22,
                          fontWeight: FontWeight.bold)),
                  const SizedBox(height: 2),
                  Text(title,
                      style: const TextStyle(
                          color: AppColors.textSecondary, fontSize: 12)),
                  if (subtitle != null) ...[                    const SizedBox(height: 2),
                    Text(subtitle!,
                        style: const TextStyle(
                            color: AppColors.textSecondary, fontSize: 11)),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}