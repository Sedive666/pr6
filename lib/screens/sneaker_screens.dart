import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../models/catalog.dart';
import '../models/queries.dart';
import '../models/sneaker.dart';
import '../models/validators.dart';
import '../repositories/entity_repository.dart';
import '../state/list_notifier.dart';
import '../widgets/entity_form.dart';
import '../widgets/entity_list_view.dart';
import '../widgets/entity_table.dart';
import '../widgets/field_spec.dart';
import '../widgets/form_options.dart';
import '../widgets/list_controls.dart';
import '../widgets/lookup.dart';

class SneakerListScreen extends StatelessWidget {
  const SneakerListScreen({super.key, required this.query});

  final SneakerQuery query;

  @override
  Widget build(BuildContext context) {
    return OptionsLoader(
      builder: (context, o) => EntityListView<Sneaker, SneakerQuery>(
        title: 'Кроссовки',
        basePath: '/sneakers',
        query: query,
        searchHint: 'Название или артикул',
        columns: [
          TableColumnSpec(
            label: 'Модель',
            sortField: 'name',
            build: (s) => cell(s.name),
          ),
          TableColumnSpec(
            label: 'Артикул',
            build: (s) => cell(s.sku, maxWidth: 140),
          ),
          TableColumnSpec(
            label: 'Бренд',
            build: (s) => cell(nameOf(o.brands, s.brandId, (b) => b.name)),
          ),
          TableColumnSpec(
            label: 'Категории',
            build: (s) => cell(
              namesOf(o.categories, s.categoryIds, (c) => c.name),
              maxWidth: 240,
            ),
          ),
          TableColumnSpec(
            label: 'Год',
            sortField: 'year',
            numeric: true,
            build: (s) => Text('${s.year}'),
          ),
          TableColumnSpec(
            label: 'Цена, ₽',
            sortField: 'price',
            numeric: true,
            build: (s) => Text(formatPrice(s.price)),
          ),
          TableColumnSpec(
            label: 'В наличии',
            sortField: 'stock',
            numeric: true,
            build: (s) => Text('${s.stockAvailable} из ${s.stockTotal}'),
          ),
        ],
        cardTitle: (s) => s.name,
        cardSubtitle: (s) =>
            '${nameOf(o.brands, s.brandId, (b) => b.name)} · ${s.sku} · '
            '${s.year} г. · ${formatPrice(s.price)} ₽',
        filters: (q, apply) => [
          FilterDropdown<int>(
            label: 'Бренд',
            value: q.brandId,
            options: {for (final b in o.brands) b.id: b.name},
            onChanged: (v) => apply(q.copyWith(brandId: v, seriesId: null)),
          ),
          FilterDropdown<int>(
            label: 'Линейка',
            value: q.seriesId,
            options: {
              for (final s in o.series)
                if (q.brandId == null || s.brandId == q.brandId) s.id: s.name,
            },
            onChanged: (v) => apply(q.copyWith(seriesId: v)),
          ),
          FilterDropdown<int>(
            label: 'Категория',
            value: q.categoryId,
            options: {for (final c in o.categories) c.id: c.name},
            onChanged: (v) => apply(q.copyWith(categoryId: v)),
          ),
          FilterDropdown<int>(
            label: 'Год от',
            value: q.yearFrom,
            options: {for (var y = 2017; y <= 2026; y++) y: '$y'},
            onChanged: (v) => apply(q.copyWith(yearFrom: v)),
          ),
          FilterDropdown<int>(
            label: 'Год до',
            value: q.yearTo,
            options: {for (var y = 2017; y <= 2026; y++) y: '$y'},
            onChanged: (v) => apply(q.copyWith(yearTo: v)),
          ),
        ],
      ),
    );
  }
}

class SneakerDetailScreen extends StatelessWidget {
  const SneakerDetailScreen({super.key, required this.id});

  final int id;

