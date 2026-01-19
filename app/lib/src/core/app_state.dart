import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/bookmark.dart';
import 'url_utils.dart';

enum EffectType { none, snow, sakura }

class AppState extends ChangeNotifier {
  static const _kHomeUrl = 'home_url';
  static const _kThemeMode = 'theme_mode';
  static const _kEffect = 'effect_type';
  static const _kAppTitle = 'app_title';
  static const _kUrlHistory = 'url_history';
  static const _kBookmarks = 'bookmarks_v1';
  static const _kDesktopMode = 'desktop_mode';
  static const _kJavascriptEnabled = 'javascript_enabled';
  static const _kMaxHistory = 25;

  final SharedPreferences _prefs;

  AppState._(this._prefs) {
    _homeUrl = _prefs.getString(_kHomeUrl) ?? UrlUtils.fallback;
    _themeMode = ThemeMode.values[_prefs.getInt(_kThemeMode) ?? ThemeMode.system.index];
    _effect = EffectType.values[_prefs.getInt(_kEffect) ?? EffectType.none.index];
    _appTitle = _prefs.getString(_kAppTitle) ?? 'LinkWeb';
    _urlHistory = _prefs.getStringList(_kUrlHistory) ?? <String>[];
    _desktopMode = _prefs.getBool(_kDesktopMode) ?? false;
    _javascriptEnabled = _prefs.getBool(_kJavascriptEnabled) ?? true;

    final rawBookmarks = _prefs.getStringList(_kBookmarks) ?? <String>[];
    _bookmarks = rawBookmarks
        .map((e) {
          try {
            return Bookmark.fromJson(e);
          } catch (_) {
            return null;
          }
        })
        .whereType<Bookmark>()
        .toList();
  }

  static Future<AppState> load() async {
    final prefs = await SharedPreferences.getInstance();
    return AppState._(prefs);
  }

  late String _homeUrl;
  late ThemeMode _themeMode;
  late EffectType _effect;
  late String _appTitle;
  late List<String> _urlHistory;
  late List<Bookmark> _bookmarks;
  late bool _desktopMode;
  late bool _javascriptEnabled;

  String get homeUrl => _homeUrl;
  ThemeMode get themeMode => _themeMode;
  EffectType get effect => _effect;
  String get appTitle => _appTitle;
  List<String> get urlHistory => List.unmodifiable(_urlHistory);
  List<Bookmark> get bookmarks => List.unmodifiable(_bookmarks);
  bool get desktopMode => _desktopMode;
  bool get javascriptEnabled => _javascriptEnabled;

  Future<void> setHomeUrl(String url) async {
    _homeUrl = UrlUtils.normalize(url);
    await _prefs.setString(_kHomeUrl, _homeUrl);
    _addToHistory(_homeUrl);
    notifyListeners();
  }

  Future<void> setThemeMode(ThemeMode mode) async {
    _themeMode = mode;
    await _prefs.setInt(_kThemeMode, mode.index);
    notifyListeners();
  }

  Future<void> setEffect(EffectType type) async {
    _effect = type;
    await _prefs.setInt(_kEffect, type.index);
    notifyListeners();
  }

  Future<void> setAppTitle(String title) async {
    final t = title.trim();
    _appTitle = t.isEmpty ? 'LinkWeb' : t;
    await _prefs.setString(_kAppTitle, _appTitle);
    notifyListeners();
  }

  Future<void> setDesktopMode(bool enabled) async {
    _desktopMode = enabled;
    await _prefs.setBool(_kDesktopMode, enabled);
    notifyListeners();
  }

  Future<void> setJavascriptEnabled(bool enabled) async {
    _javascriptEnabled = enabled;
    await _prefs.setBool(_kJavascriptEnabled, enabled);
    notifyListeners();
  }

  void _addToHistory(String url) {
    _urlHistory.remove(url);
    _urlHistory.insert(0, url);
    if (_urlHistory.length > _kMaxHistory) {
      _urlHistory = _urlHistory.sublist(0, _kMaxHistory);
    }
    _prefs.setStringList(_kUrlHistory, _urlHistory);
  }

  Future<void> clearHistory() async {
    _urlHistory.clear();
    await _prefs.setStringList(_kUrlHistory, <String>[]);
    notifyListeners();
  }

  bool isBookmarked(String url) {
    return _bookmarks.any((b) => b.url == url);
  }

  Future<void> toggleBookmark({required String url, required String title}) async {
    final normalized = UrlUtils.normalize(url);
    final idx = _bookmarks.indexWhere((b) => b.url == normalized);
    if (idx >= 0) {
      _bookmarks.removeAt(idx);
    } else {
      _bookmarks.insert(
        0,
        Bookmark(
          url: normalized,
          title: title.trim().isEmpty ? normalized : title.trim(),
          createdAt: DateTime.now(),
        ),
      );
    }
    await _saveBookmarks();
    notifyListeners();
  }

  Future<void> removeBookmark(String url) async {
    _bookmarks.removeWhere((b) => b.url == url);
    await _saveBookmarks();
    notifyListeners();
  }

  Future<void> clearBookmarks() async {
    _bookmarks.clear();
    await _saveBookmarks();
    notifyListeners();
  }

  Future<void> _saveBookmarks() async {
    final list = _bookmarks.map((b) => b.toJson()).toList();
    await _prefs.setStringList(_kBookmarks, list);
  }

  /// Export settings as a JSON string (for backup/migration).
  String exportAsJson() {
    final map = <String, dynamic>{
      _kHomeUrl: _homeUrl,
      _kThemeMode: _themeMode.index,
      _kEffect: _effect.index,
      _kAppTitle: _appTitle,
      _kUrlHistory: _urlHistory,
      _kBookmarks: _bookmarks.map((b) => b.toMap()).toList(),
      _kDesktopMode: _desktopMode,
      _kJavascriptEnabled: _javascriptEnabled,
    };
    return jsonEncode(map);
  }
}
