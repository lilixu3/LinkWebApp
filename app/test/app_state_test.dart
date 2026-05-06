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
    expect(state.isConfigured, false);
    expect(state.orientationLock, OrientationLock.followSystem);

    await state.setAppTitle('My App');
    await state.setThemeMode(ThemeMode.dark);
    await state.saveInitialSetup(
      appTitle: 'My App',
      homeUrl: 'example.com',
      orientationLock: OrientationLock.landscape,
    );

    final state2 = await AppState.load();
    expect(state2.appTitle, 'My App');
    expect(state2.themeMode, ThemeMode.dark);
    expect(state2.isConfigured, true);
    expect(state2.homeUrl, 'https://example.com');
    expect(state2.launchUrl, 'https://example.com');
    expect(state2.orientationLock, OrientationLock.landscape);
  });

  test('Bookmarks toggle works', () async {
    SharedPreferences.setMockInitialValues(<String, Object>{});
    final state = await AppState.load();

    await state.toggleBookmark(url: 'example.com', title: 'Example');
    expect(state.bookmarks.length, 1);

    await state.toggleBookmark(url: 'https://example.com', title: 'Example');
    expect(state.bookmarks.isEmpty, true);
  });
  test('Last opened URL is persisted and can restore after restart', () async {
    SharedPreferences.setMockInitialValues(<String, Object>{});
    final state = await AppState.load();

    await state.saveInitialSetup(appTitle: 'LinkWeb', homeUrl: 'https://home.example');
    await state.rememberOpenedUrl('https://page.example/path');

    final state2 = await AppState.load();
    expect(state2.resumeLastUrl, true);
    expect(state2.homeUrl, 'https://home.example');
    expect(state2.lastUrl, 'https://page.example/path');
    expect(state2.launchUrl, 'https://page.example/path');

    await state2.setResumeLastUrl(false);
    final state3 = await AppState.load();
    expect(state3.launchUrl, 'https://home.example');
  });
}
