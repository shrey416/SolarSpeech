import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../core/theme/app_colors.dart';
import '../../providers/data_providers.dart';
import '../shared/breadcrumb_bar.dart';

class SensorsScreen extends ConsumerStatefulWidget {
  const SensorsScreen({super.key});

  @override
  ConsumerState<SensorsScreen> createState() => _SensorsScreenState();
}

class _SensorsScreenState extends ConsumerState<SensorsScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabCtrl;
  String _search = '';

  @override
  void initState() {
    super.initState();
    _tabCtrl = TabController(length: 3, vsync: this);
    _tabCtrl.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    _tabCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const BreadcrumbBar(items: [
            BreadcrumbItem('Dashboard', route: '/dashboard'),
            BreadcrumbItem('Sensors'),
          ]),
          const SizedBox(height: 4),
          // Header
          Row(
            children: [
              const Text('Sensors',
                  style: TextStyle(
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
                    contentPadding: EdgeInsets.symmetric(vertical: 0),
                  ),
                  onChanged: (v) => setState(() => _search = v),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          // Tabs
          Container(
            decoration: BoxDecoration(
              color: AppColors.surface,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: AppColors.border),
            ),
            child: TabBar(
              controller: _tabCtrl,
              labelColor: AppColors.primary,
              unselectedLabelColor: AppColors.textSecondary,
              indicatorColor: AppColors.primary,
              indicatorSize: TabBarIndicatorSize.label,
              tabs: const [
                Tab(text: 'MFM'),
                Tab(text: 'WMS'),
                Tab(text: 'Radiation Sensor'),
              ],
            ),
          ),
          const SizedBox(height: 16),
          // Tab content
          IndexedStack(
            index: _tabCtrl.index,
            children: [
              _MfmTab(search: _search),
              _WfmTab(search: _search),
              _TempTab(search: _search),
            ],
          ),
        ],
      ),
    );
  }
}

// ── MFM Tab ──
class _MfmTab extends ConsumerWidget {
  final String search;
  const _MfmTab({required this.search});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final mfmsAsync = ref.watch(allMfmsProvider);
    return mfmsAsync.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => Text('Error: $e'),
      data: (mfms) {
        final filtered = search.isEmpty
            ? mfms
            : mfms
                .where((m) => (m['name'] ?? '')
                    .toString()
                    .toLowerCase()
                    .contains(search.toLowerCase()))
                .toList();
        if (filtered.isEmpty) {
          return const Padding(
            padding: EdgeInsets.all(32),
            child: Center(
                child: Text('No MFM devices found',
                    style: TextStyle(color: AppColors.textSecondary))),
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
                DataColumn(label: Text('Device Name')),
                DataColumn(label: Text('Category')),
                DataColumn(label: Text('Value')),
                DataColumn(label: Text('Created On')),
              ],
              rows: filtered.map((m) {
                final latestAsync =
                    ref.watch(latestMfmDataProvider(m['id'] as String));
                final plantId =
                    m['Sensors']?['plantId']?.toString() ?? '';
                return _buildMfmRow(context, m, latestAsync, plantId);
              }).toList(),
            ),
          ),
        );
      },
    );
  }

  DataRow _buildMfmRow(BuildContext context, Map<String, dynamic> mfm,
      AsyncValue<Map<String, dynamic>?> latestAsync, String plantId) {
    final mfmId = mfm['id'] as String;
    return latestAsync.when(
      loading: () => DataRow(
        onSelectChanged: plantId.isNotEmpty
            ? (_) => context.go('/plants/$plantId/mfm/$mfmId')
            : null,
        cells: [
        const DataCell(
            Icon(Icons.circle, color: AppColors.textSecondary, size: 10)),
        DataCell(Text(mfm['name']?.toString() ?? 'MFM')),
        const DataCell(Text('MFM')),
        const DataCell(Text('Loading...')),
        const DataCell(Text('-')),
      ]),
      error: (_, __) => DataRow(
        onSelectChanged: plantId.isNotEmpty
            ? (_) => context.go('/plants/$plantId/mfm/$mfmId')
            : null,
        cells: [
        const DataCell(
            Icon(Icons.circle, color: AppColors.alert, size: 10)),
        DataCell(Text(mfm['name']?.toString() ?? 'MFM')),
        const DataCell(Text('MFM')),
        const DataCell(Text('-')),
        const DataCell(Text('-')),
      ]),
      data: (data) {
        final power = (data?['totalPower'] as num?)?.toDouble() ?? 0;
        final color = power > 50
            ? AppColors.active
            : power > 20
                ? AppColors.warning
                : AppColors.alert;
        final ts = data?['timestamp']?.toString();
        final dt = ts != null ? DateTime.tryParse(ts) : null;
        return DataRow(
          onSelectChanged: plantId.isNotEmpty
              ? (_) => context.go('/plants/$plantId/mfm/$mfmId')
              : null,
          cells: [
          DataCell(Icon(Icons.circle, color: color, size: 10)),
          DataCell(Text(mfm['name']?.toString() ?? 'MFM',
              style: const TextStyle(fontWeight: FontWeight.w600))),
          const DataCell(Text('MFM')),
          DataCell(Text('${power.toStringAsFixed(1)} kW')),
          DataCell(Text(dt != null
              ? '${dt.day}/${dt.month}/${dt.year}'
              : '-')),
        ]);
      },
    );
  }
}

