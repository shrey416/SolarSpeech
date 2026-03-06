import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'core/theme/app_theme.dart';
import 'core/router/app_router.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Supabase.initialize(
    url: 'https://yqajxlcqwqrykzpulfzb.supabase.co',
    anonKey: 'sb_publishable_GE5TWu2IyEogyf1-TZiX5Q_MYpEtzcD',
  );
  runApp(const ProviderScope(child: MyApp()));
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp.router(
      title: 'Solar Dashboard',
      theme: AppTheme.lightTheme,
      debugShowCheckedModeBanner: false,
      routerConfig: goRouter,
    );
  }
}