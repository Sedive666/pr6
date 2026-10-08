import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../core/api_exceptions.dart';
import '../core/connectivity.dart';
import '../core/permissions.dart';
import '../models/app_user.dart';
import '../state/auth_notifier.dart';
import '../widgets/app_scaffold.dart';

class _ApiView extends StatefulWidget {
  const _ApiView({required this.path, required this.builder});

  final String path;
  final Widget Function(dynamic data, VoidCallback reload) builder;

  @override
  State<_ApiView> createState() => _ApiViewState();
}

class _ApiViewState extends State<_ApiView> {
  late Future<dynamic> _future = _load();
  late final ConnectivityMonitor _net = context.read<ConnectivityMonitor>();
  bool _failed = false;

  @override
  void initState() {
    super.initState();
    _net.addListener(_onNetworkChanged);
  }

  @override
  void dispose() {
    _net.removeListener(_onNetworkChanged);
    super.dispose();
  }

  /// Связь вернулась — запрос повторяется сам, без обновления страницы.
  void _onNetworkChanged() {
    if (mounted && _net.online && _failed) _reload();
  }

  Future<dynamic> _load() async {
    try {
      final data = await guard(
        () async => (await context.read<Dio>().get(widget.path)).data,
      );
      _failed = false;
      return data;
    } catch (_) {
      _failed = true;
      rethrow;
    }
  }

  void _reload() {
    setState(() {
      _future = _load();
    });
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder(
      future: _future,
      builder: (context, snap) {
        if (snap.connectionState != ConnectionState.done) {
          return const Center(child: CircularProgressIndicator());
        }
        if (snap.hasError) {
          return Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text('${snap.error}'),
                const SizedBox(height: 8),
                OutlinedButton(
                  onPressed: _reload,
                  child: const Text('Повторить'),
                ),
              ],
            ),
          );
        }
        return widget.builder(snap.data, _reload);
      },
    );
  }
}

Future<void> _act(BuildContext context, Future<void> Function() action) async {
  final messenger = ScaffoldMessenger.of(context);
  final errorColor = Theme.of(context).colorScheme.error;
  try {
    await guard(action);
  } catch (e) {
    messenger.showSnackBar(
      SnackBar(content: Text('$e'), backgroundColor: errorColor),
    );
  }
}

class ForbiddenScreen extends StatelessWidget {
  const ForbiddenScreen({super.key, this.path});

  final String? path;

  @override
  Widget build(BuildContext context) {
    final role = context.watch<AuthNotifier>().role;
    final theme = Theme.of(context);
    return AppScaffold(
      title: 'Доступ запрещён',
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.block,
                size: 64,
                color: theme.colorScheme.error,
                semanticLabel: 'Доступ запрещён',
              ),
              Text('403', style: theme.textTheme.displayMedium),
              const SizedBox(height: 8),
              Text(
                'Роли «${role?.title ?? 'гость'}» недоступен адрес '
                '${path ?? ''}',
                textAlign: TextAlign.center,
              ),
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
  }
}

class MyOrdersScreen extends StatelessWidget {
  const MyOrdersScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthNotifier>();
    return AppScaffold(
      title: 'Мои заказы',
      body: _ApiView(
        path: '/my/orders',
        builder: (data, reload) {
          final items = ((data as Map)['items'] as List).cast<Map>();
          if (items.isEmpty) {
            return const Center(child: Text('У вас пока нет заказов'));
          }
          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              for (final o in items)
                Card(
                  child: ListTile(
                    leading: const Icon(Icons.receipt_long_outlined),
                    title: Text(
                      '${o['number']} · ${(o['sneaker'] as Map?)?['name'] ?? ''}',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    subtitle: Text(
                      'Размер ${o['size']} · ${o['quantity']} шт. · '
                      '${o['total']} ₽ · ${o['status']}',
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    trailing:
                        o['status'] == 'Новый' && auth.can(Op.cancelOwnOrder)
                        ? OutlinedButton(
                            onPressed: () => _act(context, () async {
                              await context.read<Dio>().post(
                                '/my/orders/${o['id']}/cancel',
                              );
                              reload();
                            }),
                            child: const Text('Отменить'),
                          )
                        : null,
                  ),
                ),
            ],
          );
        },
      ),
    );
  }
}

