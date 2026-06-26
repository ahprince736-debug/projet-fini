import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:go_router/go_router.dart';

import 'config/supabase_config.dart';
import 'services/secure_otp_storage.dart';

import 'screens/vendor/register_screen.dart';
import 'screens/vendor/login_screen.dart';
import 'screens/vendor/dashboard_screen.dart';
import 'screens/vendor/create_order_screen.dart';
import 'screens/vendor/radar_screen.dart';
import 'screens/vendor/handover_screen.dart';

import 'screens/driver/register_kyc_screen.dart';
import 'screens/driver/waiting_screen.dart';
import 'screens/driver/login_screen.dart';
import 'screens/driver/dashboard_screen.dart';
import 'screens/driver/collect_route_screen.dart';
import 'screens/driver/deliver_route_screen.dart';
import 'screens/driver/otp_validation_screen.dart';
import 'screens/driver/wallet_screen.dart';

import 'screens/shared/splash_screen.dart';
import 'screens/shared/paywall_screen.dart';
import 'screens/web/tracking_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await Supabase.initialize(
    url:            SupabaseConfig.url,
    anonKey:        SupabaseConfig.anonKey,
  );

  await SecureOtpStorage.init();

  runApp(
    const ProviderScope(
      child: FlashGoApp(),
    ),
  );
}

final _router = GoRouter(
  initialLocation: '/',
  routes: [
    GoRoute(path: '/',                 builder: (c, s) => const SplashScreen()),
    GoRoute(path: '/vendor/register',  builder: (c, s) => const VendorRegisterScreen()),
    GoRoute(path: '/vendor/login',     builder: (c, s) => const VendorLoginScreen()),
    GoRoute(path: '/vendor/dashboard', builder: (c, s) => const VendorDashboardScreen()),
    GoRoute(path: '/vendor/new-order', builder: (c, s) => const CreateOrderScreen()),
    GoRoute(
      path:    '/vendor/radar/:orderId',
      builder: (c, s) => RadarScreen(orderId: s.pathParameters['orderId']!),
    ),
    GoRoute(
      path:    '/vendor/handover/:orderId',
      builder: (c, s) => HandoverScreen(orderId: s.pathParameters['orderId']!),
    ),
    GoRoute(path: '/driver/register',  builder: (c, s) => const DriverRegisterScreen()),
    GoRoute(path: '/driver/waiting',   builder: (c, s) => const DriverWaitingScreen()),
    GoRoute(path: '/driver/login',     builder: (c, s) => const DriverLoginScreen()),
    GoRoute(path: '/driver/dashboard', builder: (c, s) => const DriverDashboardScreen()),
    GoRoute(
      path:    '/driver/collect/:orderId',
      builder: (c, s) => CollectRouteScreen(orderId: s.pathParameters['orderId']!),
    ),
    GoRoute(
      path:    '/driver/deliver/:orderId',
      builder: (c, s) => DeliverRouteScreen(orderId: s.pathParameters['orderId']!),
    ),
    GoRoute(
      path:    '/driver/otp/:orderId',
      builder: (c, s) => OtpValidationScreen(orderId: s.pathParameters['orderId']!),
    ),
    GoRoute(path: '/driver/wallet',    builder: (c, s) => const WalletScreen()),
    GoRoute(
      path:    '/track/:orderId',
      builder: (c, s) => TrackingScreen(orderId: s.pathParameters['orderId']!),
    ),
    GoRoute(path: '/paywall',          builder: (c, s) => const PaywallScreen()),
  ],
);

class FlashGoApp extends StatelessWidget {
  const FlashGoApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp.router(
      title:                      'FlashGo',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        scaffoldBackgroundColor: const Color(0xFF0D1B2A),
        colorScheme: ColorScheme.fromSeed(
          seedColor:  const Color(0xFF006D77),
          brightness: Brightness.dark,
        ),
      ),
      routerConfig: _router,
    );
  }
}