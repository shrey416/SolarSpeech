// ignore: avoid_web_libraries_in_flutter
import 'dart:html' as html;
import 'package:flutter/material.dart';

Future<void> exportCsvFile(
    String csvContent, String filename, BuildContext context) async {
  final blob = html.Blob([csvContent], 'text/csv');
  final url = html.Url.createObjectUrlFromBlob(blob);
  html.AnchorElement()
    ..href = url
    ..download = filename
    ..click();
  html.Url.revokeObjectUrl(url);
  if (context.mounted) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('$filename downloaded')),
    );
  }
}
