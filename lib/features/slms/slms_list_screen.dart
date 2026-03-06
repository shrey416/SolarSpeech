import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
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
              final count = inverters.length;
              final filtered = search.isEmpty
                  ? inverters
                  : inverters
                      .where((inv) => (inv['name'] ?? '')
                          .toString()
                          .toLowerCase()
                          .contains(search.toLowerCase()))
                      .toList();

              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Header
                  Row(
                    children: [
                      Text('SLMS ($count)',
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
                              .state = v,
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
                          DataColumn(label: Text('Total Current')),
                          DataColumn(label: Text('Last Updated')),
                        ],
                        rows: filtered.map((inv) {
                          final id = inv['id'] as String;
                          return DataRow(
                            onSelectChanged: (_) =>
                                context.go('/slms/$id'),
                            cells: [
                              DataCell(_StatusDot(inv)),
                              DataCell(Text(
                                  inv['name']?.toString() ?? 'Inverter',
                                  style: const TextStyle(
                                      fontWeight: FontWeight.w600))),
                              const DataCell(Text('5')),
                              const DataCell(Text('-')),
                              const DataCell(Text('-')),
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

class _StatusDot extends StatelessWidget {
  final Map<String, dynamic> inv;
  const _StatusDot(this.inv);

  @override
  Widget build(BuildContext context) {
    // Use simple heuristic for status color
    return const Icon(Icons.circle, color: AppColors.active, size: 10);
  }
}
