import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import '../../core/theme/app_colors.dart';

class SingleInverterScreen extends StatelessWidget {
  final String inverterId;
  const SingleInverterScreen({super.key, required this.inverterId});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("GRP_INVERTER_7 Dashboard")),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children:[
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children:[
                // Grid Measurements Card
                Expanded(
                  flex: 2,
                  child: Card(
                    child: Padding(
                      padding: const EdgeInsets.all(20.0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children:[
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children:[
                              const Text("Grid Measurements", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: AppColors.primary)),
                              OutlinedButton.icon(onPressed: (){}, icon: const Icon(Icons.edit, size: 16), label: const Text("Edit"))
                            ],
                          ),
                          const SizedBox(height: 20),
                          Wrap(
                            spacing: 40,
                            runSpacing: 20,
                            children: List.generate(8, (index) => _buildMeasurement("Grid Voltage AB", "50.45")),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 16),
                // Energy Data Card
                Expanded(
                  flex: 1,
                  child: Card(
                    child: Padding(
                      padding: const EdgeInsets.all(20.0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children:[
                          const Text("Energy Data", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: AppColors.primary)),
                          const SizedBox(height: 20),
                          _buildMeasurement("E-Today Active Production", "50.45", icon: Icons.solar_power),
                          const SizedBox(height: 16),
                          _buildMeasurement("Active Power", "50.45", icon: Icons.bolt),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 24),
            // String Current Chart
            Card(
              child: Padding(
                padding: const EdgeInsets.all(20.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children:[
                    const Text("String Current", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: AppColors.primary)),
                    const SizedBox(height: 20),
                    SizedBox(
                      height: 300,
                      child: _buildChart(), // Insert FLChart here (similar to previous line chart)
                    )
                  ],
                ),
              ),
            )
          ],
        ),
      ),
    );
  }

  Widget _buildMeasurement(String label, String value, {IconData? icon}) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children:[
        if (icon != null) ...[Icon(icon, color: AppColors.primaryLight, size: 32), const SizedBox(width: 12)],
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children:[
            Text(label, style: const TextStyle(color: AppColors.textSecondary, fontSize: 12)),
            Text(value, style: const TextStyle(color: AppColors.primary, fontSize: 20, fontWeight: FontWeight.bold)),
          ],
        ),
      ],
    );
  }

  Widget _buildChart() {
    return LineChart(
      LineChartData(
        gridData: FlGridData(show: true, drawVerticalLine: false),
        titlesData: FlTitlesData(
          bottomTitles: AxisTitles(sideTitles: SideTitles(showTitles: true, reservedSize: 22)),
          leftTitles: AxisTitles(sideTitles: SideTitles(showTitles: true, reservedSize: 40)),
          topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
        ),
        borderData: FlBorderData(show: false),
        lineBarsData:[
          LineChartBarData(
            spots: const[ FlSpot(0, 3), FlSpot(2, 8), FlSpot(4, 15), FlSpot(6, 10) ],
            isCurved: true, color: AppColors.primary, barWidth: 2, dotData: const FlDotData(show: false),
          ),
        ],
      ),
    );
  }
}