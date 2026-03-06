import 'package:go_router/go_router.dart';
import '../../features/shared/main_layout.dart';
import '../../features/dashboard/dashboard_screen.dart';
import '../../features/plants/plants_screen.dart';
import '../../features/inverters/single_inverter_screen.dart';
import '../../features/slms/latest_string_data_screen.dart';

final goRouter = GoRouter(
  initialLocation: '/dashboard',
  routes:[
    ShellRoute(
      builder: (context, state, child) => MainLayout(child: child),
      routes:[
        GoRoute(path: '/dashboard', builder: (context, state) => const DashboardScreen()),
        GoRoute(path: '/plants', builder: (context, state) => const PlantsScreen()),
        GoRoute(
          path: '/inverters/:id',
          builder: (context, state) => SingleInverterScreen(inverterId: state.pathParameters['id']!),
        ),
        GoRoute(path: '/slms', builder: (context, state) => const LatestStringDataScreen()),
      ],
    ),
  ],
);