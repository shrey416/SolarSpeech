import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../features/shared/main_layout.dart';
import '../../features/dashboard/dashboard_screen.dart';
import '../../features/plants/my_plants_screen.dart';
import '../../features/plants/plants_screen.dart';
import '../../features/inverters/inverters_list_screen.dart';
import '../../features/inverters/single_inverter_screen.dart';
import '../../features/slms/slms_list_screen.dart';
import '../../features/slms/latest_string_data_screen.dart';
import '../../features/sensors/sensors_screen.dart';
import '../../features/sensors/single_mfm_screen.dart';
import '../../features/sensors/single_temp_screen.dart';
import '../../features/alerts/alerts_screen.dart';
import '../../features/exports/exports_screen.dart';

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
          path: '/my-plants',
          builder: (context, state) => const MyPlantsScreen(),
        ),
        GoRoute(
          path: '/inverters',
          builder: (context, state) {
            final plantId = state.uri.queryParameters['plant'];
            return InvertersListScreen(
              key: ValueKey('inverters_$plantId'),
              initialPlantId: plantId,
            );
          },
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
            initialChart: state.uri.queryParameters['chart'],
            initialDate: state.uri.queryParameters['date'],
          ),
        ),
        GoRoute(
          path: '/plants/:plantId/mfm/:mfmId',
          builder: (context, state) => SingleMfmScreen(
            mfmId: state.pathParameters['mfmId']!,
            plantId: state.pathParameters['plantId']!,
            initialDate: state.uri.queryParameters['date'],
            initialChart: state.uri.queryParameters['chart'],
          ),
        ),
        GoRoute(
          path: '/plants/:plantId/temp/:deviceId',
          builder: (context, state) => SingleTempScreen(
            deviceId: state.pathParameters['deviceId']!,
            plantId: state.pathParameters['plantId']!,
            initialDate: state.uri.queryParameters['date'],
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
          builder: (context, state) {
            final tabParam = state.uri.queryParameters['tab'];
            final plantId = state.uri.queryParameters['plant'];
            int initialTab = 0;
            if (tabParam == 'mfm') initialTab = 1;
            if (tabParam == 'wms') initialTab = 2;
            if (tabParam == 'temperature') initialTab = 3;
            return SensorsScreen(
              key: ValueKey('sensors_${tabParam}_$plantId'),
              initialTab: initialTab,
              initialPlantId: plantId,
            );
          },
        ),
        GoRoute(
          path: '/alerts',
          builder: (context, state) {
            final deviceId = state.uri.queryParameters['deviceId'];
            final deviceName = state.uri.queryParameters['deviceName'];
            return AlertsScreen(
              key: ValueKey('alerts_$deviceId'),
              deviceId: deviceId,
              deviceName: deviceName,
            );
          },
        ),
        GoRoute(
          path: '/exports',
          builder: (context, state) => const ExportsScreen(),
        ),
      ],
    ),
  ],
);