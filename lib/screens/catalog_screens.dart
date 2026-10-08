import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/brand.dart';
import '../models/category.dart';
import '../models/queries.dart';
import '../models/series.dart';
import '../models/validators.dart';
import '../state/list_notifier.dart';
import '../widgets/entity_form.dart';
import '../widgets/entity_list_view.dart';
import '../widgets/entity_table.dart';
import '../widgets/field_spec.dart';
import '../widgets/form_options.dart';
import '../widgets/list_controls.dart';
import '../widgets/lookup.dart';

class BrandListScreen extends StatelessWidget {
  const BrandListScreen({super.key, required this.query});

  final BrandQuery query;

  @override
  Widget build(BuildContext context) {
    return EntityListView<Brand, BrandQuery>(
      title: 'Бренды',
      basePath: '/brands',
      query: query,
      searchHint: 'Название или страна',
      columns: [
        TableColumnSpec(
          label: 'Бренд',
          sortField: 'name',
          build: (b) => cell(b.name),
        ),
        TableColumnSpec(
          label: 'Страна',
          sortField: 'country',
          build: (b) => cell(b.country, maxWidth: 160),
        ),
        TableColumnSpec(
          label: 'Год основания',
          sortField: 'year',
          numeric: true,
          build: (b) => Text('${b.foundedYear}'),
        ),
      ],
      cardTitle: (b) => b.name,
      cardSubtitle: (b) => '${b.country} · с ${b.foundedYear} г.',
    );
  }
}

class BrandDetailScreen extends StatelessWidget {
  const BrandDetailScreen({super.key, required this.id});

  final int id;

  @override
  Widget build(BuildContext context) {
    return EntityDetailView<Brand, BrandQuery>(
      id: id,
      listPath: '/brands',
      title: (b) => b.name,
      fields: (b) => [
        ('Страна', b.country),
        ('Год основания', '${b.foundedYear}'),
      ],
    );
  }
}

class BrandFormScreen extends StatelessWidget {
  const BrandFormScreen({super.key, this.id});

  final int? id;

  @override
  Widget build(BuildContext context) {
    final notifier = context.read<BrandListNotifier>();
    return EntityFormScreen(
      id: id,
      title: 'бренда',
      listPath: '/brands',
      load: (id) async {
        final b = await notifier.findById(id);
        if (b == null) return null;
        return FormValues()
          ..text.addAll({
            'name': b.name,
            'country': b.country,
            'foundedYear': '${b.foundedYear}',
          });
      },
      save: (v) => notifier.save(
        Brand(
          id: id ?? 0,
          name: v.str('name'),
          country: v.str('country'),
          foundedYear: v.number('foundedYear'),
        ),
      ),
      fields: (_) => [
        TextFieldSpec(
          name: 'name',
          label: 'Название бренда',
          validator: combine([notEmpty(), length(2, 40)]),
        ),
        TextFieldSpec(
          name: 'country',
          label: 'Страна',
          validator: combine([notEmpty(), length(2, 40)]),
        ),
        TextFieldSpec(
          name: 'foundedYear',
          label: 'Год основания',
          numeric: true,
          validator: combine([notEmpty(), intRange(1800, 2026)]),
        ),
      ],
    );
  }
}

class CategoryListScreen extends StatelessWidget {
  const CategoryListScreen({super.key, required this.query});

  final CategoryQuery query;

  @override
  Widget build(BuildContext context) {
    return EntityListView<Category, CategoryQuery>(
      title: 'Категории',
      basePath: '/categories',
      query: query,
      searchHint: 'Название или описание',
      columns: [
        TableColumnSpec(
          label: 'Категория',
          sortField: 'name',
          build: (c) => cell(c.name),
        ),
        TableColumnSpec(
          label: 'Описание',
          build: (c) => cell(c.description, maxWidth: 320, maxLines: 2),
        ),
      ],
      cardTitle: (c) => c.name,
      cardSubtitle: (c) => c.description,
    );
  }
}

class CategoryDetailScreen extends StatelessWidget {
  const CategoryDetailScreen({super.key, required this.id});

  final int id;

  @override
  Widget build(BuildContext context) {
    return EntityDetailView<Category, CategoryQuery>(
      id: id,
      listPath: '/categories',
      title: (c) => c.name,
      fields: (c) => [('Описание', c.description)],
    );
  }
}

class CategoryFormScreen extends StatelessWidget {
  const CategoryFormScreen({super.key, this.id});

  final int? id;

