import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

Future<void> exportCsvFile(
    String csvContent, String filename, BuildContext context) async {
  await Clipboard.setData(ClipboardData(text: csvContent));
  if (context.mounted) {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
          content:
              Text('CSV data copied to clipboard – paste into a text editor')),
    );
  }
}
