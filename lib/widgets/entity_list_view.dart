import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../core/breakpoints.dart';
import '../core/connectivity.dart';
import '../core/permissions.dart';
import '../models/entity.dart';
import '../models/list_query.dart';
import '../state/auth_notifier.dart';
import '../state/list_notifier.dart';
import 'app_scaffold.dart';
import 'entity_card_list.dart';
import 'entity_table.dart';
import 'list_controls.dart';

class EntityListView<T extends Entity, Q extends ListQuery<Q>>
    extends StatefulWidget {
  const EntityListView({
    super.key,
    required this.title,
    required this.basePath,
    required this.query,
    required this.searchHint,
    required this.columns,
    required this.cardTitle,
    required this.cardSubtitle,
    this.filters,
  });

  final String title;
  final String basePath;
  final Q query;
  final String searchHint;
  final List<TableColumnSpec<T>> columns;
  final String Function(T item) cardTitle;
  final String Function(T item) cardSubtitle;
  final List<Widget> Function(Q query, ValueChanged<Q> apply)? filters;

  @override
  State<EntityListView<T, Q>> createState() => _EntityListViewState<T, Q>();
}

class _EntityListViewState<T extends Entity, Q extends ListQuery<Q>>
    extends State<EntityListView<T, Q>> {
  ListNotifier<T, Q> get _notifier => context.read<ListNotifier<T, Q>>();

  late final ConnectivityMonitor _net = context.read<ConnectivityMonitor>();

  @override
  void initState() {
    super.initState();
    _net.addListener(_onNetworkChanged);
    _sync();
  }

  @override
  void dispose() {
    _net.removeListener(_onNetworkChanged);
    super.dispose();
  }

  /// Связь с сервером вернулась — список перезагружается сам, пользователю
  /// не нужно ни обновлять страницу, ни нажимать «Повторить».
  void _onNetworkChanged() {
    if (!mounted) return;
    if (_net.online && _notifier.status == LoadStatus.error) _notifier.load();
  }

  @override
  void didUpdateWidget(EntityListView<T, Q> old) {
    super.didUpdateWidget(old);
    if (!old.query.sameAs(widget.query)) _sync();
  }

  void _sync() => WidgetsBinding.instance.addPostFrameCallback((_) {
    if (mounted) _notifier.applyQuery(widget.query);
  });

  void _go(Q q) {
    final params = q.toParams();
    context.go(
      Uri(
        path: widget.basePath,
        queryParameters: params.isEmpty ? null : params,
      ).toString(),
    );
  }

  void _sort(String field) {
    final q = widget.query;
    _go(
      q.copyBase(
        sortField: field,
        sortAscending: field == q.sortField ? !q.sortAscending : true,
      ),
    );
  }

  Future<bool> _confirm(String title, String text) async {
    final result = await showDialog<bool>(
      context: context,
      builder: (c) => AlertDialog(
        title: Text(title),
        // Без ограничения диалог растягивается по содержимому почти на всю
        // ширину монитора.
        content: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 420),
          child: Text(text),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(c, false),
            child: const Text('Отмена'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(c, true),
            child: const Text('Удалить'),
          ),
        ],
      ),
    );
    return result ?? false;
  }

  Future<void> _guard(Future<void> Function() action) async {
    final messenger = ScaffoldMessenger.of(context);
    final errorColor = Theme.of(context).colorScheme.error;
    try {
      await action();
    } catch (e) {
      messenger.showSnackBar(
        SnackBar(content: Text('$e'), backgroundColor: errorColor),
      );
    }
  }

  Future<void> _deleteSelected() async {
    final n = _notifier;
    final messenger = ScaffoldMessenger.of(context);
    final ok = await _confirm(
      'Удалить выбранные?',
      'Будет удалено записей: ${n.selected.length}. '
          'Их можно восстановить, включив показ удалённых.',
    );
    if (!ok) return;
    await _guard(() async {
      final count = await n.deleteSelected();
      messenger.showSnackBar(
        SnackBar(content: Text('Удалено записей: $count')),
      );
    });
  }

  Future<void> _hardDelete(T item) async {
    final ok = await _confirm(
      'Удалить навсегда?',
      '«${widget.cardTitle(item)}» будет стёрта без возможности восстановления.',
    );
    if (ok) await _guard(() => _notifier.hardDelete(item.id));
  }

  bool _can(Op op) => context.read<AuthNotifier>().can(op);

  List<Widget> _actions(T item) => [
    if (_can(Op.editRecords))
      IconButton(
        tooltip: 'Изменить',
        icon: const Icon(Icons.edit_outlined),
        onPressed: () => context.push('${widget.basePath}/${item.id}/edit'),
      ),
    if (item.isDeleted && _can(Op.restore))
      IconButton(
        tooltip: 'Восстановить',
        icon: const Icon(Icons.restore),
        onPressed: () => _guard(() => _notifier.restore(item.id)),
      ),
    if (!item.isDeleted && _can(Op.softDelete))
      IconButton(
        tooltip: 'Удалить',
        icon: const Icon(Icons.delete_outline),
        onPressed: () => _guard(() => _notifier.softDelete(item.id)),
      ),
    if (_can(Op.hardDelete))
      IconButton(
        tooltip: 'Удалить навсегда',
        icon: const Icon(Icons.delete_forever_outlined),
        onPressed: () => _hardDelete(item),
      ),
  ];

  void _open(T item) => context.push('${widget.basePath}/${item.id}');

  Widget _sortMenu(Q q) {
    final sortable = widget.columns.where((c) => c.sortField != null).toList();
    if (sortable.isEmpty) return const SizedBox.shrink();
    final current = sortable.firstWhere(
      (c) => c.sortField == q.sortField,
      orElse: () => sortable.first,
    );
    return PopupMenuButton<String>(
      tooltip: 'Сортировка',
      onSelected: _sort,
      itemBuilder: (_) => [
        for (final c in sortable)
          CheckedPopupMenuItem(
            value: c.sortField,
            checked: c.sortField == q.sortField,
            child: Text(c.label),
          ),
      ],
      child: Chip(
        avatar: Icon(
          q.sortAscending ? Icons.arrow_upward : Icons.arrow_downward,
          size: 18,
        ),
        label: Text('Сортировка: ${current.label}'),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final n = context.watch<ListNotifier<T, Q>>();
    final auth = context.watch<AuthNotifier>();
    final q = widget.query;
    final result = n.result;

    return AppScaffold(
      title: widget.title,
      body: LayoutBuilder(
        builder: (context, constraints) {
          final layout = layoutOf(constraints.maxWidth);
          final header = <Widget>[
            Wrap(
              spacing: 12,
              runSpacing: 12,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                SizedBox(
                  width: layout == Layout.compact ? double.infinity : 280,
                  child: SearchField(
                    value: q.search,
                    hint: widget.searchHint,
                    onChanged: (s) => _go(q.copyBase(search: s)),
                  ),
                ),
                ...?widget.filters?.call(q, _go),
                if (auth.can(Op.viewDeleted))
                  FilterChip(
                    label: const Text('Показывать удалённые'),
                    selected: q.includeDeleted,
                    onSelected: (v) => _go(q.copyBase(includeDeleted: v)),
                  ),
                // В таблице сортировка переключается щелчком по заголовку
                // колонки, в карточках — этим меню.
                if (!layout.showsTable) _sortMenu(q),
                if (q.hasFilters)
                  TextButton.icon(
                    onPressed: () => _go(q.reset()),
                    icon: const Icon(Icons.filter_alt_off_outlined),
                    label: const Text('Сбросить'),
                  ),
                if (auth.can(Op.editRecords))
                  FilledButton.icon(
                    onPressed: () => context.push('${widget.basePath}/new'),
                    icon: const Icon(Icons.add),
                    label: const Text('Добавить'),
                  ),
              ],
            ),
            if (n.hasSelection && auth.can(Op.softDelete))
              Padding(
                padding: const EdgeInsets.only(top: 12),
                child: Wrap(
                  spacing: 12,
                  runSpacing: 8,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    Text(
                      'Выбрано: ${n.selected.length}',
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                    TextButton(
                      onPressed: n.clearSelection,
                      child: const Text('Снять выделение'),
                    ),
                    FilledButton.tonalIcon(
                      onPressed: _deleteSelected,
                      icon: const Icon(Icons.delete_sweep_outlined),
                      label: const Text('Удалить выбранные'),
                    ),
                  ],
                ),
              ),
            const SizedBox(height: 12),
          ];

          final data = ListStateView(
            status: n.status,
            error: n.error,
            hasItems: result.items.isNotEmpty,
            onRetry: n.load,
            onReset: () => _go(q.reset()),
            expand: layout.showsTable,
            child: !layout.showsTable
                ? EntityCardList<T>(
                    items: result.items,
                    idOf: (e) => e.id,
                    title: widget.cardTitle,
                    subtitle: widget.cardSubtitle,
                    selected: n.selected,
                    onToggleSelect: n.toggleSelection,
                    actions: _actions,
                    muted: (e) => e.isDeleted,
                    onTap: _open,
                  )
                : EntityTable<T>(
                    columns: widget.columns,
                    items: result.items,
                    idOf: (e) => e.id,
                    selected: n.selected,
                    onToggleSelect: n.toggleSelection,
                    onToggleAll: (v) =>
                        n.setSelection(result.items.map((e) => e.id), v),
                    sortField: q.sortField,
                    sortAscending: q.sortAscending,
                    onSort: _sort,
                    actions: _actions,
                    muted: (e) => e.isDeleted,
                    onTap: _open,
                  ),
          );

          final pagination = result.total > 0 && n.status != LoadStatus.error
              ? PaginationBar(
                  page: result.page,
                  totalPages: result.totalPages,
                  total: result.total,
                  size: result.size,
                  onPage: (p) => _go(q.copyBase(page: p)),
                  onSize: (s) => _go(q.copyBase(size: s)),
                )
              : const SizedBox.shrink();

          // Таблица: отбор и пагинация закреплены, прокручивается сама
          // таблица — по вертикали и по горизонтали.
          if (layout.showsTable) {
            return Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                children: [
                  ...header,
                  Expanded(child: data),
                  pagination,
                ],
              ),
            );
          }
          // Карточки: панель отбора на узком окне занимает несколько строк,
          // поэтому прокручивается вся страница целиком.
          return ListView(
            padding: const EdgeInsets.all(16),
            children: [...header, data, pagination],
          );
        },
      ),
    );
  }
}