  @override
  Widget build(BuildContext context) {
    return OptionsLoader(
      builder: (context, o) => EntityDetailView<Sneaker, SneakerQuery>(
        id: id,
        listPath: '/sneakers',
        title: (s) => s.name,
        fields: (s) => [
          ('Артикул', s.sku),
          ('Бренд', nameOf(o.brands, s.brandId, (b) => b.name)),
          ('Линейки', namesOf(o.series, s.seriesIds, (e) => e.name)),
          ('Категории', namesOf(o.categories, s.categoryIds, (c) => c.name)),
          ('Год выпуска', '${s.year}'),
          ('Цена', '${formatPrice(s.price)} ₽'),
          ('В наличии', '${s.stockAvailable} пар из ${s.stockTotal}'),
        ],
        extra: (context, s) => TextButton.icon(
          onPressed: () => context.push('/reviews?sneakerId=${s.id}'),
          icon: const Icon(Icons.reviews_outlined),
          label: const Text('Отзывы на модель'),
        ),
      ),
    );
  }
}

class SneakerFormScreen extends StatelessWidget {
  const SneakerFormScreen({super.key, this.id});

  final int? id;

  @override
  Widget build(BuildContext context) {
    final notifier = context.read<SneakerListNotifier>();
    return OptionsLoader(
      builder: (context, o) => EntityFormScreen(
        id: id,
        title: 'кроссовки',
        listPath: '/sneakers',
        load: (id) async {
          final s = await notifier.findById(id);
          if (s == null) return null;
          return FormValues()
            ..text.addAll({
              'name': s.name,
              'sku': s.sku,
              'year': '${s.year}',
              'price': '${s.price}',
              'stockTotal': '${s.stockTotal}',
              'stockAvailable': '${s.stockAvailable}',
            })
            ..choice['brandId'] = s.brandId
            ..multi['seriesIds'] = [...s.seriesIds]
            ..multi['categoryIds'] = [...s.categoryIds];
        },
        save: (v) async {
          final total = v.number('stockTotal');
          final available = v.number('stockAvailable');
          if (available > total) {
            throw const FieldException(
              'stockAvailable',
              'Не может превышать общее количество',
            );
          }
          await notifier.save(
            Sneaker(
              id: id ?? 0,
              name: v.str('name'),
              sku: v.str('sku'),
              year: v.number('year'),
              price: v.number('price'),
              brandId: v.pick('brandId') ?? 0,
              seriesIds: v.list('seriesIds'),
              categoryIds: v.list('categoryIds'),
              stockTotal: total,
              stockAvailable: available,
            ),
          );
        },
        fields: (values) => [
          TextFieldSpec(
            name: 'name',
            label: 'Название модели',
            hint: 'Nike Air Max 90',
            validator: combine([notEmpty(), length(3, 80)]),
          ),
          TextFieldSpec(
            name: 'sku',
            label: 'Артикул',
            hint: 'CN8490-002',
            validator: combine([notEmpty(), sku()]),
          ),
          DropdownFieldSpec(
            name: 'brandId',
            label: 'Бренд',
            options: (_) => entriesOf(o.brands, (b) => b.id, (b) => b.name),
            validator: (v) => v == null ? 'Выберите бренд' : null,
          ),
          MultiSelectFieldSpec(
            name: 'seriesIds',
            label: 'Линейки',
            hint: 'Сначала выберите бренд',
            dependsOn: 'brandId',
            options: (_) => entriesOf(
              o.series,
              (s) => s.id,
              (s) => s.name,
              group: (s) => s.brandId,
            ),
            filter: (vals, e) =>
                vals.pick('brandId') == null || e.group == vals.pick('brandId'),
            validator: (v) =>
                v.isEmpty ? 'Выберите хотя бы одну линейку' : null,
          ),
          MultiSelectFieldSpec(
            name: 'categoryIds',
            label: 'Категории',
            options: (_) => entriesOf(o.categories, (c) => c.id, (c) => c.name),
            validator: (v) =>
                v.isEmpty ? 'Выберите хотя бы одну категорию' : null,
          ),
          TextFieldSpec(
            name: 'year',
            label: 'Год выпуска',
            numeric: true,
            validator: combine([notEmpty(), intRange(1970, 2026)]),
          ),
          TextFieldSpec(
            name: 'price',
            label: 'Цена, ₽',
            numeric: true,
            validator: combine([notEmpty(), intRange(1, 1000000)]),
          ),
          TextFieldSpec(
            name: 'stockTotal',
            label: 'Всего пар',
            numeric: true,
            validator: combine([notEmpty(), intRange(0, 10000)]),
          ),
          TextFieldSpec(
            name: 'stockAvailable',
            label: 'Доступно пар',
            numeric: true,
            validator: combine([notEmpty(), intRange(0, 10000)]),
          ),
        ],
      ),
    );
  }
}
