import 'package:flutter/material.dart';
import '../../core/theme/app_colors.dart';

class AdaptiveDataTable extends StatelessWidget {
  final List<String> columns;
  final List<List<Widget>> rows;

  const AdaptiveDataTable({super.key, required this.columns, required this.rows});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.border),
      ),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: DataTable(
          headingRowColor: MaterialStateProperty.all(AppColors.primaryLight),
          dataRowHeight: 60,
          columns: columns.map((col) => DataColumn(
            label: Text(col, style: const TextStyle(fontWeight: FontWeight.bold, color: AppColors.textSecondary)),
          )).toList(),
          rows: rows.map((row) => DataRow(
            cells: row.map((cell) => DataCell(cell)).toList(),
          )).toList(),
        ),
      ),
    );
  }
}