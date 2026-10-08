import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_web_plugins/url_strategy.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'core/api_client.dart';
import 'core/auth_api.dart';
import 'core/connectivity.dart';
import 'models/queries.dart';
import 'repositories/repositories.dart';
import 'router.dart';
import 'state/auth_notifier.dart';
import 'state/list_notifier.dart';
import 'widgets/inactivity_watcher.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  usePathUrlStrategy();
  final auth = AuthNotifier(await SharedPreferences.getInstance(), AuthApi());
  await auth.restore();
  runApp(ShoeStoreApp(auth: auth, router: createRouter(auth)));
}

final messengerKey = GlobalKey<ScaffoldMessengerState>();

class ShoeStoreApp extends StatefulWidget {
  const ShoeStoreApp({
    super.key,
    required this.auth,
    required this.router,
    this.dio,
    this.monitor,
  });

  final AuthNotifier auth;
  final GoRouter router;
  final Dio? dio;
  final ConnectivityMonitor? monitor;

  @override
  State<ShoeStoreApp> createState() => _ShoeStoreAppState();
}

class _ShoeStoreAppState extends State<ShoeStoreApp> {
  // Монитор связи создаётся один раз на всё время работы приложения.
  late final ConnectivityMonitor _net = widget.monitor ?? ConnectivityMonitor();

  @override
  void dispose() {
    if (widget.monitor == null) _net.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final auth = widget.auth;
    return MultiProvider(
      providers: [
        ChangeNotifierProvider<AuthNotifier>.value(value: auth),
        ChangeNotifierProvider<ConnectivityMonitor>.value(value: _net),
        Provider<Dio>(
          create: (_) => widget.dio ?? buildDio(auth: auth, monitor: _net),
        ),
        ProxyProvider<Dio, Repositories>(
          update: (_, dio, __) => Repositories(dio),
        ),
        ChangeNotifierProvider<SneakerListNotifier>(
          create: (c) => SneakerListNotifier(
            c.read<Repositories>().sneakers,
            const SneakerQuery(),
          ),
        ),
        ChangeNotifierProvider<SeriesListNotifier>(
          create: (c) => SeriesListNotifier(
            c.read<Repositories>().series,
            const SeriesQuery(),
          ),
        ),
        ChangeNotifierProvider<BrandListNotifier>(
          create: (c) => BrandListNotifier(
            c.read<Repositories>().brands,
            const BrandQuery(),
          ),
        ),
        ChangeNotifierProvider<CategoryListNotifier>(
          create: (c) => CategoryListNotifier(
            c.read<Repositories>().categories,
            const CategoryQuery(),
          ),
        ),
        ChangeNotifierProvider<CustomerListNotifier>(
          create: (c) => CustomerListNotifier(
            c.read<Repositories>().customers,
            const CustomerQuery(),
          ),
        ),
        ChangeNotifierProvider<OrderListNotifier>(
          create: (c) => OrderListNotifier(
            c.read<Repositories>().orders,
            const OrderQuery(),
          ),
        ),
        ChangeNotifierProvider<ReviewListNotifier>(
          create: (c) => ReviewListNotifier(
            c.read<Repositories>().reviews,
            const ReviewQuery(),
          ),
        ),
      ],
      child: MaterialApp.router(
        title: 'Магазин кроссовок',
        debugShowCheckedModeBanner: false,
        theme: ThemeData(
          colorScheme: ColorScheme.fromSeed(seedColor: Colors.deepOrange),
          useMaterial3: true,
        ),
        scaffoldMessengerKey: messengerKey,
        routerConfig: widget.router,
        builder: (context, child) => InactivityWatcher(
          auth: auth,
          messengerKey: messengerKey,
          child: child!,
        ),
      ),
    );
  }
}