  @override
  Widget build(BuildContext context) {
    final notifier = context.read<CategoryListNotifier>();
    return EntityFormScreen(
      id: id,
      title: 'категории',
      listPath: '/categories',
      load: (id) async {
        final c = await notifier.findById(id);
        if (c == null) return null;
        return FormValues()
          ..text.addAll({'name': c.name, 'description': c.description});
      },
      save: (v) => notifier.save(
        Category(
          id: id ?? 0,
          name: v.str('name'),
          description: v.str('description'),
        ),
      ),
      fields: (_) => [
        TextFieldSpec(
          name: 'name',
          label: 'Название категории',
          validator: combine([notEmpty(), length(3, 40)]),
        ),
        TextFieldSpec(
          name: 'description',
          label: 'Описание',
          multiline: true,
          validator: length(0, 200),
        ),
      ],
    );
  }
}

class SeriesListScreen extends StatelessWidget {
  const SeriesListScreen({super.key, required this.query});

  final SeriesQuery query;

  @override
  Widget build(BuildContext context) {
    return OptionsLoader(
      builder: (context, o) => EntityListView<Series, SeriesQuery>(
        title: 'Линейки',
        basePath: '/series',
        query: query,
        searchHint: 'Название или страна',
        columns: [
          TableColumnSpec(
            label: 'Линейка',
            sortField: 'name',
            build: (s) => cell(s.name),
          ),
          TableColumnSpec(
            label: 'Бренд',
            build: (s) => cell(nameOf(o.brands, s.brandId, (b) => b.name)),
          ),
          TableColumnSpec(
            label: 'Страна',
            sortField: 'country',
            build: (s) => cell(s.country, maxWidth: 160),
          ),
          TableColumnSpec(
            label: 'Год запуска',
            sortField: 'year',
            numeric: true,
            build: (s) => Text('${s.launchYear}'),
          ),
        ],
        cardTitle: (s) => s.name,
        cardSubtitle: (s) =>
            '${nameOf(o.brands, s.brandId, (b) => b.name)} · ${s.country} · '
            'с ${s.launchYear} г.',
        filters: (q, apply) => [
          FilterDropdown<int>(
            label: 'Бренд',
            value: q.brandId,
            options: {for (final b in o.brands) b.id: b.name},
            onChanged: (v) => apply(q.copyWith(brandId: v)),
          ),
        ],
      ),
    );
  }
}

class SeriesDetailScreen extends StatelessWidget {
  const SeriesDetailScreen({super.key, required this.id});

  final int id;

  @override
  Widget build(BuildContext context) {
    return OptionsLoader(
      builder: (context, o) => EntityDetailView<Series, SeriesQuery>(
        id: id,
        listPath: '/series',
        title: (s) => s.name,
        fields: (s) => [
          ('Бренд', nameOf(o.brands, s.brandId, (b) => b.name)),
          ('Страна', s.country),
          ('Год запуска', '${s.launchYear}'),
        ],
      ),
    );
  }
}

class SeriesFormScreen extends StatelessWidget {
  const SeriesFormScreen({super.key, this.id});

  final int? id;

  @override
  Widget build(BuildContext context) {
    final notifier = context.read<SeriesListNotifier>();
    return OptionsLoader(
      builder: (context, o) => EntityFormScreen(
        id: id,
        title: 'линейки',
        listPath: '/series',
        load: (id) async {
          final s = await notifier.findById(id);
          if (s == null) return null;
          return FormValues()
            ..text.addAll({
              'name': s.name,
              'country': s.country,
              'launchYear': '${s.launchYear}',
            })
            ..choice['brandId'] = s.brandId;
        },
        save: (v) => notifier.save(
          Series(
            id: id ?? 0,
            name: v.str('name'),
            brandId: v.pick('brandId') ?? 0,
            country: v.str('country'),
            launchYear: v.number('launchYear'),
          ),
        ),
        fields: (_) => [
          TextFieldSpec(
            name: 'name',
            label: 'Название линейки',
            validator: combine([notEmpty(), length(2, 40)]),
          ),
          DropdownFieldSpec(
            name: 'brandId',
            label: 'Бренд',
            options: (_) => entriesOf(o.brands, (b) => b.id, (b) => b.name),
            validator: (v) => v == null ? 'Выберите бренд' : null,
          ),
          TextFieldSpec(
            name: 'country',
            label: 'Страна производства',
            validator: combine([notEmpty(), length(2, 40)]),
          ),
          TextFieldSpec(
            name: 'launchYear',
            label: 'Год запуска',
            numeric: true,
            validator: combine([notEmpty(), intRange(1900, 2026)]),
          ),
        ],
      ),
    );
  }
}
