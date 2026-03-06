import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import '../../core/theme/app_colors.dart';
import '../../providers/data_providers.dart';
import '../shared/breadcrumb_bar.dart';
import '../shared/kpi_card.dart';
import '../shared/line_chart_widget.dart';

class PlantsScreen extends ConsumerStatefulWidget {
  final String plantId;
  const PlantsScreen({super.key, required this.plantId});

  @override
  ConsumerState<PlantsScreen> createState() => _PlantsScreenState();
}

class _PlantsScreenState extends ConsumerState<PlantsScreen> {
  String _deviceFilter = 'All';
  String _deviceSearch = '';

  @override
  Widget build(BuildContext context) {
    final plantAsync = ref.watch(plantByIdProvider(widget.plantId));
    final invertersAsync = ref.watch(invertersByPlantProvider(widget.plantId));
    final sensorsAsync = ref.watch(sensorsByPlantProvider(widget.plantId));
    final width = MediaQuery.of(context).size.width;
    final isMobile = width < 768;

    return plantAsync.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => Center(child: Text('Error: $e')),
      data: (plant) {
        if (plant == null) {
          return const Center(child: Text('Plant not found'));
        }
        final name = plant['name'] ?? 'Unknown';
        final todayE =
            (plant['todayEnergy'] as num?)?.toStringAsFixed(1) ?? '-';
        final totalE =
            (plant['totalEnergy'] as num?)?.toStringAsFixed(1) ?? '-';
        final cap =
            (plant['capacityKWp'] as num?)?.toStringAsFixed(2) ?? '-';
        final co2 =
            (plant['co2Reduced'] as num?)?.toStringAsFixed(2) ?? '-';

        return SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // ── Breadcrumb ──
              BreadcrumbBar(items: [
                const BreadcrumbItem('Dashboard', route: '/dashboard'),
                const BreadcrumbItem('Plants', route: '/dashboard'),
                BreadcrumbItem(name),
              ]),

              // ── Status + Name ──
              Row(
                children: [
                  const Icon(Icons.circle, color: AppColors.active, size: 10),
                  const SizedBox(width: 6),
                  const Text('Active',
                      style: TextStyle(
                          color: AppColors.active,
                          fontSize: 13,
                          fontWeight: FontWeight.w500)),
                  const Spacer(),
                  FilledButton.icon(
                    icon: const Icon(Icons.warning_amber_rounded, size: 16),
                    label: const Text('Alerts'),
                    onPressed: () => context.go('/alerts'),
                    style: FilledButton.styleFrom(
                        backgroundColor: AppColors.primary),
                  ),
                ],
              ),
              const SizedBox(height: 4),
              Text(name,
                  style: const TextStyle(
                      fontSize: 24, fontWeight: FontWeight.bold)),
              const SizedBox(height: 20),

              // ── KPI Cards ──
              Wrap(
                spacing: 12,
                runSpacing: 12,
                children: [
                  SizedBox(
                    width: isMobile ? double.infinity : 200,
                    child: KpiCard(
                        title: 'Today Energy',
                        value: '$todayE kWh',
                        icon: Icons.bolt),
                  ),
                  SizedBox(
                    width: isMobile ? double.infinity : 200,
                    child: KpiCard(
                        title: 'Total Energy',
                        value: '$totalE kWh',
                        icon: Icons.electric_meter_outlined),
                  ),
                  SizedBox(
                    width: isMobile ? double.infinity : 200,
                    child: KpiCard(
                        title: 'Capacity',
                        value: '$cap kWp',
                        icon: Icons.battery_full_outlined),
                  ),
                  SizedBox(
                    width: isMobile ? double.infinity : 200,
                    child: KpiCard(
                        title: 'CO\u2082 Reduced',
                        value: '$co2 T',
                        icon: Icons.eco_outlined,
                        color: AppColors.active),
                  ),
                ],
              ),

              const SizedBox(height: 24),

              // ── Revenue & Energy Generation side by side ──
              isMobile
                  ? Column(children: [
                      _ChartCard(title: 'Revenue', plantId: widget.plantId),
                      const SizedBox(height: 16),
                      _ChartCard(
                          title: 'Energy Generation',
                          plantId: widget.plantId),
                    ])
                  : Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                            child: _ChartCard(
                                title: 'Revenue',
                                plantId: widget.plantId)),
                        const SizedBox(width: 16),
                        Expanded(
                            child: _ChartCard(
                                title: 'Energy Generation',
                                plantId: widget.plantId)),
                      ],
                    ),

              const SizedBox(height: 24),

              // ── Inverter Production Chart ──
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('Inverter Production',
                          style: TextStyle(
                              fontSize: 16, fontWeight: FontWeight.bold)),
                      const SizedBox(height: 16),
                      SizedBox(
                        height: 220,
                        child: LineChartWidget(),
                      ),
                    ],
                  ),
                ),
              ),

              const SizedBox(height: 24),

              // ── Devices Section ──
              const Text('Devices',
                  style:
                      TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
              const SizedBox(height: 12),
              // Filter tabs
              Wrap(
                spacing: 8,
                runSpacing: 8,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  for (final tab in [
                    'All',
                    'Inverter',
                    'MFM',
                    'WMS',
                    'Radiation Sensor'
                  ])
                    ChoiceChip(
                      label: Text(tab),
                      selected: _deviceFilter == tab,
                      onSelected: (v) {
                        if (v) setState(() => _deviceFilter = tab);
                      },
                      selectedColor: AppColors.primaryLight,
                      labelStyle: TextStyle(
                          color: _deviceFilter == tab
                              ? AppColors.primary
                              : AppColors.textSecondary,
                          fontWeight: _deviceFilter == tab
                              ? FontWeight.w600
                              : FontWeight.normal),
                    ),
                  const SizedBox(width: 8),
                  SizedBox(
                    width: 200,
                    height: 38,
                    child: TextField(
                      decoration: const InputDecoration(
                        prefixIcon: Icon(Icons.search, size: 18),
                        hintText: 'Search Devices',
                        contentPadding: EdgeInsets.symmetric(vertical: 0),
                      ),
                      onChanged: (v) =>
                          setState(() => _deviceSearch = v),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),

              // Device grid - inverters
              invertersAsync.when(
                loading: () =>
                    const Center(child: CircularProgressIndicator()),
                error: (e, _) => Text('Error: $e'),
                data: (inverters) {
                  var filtered = inverters;
                  if (_deviceFilter != 'All' &&
                      _deviceFilter != 'Inverter') {
                    filtered = [];
                  }
                  if (_deviceSearch.isNotEmpty) {
                    filtered = filtered
                        .where((inv) => (inv['name'] ?? '')
                            .toString()
                            .toLowerCase()
                            .contains(_deviceSearch.toLowerCase()))
                        .toList();
                  }
                  if (filtered.isEmpty) {
                    return const Padding(
                      padding: EdgeInsets.all(24),
                      child: Center(
                          child: Text('No devices found',
                              style: TextStyle(
                                  color: AppColors.textSecondary))),
                    );
                  }
                  return Wrap(
                    spacing: 12,
                    runSpacing: 12,
                    children: filtered
                        .map((inv) => _DeviceCard(
                              name: inv['name'] ?? 'Inverter',
                              type: 'Inverter',
                              onTap: () => context.go(
                                  '/plants/${widget.plantId}/inverters/${inv['id']}'),
                            ))
                        .toList(),
                  );
                },
              ),

              // Show MFM / WFM / Temp sensor cards if available
              sensorsAsync.when(
                loading: () => const SizedBox.shrink(),
                error: (_, __) => const SizedBox.shrink(),
                data: (sensors) {
                  if (sensors == null) return const SizedBox.shrink();
                  final sid = sensors['id'] as String;
                  return _SensorDevicesList(
                    sensorsId: sid,
                    filter: _deviceFilter,
                    search: _deviceSearch,
                  );
                },
              ),

              const SizedBox(height: 32),

              // ── Plant Details Section ──
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          const Text('Plant Details',
                              style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold)),
                          const Spacer(),
                          OutlinedButton.icon(
                            icon: const Icon(Icons.edit, size: 14),
                            label: const Text('Edit'),
                            onPressed: () {},
                          ),
                        ],
                      ),
                      const Divider(height: 24),
                      _DetailRow('Plant Name', name),
                      _DetailRow('Plant Type', plant['plantType'] ?? '-'),
                      _DetailRow(
                          'Installation Date',
                          plant['installationDate'] != null
                              ? DateFormat('d/M/yy').format(
                                  DateTime.tryParse(
                                          plant['installationDate']
                                              .toString()) ??
                                      DateTime.now())
                              : '-'),
                      _DetailRow('Location',
                          '${plant['address'] ?? ''}, ${plant['city'] ?? ''}, ${plant['state'] ?? ''}, ${plant['country'] ?? ''}'),
                    ],
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _ChartCard extends StatelessWidget {
  final String title;
  final String plantId;
  const _ChartCard({required this.title, required this.plantId});

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Text(title,
                    style: const TextStyle(
                        fontSize: 14, fontWeight: FontWeight.bold)),
                const Spacer(),
                const Text('Monthly',
                    style: TextStyle(
                        fontSize: 12,
                        color: AppColors.primary,
                        fontWeight: FontWeight.w600)),
              ],
            ),
            const SizedBox(height: 16),
            SizedBox(height: 160, child: LineChartWidget()),
          ],
        ),
      ),
    );
  }
}

