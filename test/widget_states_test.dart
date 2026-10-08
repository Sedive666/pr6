import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shoe_store/models/app_user.dart';
import 'package:shoe_store/widgets/entity_card_list.dart';
import 'package:shoe_store/widgets/entity_table.dart';

import 'app_harness.dart';
import 'fake_api.dart';

/// Тесты виджетов: каждое состояние списка и формы проверяется так, как его
/// видит пользователь — по надписям и кнопкам на экране, а не по внутренним
/// полям состояния.
///
/// Экран брендов выбран потому, что его колонки не требуют справочников:
/// иначе индикатор загрузки справочников накладывался бы на индикатор
/// загрузки самого списка и тест проверял бы не то, что заявлено.
void main() {
  testWidgets('во время загрузки списка виден индикатор', (tester) async {
    final api = FakeApi()..gate = Completer<void>();
    await openApp(tester, api: api, settle: false);

    // Раздел подключён отложенно: первые кадры уходят на загрузку его кода,
    // после чего экран списка показывает свой индикатор.
    await tester.pump();
    await tester.pump();
    await tester.pump();
    expect(find.byType(CircularProgressIndicator), findsOneWidget);
    expect(find.text('Nike'), findsNothing);

    api.gate!.complete();
    api.gate = null;
    await tester.pumpAndSettle();

    expect(find.byType(CircularProgressIndicator), findsNothing);
    expect(find.text('Nike'), findsOneWidget);
  });

  testWidgets('пустой результат отличается от загрузки', (tester) async {
    await openApp(tester, location: '/brands?search=zzz');

    expect(find.text('Ничего не найдено'), findsOneWidget);
    expect(find.byType(CircularProgressIndicator), findsNothing);

    await tester.tap(find.text('Сбросить условия'));
    await tester.pumpAndSettle();
    expect(find.text('Nike'), findsOneWidget);
  });

  testWidgets('ошибка загрузки: сообщение и работающий повтор', (tester) async {
    final api = FakeApi()..failures = 1;
    await openApp(tester, api: api);

    expect(find.text('Ошибка загрузки'), findsOneWidget);
    expect(find.text('Ничего не найдено'), findsNothing);
    expect(find.text('Повторить'), findsOneWidget);
    expect(find.byIcon(Icons.refresh), findsOneWidget);

    await tester.tap(find.text('Повторить'));
    await tester.pumpAndSettle();

    expect(find.text('Ошибка загрузки'), findsNothing);
    expect(find.text('Nike'), findsOneWidget);
  });

  testWidgets('форма входа не отправляется с пустыми полями', (tester) async {
    await openApp(tester, role: null, location: '/login');

    await tester.tap(find.text('Войти'));
    await tester.pump();

    expect(find.text('Введите логин'), findsOneWidget);
    expect(find.text('Введите пароль'), findsOneWidget);
  });

  testWidgets('недоступные роли действия на экране не показываются', (
    tester,
  ) async {
    await openApp(tester, role: Role.client);
    expect(find.text('Добавить'), findsNothing);
    expect(find.text('Показывать удалённые'), findsNothing);
    expect(find.byTooltip('Изменить'), findsNothing);

    await openApp(tester, role: Role.manager);
    expect(find.text('Добавить'), findsOneWidget);
    expect(find.byTooltip('Изменить'), findsWidgets);
    expect(find.text('Показывать удалённые'), findsNothing);

    await openApp(tester, role: Role.admin);
    expect(find.text('Показывать удалённые'), findsOneWidget);
    expect(find.byTooltip('Удалить навсегда'), findsWidgets);
    expect(find.text('Добавить'), findsNothing);
  });

  testWidgets('раскладка перестраивается по ширине окна', (tester) async {
    await openApp(tester, size: const Size(360, 800));
    expect(find.byWidgetPredicate((w) => w is EntityCardList), findsOneWidget);
    expect(find.byType(NavigationBar), findsOneWidget);
    expect(find.byType(NavigationRail), findsNothing);

    await openApp(tester, size: const Size(1280, 900));
    expect(find.byWidgetPredicate((w) => w is EntityTable), findsOneWidget);
    expect(find.byType(NavigationRail), findsOneWidget);
    expect(find.byType(NavigationBar), findsNothing);
  });
}
