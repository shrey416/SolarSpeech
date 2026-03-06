import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../core/theme/app_colors.dart';
import '../assistant/ai_assistant_dialog.dart';

class MainLayout extends StatefulWidget {
  final Widget child;
  final String currentPath;
  const MainLayout({super.key, required this.child, required this.currentPath});

  @override
  State<MainLayout> createState() => _MainLayoutState();
}

class _MainLayoutState extends State<MainLayout> {
  bool _isExpanded = true;

  int get _selectedIndex {
    final p = widget.currentPath;
    if (p == '/my-plants') return 1;
    if (p.startsWith('/plants') || p.startsWith('/inverters')) return 2;
    if (p.startsWith('/slms')) return 3;
    if (p.startsWith('/sensors')) return 4;
    if (p.startsWith('/alerts')) return 5;
    if (p.startsWith('/exports')) return 6;
    return 0; // dashboard
  }

  static const _navItems = <_NavDef>[
    _NavDef(Icons.dashboard_outlined, Icons.dashboard, 'Dashboard', '/dashboard'),
    _NavDef(Icons.park_outlined, Icons.park, 'My Plants', '/my-plants'),
    _NavDef(Icons.electrical_services_outlined, Icons.electrical_services, 'Inverters', '/inverters'),
    _NavDef(Icons.monitor_outlined, Icons.monitor, 'Slms Devices', '/slms'),
    _NavDef(Icons.sensors_outlined, Icons.sensors, 'Sensors', '/sensors'),
    _NavDef(Icons.warning_amber_outlined, Icons.warning_amber, 'Alerts', '/alerts'),
    _NavDef(Icons.file_download_outlined, Icons.file_download, 'Exports', '/exports'),
  ];

  @override
  Widget build(BuildContext context) {
    final width = MediaQuery.of(context).size.width;
    final isDesktop = width >= 768;

    return Scaffold(
      drawer: isDesktop ? null : _buildDrawer(),
      appBar: isDesktop
          ? null
          : AppBar(
              title: const Text('Solar Dashboard'),
              actions: [
                IconButton(
                  icon: const Icon(Icons.mic),
                  onPressed: () => _showAssistant(context),
                ),
              ],
            ),
      body: Row(
        children: [
          if (isDesktop) _buildSidebar(),
          Expanded(child: widget.child),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        backgroundColor: AppColors.primary,
        child: const Icon(Icons.mic, color: Colors.white),
        onPressed: () => _showAssistant(context),
      ),
    );
  }

  Widget _buildSidebar() {
    final sidebarWidth = _isExpanded ? 220.0 : 72.0;
    return AnimatedContainer(
      duration: const Duration(milliseconds: 200),
      width: sidebarWidth,
      decoration: const BoxDecoration(
        color: AppColors.surface,
        border: Border(right: BorderSide(color: AppColors.border, width: 1)),
      ),
      child: Column(
        children: [
          // Logo
          SizedBox(
            height: 64,
            child: Padding(
              padding: EdgeInsets.symmetric(horizontal: _isExpanded ? 16 : 8),
              child: Row(
                children: [
                  const Icon(Icons.solar_power_rounded,
                      color: AppColors.primary, size: 28),
                  if (_isExpanded) ...[
                    const SizedBox(width: 10),
                    const Expanded(
                      child: Text('SolarOS',
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                              color: AppColors.primary)),
                    ),
                  ],
                  IconButton(
                    icon: Icon(
                        _isExpanded ? Icons.chevron_left : Icons.chevron_right,
                        size: 20),
                    onPressed: () =>
                        setState(() => _isExpanded = !_isExpanded),
                    splashRadius: 18,
                  ),
                ],
              ),
            ),
          ),
          const Divider(height: 1),
          const SizedBox(height: 8),
          // Nav items
          for (int i = 0; i < _navItems.length; i++)
            _sidebarTile(i, _navItems[i]),
          const Spacer(),
          const Divider(height: 1),
          _sidebarTile(
              -1, const _NavDef(Icons.settings_outlined, Icons.settings, 'Settings', null)),
          _sidebarTile(
              -1, const _NavDef(Icons.person_outline, Icons.person, 'Account', null)),
          const SizedBox(height: 8),
        ],
      ),
    );
  }

  Widget _sidebarTile(int index, _NavDef nav) {
    final active = index >= 0 && index == _selectedIndex;
    final icon = active ? nav.activeIcon : nav.icon;
    final color = active ? AppColors.primary : AppColors.textSecondary;

    return Tooltip(
      message: _isExpanded ? '' : nav.label,
      child: Container(
        margin: EdgeInsets.symmetric(
            horizontal: _isExpanded ? 10 : 8, vertical: 2),
        decoration: BoxDecoration(
          color: active ? AppColors.primaryLighter : Colors.transparent,
          borderRadius: BorderRadius.circular(12),
        ),
        child: InkWell(
          borderRadius: BorderRadius.circular(12),
          onTap: nav.route != null ? () => context.go(nav.route!) : null,
          child: Padding(
            padding: EdgeInsets.symmetric(
                vertical: 10, horizontal: _isExpanded ? 12 : 0),
            child: _isExpanded
                ? Row(children: [
                    Icon(icon, color: color, size: 22),
                    const SizedBox(width: 12),
                    Expanded(
                        child: Text(nav.label,
                            style: TextStyle(
                                color: color,
                                fontWeight: active
                                    ? FontWeight.w600
                                    : FontWeight.normal,
                                fontSize: 14))),
                  ])
                : Center(child: Icon(icon, color: color, size: 22)),
          ),
        ),
      ),
    );
  }

  Widget _buildDrawer() {
    return Drawer(
      child: ListView(
        padding: EdgeInsets.zero,
        children: [
          const DrawerHeader(
            decoration: BoxDecoration(color: AppColors.primary),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                Icon(Icons.solar_power_rounded, color: Colors.white, size: 40),
                SizedBox(height: 12),
                Text('SolarOS',
                    style: TextStyle(
                        color: Colors.white,
                        fontSize: 22,
                        fontWeight: FontWeight.bold)),
              ],
            ),
          ),
          for (int i = 0; i < _navItems.length; i++)
            ListTile(
              leading: Icon(
                  i == _selectedIndex
                      ? _navItems[i].activeIcon
                      : _navItems[i].icon,
                  color: i == _selectedIndex
                      ? AppColors.primary
                      : AppColors.textSecondary),
              title: Text(_navItems[i].label,
                  style: TextStyle(
                      color: i == _selectedIndex
                          ? AppColors.primary
                          : AppColors.textPrimary,
                      fontWeight: i == _selectedIndex
                          ? FontWeight.w600
                          : FontWeight.normal)),
              selected: i == _selectedIndex,
              selectedTileColor: AppColors.primaryLighter,
              onTap: () {
                Navigator.pop(context);
                if (_navItems[i].route != null) {
                  context.go(_navItems[i].route!);
                }
              },
            ),
        ],
      ),
    );
  }

  void _showAssistant(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => const AiAssistantDialog(),
    );
  }
}

class _NavDef {
  final IconData icon;
  final IconData activeIcon;
  final String label;
  final String? route;
  const _NavDef(this.icon, this.activeIcon, this.label, this.route);
}