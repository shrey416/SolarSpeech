import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:responsive_framework/responsive_framework.dart';
import '../../providers/data_providers.dart';
import '../../core/theme/app_colors.dart';
import '../shared/line_chart_widget.dart';

class PlantsScreen extends ConsumerWidget {
  const PlantsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final plantsAsync = ref.watch(plantsProvider);
    final isMobile = ResponsiveBreakpoints.of(context).isMobile;

    return Scaffold(
      floatingActionButton: FloatingActionButton(
        backgroundColor: AppColors.primary,
        onPressed: () {},
        child: const Icon(Icons.add, color: Colors.white),
      ),
      body: plantsAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (err, stack) => Center(child: Text('Error: $err')),
        data: (plants) {
          if (plants.isEmpty) return const _EmptyPlantState();

          return Padding(
            padding: const EdgeInsets.all(24.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children:[
                Text("Plants (${plants.length})", style: const TextStyle(fontSize: 24, color: AppColors.primary, fontWeight: FontWeight.bold)),
                const SizedBox(height: 16),
                Expanded(
                  child: GridView.builder(
                    gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: isMobile ? 1 : 3,
                      crossAxisSpacing: 16,
                      mainAxisSpacing: 16,
                      childAspectRatio: 1.5,
                    ),
                    itemCount: plants.length,
                    itemBuilder: (context, index) {
                      final plant = plants[index];
                      return _PlantCard(plant: plant);
                    },
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}

class _PlantCard extends StatelessWidget {
  final Map<String, dynamic> plant;
  const _PlantCard({required this.plant});

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children:[
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(plant['name'] ?? 'Unknown Plant', style: const TextStyle(fontSize: 18, color: AppColors.primary, fontWeight: FontWeight.bold)),
                const Row(children:[
                  Icon(Icons.circle, color: AppColors.active, size: 10),
                  SizedBox(width: 4),
                  Text("Active", style: TextStyle(color: AppColors.active, fontSize: 12)),
                ])
              ],
            ),
            const SizedBox(height: 16),
            const Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children:[
                _MiniStat(label: "Today", value: "4567 Kwh"),
                _MiniStat(label: "Total", value: "4567 Kwh"),
                _MiniStat(label: "Devices", value: "55"),
              ],
            ),
            const Spacer(),
            const Text("Active Power", style: TextStyle(fontSize: 12, color: AppColors.textSecondary)),
            const SizedBox(height: 8),
            SizedBox(height: 80, child: LineChartWidget())
          ],
        ),
      ),
    );
  }
}

class _MiniStat extends StatelessWidget {
  final String label, value;
  const _MiniStat({required this.label, required this.value});
  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children:[
        Text(label, style: const TextStyle(color: AppColors.textSecondary, fontSize: 12)),
        Text(value, style: const TextStyle(color: AppColors.primary, fontWeight: FontWeight.bold)),
      ],
    );
  }
}

// Emptry state matching Image 8
class _EmptyPlantState extends StatelessWidget {
  const _EmptyPlantState();
  @override
  Widget build(BuildContext context) {
    return const Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children:[
          Icon(Icons.solar_power, size: 80, color: AppColors.border),
          SizedBox(height: 16),
          Text("No plant found yet!!", style: TextStyle(color: AppColors.primary, fontSize: 20)),
        ],
      ),
    );
  }
}