import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import 'core/permissions.dart';
import 'models/queries.dart';
import 'screens/account_screens.dart';
import 'screens/auth_screens.dart';
import 'screens/catalog_screens.dart';
import 'screens/customer_screens.dart';
import 'screens/sales_screens.dart';
import 'screens/sneaker_screens.dart';
import 'state/auth_notifier.dart';
import 'widgets/app_scaffold.dart';

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
          builder: (_, state) =>
              ForbiddenScreen(path: state.uri.queryParameters['path']),
        ),
        GoRoute(path: '/my/orders', builder: (_, _) => const MyOrdersScreen()),
        GoRoute(path: '/admin/users', builder: (_, _) => const UsersScreen()),
        GoRoute(path: '/admin/stats', builder: (_, _) => const StatsScreen()),
        _section(
          path: '/sneakers',
          list: (p) => SneakerListScreen(query: SneakerQuery.fromParams(p)),
          detail: (id) => SneakerDetailScreen(id: id),
          form: (id) => SneakerFormScreen(id: id),
        ),
        _section(
          path: '/brands',
          list: (p) => BrandListScreen(query: BrandQuery.fromParams(p)),
          detail: (id) => BrandDetailScreen(id: id),
          form: (id) => BrandFormScreen(id: id),
        ),
        _section(
          path: '/series',
          list: (p) => SeriesListScreen(query: SeriesQuery.fromParams(p)),
          detail: (id) => SeriesDetailScreen(id: id),
          form: (id) => SeriesFormScreen(id: id),
        ),
        _section(
          path: '/categories',
          list: (p) => CategoryListScreen(query: CategoryQuery.fromParams(p)),
          detail: (id) => CategoryDetailScreen(id: id),
          form: (id) => CategoryFormScreen(id: id),
        ),
        _section(
          path: '/customers',
          list: (p) => CustomerListScreen(query: CustomerQuery.fromParams(p)),
          detail: (id) => CustomerDetailScreen(id: id),
          form: (id) => CustomerFormScreen(id: id),
        ),
        _section(
          path: '/orders',
          list: (p) => OrderListScreen(query: OrderQuery.fromParams(p)),
          detail: (id) => OrderDetailScreen(id: id),
          form: (id) => OrderFormScreen(id: id),
        ),
        _section(
          path: '/reviews',
          list: (p) => ReviewListScreen(query: ReviewQuery.fromParams(p)),
          detail: (id) => ReviewDetailScreen(id: id),
          form: (id) => ReviewFormScreen(id: id),
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