class _DeviceCard extends StatelessWidget {
  final String name;
  final String type;
  final VoidCallback? onTap;
  const _DeviceCard({required this.name, required this.type, this.onTap});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 220,
      child: Card(
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(
                      type == 'Inverter'
                          ? Icons.electrical_services
                          : type == 'MFM'
                              ? Icons.speed
                              : Icons.thermostat,
                      color: AppColors.primary,
                      size: 20,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                        child: Text(name,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                                fontWeight: FontWeight.w600,
                                fontSize: 13))),
                    const Icon(Icons.circle,
                        color: AppColors.active, size: 8),
                  ],
                ),
                const SizedBox(height: 8),
                Text(type,
                    style: const TextStyle(
                        color: AppColors.textSecondary, fontSize: 11)),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _SensorDevicesList extends ConsumerWidget {
  final String sensorsId;
  final String filter;
  final String search;
  const _SensorDevicesList(
      {required this.sensorsId, required this.filter, required this.search});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final mfms = ref.watch(mfmsBySensorsProvider(sensorsId));
    final wfms = ref.watch(wfmsBySensorsProvider(sensorsId));
    final temps = ref.watch(tempDevicesBySensorsProvider(sensorsId));

    final widgets = <Widget>[];

    if (filter == 'All' || filter == 'MFM') {
      mfms.whenData((list) {
        for (final m in list) {
          final n = m['name']?.toString() ?? 'MFM';
          if (search.isEmpty ||
              n.toLowerCase().contains(search.toLowerCase())) {
            widgets.add(_DeviceCard(name: n, type: 'MFM'));
          }
        }
      });
    }
    if (filter == 'All' || filter == 'WMS') {
      wfms.whenData((list) {
        for (final w in list) {
          final n = w['name']?.toString() ?? 'WFM';
          if (search.isEmpty ||
              n.toLowerCase().contains(search.toLowerCase())) {
            widgets.add(_DeviceCard(name: n, type: 'WMS'));
          }
        }
      });
    }
    if (filter == 'All' || filter == 'Radiation Sensor') {
      temps.whenData((list) {
        for (final t in list) {
          final n = t['name']?.toString() ?? 'Radiation Sensor';
          if (search.isEmpty ||
              n.toLowerCase().contains(search.toLowerCase())) {
            widgets.add(_DeviceCard(name: n, type: 'Radiation Sensor'));
          }
        }
      });
    }

    if (widgets.isEmpty) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.only(top: 12),
      child: Wrap(spacing: 12, runSpacing: 12, children: widgets),
    );
  }
}

class _DetailRow extends StatelessWidget {
  final String label;
  final String value;
  const _DetailRow(this.label, this.value);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 140,
            child: Text(label,
                style: const TextStyle(
                    color: AppColors.textSecondary, fontSize: 13)),
          ),
          Expanded(
              child: Text(value,
                  style: const TextStyle(
                      color: AppColors.primary,
                      fontWeight: FontWeight.w500,
                      fontSize: 13))),
        ],
      ),
    );
  }
}