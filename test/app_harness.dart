import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:shoe_store/core/auth_api.dart';
import 'package:shoe_store/main.dart';
import 'package:shoe_store/models/app_user.dart';
import 'package:shoe_store/router.dart';
import 'package:shoe_store/state/auth_notifier.dart';

import 'fake_api.dart';

/// Учебные пользователи для каждой роли.
const testUsers = {
  Role.client: AppUser(
    id: 3,
    login: 'client',
    name: 'Покупатель',
    role: Role.client,
    customerId: 1,
  ),
  Role.manager: AppUser(
    id: 2,
    login: 'manager',
    name: 'Менеджер',
    role: Role.manager,
  ),
  Role.admin: AppUser(
    id: 1,
    login: 'admin',
    name: 'Администратор',
    role: Role.admin,
  ),
};

/// Что получилось у теста в руках после [openApp].
typedef TestHandles = ({AuthNotifier auth, FakeApi api});

/// Собирает приложение целиком на подменённом транспорте Dio.
///
/// `role: null` — не вошедший пользователь: так проверяются экраны входа и
/// перенаправления. Размер окна задаётся явно, потому что от него зависит
/// раскладка: до 600 — карточки и нижняя панель, от 1024 — таблицы и
/// боковая полоса.
Future<TestHandles> openApp(
  WidgetTester tester, {
  Role? role = Role.manager,
  String location = '/brands',
  FakeApi? api,
  Size size = const Size(1400, 2600),
  bool settle = true,
}) async {
  SharedPreferences.setMockInitialValues({});
  final prefs = await SharedPreferences.getInstance();
  final auth = role == null
      ? AuthNotifier(prefs, AuthApi())
      : AuthNotifier.signedIn(prefs, AuthApi(), testUsers[role]!);
  final fake = api ?? FakeApi();

  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);

  await tester.pumpWidget(
    ShoeStoreApp(
      auth: auth,
      dio: fakeDio(fake),
      router: createRouter(auth, initialLocation: location),
    ),
  );
  if (settle) await tester.pumpAndSettle();
  return (auth: auth, api: fake);
}
