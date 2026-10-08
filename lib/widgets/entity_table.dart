import 'package:flutter/material.dart';

class TableColumnSpec<T> {
  final String label;
  final String? sortField;
  final bool numeric;
  final Widget Function(T item) build;

  const TableColumnSpec({
    required this.label,
    required this.build,
    this.sortField,
    this.numeric = false,
  });
}

/// Текст ячейки таблицы. Длинное значение обрезается многоточием: иначе одна
/// запись растягивает всю таблицу и уводит её в горизонтальную прокрутку даже
/// на широком мониторе.
Widget cell(String text, {double maxWidth = 220, int maxLines = 1}) =>
    ConstrainedBox(
      constraints: BoxConstraints(maxWidth: maxWidth),
      child: Text(text, maxLines: maxLines, overflow: TextOverflow.ellipsis),
    );

class EntityTable<T> extends StatefulWidget {
  final List<TableColumnSpec<T>> columns;
  final List<T> items;
  final int Function(T item) idOf;
  final Set<int> selected;
  final ValueChanged<int>? onToggleSelect;
  final ValueChanged<bool>? onToggleAll;
  final String? sortField;
  final bool sortAscending;
  final void Function(String field)? onSort;
  final List<Widget> Function(T item)? actions;
  final bool Function(T item)? muted;
  final ValueChanged<T>? onTap;

  const EntityTable({
    super.key,
    required this.columns,
    required this.items,
    required this.idOf,
    this.selected = const {},
    this.onToggleSelect,
    this.onToggleAll,
    this.sortField,
    this.sortAscending = true,
    this.onSort,
    this.actions,
    this.muted,
    this.onTap,
  });

  @override
  State<EntityTable<T>> createState() => _EntityTableState<T>();
}

class _EntityTableState<T> extends State<EntityTable<T>> {
  final _vertical = ScrollController();
  final _horizontal = ScrollController();

  @override
  void dispose() {
    _vertical.dispose();
    _horizontal.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final w = widget;
    final sortIndex = w.columns.indexWhere(
      (c) => c.sortField != null && c.sortField == w.sortField,
    );
    final mutedColor = WidgetStatePropertyAll(
      Theme.of(context).colorScheme.errorContainer.withValues(alpha: 0.4),
    );

    final table = DataTable(
      sortColumnIndex: sortIndex < 0 ? null : sortIndex,
      sortAscending: w.sortAscending,
      showCheckboxColumn: w.onToggleSelect != null,
      onSelectAll: w.onToggleAll == null
          ? null
          : (v) => w.onToggleAll!(v ?? false),
      columns: [
        for (final c in w.columns)
          DataColumn(
            label: Text(c.label),
            numeric: c.numeric,
            onSort: c.sortField == null || w.onSort == null
                ? null
                : (_, _) => w.onSort!(c.sortField!),
          ),
        if (w.actions != null) const DataColumn(label: Text('Действия')),
      ],
      rows: [
        for (final item in w.items)
          DataRow(
            selected: w.selected.contains(w.idOf(item)),
            onSelectChanged: w.onToggleSelect == null
                ? null
                : (_) => w.onToggleSelect!(w.idOf(item)),
            color: w.muted?.call(item) ?? false ? mutedColor : null,
            cells: [
              for (final c in w.columns)
                DataCell(
                  c.build(item),
                  onTap: w.onTap == null ? null : () => w.onTap!(item),
                ),
              if (w.actions != null)
                DataCell(
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: w.actions!(item),
                  ),
                ),
            ],
          ),
      ],
    );

    // Двумерная прокрутка: вертикальная снаружи, горизонтальная внутри, у
    // каждой оси своя видимая полоса — иначе непонятно, что таблицу можно
    // двигать в сторону. Высоту области задаёт родитель (Expanded), поэтому
    // вертикальная прокрутка принадлежит самой таблице, а не всей странице.
    return LayoutBuilder(
      builder: (context, constraints) => Scrollbar(
        controller: _vertical,
        thumbVisibility: true,
        child: SingleChildScrollView(
          controller: _vertical,
          child: Scrollbar(
            controller: _horizontal,
            thumbVisibility: true,
            notificationPredicate: (n) => n.depth == 1,
            child: SingleChildScrollView(
              controller: _horizontal,
              scrollDirection: Axis.horizontal,
              child: ConstrainedBox(
                constraints: BoxConstraints(minWidth: constraints.maxWidth),
                child: table,
              ),
            ),
          ),
        ),
      ),
    );
  }
}