class UsersScreen extends StatelessWidget {
  const UsersScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final me = context.watch<AuthNotifier>().user;
    return AppScaffold(
      title: 'Пользователи и роли',
      body: _ApiView(
        path: '/users',
        builder: (data, reload) {
          final users = ((data as Map)['items'] as List)
              .map((j) => AppUser.fromJson(j as Map<String, dynamic>))
              .toList();
          Future<void> update(AppUser u, Map<String, dynamic> body) =>
              _act(context, () async {
                await context.read<Dio>().put('/users/${u.id}', data: body);
                reload();
              });
          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              for (final u in users)
                Card(
                  child: ListTile(
                    leading: Icon(
                      u.blocked ? Icons.person_off_outlined : Icons.person,
                      semanticLabel: u.blocked ? 'заблокирован' : 'активен',
                    ),
                    title: Text(
                      '${u.name} (${u.login})',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    subtitle: Text(u.blocked ? 'Заблокирован' : 'Активен'),
                    trailing: Wrap(
                      spacing: 12,
                      crossAxisAlignment: WrapCrossAlignment.center,
                      children: [
                        DropdownButton<Role>(
                          value: u.role,
                          onChanged: u.id == me?.id
                              ? null
                              : (r) => update(u, {'role': r!.name}),
                          items: [
                            for (final r in Role.values)
                              DropdownMenuItem(value: r, child: Text(r.title)),
                          ],
                        ),
                        Semantics(
                          // Переключатель без подписи: без этого чтение с
                          // экрана объявляет просто «переключатель».
                          label: 'Доступ в систему',
                          child: Switch(
                            value: !u.blocked,
                            onChanged: u.id == me?.id
                                ? null
                                : (v) => update(u, {'blocked': !v}),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
            ],
          );
        },
      ),
    );
  }
}

class StatsScreen extends StatelessWidget {
  const StatsScreen({super.key});

  static const _names = {
    'sneakers': 'Кроссовки',
    'brands': 'Бренды',
    'series': 'Линейки',
    'categories': 'Категории',
    'customers': 'Покупатели',
    'orders': 'Заказы',
    'reviews': 'Отзывы',
  };

  @override
  Widget build(BuildContext context) {
    return AppScaffold(
      title: 'Статистика',
      body: _ApiView(
        path: '/stats',
        builder: (data, _) {
          final d = data as Map;
          Widget block(
            String title,
            Map values, [
            String Function(Object)? key,
          ]) => SizedBox(
            width: 320,
            child: Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title, style: Theme.of(context).textTheme.titleMedium),
                    const Divider(),
                    for (final e in values.entries)
                      Row(
                        children: [
                          Expanded(child: Text(key?.call(e.key) ?? '${e.key}')),
                          Text('${e.value}'),
                        ],
                      ),
                  ],
                ),
              ),
            ),
          );
          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              Card(
                child: ListTile(
                  leading: const Icon(Icons.payments_outlined),
                  title: const Text('Выручка (без отменённых заказов)'),
                  trailing: Text(
                    '${d['revenue']} ₽',
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                ),
              ),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  block(
                    'Записей',
                    d['counts'] as Map,
                    (k) => _names[k] ?? '$k',
                  ),
                  block(
                    'В корзине (удалены)',
                    d['deleted'] as Map,
                    (k) => _names[k] ?? '$k',
                  ),
                  block('Заказы по статусам', d['byStatus'] as Map),
                  block(
                    'Пользователи по ролям',
                    d['users'] as Map,
                    (k) => Role.parse(k)?.title ?? '$k',
                  ),
                ],
              ),
            ],
          );
        },
      ),
    );
  }
}
