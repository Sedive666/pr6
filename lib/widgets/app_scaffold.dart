import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../core/breakpoints.dart';
import '../core/connectivity.dart';
import '../core/permissions.dart';
import '../state/auth_notifier.dart';

typedef NavSection = ({String path, String label, IconData icon});

/// Разделы навигации в порядке важности: на узком окне в нижнюю панель
/// попадают первые из доступных роли, остальные открываются из пункта «Ещё».
const navSections = <NavSection>[
  (path: '/my/orders', label: 'Мои заказы', icon: Icons.receipt_long_outlined),
  (path: '/admin/stats', label: 'Статистика', icon: Icons.bar_chart_outlined),
  (path: '/sneakers', label: 'Кроссовки', icon: Icons.directions_run_outlined),
  (path: '/orders', label: 'Заказы', icon: Icons.shopping_cart_outlined),
  (path: '/customers', label: 'Покупатели', icon: Icons.people_outline),
  (
    path: '/admin/users',
    label: 'Пользователи',
    icon: Icons.manage_accounts_outlined,
  ),
  (path: '/brands', label: 'Бренды', icon: Icons.label_outline),
  (
    path: '/series',
    label: 'Линейки',
    icon: Icons.collections_bookmark_outlined,
  ),
  (path: '/categories', label: 'Категории', icon: Icons.category_outlined),
  (path: '/reviews', label: 'Отзывы', icon: Icons.star_outline),
];

/// Разделы, доступные роли.
List<NavSection> sectionsFor(AuthNotifier auth) => [
  for (final s in navSections)
    if (auth.can(requiredOp(s.path)!)) s,
];

/// Сколько пунктов помещается в нижнюю панель до появления пункта «Ещё».
const _bottomSlots = 4;

/// Разделы для нижней панели. Если их больше, чем мест, последнее место
/// отдаётся открытому разделу — иначе панель подсвечивала бы не тот пункт.
@visibleForTesting
List<NavSection> bottomSections(List<NavSection> all, String location) {
  if (all.length <= _bottomSlots + 1) return all;
  final head = all.take(_bottomSlots).toList();
  final current = all.indexWhere((s) => location.startsWith(s.path));
  if (current >= _bottomSlots) head[_bottomSlots - 1] = all[current];
  return head;
}

class AppScaffold extends StatelessWidget {
  const AppScaffold({super.key, required this.title, required this.body});

  final String title;
  final Widget body;

  @override
  Widget build(BuildContext context) {
    final location = GoRouterState.of(context).uri.path;
    final auth = context.watch<AuthNotifier>();
    final sections = sectionsFor(auth);

    return LayoutBuilder(
      builder: (context, constraints) {
        final layout = layoutOf(constraints.maxWidth);
        final content = _Content(layout: layout, child: body);

        if (layout == Layout.compact) {
          return Scaffold(
            appBar: _appBar(context, auth, layout),
            body: content,
            bottomNavigationBar: sections.isEmpty
                ? null
                : _BottomNav(sections: sections, location: location),
          );
        }

        return Scaffold(
          appBar: _appBar(context, auth, layout),
          body: Row(
            children: [
              if (sections.isNotEmpty)
                _Rail(
                  sections: sections,
                  location: location,
                  extended: layout != Layout.medium,
                ),
              Expanded(child: content),
            ],
          ),
        );
      },
    );
  }

  AppBar _appBar(BuildContext context, AuthNotifier auth, Layout layout) {
    final user = auth.user;
    return AppBar(
      title: Text(title, maxLines: 1, overflow: TextOverflow.ellipsis),
      actions: [
        if (user != null) ...[
          // На узком окне подпись не влезает рядом с заголовком: остаётся
          // только кнопка выхода, а имя и роль уходят в её подсказку.
          if (layout != Layout.compact)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8),
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 240),
                child: Chip(
                  avatar: const Icon(Icons.account_circle_outlined, size: 18),
                  label: Text(
                    '${user.name} · ${user.role.title}',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ),
            ),
          IconButton(
            tooltip: layout == Layout.compact
                ? 'Выйти — ${user.name} · ${user.role.title}'
                : 'Выйти',
            icon: const Icon(Icons.logout),
            onPressed: auth.logout,
          ),
        ],
      ],
    );
  }
}

/// Полоса-предупреждение о пропаже связи и ограничение ширины содержимого.
class _Content extends StatelessWidget {
  const _Content({required this.layout, required this.child});

  final Layout layout;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final online = context.watch<ConnectivityMonitor>().online;
    final limited = layout == Layout.large
        ? Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: Bp.maxContent),
              child: child,
            ),
          )
        : child;
    if (online) return limited;

    final colors = Theme.of(context).colorScheme;
    return Column(
      children: [
        Container(
          width: double.infinity,
          color: colors.errorContainer,
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          child: Row(
            children: [
              Icon(Icons.cloud_off, size: 18, color: colors.onErrorContainer),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  'Нет связи с сервером. Проверяем соединение — '
                  'страницу обновлять не нужно.',
                  style: TextStyle(color: colors.onErrorContainer),
                ),
              ),
            ],
          ),
        ),
        Expanded(child: limited),
      ],
    );
  }
}

class _BottomNav extends StatelessWidget {
  const _BottomNav({required this.sections, required this.location});

  final List<NavSection> sections;
  final String location;

  @override
  Widget build(BuildContext context) {
    final shown = bottomSections(sections, location);
    final rest = sections.where((s) => !shown.contains(s)).toList();
    final current = shown.indexWhere((s) => location.startsWith(s.path));

    return NavigationBar(
      selectedIndex: current < 0 ? 0 : current,
      onDestinationSelected: (i) {
        if (i < shown.length) {
          context.go(shown[i].path);
        } else {
          _showRest(context, rest);
        }
      },
      destinations: [
        for (final s in shown)
          NavigationDestination(icon: Icon(s.icon), label: s.label),
        if (rest.isNotEmpty)
          const NavigationDestination(
            icon: Icon(Icons.more_horiz),
            label: 'Ещё',
          ),
      ],
    );
  }

  void _showRest(BuildContext context, List<NavSection> rest) {
    showModalBottomSheet<void>(
      context: context,
      builder: (sheet) => SafeArea(
        child: ListView(
          shrinkWrap: true,
          children: [
            for (final s in rest)
              ListTile(
                leading: Icon(s.icon),
                title: Text(s.label),
                onTap: () {
                  Navigator.pop(sheet);
                  context.go(s.path);
                },
              ),
          ],
        ),
      ),
    );
  }
}

class _Rail extends StatelessWidget {
  const _Rail({
    required this.sections,
    required this.location,
    required this.extended,
  });

  final List<NavSection> sections;
  final String location;
  final bool extended;

  @override
  Widget build(BuildContext context) {
    final current = sections.indexWhere((s) => location.startsWith(s.path));
    // Полоса не прокручивается сама: в невысоком окне десять разделов
    // не поместились бы, поэтому её содержимое обёрнуто в прокрутку.
    return LayoutBuilder(
      builder: (context, constraints) => SingleChildScrollView(
        child: ConstrainedBox(
          constraints: BoxConstraints(minHeight: constraints.maxHeight),
          child: IntrinsicHeight(
            child: NavigationRail(
              selectedIndex: current < 0 ? null : current,
              extended: extended,
              labelType: extended ? null : NavigationRailLabelType.selected,
              onDestinationSelected: (i) => context.go(sections[i].path),
              destinations: [
                for (final s in sections)
                  NavigationRailDestination(
                    icon: Icon(s.icon),
                    label: Text(s.label),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
