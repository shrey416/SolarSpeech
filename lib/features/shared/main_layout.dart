import 'package:flutter/material.dart';
import 'package:responsive_framework/responsive_framework.dart';
import '../../core/theme/app_colors.dart';
import '../assistant/ai_assistant_dialog.dart';
class MainLayout extends StatelessWidget {
  final Widget child;
  const MainLayout({Key? key, required this.child}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final isDesktop = ResponsiveBreakpoints.of(context).isDesktop;

    return Scaffold(
      appBar: isDesktop ? null : AppBar(
        title: const Text('Solar Dashboard'),
        backgroundColor: AppColors.surface,
        foregroundColor: AppColors.textPrimary,
        elevation: 1,
      ),
      drawer: isDesktop ? null : const AppSidebar(),
      body: Row(
        children:[
          if (isDesktop) const AppSidebar(),
          Expanded(child: child),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        backgroundColor: AppColors.primary,
        icon: const Icon(Icons.mic, color: Colors.white),
        label: const Text("Quick Help", style: TextStyle(color: Colors.white)),
        onPressed: () {
          showDialog(
            context: context,
            builder: (context) => const AiAssistantDialog(),
          );
        },
      ),
    );
  }
}

class AppSidebar extends StatelessWidget {
  const AppSidebar({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 260,
      color: AppColors.surface,
      child: Column(
        children:[
          const Padding(
            padding: EdgeInsets.all(24.0),
            child: Row(
              children:[
                Icon(Icons.solar_power, color: AppColors.primary, size: 32),
                SizedBox(width: 12),
                Text("SolarOS", style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
              ],
            ),
          ),
          _buildNavItem(Icons.dashboard, 'Dashboard', isActive: true),
          _buildNavItem(Icons.factory, 'Plants'),
          _buildNavItem(Icons.electric_meter, 'Inverters'),
          _buildNavItem(Icons.sensors, 'Sensors'),
          _buildNavItem(Icons.warning_amber, 'Alerts'),
        ],
      ),
    );
  }

  Widget _buildNavItem(IconData icon, String label, {bool isActive = false}) {
    return ListTile(
      leading: Icon(icon, color: isActive ? AppColors.primary : AppColors.textSecondary),
      title: Text(
        label,
        style: TextStyle(
          color: isActive ? AppColors.primary : AppColors.textSecondary,
          fontWeight: isActive ? FontWeight.bold : FontWeight.normal,
        ),
      ),
      selected: isActive,
      selectedTileColor: AppColors.primaryLight,
      onTap: () {
        // Navigation logic
      },
    );
  }
}