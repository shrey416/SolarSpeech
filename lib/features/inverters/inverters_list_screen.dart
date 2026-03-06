import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../core/theme/app_colors.dart';
import '../../providers/data_providers.dart';
import '../shared/breadcrumb_bar.dart';

class InvertersListScreen extends ConsumerWidget {
  const InvertersListScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final invertersAsync = ref.watch(allInvertersProvider);
    final search = ref.watch(deviceSearchProvider);

    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const BreadcrumbBar(items: [
            BreadcrumbItem('Dashboard', route: '/dashboard'),
            BreadcrumbItem('Inverters'),
          ]),
          const SizedBox(height: 4),
          Row(
            children: [
              const Text('Inverters',
                  style: TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                      color: AppColors.primary)),
              const Spacer(),
              SizedBox(
                width: 220,
                height: 38,
                child: TextField(
                  decoration: const InputDecoration(
                    prefixIcon: Icon(Icons.search, size: 18),
                    hintText: 'Search Inverters...',
                    contentPadding: EdgeInsets.symmetric(vertical: 0),
                  ),
                  onChanged: (v) =>
                      ref.read(deviceSearchProvider.notifier).set(v),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          invertersAsync.when(
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (e, _) => Text('Error: $e'),
            data: (inverters) {
              final filtered = search.isEmpty
                  ? inverters
                  : inverters
                      .where((inv) => (inv['name'] ?? '')
                          .toString()
                          .toLowerCase()
                          .contains(search.toLowerCase()))
                      .toList();
              if (filtered.isEmpty) {
                return const Padding(
                  padding: EdgeInsets.all(32),
                  child: Center(
                      child: Text('No inverters found',
                          style:
                              TextStyle(color: AppColors.textSecondary))),
                );
              }
              return Card(
                child: SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: DataTable(
                    showCheckboxColumn: false,
                    headingRowColor:
                        WidgetStateProperty.all(AppColors.primaryLighter),
                    columns: const [
                      DataColumn(label: Text('')),
                      DataColumn(label: Text('Inverter Name')),
                      DataColumn(label: Text('Plant')),
                      DataColumn(label: Text('E-Today')),
                      DataColumn(label: Text('E-Total')),
                      DataColumn(label: Text('Active Power')),
                    ],
                    rows: filtered.map((inv) {
                      final id = inv['id'] as String;
                      final plantId = inv['plantId']?.toString() ?? '';
                      final plantName =
                          inv['Plant']?['name']?.toString() ?? 'Unknown';
                      final latestAsync =
                          ref.watch(latestInverterDataProvider(id));
                      return _buildRow(
                          context, inv, latestAsync, plantId, plantName);
                    }).toList(),
                  ),
                ),
              );
            },
          ),
        ],
      ),
    );
  }

  DataRow _buildRow(
      BuildContext context,
      Map<String, dynamic> inv,
      AsyncValue<Map<String, dynamic>?> latestAsync,
      String plantId,
      String plantName) {
    final id = inv['id'] as String;
    final name = inv['name']?.toString() ?? 'Inverter';
    return latestAsync.when(
      loading: () => DataRow(
        onSelectChanged: plantId.isNotEmpty
            ? (_) => context.go('/plants/$plantId/inverters/$id')
            : null,
        cells: [
          const DataCell(
              Icon(Icons.circle, color: AppColors.textSecondary, size: 10)),
          DataCell(Text(name)),
          DataCell(Text(plantName)),
          const DataCell(Text('Loading...')),
          const DataCell(Text('Loading...')),
          const DataCell(Text('Loading...')),
        ],
      ),
      error: (_, __) => DataRow(
        onSelectChanged: plantId.isNotEmpty
            ? (_) => context.go('/plants/$plantId/inverters/$id')
            : null,
        cells: [
          const DataCell(
              Icon(Icons.circle, color: AppColors.alert, size: 10)),
          DataCell(Text(name,
              style: const TextStyle(fontWeight: FontWeight.w600))),
          DataCell(Text(plantName)),
          const DataCell(Text('-')),
          const DataCell(Text('-')),
          const DataCell(Text('-')),
        ],
      ),
      data: (data) {
        final eTodayPower =
            (data?['eTodayPower'] as num?)?.toDouble();
        final eTotalPower =
            (data?['eTotalPower'] as num?)?.toDouble();
        final activePower =
            (data?['activePower'] as num?)?.toDouble();

        // Fallback
        double computed = 0;
        if (data != null) {
          for (int ch = 1; ch <= 8; ch++) {
            final v = (data['dcVoltage$ch'] as num?)?.toDouble() ?? 0;
            final c = (data['dcCurrent$ch'] as num?)?.toDouble() ?? 0;
            computed += v * c;
          }
        }

        final eTodayStr = eTodayPower != null
            ? '${eTodayPower.toStringAsFixed(2)} kW'
            : '${(computed / 1000).toStringAsFixed(2)} kW';
        final eTotalStr = eTotalPower != null
            ? '${eTotalPower.toStringAsFixed(2)} kW'
            : '${(computed / 1000).toStringAsFixed(2)} kW';
        final activeStr = activePower != null
            ? '${activePower.toStringAsFixed(2)} W'
            : '${computed.toStringAsFixed(2)} W';

        final isActive = (activePower ?? computed) > 0;

        return DataRow(
          onSelectChanged: plantId.isNotEmpty
              ? (_) => context.go('/plants/$plantId/inverters/$id')
              : null,
          cells: [
            DataCell(Icon(Icons.circle,
                color: isActive ? AppColors.active : AppColors.warning,
                size: 10)),
            DataCell(Text(name,
                style: const TextStyle(fontWeight: FontWeight.w600))),
            DataCell(Text(plantName)),
            DataCell(Text(eTodayStr)),
            DataCell(Text(eTotalStr)),
            DataCell(Text(activeStr)),
          ],
        );
      },
    );
  }
}
