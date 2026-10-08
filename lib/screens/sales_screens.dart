import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/catalog.dart';
import '../models/order.dart';
import '../models/queries.dart';
import '../models/review.dart';
import '../models/validators.dart';
import '../state/list_notifier.dart';
import '../widgets/entity_form.dart';
import '../widgets/entity_list_view.dart';
import '../widgets/entity_table.dart';
import '../widgets/field_spec.dart';
import '../widgets/form_options.dart';
import '../widgets/list_controls.dart';
import '../widgets/lookup.dart';

class OrderListScreen extends StatelessWidget {
  const OrderListScreen({super.key, required this.query});

  final OrderQuery query;

  @override
  Widget build(BuildContext context) {
    return OptionsLoader(
      builder: (context, o) => EntityListView<Order, OrderQuery>(
        title: 'Заказы',
        basePath: '/orders',
        query: query,
        searchHint: 'Номер заказа',
        columns: [
          TableColumnSpec(
            label: 'Номер',
            sortField: 'number',
            build: (x) => cell(x.number, maxWidth: 160),
          ),
          TableColumnSpec(
            label: 'Дата',
            sortField: 'date',
            build: (x) => Text(formatDate(x.createdAt)),
          ),
          TableColumnSpec(
            label: 'Покупатель',
            build: (x) =>
                cell(nameOf(o.customers, x.customerId, (c) => c.fullName)),
          ),
          TableColumnSpec(
            label: 'Модель',
            build: (x) => cell(nameOf(o.sneakers, x.sneakerId, (s) => s.name)),
          ),
          TableColumnSpec(
            label: 'Размер',
            numeric: true,
            build: (x) => Text('${x.size}'),
          ),
          TableColumnSpec(
            label: 'Кол-во',
            numeric: true,
            build: (x) => Text('${x.quantity}'),
          ),
          TableColumnSpec(
            label: 'Сумма, ₽',
            sortField: 'total',
            numeric: true,
            build: (x) => Text(formatPrice(x.total)),
          ),
          TableColumnSpec(
            label: 'Статус',
            build: (x) => cell(x.status, maxWidth: 140),
          ),
        ],
        cardTitle: (x) => '${x.number} · ${formatPrice(x.total)} ₽',
        cardSubtitle: (x) =>
            '${nameOf(o.customers, x.customerId, (c) => c.fullName)} · '
            '${x.status} · ${formatDate(x.createdAt)}',
        filters: (q, apply) => [
          SizedBox(
            width: 170,
            child: DropdownButtonFormField<String?>(
              key: ValueKey(q.status),
              initialValue: q.status,
              isExpanded: true,
              decoration: const InputDecoration(
                labelText: 'Статус',
                isDense: true,
                border: OutlineInputBorder(),
              ),
              items: [
                const DropdownMenuItem<String?>(child: Text('Все')),
                for (final s in orderStatuses)
                  DropdownMenuItem<String?>(value: s, child: Text(s)),
              ],
              onChanged: (v) => apply(q.copyWith(status: v)),
            ),
          ),
          FilterDropdown<int>(
            label: 'Покупатель',
            value: q.customerId,
            options: {for (final c in o.customers) c.id: c.fullName},
            onChanged: (v) => apply(q.copyWith(customerId: v)),
          ),
        ],
      ),
    );
  }
}

class OrderDetailScreen extends StatelessWidget {
  const OrderDetailScreen({super.key, required this.id});

  final int id;

  @override
  Widget build(BuildContext context) {
    return OptionsLoader(
      builder: (context, o) => EntityDetailView<Order, OrderQuery>(
        id: id,
        listPath: '/orders',
        title: (x) => 'Заказ ${x.number}',
        fields: (x) => [
          ('Дата', formatDate(x.createdAt)),
          ('Покупатель', nameOf(o.customers, x.customerId, (c) => c.fullName)),
          ('Модель', nameOf(o.sneakers, x.sneakerId, (s) => s.name)),
          ('Размер', '${x.size}'),
          ('Количество', '${x.quantity} пар'),
          ('Цена за пару', '${formatPrice(x.price)} ₽'),
          ('Сумма заказа', '${formatPrice(x.total)} ₽'),
          ('Статус', x.status),
        ],
      ),
    );
  }
}