// ── WFM Tab ──
class _WfmTab extends ConsumerWidget {
  final String search;
  const _WfmTab({required this.search});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final wfmsAsync = ref.watch(allWfmsProvider);
    return wfmsAsync.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => Text('Error: $e'),
      data: (wfms) {
        final filtered = search.isEmpty
            ? wfms
            : wfms
                .where((w) => (w['name'] ?? '')
                    .toString()
                    .toLowerCase()
                    .contains(search.toLowerCase()))
                .toList();
        if (filtered.isEmpty) {
          return const Padding(
            padding: EdgeInsets.all(32),
            child: Center(
                child: Text('No WMS devices found',
                    style: TextStyle(color: AppColors.textSecondary))),
          );
        }
        return Card(
          child: SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: DataTable(
              headingRowColor:
                  WidgetStateProperty.all(AppColors.primaryLighter),
              columns: const [
                DataColumn(label: Text('')),
                DataColumn(label: Text('Device Name')),
                DataColumn(label: Text('Category')),
              ],
              rows: filtered
                  .map((w) => DataRow(cells: [
                        const DataCell(Icon(Icons.circle,
                            color: AppColors.active, size: 10)),
                        DataCell(Text(w['name']?.toString() ?? 'WMS',
                            style:
                                const TextStyle(fontWeight: FontWeight.w600))),
                        const DataCell(Text('WMS')),
                      ]))
                  .toList(),
            ),
          ),
        );
      },
    );
  }
}

// ── Temperature / Radiation Sensor Tab ──
class _TempTab extends ConsumerWidget {
  final String search;
  const _TempTab({required this.search});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tempsAsync = ref.watch(allTempDevicesProvider);
    return tempsAsync.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => Text('Error: $e'),
      data: (temps) {
        final filtered = search.isEmpty
            ? temps
            : temps
                .where((t) => (t['name'] ?? '')
                    .toString()
                    .toLowerCase()
                    .contains(search.toLowerCase()))
                .toList();
        if (filtered.isEmpty) {
          return const Padding(
            padding: EdgeInsets.all(32),
            child: Center(
                child: Text('No radiation sensor devices found',
                    style: TextStyle(color: AppColors.textSecondary))),
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
                DataColumn(label: Text('Device Name')),
                DataColumn(label: Text('Category')),
                DataColumn(label: Text('Value')),
                DataColumn(label: Text('Created On')),
              ],
              rows: filtered.map((t) {
                final latestAsync =
                    ref.watch(latestTempDataProvider(t['id'] as String));
                final plantId =
                    t['Sensors']?['plantId']?.toString() ?? '';
                return _buildTempRow(context, t, latestAsync, plantId);
              }).toList(),
            ),
          ),
        );
      },
    );
  }

  DataRow _buildTempRow(BuildContext context, Map<String, dynamic> device,
      AsyncValue<Map<String, dynamic>?> latestAsync, String plantId) {
    final deviceId = device['id'] as String;
    return latestAsync.when(
      loading: () => DataRow(
        onSelectChanged: plantId.isNotEmpty
            ? (_) => context.go('/plants/$plantId/temp/$deviceId')
            : null,
        cells: [
        const DataCell(
            Icon(Icons.circle, color: AppColors.textSecondary, size: 10)),
        DataCell(Text(device['name']?.toString() ?? 'Sensor')),
        const DataCell(Text('Radiation')),
        const DataCell(Text('Loading...')),
        const DataCell(Text('-')),
      ]),
      error: (_, __) => DataRow(
        onSelectChanged: plantId.isNotEmpty
            ? (_) => context.go('/plants/$plantId/temp/$deviceId')
            : null,
        cells: [
        const DataCell(
            Icon(Icons.circle, color: AppColors.alert, size: 10)),
        DataCell(Text(device['name']?.toString() ?? 'Sensor')),
        const DataCell(Text('Radiation')),
        const DataCell(Text('-')),
        const DataCell(Text('-')),
      ]),
      data: (data) {
        final val = (data?['value'] as num?)?.toDouble() ?? 0;
        final color = val > 30
            ? AppColors.active
            : val > 15
                ? AppColors.warning
                : AppColors.alert;
        final ts = data?['timestamp']?.toString();
        final dt = ts != null ? DateTime.tryParse(ts) : null;
        return DataRow(
          onSelectChanged: plantId.isNotEmpty
              ? (_) => context.go('/plants/$plantId/temp/$deviceId')
              : null,
          cells: [
          DataCell(Icon(Icons.circle, color: color, size: 10)),
          DataCell(Text(device['name']?.toString() ?? 'Sensor',
              style: const TextStyle(fontWeight: FontWeight.w600))),
          const DataCell(Text('Radiation')),
          DataCell(Text('${val.toStringAsFixed(1)} °C')),
          DataCell(Text(dt != null
              ? '${dt.day}/${dt.month}/${dt.year}'
              : '-')),
        ]);
      },
    );
  }
}


