import 'package:flutter/material.dart';
import 'package:responsive_framework/responsive_framework.dart';
import '../../core/theme/app_colors.dart';
import '../shared/kpi_card.dart';
import '../shared/line_chart_widget.dart';

class DashboardScreen extends StatelessWidget {
  const DashboardScreen({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children:[
          const Text(
            "Namaste, Dhruti!\nSolar Performance Overview",
            style: TextStyle(fontSize: 24, color: AppColors.primary, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 24),
          
          // Responsive KPI Grid
          ResponsiveRowColumn(
            layout: ResponsiveBreakpoints.of(context).isMobile 
                ? ResponsiveRowColumnType.COLUMN 
                : ResponsiveRowColumnType.ROW,
            rowSpacing: 16,
            columnSpacing: 16,
            children:[
              ResponsiveRowColumnItem(
                rowFlex: 1,
                child: KpiCard(title: "Today Energy", value: "62 Kwh", icon: Icons.bolt),
              ),
              ResponsiveRowColumnItem(
                rowFlex: 1,
                child: KpiCard(title: "Total Capacity", value: "50.45 Kwh", icon: Icons.battery_charging_full),
              ),
              ResponsiveRowColumnItem(
                rowFlex: 1,
                child: KpiCard(title: "Co2 Reduced", value: "1.4 T", icon: Icons.eco, isGreen: true),
              ),
            ],
          ),
          
          const SizedBox(height: 24),
          
          // Charts Section
          Container(
            height: 300,
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: AppColors.surface,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: AppColors.border),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children:[
                const Text("Inverter Production", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                const SizedBox(height: 16),
                Expanded(child: LineChartWidget()), // FL Chart
              ],
            ),
          ),
        ],
      ),
    );
  }
}