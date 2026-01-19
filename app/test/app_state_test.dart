import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:linkweb/src/core/app_state.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('AppState loads defaults and persists changes', () async {
    SharedPreferences.setMockInitialValues(<String, Object>{});
    final state = await AppState.load();

    expect(state.appTitle, 'LinkWeb');
    expect(state.themeMode, ThemeMode.system);

    await state.setAppTitle('My App');
    await state.setThemeMode(ThemeMode.dark);

    final state2 = await AppState.load();
    expect(state2.appTitle, 'My App');
    expect(state2.themeMode, ThemeMode.dark);
  });

  test('Bookmarks toggle works', () async {
    SharedPreferences.setMockInitialValues(<String, Object>{});
    final state = await AppState.load();

    await state.toggleBookmark(url: 'example.com', title: 'Example');
    expect(state.bookmarks.length, 1);

    await state.toggleBookmark(url: 'https://example.com', title: 'Example');
    expect(state.bookmarks.isEmpty, true);
  });
}
