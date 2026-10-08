import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../models/catalog.dart';
import '../models/customer.dart';
import '../models/queries.dart';
import '../models/validators.dart';
import '../state/list_notifier.dart';
import '../widgets/entity_form.dart';
import '../widgets/entity_list_view.dart';
import '../widgets/entity_table.dart';
import '../widgets/field_spec.dart';
import '../widgets/form_options.dart';

class CustomerListScreen extends StatelessWidget {
  const CustomerListScreen({super.key, required this.query});

  final CustomerQuery query;

  @override
  Widget build(BuildContext context) {
    return OptionsLoader(
      builder: (context, o) {
        final cities = {for (final c in o.customers) c.city}.toList()..sort();
        return EntityListView<Customer, CustomerQuery>(
          title: 'Покупатели',
          basePath: '/customers',
          query: query,
          searchHint: 'Фамилия, почта или телефон',
          columns: [
            TableColumnSpec(
              label: 'Покупатель',
              sortField: 'name',
              build: (c) => cell(c.fullName),
            ),
            TableColumnSpec(label: 'Почта', build: (c) => cell(c.email)),
            TableColumnSpec(
              label: 'Телефон',
              build: (c) => cell(c.phone, maxWidth: 160),
            ),
            TableColumnSpec(
              label: 'Город',
              sortField: 'city',
              build: (c) => cell(c.city, maxWidth: 160),
            ),
            TableColumnSpec(
              label: 'Карта',
              build: (c) => Text(c.card?.level ?? 'нет'),
            ),
            TableColumnSpec(
              label: 'Бонусы',
              sortField: 'bonus',
              numeric: true,
              build: (c) => Text('${c.card?.bonusPoints ?? 0}'),
            ),
          ],
          cardTitle: (c) => c.fullName,
          cardSubtitle: (c) => '${c.email} · ${c.city}',
          filters: (q, apply) => [
            SizedBox(
              width: 170,
              child: DropdownButtonFormField<String?>(
                key: ValueKey(q.city),
                initialValue: q.city,
                isExpanded: true,
                decoration: const InputDecoration(
                  labelText: 'Город',
                  isDense: true,
                  border: OutlineInputBorder(),
                ),
                items: [
                  const DropdownMenuItem<String?>(child: Text('Все')),
                  for (final c in cities)
                    DropdownMenuItem<String?>(value: c, child: Text(c)),
                ],
                onChanged: (v) => apply(q.copyWith(city: v)),
              ),
            ),
          ],
        );
      },
    );
  }
}

class CustomerDetailScreen extends StatelessWidget {
  const CustomerDetailScreen({super.key, required this.id});

  final int id;

  @override
  Widget build(BuildContext context) {
    return EntityDetailView<Customer, CustomerQuery>(
      id: id,
      listPath: '/customers',
      title: (c) => c.fullName,
      fields: (c) => [
        ('Почта', c.email),
        ('Телефон', c.phone),
        ('Город', c.city),
        ('Карта лояльности', c.card == null ? 'не оформлена' : c.card!.number),
        if (c.card != null) ...[
          ('Уровень карты', c.card!.level),
          ('Бонусов', '${c.card!.bonusPoints}'),
          ('Карта выдана', formatDate(c.card!.issuedAt)),
        ],
      ],
      extra: (context, c) => TextButton.icon(
        onPressed: () => context.push('/orders?customerId=${c.id}'),
        icon: const Icon(Icons.receipt_long_outlined),
        label: const Text('Заказы покупателя'),
      ),
    );
  }
}

class CustomerFormScreen extends StatelessWidget {
  const CustomerFormScreen({super.key, this.id});

  final int? id;

  @override
  Widget build(BuildContext context) {
    final notifier = context.read<CustomerListNotifier>();
    return EntityFormScreen(
      id: id,
      title: 'покупателя',
      listPath: '/customers',
      load: (id) async {
        final c = await notifier.findById(id);
        if (c == null) return null;
        final values = FormValues()
          ..text.addAll({
            'firstName': c.firstName,
            'lastName': c.lastName,
            'email': c.email,
            'phone': c.phone,
            'city': c.city,
          });
        final card = c.card;
        if (card != null) {
          values.text.addAll({
            'cardNumber': card.number,
            'bonusPoints': '${card.bonusPoints}',
          });
          values.textChoice['cardLevel'] = card.level;
        }
        return values;
      },
      save: (v) async {
        final number = v.str('cardNumber');
        await notifier.save(
          Customer(
            id: id ?? 0,
            firstName: v.str('firstName'),
            lastName: v.str('lastName'),
            email: v.str('email'),
            phone: v.str('phone'),
            city: v.str('city'),
            card: number.isEmpty
                ? null
                : LoyaltyCard(
                    number: number,
                    level: v.option('cardLevel') ?? cardLevels.first,
                    bonusPoints: v.number('bonusPoints'),
                    issuedAt: DateTime.now(),
                  ),
          ),
        );
      },
      fields: (_) => [
        TextFieldSpec(
          name: 'lastName',
          label: 'Фамилия',
          validator: combine([notEmpty(), length(2, 40)]),
        ),
        TextFieldSpec(
          name: 'firstName',
          label: 'Имя',
          validator: combine([notEmpty(), length(2, 40)]),
        ),
        TextFieldSpec(
          name: 'email',
          label: 'Электронная почта',
          hint: 'name@example.com',
          validator: combine([notEmpty(), email()]),
        ),
        TextFieldSpec(
          name: 'phone',
          label: 'Телефон',
          hint: '+7 916 123-45-67',
          validator: combine([notEmpty(), phone()]),
        ),
        TextFieldSpec(
          name: 'city',
          label: 'Город',
          validator: combine([notEmpty(), length(2, 40)]),
        ),
        SectionSpec(
          name: 'card',
          label: 'Карта лояльности',
          optional: true,
          enabledLabel: 'Карта не оформлена',
          fields: [
            TextFieldSpec(
              name: 'cardNumber',
              label: 'Номер карты',
              hint: '10000001',
              numeric: true,
              validator: combine([notEmpty(), cardNumber()]),
            ),
            TextDropdownFieldSpec(
              name: 'cardLevel',
              label: 'Уровень',
              options: cardLevels,
              validator: (v) => v == null ? 'Выберите уровень карты' : null,
            ),
            TextFieldSpec(
              name: 'bonusPoints',
              label: 'Бонусных баллов',
              numeric: true,
              validator: combine([notEmpty(), intRange(0, 1000000)]),
            ),
          ],
        ),
      ],
    );
  }
}
