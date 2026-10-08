/// Точки перелома раскладки. Единственное место, где записаны эти числа:
/// виджеты спрашивают [layoutOf], а не сравнивают ширину сами.
///
/// | Ширина окна | Раскладка  | Что видно                                      |
/// | ----------- | ---------- | ---------------------------------------------- |
/// | до 600      | `compact`  | одна колонка, навигация снизу, списки карточками |
/// | 600–1023    | `medium`   | боковая полоса со значками, карточки в две колонки |
/// | 1024–1439   | `expanded` | таблицы, боковая полоса с подписями            |
/// | 1440 и шире | `large`    | то же, но содержимое ограничено по ширине      |
enum Layout {
  compact,
  medium,
  expanded,
  large;

  /// Таблица помещается только начиная с [expanded]; до этого — карточки.
  bool get showsTable => index >= Layout.expanded.index;

  /// Сколько колонок в сетке карточек.
  int get cardColumns => this == Layout.compact ? 1 : 2;
}

/// Границы в логических пикселях.
abstract final class Bp {
  static const compact = 600.0;
  static const medium = 1024.0;
  static const expanded = 1440.0;

  /// Предел ширины содержимого: на широком мониторе таблица не растягивается
  /// на весь экран, а остаётся читаемой полосой по центру.
  static const maxContent = 1400.0;
}

Layout layoutOf(double width) => switch (width) {
  < Bp.compact => Layout.compact,
  < Bp.medium => Layout.medium,
  < Bp.expanded => Layout.expanded,
  _ => Layout.large,
};