class OrderFormScreen extends StatelessWidget {
  const OrderFormScreen({super.key, this.id});

  final int? id;

  @override
  Widget build(BuildContext context) {
    final notifier = context.read<OrderListNotifier>();
    return OptionsLoader(
      builder: (context, o) => EntityFormScreen(
        id: id,
        title: 'заказа',
        listPath: '/orders',
        load: (id) async {
          final x = await notifier.findById(id);
          if (x == null) return null;
          return FormValues()
            ..text.addAll({
              'number': x.number,
              'quantity': '${x.quantity}',
              'price': '${x.price}',
            })
            ..choice.addAll({
              'customerId': x.customerId,
              'sneakerId': x.sneakerId,
              'size': x.size,
            })
            ..textChoice['status'] = x.status;
        },
        save: (v) => notifier.save(
          Order(
            id: id ?? 0,
            number: v.str('number'),
            customerId: v.pick('customerId') ?? 0,
            sneakerId: v.pick('sneakerId') ?? 0,
            size: v.pick('size') ?? 0,
            quantity: v.number('quantity', 1),
            price: v.number('price'),
            status: v.option('status') ?? orderStatuses.first,
            createdAt: DateTime.now(),
          ),
        ),
        fields: (_) => [
          TextFieldSpec(
            name: 'number',
            label: 'Номер заказа',
            hint: 'ORD-1013',
            validator: combine([notEmpty(), length(4, 20)]),
          ),
          DropdownFieldSpec(
            name: 'customerId',
            label: 'Покупатель',
            options: (_) =>
                entriesOf(o.customers, (c) => c.id, (c) => c.fullName),
            validator: (v) => v == null ? 'Выберите покупателя' : null,
          ),
          DropdownFieldSpec(
            name: 'sneakerId',
            label: 'Модель',
            options: (_) => entriesOf(o.sneakers, (s) => s.id, (s) => s.name),
            validator: (v) => v == null ? 'Выберите модель' : null,
          ),
          DropdownFieldSpec(
            name: 'size',
            label: 'Размер',
            options: (_) => [for (final s in shoeSizes) DropdownEntry(s, '$s')],
            validator: (v) => v == null ? 'Выберите размер' : null,
          ),
          TextFieldSpec(
            name: 'quantity',
            label: 'Количество пар',
            numeric: true,
            validator: combine([notEmpty(), intRange(1, 100)]),
          ),
          TextFieldSpec(
            name: 'price',
            label: 'Цена за пару, ₽',
            numeric: true,
            validator: combine([notEmpty(), intRange(1, 1000000)]),
          ),
          TextDropdownFieldSpec(
            name: 'status',
            label: 'Статус',
            options: orderStatuses,
            validator: (v) => v == null ? 'Выберите статус' : null,
          ),
        ],
      ),
    );
  }
}

class ReviewListScreen extends StatelessWidget {
  const ReviewListScreen({super.key, required this.query});

  final ReviewQuery query;

