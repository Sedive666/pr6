import 'dart:async';

import 'package:flutter/material.dart';

import '../models/list_query.dart';
import '../state/list_notifier.dart';

class SearchField extends StatefulWidget {
  const SearchField({
    super.key,
    required this.value,
    required this.hint,
    required this.onChanged,
    this.delay = const Duration(milliseconds: 400),
  });

  final String value;
  final String hint;
  final ValueChanged<String> onChanged;
  final Duration delay;

  @override
  State<SearchField> createState() => _SearchFieldState();
}

class _SearchFieldState extends State<SearchField> {
  late final _controller = TextEditingController(text: widget.value);
  late String _emitted = widget.value;
  Timer? _timer;

  @override
  void didUpdateWidget(SearchField old) {
    super.didUpdateWidget(old);
    if (widget.value != _emitted) {
      _emitted = widget.value;
      _controller.text = widget.value;
    }
  }

  @override
  void dispose() {
    _timer?.cancel();
    _controller.dispose();
    super.dispose();
  }

  void _emit(String text) {
    _timer?.cancel();
    _emitted = text;
    widget.onChanged(text);
  }

  void _onChanged(String text) {
    _timer?.cancel();
    _timer = Timer(widget.delay, () => _emit(text));
  }

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: _controller,
      onChanged: _onChanged,
      onSubmitted: _emit,
      decoration: InputDecoration(
        prefixIcon: const Icon(Icons.search),
        hintText: widget.hint,
        isDense: true,
        border: const OutlineInputBorder(),
        suffixIcon: IconButton(
          tooltip: 'Очистить',
          icon: const Icon(Icons.clear),
          onPressed: () {
            _controller.clear();
            _emit('');
          },
        ),
      ),
    );
  }
}

class FilterDropdown<V> extends StatelessWidget {
  const FilterDropdown({
    super.key,
    required this.label,
    required this.value,
    required this.options,
    required this.onChanged,
  });

  final String label;
  final V? value;
  final Map<V, String> options;
  final ValueChanged<V?> onChanged;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 170,
      child: DropdownButtonFormField<V?>(
        key: ValueKey(value),
        initialValue: value,
        isExpanded: true,
        decoration: InputDecoration(
          labelText: label,
          isDense: true,
          border: const OutlineInputBorder(),
        ),
        items: [
          DropdownMenuItem<V?>(value: null, child: const Text('Все')),
          for (final e in options.entries)
            DropdownMenuItem<V?>(value: e.key, child: Text(e.value)),
        ],
        onChanged: onChanged,
      ),
    );
  }
}

class PaginationBar extends StatelessWidget {
  const PaginationBar({
    super.key,
    required this.page,
    required this.totalPages,
    required this.total,
    required this.size,
    required this.onPage,
    required this.onSize,
  });

  final int page;
  final int totalPages;
  final int total;
  final int size;
  final ValueChanged<int> onPage;
  final ValueChanged<int> onSize;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 12),
      child: Wrap(
        alignment: WrapAlignment.spaceBetween,
        crossAxisAlignment: WrapCrossAlignment.center,
        spacing: 16,
        runSpacing: 8,
        children: [
          Text('Всего записей: $total'),
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              IconButton(
                tooltip: 'Первая',
                visualDensity: VisualDensity.compact,
                icon: const Icon(Icons.first_page),
                onPressed: page > 1 ? () => onPage(1) : null,
              ),
              IconButton(
                tooltip: 'Предыдущая',
                visualDensity: VisualDensity.compact,
                icon: const Icon(Icons.chevron_left),
                onPressed: page > 1 ? () => onPage(page - 1) : null,
              ),
              // Подпись сжимаема, а кнопки уплотнены: иначе на окне шириной
              // 360 эта строка переполняется на два десятка пикселей.
              Flexible(
                child: Text(
                  'Стр. $page из $totalPages',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              IconButton(
                tooltip: 'Следующая',
                visualDensity: VisualDensity.compact,
                icon: const Icon(Icons.chevron_right),
                onPressed: page < totalPages ? () => onPage(page + 1) : null,
              ),
              IconButton(
                tooltip: 'Последняя',
                visualDensity: VisualDensity.compact,
                icon: const Icon(Icons.last_page),
                onPressed: page < totalPages ? () => onPage(totalPages) : null,
              ),
            ],
          ),
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Flexible(child: Text('На странице: ')),
              DropdownButton<int>(
                value: size,
                items: [
                  for (final s in pageSizes)
                    DropdownMenuItem(value: s, child: Text('$s')),
                ],
                onChanged: (v) {
                  if (v != null) onSize(v);
                },
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class ListStateView extends StatelessWidget {
  const ListStateView({
    super.key,
    required this.status,
    required this.error,
    required this.hasItems,
    required this.onRetry,
    required this.onReset,
    required this.child,
    this.expand = false,
  });

  final LoadStatus status;
  final String? error;
  final bool hasItems;
  final VoidCallback onRetry;
  final VoidCallback onReset;
  final Widget child;

  /// `true`, когда область данных занимает остаток высоты (режим таблицы):
  /// тогда прокрутка принадлежит таблице, а сообщения центрируются.
  final bool expand;

  Widget _fit(Widget message) =>
      expand ? Center(child: SingleChildScrollView(child: message)) : message;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    if (status == LoadStatus.error) {
      return _fit(
        _Message(
          icon: Icons.cloud_off,
          color: colors.error,
          title: 'Ошибка загрузки',
          text: error ?? '',
          action: FilledButton.icon(
            onPressed: onRetry,
            icon: const Icon(Icons.refresh),
            label: const Text('Повторить'),
          ),
        ),
      );
    }
    if (!hasItems && status != LoadStatus.success) {
      return _fit(
        const Padding(
          padding: EdgeInsets.all(48),
          child: Center(child: CircularProgressIndicator()),
        ),
      );
    }
    if (!hasItems) {
      return _fit(
        _Message(
          icon: Icons.search_off,
          color: colors.outline,
          title: 'Ничего не найдено',
          text: 'Под выбранные условия не подходит ни одна запись',
          action: OutlinedButton.icon(
            onPressed: onReset,
            icon: const Icon(Icons.filter_alt_off_outlined),
            label: const Text('Сбросить условия'),
          ),
        ),
      );
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SizedBox(
          height: 4,
          child: status == LoadStatus.loading
              ? const LinearProgressIndicator()
              : null,
        ),
        if (expand) Expanded(child: child) else child,
      ],
    );
  }
}

class _Message extends StatelessWidget {
  const _Message({
    required this.icon,
    required this.color,
    required this.title,
    required this.text,
    required this.action,
  });

  final IconData icon;
  final Color color;
  final String title;
  final String text;
  final Widget action;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 48, horizontal: 16),
      child: Column(
        children: [
          Icon(icon, size: 64, color: color, semanticLabel: title),
          const SizedBox(height: 12),
          Text(title, style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: 8),
          Text(text, textAlign: TextAlign.center),
          const SizedBox(height: 16),
          action,
        ],
      ),
    );
  }
}
