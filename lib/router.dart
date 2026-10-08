import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import 'core/permissions.dart';
import 'models/queries.dart';
import 'screens/auth_screens.dart';
import 'state/auth_notifier.dart';
import 'widgets/app_scaffold.dart';
import 'widgets/deferred_screen.dart';

// Редко открываемые разделы подключены отложенно: их код не входит в основной
// файл сборки, а скачивается отдельной частью при первом открытии раздела.
// Экраны входа и кроссовок остаются в основной части — с них начинается
// работа у всех ролей, кроме покупателя.
import 'screens/account_screens.dart' deferred as account;
import 'screens/catalog_screens.dart' deferred as catalog;
import 'screens/customer_screens.dart' deferred as customers;
import 'screens/sales_screens.dart' deferred as sales;
import 'screens/sneaker_screens.dart' as sneakers;

int _id(GoRouterState state) =>
    int.tryParse(state.pathParameters['id'] ?? '') ?? -1;

RouteBase _section({
  required String path,
  required Widget Function(Map<String, String> params) list,
  required Widget Function(int id) detail,
  required Widget Function(int? id) form,
}) => GoRoute(
  path: path,
  builder: (context, state) => list(state.uri.queryParameters),
  routes: [
    GoRoute(path: 'new', builder: (context, state) => form(null)),
    GoRoute(
      path: ':id',
      builder: (context, state) => detail(_id(state)),
      routes: [
        GoRoute(path: 'edit', builder: (context, state) => form(_id(state))),
      ],
    ),
  ],
);

/// Раздел, код которого скачивается при первом открытии.
RouteBase _deferredSection({
  required String path,
  required Future<void> Function() load,
  required Widget Function(Map<String, String> params) list,
  required Widget Function(int id) detail,
  required Widget Function(int? id) form,
}) => _section(
  path: path,
  list: (p) => DeferredScreen(load: load, builder: (_) => list(p)),
  detail: (id) => DeferredScreen(load: load, builder: (_) => detail(id)),
  form: (id) => DeferredScreen(load: load, builder: (_) => form(id)),
);

GoRouter createRouter(AuthNotifier auth, {String initialLocation = '/'}) =>
    GoRouter(
      initialLocation: initialLocation,
      refreshListenable: auth,
      redirect: (context, state) =>
          guardRedirect(role: auth.role, uri: state.uri),
      routes: [
        GoRoute(path: '/', builder: (_, _) => const SizedBox.shrink()),
        GoRoute(path: '/login', builder: (_, _) => const LoginScreen()),
        GoRoute(path: '/register', builder: (_, _) => const RegisterScreen()),
        GoRoute(
          path: '/forbidden',
          builder: (_, state) => DeferredScreen(
            load: account.loadLibrary,
            builder: (_) => account.ForbiddenScreen(
              path: state.uri.queryParameters['path'],
            ),
          ),
        ),
        GoRoute(
          path: '/my/orders',
          builder: (_, _) => DeferredScreen(
            load: account.loadLibrary,
            builder: (_) => account.MyOrdersScreen(),
          ),
        ),
        GoRoute(
          path: '/admin/users',
          builder: (_, _) => DeferredScreen(
            load: account.loadLibrary,
            builder: (_) => account.UsersScreen(),
          ),
        ),
        GoRoute(
          path: '/admin/stats',
          builder: (_, _) => DeferredScreen(
            load: account.loadLibrary,
            builder: (_) => account.StatsScreen(),
          ),
        ),
        _section(
          path: '/sneakers',
          list: (p) =>
              sneakers.SneakerListScreen(query: SneakerQuery.fromParams(p)),
          detail: (id) => sneakers.SneakerDetailScreen(id: id),
          form: (id) => sneakers.SneakerFormScreen(id: id),
        ),
        _deferredSection(
          path: '/brands',
          load: catalog.loadLibrary,
          list: (p) => catalog.BrandListScreen(query: BrandQuery.fromParams(p)),
          detail: (id) => catalog.BrandDetailScreen(id: id),
          form: (id) => catalog.BrandFormScreen(id: id),
        ),
        _deferredSection(
          path: '/series',
          load: catalog.loadLibrary,
          list: (p) =>
              catalog.SeriesListScreen(query: SeriesQuery.fromParams(p)),
          detail: (id) => catalog.SeriesDetailScreen(id: id),
          form: (id) => catalog.SeriesFormScreen(id: id),
        ),
        _deferredSection(
          path: '/categories',
          load: catalog.loadLibrary,
          list: (p) =>
              catalog.CategoryListScreen(query: CategoryQuery.fromParams(p)),
          detail: (id) => catalog.CategoryDetailScreen(id: id),
          form: (id) => catalog.CategoryFormScreen(id: id),
        ),
        _deferredSection(
          path: '/customers',
          load: customers.loadLibrary,
          list: (p) =>
              customers.CustomerListScreen(query: CustomerQuery.fromParams(p)),
          detail: (id) => customers.CustomerDetailScreen(id: id),
          form: (id) => customers.CustomerFormScreen(id: id),
        ),
        _deferredSection(
          path: '/orders',
          load: sales.loadLibrary,
          list: (p) => sales.OrderListScreen(query: OrderQuery.fromParams(p)),
          detail: (id) => sales.OrderDetailScreen(id: id),
          form: (id) => sales.OrderFormScreen(id: id),
        ),
        _deferredSection(
          path: '/reviews',
          load: sales.loadLibrary,
          list: (p) => sales.ReviewListScreen(query: ReviewQuery.fromParams(p)),
          detail: (id) => sales.ReviewDetailScreen(id: id),
          form: (id) => sales.ReviewFormScreen(id: id),
        ),
      ],
      errorBuilder: (context, state) => AppScaffold(
        title: 'Страница не найдена',
        body: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text('404', style: Theme.of(context).textTheme.displayLarge),
              Text(state.uri.toString()),
              const SizedBox(height: 16),
              FilledButton(
                onPressed: () => context.go('/'),
                child: const Text('На главную'),
              ),
            ],
          ),
        ),
      ),
    );
