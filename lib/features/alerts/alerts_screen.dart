import 'package:flutter/material.dart';
import '../../core/theme/app_colors.dart';
import '../shared/breadcrumb_bar.dart';

class AlertsScreen extends StatelessWidget {
  const AlertsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const BreadcrumbBar(items: [
            BreadcrumbItem('Dashboard', route: '/dashboard'),
            BreadcrumbItem('Alerts'),
          ]),
          const SizedBox(height: 4),
          // Header
          const Text('Alerts',
              style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: AppColors.primary)),
          const SizedBox(height: 8),
          SizedBox(
            height: 36,
            child: TextField(
              style: const TextStyle(fontSize: 13),
              decoration: const InputDecoration(
                prefixIcon: Icon(Icons.search, size: 16),
                hintText: 'Alarm Name',
                hintStyle: TextStyle(fontSize: 13),
                contentPadding: EdgeInsets.symmetric(vertical: 0),
              ),
              onChanged: (_) {},
            ),
          ),
          const SizedBox(height: 16),
          // Filters
          Wrap(
            spacing: 12,
            runSpacing: 8,
            children: [
              _FilterChip(label: 'All Plants'),
              _FilterChip(label: 'All Devices'),
            ],
          ),
          const SizedBox(height: 16),
          // Table – alerts will come from Supabase when table is available
          Card(
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                children: [
                  const Icon(Icons.check_circle_outline,
                      color: AppColors.active, size: 48),
                  const SizedBox(height: 12),
                  const Text('No active alerts',
                      style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                          color: AppColors.textSecondary)),
                  const SizedBox(height: 4),
                  const Text(
                      'Alerts will appear here when issues are detected.',
                      style: TextStyle(
                          color: AppColors.textSecondary, fontSize: 13)),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _FilterChip extends StatelessWidget {
  final String label;
  const _FilterChip({required this.label});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
      decoration: BoxDecoration(
        border: Border.all(color: AppColors.border),
        borderRadius: BorderRadius.circular(8),
        color: AppColors.surface,
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(label, style: const TextStyle(fontSize: 13)),
          const SizedBox(width: 6),
          const Icon(Icons.keyboard_arrow_down,
              color: AppColors.textSecondary, size: 16),
        ],
      ),
    );
  }
}