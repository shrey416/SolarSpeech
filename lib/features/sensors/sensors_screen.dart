import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../core/theme/app_colors.dart';
import '../../providers/data_providers.dart';
import '../shared/breadcrumb_bar.dart';

class SensorsScreen extends ConsumerStatefulWidget {
  final int initialTab;
  final String? initialPlantId;
  const SensorsScreen({super.key, this.initialTab = 0, this.initialPlantId});

  @override
  ConsumerState<SensorsScreen> createState() => _SensorsScreenState();
}

class _SensorsScreenState extends ConsumerState<SensorsScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabCtrl;
  String _search = '';
  String? _selectedPlantId;

  @override
  void initState() {
    super.initState();
    _tabCtrl = TabController(length: 4, vsync: this, initialIndex: widget.initialTab);
    _tabCtrl.addListener(() => setState(() {}));
    _selectedPlantId = widget.initialPlantId;
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
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: AppColors.primary)),
              const SizedBox(width: 12),
              _buildPlantDropdown(),
            ],
          ),
          const SizedBox(height: 8),
          SizedBox(
            height: 36,
            child: TextField(
              style: const TextStyle(fontSize: 13),
              decoration: const InputDecoration(
                prefixIcon: Icon(Icons.search, size: 16),
                hintText: 'Search Devices',
                hintStyle: TextStyle(fontSize: 13),
                contentPadding: EdgeInsets.symmetric(vertical: 0),
              ),
              onChanged: (v) => setState(() => _search = v),
            ),
          ),
          const SizedBox(height: 12),
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
              isScrollable: true,
              tabAlignment: TabAlignment.start,
              tabs: const [
                Tab(text: 'All'),
                Tab(text: 'MFM'),
                Tab(text: 'WMS'),
                Tab(text: 'Temperature'),
              ],
            ),
          ),
          const SizedBox(height: 16),
          // Tab content
          IndexedStack(
            index: _tabCtrl.index,
            children: [
              _AllTab(search: _search, plantId: _selectedPlantId),
              _MfmTab(search: _search, plantId: _selectedPlantId),
              _WfmTab(search: _search, plantId: _selectedPlantId),
              _TempTab(search: _search, plantId: _selectedPlantId),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildPlantDropdown() {
    final plantsAsync = ref.watch(plantsProvider);
    return plantsAsync.when(
      loading: () => const SizedBox(width: 120, height: 36, child: Center(child: SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2)))),
      error: (_, __) => const SizedBox.shrink(),
      data: (plants) {
        return Container(
          height: 36,
          padding: const EdgeInsets.symmetric(horizontal: 10),
          decoration: BoxDecoration(
            border: Border.all(color: AppColors.border),
            borderRadius: BorderRadius.circular(8),
          ),
          child: DropdownButtonHideUnderline(
            child: DropdownButton<String?>(
              value: _selectedPlantId,
              hint: const Text('All Plants', style: TextStyle(fontSize: 12)),
              icon: const Icon(Icons.arrow_drop_down, size: 18),
              style: const TextStyle(fontSize: 12, color: AppColors.textPrimary),
              isDense: true,
              items: [
                const DropdownMenuItem<String?>(
                  value: null,
                  child: Text('All Plants', style: TextStyle(fontSize: 12)),
                ),
                ...plants.map((p) => DropdownMenuItem<String?>(
                  value: p['id'] as String,
                  child: Text(p['name']?.toString() ?? 'Unknown', style: const TextStyle(fontSize: 12)),
                )),
              ],
              onChanged: (v) => setState(() => _selectedPlantId = v),
            ),
          ),
        );
      },
    );
  }
}