class EntityDetailView<T extends Entity, Q extends ListQuery<Q>>
    extends StatelessWidget {
  const EntityDetailView({
    super.key,
    required this.id,
    required this.listPath,
    required this.title,
    required this.fields,
    this.extra,
  });

  final int id;
  final String listPath;
  final String Function(T item) title;
  final List<(String, String)> Function(T item) fields;
  final Widget Function(BuildContext context, T item)? extra;

  @override
  Widget build(BuildContext context) {
    final n = context.read<ListNotifier<T, Q>>();
    return AppScaffold(
      title: 'Карточка',
      body: FutureBuilder<T?>(
        future: n.findById(id),
        builder: (context, snap) {
          if (snap.connectionState != ConnectionState.done) {
            return const Center(child: CircularProgressIndicator());
          }
          final item = snap.data;
          final theme = Theme.of(context);
          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 560),
                  child: Card(
                    child: Padding(
                      padding: const EdgeInsets.all(24),
                      child: item == null
                          ? Text(
                              'Запись $id не найдена',
                              style: theme.textTheme.titleMedium,
                            )
                          : Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  title(item),
                                  style: theme.textTheme.headlineSmall,
                                ),
                                if (item.isDeleted)
                                  Padding(
                                    padding: const EdgeInsets.only(top: 8),
                                    child: Chip(
                                      label: const Text('Удалена'),
                                      backgroundColor:
                                          theme.colorScheme.errorContainer,
                                    ),
                                  ),
                                const SizedBox(height: 16),
                                for (final (label, value) in fields(item))
                                  _DetailRow(label: label, value: value),
                                if (extra != null) ...[
                                  const SizedBox(height: 16),
                                  extra!(context, item),
                                ],
                                const SizedBox(height: 16),
                                if (context.watch<AuthNotifier>().can(
                                  Op.editRecords,
                                ))
                                  FilledButton.icon(
                                    onPressed: () =>
                                        context.push('$listPath/$id/edit'),
                                    icon: const Icon(Icons.edit_outlined),
                                    label: const Text('Изменить'),
                                  ),
                              ],
                            ),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              Center(
                child: OutlinedButton.icon(
                  onPressed: () =>
                      context.canPop() ? context.pop() : context.go(listPath),
                  icon: const Icon(Icons.arrow_back),
                  label: const Text('К списку'),
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

/// Строка карточки записи. На узком окне метка 170 пикселей съедала половину
/// экрана, поэтому там метка и значение идут друг под другом.
class _DetailRow extends StatelessWidget {
  const _DetailRow({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final style = TextStyle(color: Theme.of(context).colorScheme.outline);
    final stacked = MediaQuery.sizeOf(context).width < Bp.compact;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: stacked
          ? Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label, style: style),
                Text(value),
              ],
            )
          : Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SizedBox(width: 170, child: Text(label, style: style)),
                Expanded(child: Text(value)),
              ],
            ),
    );
  }
}
