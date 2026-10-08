import 'package:flutter/material.dart';

import '../core/breakpoints.dart';

class EntityCardList<T> extends StatelessWidget {
  final List<T> items;
  final int Function(T item) idOf;
  final String Function(T item) title;
  final String Function(T item) subtitle;
  final Set<int> selected;
  final ValueChanged<int>? onToggleSelect;
  final List<Widget> Function(T item)? actions;
  final bool Function(T item)? muted;
  final ValueChanged<T>? onTap;

  const EntityCardList({
    super.key,
    required this.items,
    required this.idOf,
    required this.title,
    required this.subtitle,
    this.selected = const {},
    this.onToggleSelect,
    this.actions,
    this.muted,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final mutedColor = Theme.of(context).colorScheme.errorContainer;
    const gap = 12.0;

    return LayoutBuilder(
      builder: (context, constraints) {
        final columns = layoutOf(constraints.maxWidth).cardColumns;
        final width = columns == 1
            ? constraints.maxWidth
            : (constraints.maxWidth - gap * (columns - 1)) / columns;
        return Wrap(
          spacing: gap,
          runSpacing: gap,
          children: [
            for (final item in items)
              SizedBox(
                width: width,
                child: Card(
                  margin: EdgeInsets.zero,
                  color: muted?.call(item) ?? false ? mutedColor : null,
                  child: ListTile(
                    leading: onToggleSelect == null
                        ? null
                        : Checkbox(
                            semanticLabel: 'Выбрать запись',
                            value: selected.contains(idOf(item)),
                            onChanged: (_) => onToggleSelect!(idOf(item)),
                          ),
                    // Без обрезки длинное название или текст отзыва
                    // разворачивает карточку в абзац на полэкрана.
                    title: Text(
                      title(item),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    subtitle: Text(
                      subtitle(item),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    onTap: onTap == null ? null : () => onTap!(item),
                    trailing: actions == null
                        ? null
                        : ConstrainedBox(
                            constraints: const BoxConstraints(maxWidth: 112),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: actions!(item),
                            ),
                          ),
                  ),
                ),
              ),
          ],
        );
      },
    );
  }
}
