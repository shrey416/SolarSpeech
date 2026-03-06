import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import '../../core/theme/app_colors.dart';

class LineChartWidget extends StatelessWidget {
  final List<List<FlSpot>>? seriesData;
  final List<Color>? seriesColors;
  final List<String>? bottomLabels;
  final String? yLabel;

  const LineChartWidget({
    super.key,
    this.seriesData,
    this.seriesColors,
    this.bottomLabels,
    this.yLabel,
  });

  @override
  Widget build(BuildContext context) {
    final data = seriesData ??
        [
          const [
            FlSpot(0, 3), FlSpot(2, 8), FlSpot(4, 15),
            FlSpot(6, 10), FlSpot(8, 18), FlSpot(10, 8),
          ]
        ];
    final colors = seriesColors ?? [AppColors.primary];

    return LineChart(
      LineChartData(
        gridData: FlGridData(
          show: true,
          drawVerticalLine: false,
          horizontalInterval: 5,
          getDrawingHorizontalLine: (v) =>
              FlLine(color: AppColors.border, strokeWidth: 1),
        ),
        titlesData: FlTitlesData(
          bottomTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              reservedSize: 28,
              getTitlesWidget: (value, meta) {
                if (bottomLabels != null) {
                  final idx = value.toInt();
                  if (idx >= 0 && idx < bottomLabels!.length) {
                    return Padding(
                      padding: const EdgeInsets.only(top: 6),
                      child: Text(bottomLabels![idx],
                          style: const TextStyle(
                              fontSize: 10,
                              color: AppColors.textSecondary)),
                    );
                  }
                }
                return Padding(
                  padding: const EdgeInsets.only(top: 6),
                  child: Text(value.toInt().toString(),
                      style: const TextStyle(
                          fontSize: 10, color: AppColors.textSecondary)),
                );
              },
            ),
          ),
          leftTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              reservedSize: 40,
              getTitlesWidget: (value, meta) => Text(
                value.toInt().toString(),
                style: const TextStyle(
                    fontSize: 10, color: AppColors.textSecondary),
              ),
            ),
          ),
          topTitles:
              const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          rightTitles:
              const AxisTitles(sideTitles: SideTitles(showTitles: false)),
        ),
        borderData: FlBorderData(show: false),
        lineBarsData: [
          for (int i = 0; i < data.length; i++)
            LineChartBarData(
              spots: data[i],
              isCurved: true,
              color: colors[i % colors.length],
              barWidth: 2.5,
              isStrokeCapRound: true,
              dotData: const FlDotData(show: false),
              belowBarData: BarAreaData(
                show: data.length == 1,
                color: colors[i % colors.length].withOpacity(0.08),
              ),
            ),
        ],
      ),
    );
  }
}