// ── All Tab (shows MFM + WMS + Temperature combined) ──
class _AllTab extends ConsumerWidget {
  final String search;
  final String? plantId;
  const _AllTab({required this.search, this.plantId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final mfmsAsync = ref.watch(allMfmsProvider);
    final wfmsAsync = ref.watch(allWfmsProvider);
    final tempsAsync = ref.watch(allTempDevicesProvider);

    final isLoading = mfmsAsync.isLoading || wfmsAsync.isLoading || tempsAsync.isLoading;
    if (isLoading) return const Center(child: CircularProgressIndicator());

    final hasError = mfmsAsync.hasError || wfmsAsync.hasError || tempsAsync.hasError;
    if (hasError) return const Text('Error loading devices');

    final mfms = mfmsAsync.value ?? [];
    final wfms = wfmsAsync.value ?? [];
    final temps = tempsAsync.value ?? [];

    // Build unified rows: [{name, category, type, id, plantId}]
    final allDevices = <Map<String, dynamic>>[];
    for (final m in mfms) {
      allDevices.add({
        'name': m['name']?.toString() ?? 'MFM',
        'category': 'MFM',
        'id': m['id'],
        'plantId': m['Sensors']?['plantId']?.toString() ?? '',
        'type': 'mfm',
        'raw': m,
      });
    }
    for (final w in wfms) {
      allDevices.add({
        'name': w['name']?.toString() ?? 'WMS',
        'category': 'WMS',
        'id': w['id'],
        'plantId': w['Sensors']?['plantId']?.toString() ?? '',
        'type': 'wms',
        'raw': w,
      });
    }
    for (final t in temps) {
      allDevices.add({
        'name': t['name']?.toString() ?? 'Temperature',
        'category': 'Temperature',
        'id': t['id'],
        'plantId': t['Sensors']?['plantId']?.toString() ?? '',
        'type': 'temp',
        'raw': t,
      });
    }

    // Apply plant filter
    final plantFiltered = plantId == null
        ? allDevices
        : allDevices.where((d) => d['plantId'] == plantId).toList();

    final filtered = search.isEmpty
        ? plantFiltered
        : plantFiltered
            .where((d) =>
                d['name'].toString().toLowerCase().contains(search.toLowerCase()) ||
                d['category'].toString().toLowerCase().contains(search.toLowerCase()))
            .toList();

    if (filtered.isEmpty) {
      return const Padding(
        padding: EdgeInsets.all(32),
        child: Center(
            child: Text('No devices found',
                style: TextStyle(color: AppColors.textSecondary))),
      );
    }

    return Card(
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: DataTable(
          showCheckboxColumn: false,
          headingRowColor: WidgetStateProperty.all(AppColors.primaryLighter),
          columns: const [
            DataColumn(label: Text('')),
            DataColumn(label: Text('Device Name')),
            DataColumn(label: Text('Category')),
          ],
          rows: filtered.map((d) {
            final color = d['type'] == 'mfm'
                ? AppColors.alert
                : d['type'] == 'wms'
                    ? AppColors.active
                    : AppColors.warning;
            return DataRow(
              onSelectChanged: (_) {
                final plantId = d['plantId'] as String;
                if (plantId.isEmpty) return;
                if (d['type'] == 'mfm') {
                  context.go('/plants/$plantId/mfm/${d['id']}');
                } else if (d['type'] == 'temp') {
                  context.go('/plants/$plantId/temp/${d['id']}');
                }
              },
              cells: [
                DataCell(Icon(Icons.circle, color: color, size: 10)),
                DataCell(Text(d['name'],
                    style: const TextStyle(fontWeight: FontWeight.w600))),
                DataCell(Text(d['category'])),
              ],
            );
          }).toList(),
        ),
      ),
    );
  }
}

// ── MFM Tab ──
class _MfmTab extends ConsumerWidget {
  final String search;
  final String? plantId;
  const _MfmTab({required this.search, this.plantId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final mfmsAsync = ref.watch(allMfmsProvider);
    return mfmsAsync.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => Text('Error: $e'),
      data: (mfms) {
        final plantFiltered = plantId == null
            ? mfms
            : mfms.where((m) => m['Sensors']?['plantId']?.toString() == plantId).toList();
        final filtered = search.isEmpty
            ? plantFiltered
            : plantFiltered
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
  final String? plantId;
  const _WfmTab({required this.search, this.plantId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final wfmsAsync = ref.watch(allWfmsProvider);
    return wfmsAsync.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => Text('Error: $e'),
      data: (wfms) {
        final plantFiltered = plantId == null
            ? wfms
            : wfms.where((w) => w['Sensors']?['plantId']?.toString() == plantId).toList();
        final filtered = search.isEmpty
            ? plantFiltered
            : plantFiltered
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

// ── Temperature Tab ──
class _TempTab extends ConsumerWidget {
  final String search;
  final String? plantId;
  const _TempTab({required this.search, this.plantId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tempsAsync = ref.watch(allTempDevicesProvider);
    return tempsAsync.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => Text('Error: $e'),
      data: (temps) {
        final plantFiltered = plantId == null
            ? temps
            : temps.where((t) => t['Sensors']?['plantId']?.toString() == plantId).toList();
        final filtered = search.isEmpty
            ? plantFiltered
            : plantFiltered
                .where((t) => (t['name'] ?? '')
                    .toString()
                    .toLowerCase()
                    .contains(search.toLowerCase()))
                .toList();
        if (filtered.isEmpty) {
          return const Padding(
            padding: EdgeInsets.all(32),
            child: Center(
                child: Text('No temperature devices found',
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
        const DataCell(Text('Temperature')),
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
        const DataCell(Text('Temperature')),
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
          const DataCell(Text('Temperature')),
          DataCell(Text('${val.toStringAsFixed(1)} °C')),
          DataCell(Text(dt != null
              ? '${dt.day}/${dt.month}/${dt.year}'
              : '-')),
        ]);
      },
    );
  }
}


