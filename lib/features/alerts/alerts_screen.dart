import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/theme/app_colors.dart';
import '../../providers/data_providers.dart';
import '../shared/breadcrumb_bar.dart';

class AlertsScreen extends ConsumerStatefulWidget {
  final String? deviceId;
  final String? deviceName;
  const AlertsScreen({super.key, this.deviceId, this.deviceName});

  @override
  ConsumerState<AlertsScreen> createState() => _AlertsScreenState();
}

class _AlertsScreenState extends ConsumerState<AlertsScreen> {
  String _search = '';
  String _plantFilter = '';
  String _severityFilter = '';
  int? _expandedIndex;

  @override
  Widget build(BuildContext context) {
    final alertsAsync = widget.deviceId != null
        ? ref.watch(alertsByDeviceProvider(widget.deviceId!))
        : ref.watch(allAlertsProvider);

    return alertsAsync.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => Center(child: Text('Error: $e')),
      data: (alerts) {
        // Apply filters
        var filtered = alerts.where((a) {
          if (_search.isNotEmpty) {
            final s = _search.toLowerCase();
            final title = (a['title'] ?? '').toString().toLowerCase();
            final device = (a['deviceName'] ?? '').toString().toLowerCase();
            final desc = (a['description'] ?? '').toString().toLowerCase();
            if (!title.contains(s) && !device.contains(s) && !desc.contains(s)) {
              return false;
            }
          }
          if (_plantFilter.isNotEmpty && a['plantId'] != _plantFilter) return false;
          if (_severityFilter.isNotEmpty && a['severity'] != _severityFilter) return false;
          return true;
        }).toList();

        final critical = alerts.where((a) => a['severity'] == 'critical' && a['isActive'] == true).length;
        final warning = alerts.where((a) => a['severity'] == 'warning' && a['isActive'] == true).length;
        final info = alerts.where((a) => a['severity'] == 'info' && a['isActive'] == true).length;
        final resolved = alerts.where((a) => a['isActive'] == false).length;

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
              Text(
                widget.deviceName != null
                    ? 'Alerts — ${widget.deviceName}'
                    : 'Alerts',
                style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: AppColors.primary),
              ),
              const SizedBox(height: 12),
              // KPI cards
              Wrap(
                spacing: 12,
                runSpacing: 12,
                children: [
                  _kpiCard('Critical', critical, const Color(0xFFEF4444),
                      () => setState(() => _severityFilter = _severityFilter == 'critical' ? '' : 'critical')),
                  _kpiCard('Warning', warning, const Color(0xFFF59E0B),
                      () => setState(() => _severityFilter = _severityFilter == 'warning' ? '' : 'warning')),
                  _kpiCard('Info', info, const Color(0xFF3B82F6),
                      () => setState(() => _severityFilter = _severityFilter == 'info' ? '' : 'info')),
                  _kpiCard('Resolved', resolved, AppColors.active,
                      () {}),
                ],
              ),
              const SizedBox(height: 16),
              // Search bar
              SizedBox(
                height: 36,
                child: TextField(
                  style: const TextStyle(fontSize: 13),
                  decoration: const InputDecoration(
                    prefixIcon: Icon(Icons.search, size: 16),
                    hintText: 'Search alerts...',
                    hintStyle: TextStyle(fontSize: 13),
                    contentPadding: EdgeInsets.symmetric(vertical: 0),
                  ),
                  onChanged: (v) => setState(() => _search = v),
                ),
              ),
              const SizedBox(height: 12),
              // Plant filter dropdown
              if (widget.deviceId == null) _buildPlantFilter(alerts),
              const SizedBox(height: 16),
              // Alerts list
              if (filtered.isEmpty)
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(20),
                    child: Column(
                      children: [
                        const Icon(Icons.check_circle_outline,
                            color: AppColors.active, size: 48),
                        const SizedBox(height: 12),
                        const Text('No matching alerts',
                            style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w600,
                                color: AppColors.textSecondary)),
                      ],
                    ),
                  ),
                )
              else
                ...List.generate(filtered.length, (i) => _alertRow(filtered[i], i)),
            ],
          ),
        );
      },
    );
  }

  Widget _kpiCard(String label, int count, Color color, VoidCallback onTap) {
    final isSelected = (label.toLowerCase() == _severityFilter);
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 140,
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: isSelected ? color.withValues(alpha: 0.1) : AppColors.surface,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isSelected ? color : AppColors.border,
            width: isSelected ? 2 : 1,
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(count.toString(),
                style: TextStyle(
                    fontSize: 22, fontWeight: FontWeight.bold, color: color)),
            const SizedBox(height: 4),
            Text(label, style: const TextStyle(fontSize: 12, color: AppColors.textSecondary)),
          ],
        ),
      ),
    );
  }

  Widget _buildPlantFilter(List<Map<String, dynamic>> alerts) {
    final plantNames = <String, String>{};
    for (final a in alerts) {
      final pid = a['plantId']?.toString() ?? '';
      final pname = a['Plant']?['name']?.toString() ?? pid;
      if (pid.isNotEmpty) plantNames[pid] = pname;
    }
    return Wrap(
      spacing: 8,
      children: [
        ChoiceChip(
          label: const Text('All Plants', style: TextStyle(fontSize: 12)),
          selected: _plantFilter.isEmpty,
          onSelected: (_) => setState(() => _plantFilter = ''),
          selectedColor: AppColors.primaryLight,
        ),
        ...plantNames.entries.map((e) => ChoiceChip(
              label: Text(e.value, style: const TextStyle(fontSize: 12)),
              selected: _plantFilter == e.key,
              onSelected: (_) =>
                  setState(() => _plantFilter = _plantFilter == e.key ? '' : e.key),
              selectedColor: AppColors.primaryLight,
            )),
      ],
    );
  }

  Widget _alertRow(Map<String, dynamic> alert, int index) {
    final severity = alert['severity'] ?? 'info';
    final isActive = alert['isActive'] == true;
    final expanded = _expandedIndex == index;
    final Color sevColor;
    final IconData sevIcon;
    switch (severity) {
      case 'critical':
        sevColor = const Color(0xFFEF4444);
        sevIcon = Icons.error;
        break;
      case 'warning':
        sevColor = const Color(0xFFF59E0B);
        sevIcon = Icons.warning_amber_rounded;
        break;
      default:
        sevColor = const Color(0xFF3B82F6);
        sevIcon = Icons.info_outline;
    }

    final triggered = DateTime.tryParse(alert['triggeredAt'] ?? '');
    final timeStr = triggered != null
        ? '${triggered.day}/${triggered.month}/${triggered.year} ${triggered.hour.toString().padLeft(2, '0')}:${triggered.minute.toString().padLeft(2, '0')}'
        : '';

    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(10),
        side: BorderSide(color: isActive ? sevColor.withValues(alpha: 0.3) : AppColors.border),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(10),
        onTap: () => setState(() => _expandedIndex = expanded ? null : index),
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(sevIcon, color: sevColor, size: 20),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(alert['title'] ?? '',
                            style: const TextStyle(
                                fontSize: 13, fontWeight: FontWeight.w600)),
                        const SizedBox(height: 2),
                        Text(
                          '${alert['deviceName'] ?? ''} • ${alert['category'] ?? ''}',
                          style: const TextStyle(
                              fontSize: 11, color: AppColors.textSecondary),
                        ),
                      ],
                    ),
                  ),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                        decoration: BoxDecoration(
                          color: isActive
                              ? sevColor.withValues(alpha: 0.1)
                              : AppColors.active.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Text(
                          isActive ? severity.toUpperCase() : 'RESOLVED',
                          style: TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.w700,
                            color: isActive ? sevColor : AppColors.active,
                          ),
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(timeStr,
                          style: const TextStyle(
                              fontSize: 10, color: AppColors.textSecondary)),
                    ],
                  ),
                  const SizedBox(width: 6),
                  Icon(expanded ? Icons.expand_less : Icons.expand_more,
                      color: AppColors.textSecondary, size: 20),
                ],
              ),
              if (expanded) ...[
                const Divider(height: 20),
                Text(alert['description'] ?? '',
                    style: const TextStyle(fontSize: 12, height: 1.5)),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 16,
                  children: [
                    _detailChip('Device', alert['deviceName'] ?? ''),
                    _detailChip('Type', alert['deviceType'] ?? ''),
                    _detailChip('Plant', alert['Plant']?['name'] ?? ''),
                    if (!isActive && alert['resolvedAt'] != null)
                      _detailChip('Resolved', _fmtDt(alert['resolvedAt'])),
                  ],
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _detailChip(String label, String value) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text('$label: ', style: const TextStyle(fontSize: 11, color: AppColors.textSecondary)),
        Text(value, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600)),
      ],
    );
  }

  String _fmtDt(String? iso) {
    if (iso == null) return '';
    final d = DateTime.tryParse(iso);
    if (d == null) return '';
    return '${d.day}/${d.month}/${d.year} ${d.hour.toString().padLeft(2, '0')}:${d.minute.toString().padLeft(2, '0')}';
  }
}