  @override
  Widget build(BuildContext context) {
    return OptionsLoader(
      builder: (context, o) => EntityListView<Review, ReviewQuery>(
        title: 'Отзывы',
        basePath: '/reviews',
        query: query,
        searchHint: 'Текст отзыва',
        columns: [
          TableColumnSpec(
            label: 'Дата',
            sortField: 'date',
            build: (r) => Text(formatDate(r.createdAt)),
          ),
          TableColumnSpec(
            label: 'Покупатель',
            build: (r) =>
                cell(nameOf(o.customers, r.customerId, (c) => c.fullName)),
          ),
          TableColumnSpec(
            label: 'Модель',
            build: (r) => cell(nameOf(o.sneakers, r.sneakerId, (s) => s.name)),
          ),
          TableColumnSpec(
            label: 'Оценка',
            sortField: 'rating',
            numeric: true,
            build: (r) => Text('${r.rating} из 5'),
          ),
          TableColumnSpec(
            label: 'Отзыв',
            build: (r) => cell(r.text, maxWidth: 280, maxLines: 2),
          ),
        ],
        cardTitle: (r) =>
            '${nameOf(o.sneakers, r.sneakerId, (s) => s.name)} — ${r.rating} из 5',
        cardSubtitle: (r) => r.text,
        filters: (q, apply) => [
          FilterDropdown<int>(
            label: 'Оценка',
            value: q.rating,
            options: {for (var i = 5; i >= 1; i--) i: '$i'},
            onChanged: (v) => apply(q.copyWith(rating: v)),
          ),
          FilterDropdown<int>(
            label: 'Модель',
            value: q.sneakerId,
            options: {for (final s in o.sneakers) s.id: s.name},
            onChanged: (v) => apply(q.copyWith(sneakerId: v)),
          ),
        ],
      ),
    );
  }
}

class ReviewDetailScreen extends StatelessWidget {
  const ReviewDetailScreen({super.key, required this.id});

  final int id;

  @override
  Widget build(BuildContext context) {
    return OptionsLoader(
      builder: (context, o) => EntityDetailView<Review, ReviewQuery>(
        id: id,
        listPath: '/reviews',
        title: (r) => nameOf(o.sneakers, r.sneakerId, (s) => s.name),
        fields: (r) => [
          ('Покупатель', nameOf(o.customers, r.customerId, (c) => c.fullName)),
          ('Оценка', '${r.rating} из 5'),
          ('Дата', formatDate(r.createdAt)),
          ('Отзыв', r.text),
        ],
      ),
    );
  }
}

class ReviewFormScreen extends StatelessWidget {
  const ReviewFormScreen({super.key, this.id});

  final int? id;

  @override
  Widget build(BuildContext context) {
    final notifier = context.read<ReviewListNotifier>();
    return OptionsLoader(
      builder: (context, o) => EntityFormScreen(
        id: id,
        title: 'отзыва',
        listPath: '/reviews',
        load: (id) async {
          final r = await notifier.findById(id);
          if (r == null) return null;
          return FormValues()
            ..text['text'] = r.text
            ..choice.addAll({
              'customerId': r.customerId,
              'sneakerId': r.sneakerId,
              'rating': r.rating,
            });
        },
        save: (v) => notifier.save(
          Review(
            id: id ?? 0,
            customerId: v.pick('customerId') ?? 0,
            sneakerId: v.pick('sneakerId') ?? 0,
            rating: v.pick('rating') ?? 5,
            text: v.str('text'),
            createdAt: DateTime.now(),
          ),
        ),
        fields: (_) => [
          DropdownFieldSpec(
            name: 'customerId',
            label: 'Покупатель',
            options: (_) =>
                entriesOf(o.customers, (c) => c.id, (c) => c.fullName),
            validator: (v) => v == null ? 'Выберите покупателя' : null,
          ),
          DropdownFieldSpec(
            name: 'sneakerId',
            label: 'Модель',
            options: (_) => entriesOf(o.sneakers, (s) => s.id, (s) => s.name),
            validator: (v) => v == null ? 'Выберите модель' : null,
          ),
          DropdownFieldSpec(
            name: 'rating',
            label: 'Оценка',
            options: (_) => [
              for (var i = 5; i >= 1; i--) DropdownEntry(i, '$i из 5'),
            ],
            validator: (v) => v == null ? 'Поставьте оценку' : null,
          ),
          TextFieldSpec(
            name: 'text',
            label: 'Текст отзыва',
            multiline: true,
            validator: combine([notEmpty(), length(10, 500)]),
          ),
        ],
      ),
    );
  }
}
