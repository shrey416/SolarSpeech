import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import '../../core/theme/app_colors.dart';
import '../../providers/data_providers.dart';
import '../shared/breadcrumb_bar.dart';

class SlmsListScreen extends ConsumerWidget {
  const SlmsListScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final invertersAsync = ref.watch(allInvertersProvider);
    final search = ref.watch(slmsSearchProvider);

    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const BreadcrumbBar(items: [
            BreadcrumbItem('Dashboard', route: '/dashboard'),
            BreadcrumbItem('SLMS'),
          ]),
          const SizedBox(height: 4),
          invertersAsync.when(
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (e, _) => Text('Error: $e'),
            data: (inverters) {
              // Group inverters by base name (strip -Strings/-Power)
              final groups = <String, List<Map<String, dynamic>>>{};
              for (final inv in inverters) {
                final name = inv['name']?.toString() ?? 'Inverter';
                final baseName = name.replaceAll(
                    RegExp(r'[-_](Strings|Power|String)$',
                        caseSensitive: false),
                    '');
                groups.putIfAbsent(baseName, () => []).add(inv);
              }
              final groupCount = groups.length;

              var groupEntries = groups.entries.toList();
              if (search.isNotEmpty) {
                groupEntries = groupEntries
                    .where((e) => e.key
                        .toLowerCase()
                        .contains(search.toLowerCase()))
                    .toList();
              }

              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Header
                  Row(
                    children: [
                      Text('SLMS ($groupCount)',
                          style: const TextStyle(
                              fontSize: 24,
                              fontWeight: FontWeight.bold,
                              color: AppColors.primary)),
                      const Spacer(),
                      OutlinedButton.icon(
                        icon: const Icon(Icons.filter_alt_outlined, size: 16),
                        label: const Text('Filter'),
                        onPressed: () {},
                      ),
                      const SizedBox(width: 12),
                      SizedBox(
                        width: 220,
                        height: 38,
                        child: TextField(
                          decoration: const InputDecoration(
                            prefixIcon: Icon(Icons.search, size: 18),
                            hintText: 'Search Devices',
                            contentPadding:
                                EdgeInsets.symmetric(vertical: 0),
                          ),
                          onChanged: (v) => ref
                              .read(slmsSearchProvider.notifier)
                              .set(v),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  // Table
                  Card(
                    child: SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      child: DataTable(
                        headingRowColor: WidgetStateProperty.all(
                            AppColors.primaryLighter),
                        showCheckboxColumn: false,
                        columns: const [
                          DataColumn(label: Text('')),
                          DataColumn(label: Text('Device Name')),
                          DataColumn(label: Text('Number of CT')),
                          DataColumn(label: Text('Today Production')),
                          DataColumn(label: Text('Last Updated')),
                        ],
                        rows: groupEntries.map((entry) {
                          final firstInv = entry.value.first;
                          final id = firstInv['id'] as String;
                          return DataRow(
                            onSelectChanged: (_) =>
                                context.go('/slms/$id'),
                            cells: [
                              const DataCell(Icon(Icons.circle,
                                  color: AppColors.active, size: 10)),
                              DataCell(Text(entry.key,
                                  style: const TextStyle(
                                      fontWeight: FontWeight.w600))),
                              const DataCell(Text('8')),
                              DataCell(
                                  _TodayProductionCell(inverterId: id)),
                              DataCell(
                                  _LastUpdatedCell(inverterId: id)),
                            ],
                          );
                        }).toList(),
                      ),
                    ),
                  ),
                ],
              );
            },
          ),
        ],
      ),
    );
  }
}

// ── Shows today's production from latest inverter data ──
class _TodayProductionCell extends ConsumerWidget {
  final String inverterId;
  const _TodayProductionCell({required this.inverterId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final latestAsync = ref.watch(latestInverterDataProvider(inverterId));
    return latestAsync.when(
      loading: () =>
          const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2)),
      error: (_, __) => const Text('--'),
      data: (data) {
        if (data == null) return const Text('--');
        double totalPower = 0;
        for (final ch in [1, 2, 3, 4, 5, 6, 7, 8]) {
          final v = (data['dcVoltage$ch'] as num?)?.toDouble() ?? 0;
          final c = (data['dcCurrent$ch'] as num?)?.toDouble() ?? 0;
          totalPower += v * c;
        }
        return Text('${(totalPower / 1000).toStringAsFixed(2)} kW',
            style: const TextStyle(
                color: AppColors.primary, fontWeight: FontWeight.w600));
      },
    );
  }
}

// ── Shows last updated timestamp ──
class _LastUpdatedCell extends ConsumerWidget {
  final String inverterId;
  const _LastUpdatedCell({required this.inverterId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final latestAsync = ref.watch(latestInverterDataProvider(inverterId));
    return latestAsync.when(
      loading: () =>
          const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2)),
      error: (_, __) => const Text('--'),
      data: (data) {
        if (data == null) return const Text('--');
        final ts = data['timestamp']?.toString();
        final dt = ts != null ? DateTime.tryParse(ts) : null;
        if (dt == null) return const Text('--');
        return Text(DateFormat('MMM d, HH:mm').format(dt),
            style: const TextStyle(color: AppColors.textSecondary));
      },
    );
  }
}
