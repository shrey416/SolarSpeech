import 'package:flutter/material.dart';
import '../../core/theme/app_colors.dart';

class LatestStringDataScreen extends StatelessWidget {
  const LatestStringDataScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Latest String Data (Total String - 5)")),
      body: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Container(
          decoration: BoxDecoration(
            border: Border.all(color: AppColors.border),
            borderRadius: BorderRadius.circular(12),
            color: AppColors.surface,
          ),
          child: SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: DataTable(
              headingRowColor: MaterialStateProperty.all(AppColors.primaryLight),
              columns:[
                const DataColumn(label: Text("Time")),
                ...List.generate(6, (i) => DataColumn(label: Text("CT ${i+1}"))),
              ],
              rows: List.generate(6, (index) => DataRow(
                cells:[
                  const DataCell(Text("23:43:04\n20/5/25", style: TextStyle(fontSize: 12, color: AppColors.textSecondary))),
                  ...List.generate(6, (i) => DataCell(
                    Text("5", style: TextStyle(color: index < 2 ? AppColors.primary : (index < 4 ? AppColors.warning : AppColors.alert), fontWeight: FontWeight.bold)),
                  )),
                ],
              )),
            ),
          ),
        ),
      ),
    );
  }
}