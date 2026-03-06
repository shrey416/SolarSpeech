import 'package:go_router/go_router.dart';
import '../../features/shared/main_layout.dart';
import '../../features/dashboard/dashboard_screen.dart';
import '../../features/plants/plants_screen.dart';
import '../../features/inverters/single_inverter_screen.dart';
import '../../features/slms/slms_list_screen.dart';
import '../../features/slms/latest_string_data_screen.dart';
import '../../features/sensors/sensors_screen.dart';
import '../../features/alerts/alerts_screen.dart';

final goRouter = GoRouter(
  initialLocation: '/dashboard',
  routes: [
    ShellRoute(
      builder: (context, state, child) => MainLayout(
        currentPath: state.uri.toString(),
        child: child,
      ),
      routes: [
        GoRoute(
          path: '/dashboard',
          builder: (context, state) => const DashboardScreen(),
        ),
        GoRoute(
          path: '/plants/:plantId',
          builder: (context, state) => PlantsScreen(
            plantId: state.pathParameters['plantId']!,
          ),
        ),
        GoRoute(
          path: '/plants/:plantId/inverters/:inverterId',
          builder: (context, state) => SingleInverterScreen(
            inverterId: state.pathParameters['inverterId']!,
            plantId: state.pathParameters['plantId']!,
          ),
        ),
        GoRoute(
          path: '/slms',
          builder: (context, state) => const SlmsListScreen(),
        ),
        GoRoute(
          path: '/slms/:inverterId',
          builder: (context, state) => LatestStringDataScreen(
            inverterId: state.pathParameters['inverterId']!,
          ),
        ),
        GoRoute(
          path: '/sensors',
          builder: (context, state) => const SensorsScreen(),
        ),
        GoRoute(
          path: '/alerts',
          builder: (context, state) => const AlertsScreen(),
        ),
      ],
    ),
  ],
);