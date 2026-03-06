import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../core/theme/app_colors.dart';

class BreadcrumbBar extends StatelessWidget {
  final List<BreadcrumbItem> items;
  const BreadcrumbBar({super.key, required this.items});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        children: [
          for (int i = 0; i < items.length; i++) ...[
            if (i > 0)
              const Padding(
                padding: EdgeInsets.symmetric(horizontal: 6),
                child: Text('/',
                    style:
                        TextStyle(color: AppColors.textSecondary, fontSize: 13)),
              ),
            if (items[i].route != null)
              InkWell(
                onTap: () => context.go(items[i].route!),
                borderRadius: BorderRadius.circular(4),
                child: Text(
                  items[i].label,
                  style: const TextStyle(
                      color: AppColors.textSecondary, fontSize: 13),
                ),
              )
            else
              Text(
                items[i].label,
                style: const TextStyle(
                    color: AppColors.textPrimary,
                    fontSize: 13,
                    fontWeight: FontWeight.w600),
              ),
          ],
        ],
      ),
    );
  }
}

class BreadcrumbItem {
  final String label;
  final String? route;
  const BreadcrumbItem(this.label, {this.route});
}
