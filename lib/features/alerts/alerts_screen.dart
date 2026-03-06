import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../providers/data_providers.dart';
import '../../core/theme/app_colors.dart';
import '../shared/adaptive_data_table.dart';

class AlertsScreen extends ConsumerWidget {
  const AlertsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final alertsAsync = ref.watch(alertsProvider);

    return Scaffold(
      body: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children:[
            const Text("Alerts (25)", style: TextStyle(fontSize: 24, color: AppColors.primary, fontWeight: FontWeight.bold)),
            const SizedBox(height: 16),
            
            // Filters Row
            Row(
              children:[
                _buildDropdown("All Plants"),
                const SizedBox(width: 12),
                _buildDropdown("All Devices"),
                const Spacer(),
                SizedBox(
                  width: 250,
                  child: TextField(
                    decoration: InputDecoration(
                      prefixIcon: const Icon(Icons.search),
                      hintText: "Alarm Name",
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                      contentPadding: const EdgeInsets.symmetric(vertical: 0),
                    ),
                  ),
                )
              ],
            ),
            const SizedBox(height: 24),

            // Data Table
            Expanded(
              child: alertsAsync.when(
                loading: () => const Center(child: CircularProgressIndicator()),
                error: (err, stack) => Center(child: Text('Error: $err')),
                data: (alerts) {
                  return AdaptiveDataTable(
                    columns: const ["", "Alert Name", "Plant Name", "Device Name", "Occurrence Time"],
                    rows: alerts.map((alert) => [
                      Icon(Icons.circle, color: alert['status'] == 'ACTIVE' ? AppColors.alert : AppColors.warning, size: 12),
                      Text(alert['name'] ?? 'Grid Issue', style: const TextStyle(fontWeight: FontWeight.bold)),
                      Text(alert['plants']?['name'] ?? 'Inverter 2'),
                      Text(alert['devices']?['name'] ?? 'Inverter 2'),
                      Text(alert['created_at']?.toString().substring(0, 10) ?? 'Jan 10, 8:00 AM'),
                    ]).toList(),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDropdown(String hint) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        border: Border.all(color: AppColors.border),
        borderRadius: BorderRadius.circular(8),
        color: AppColors.surface,
      ),
      child: Row(
        children:[
          Text(hint, style: const TextStyle(color: AppColors.textPrimary)),
          const SizedBox(width: 8),
          const Icon(Icons.keyboard_arrow_down, color: AppColors.textSecondary, size: 18),
        ],
      ),
    );
  }
}