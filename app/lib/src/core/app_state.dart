import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/bookmark.dart';
import 'url_utils.dart';

enum EffectType { none, snow, sakura }

enum OrientationLock { followSystem, portrait, landscape, autoRotate }

extension OrientationLockText on OrientationLock {
  String get label {
    switch (this) {
      case OrientationLock.followSystem:
        return '跟随系统';
      case OrientationLock.portrait:
        return '锁定竖屏';
      case OrientationLock.landscape:
        return '锁定横屏';
      case OrientationLock.autoRotate:
        return '允许旋转';
    }
  }

  String get description {
    switch (this) {
      case OrientationLock.followSystem:
        return '不强行改系统方向，按设备当前设置显示。';
      case OrientationLock.portrait:
        return '始终竖屏运行，适合大多数网页 App。';
      case OrientationLock.landscape:
        return '始终横屏运行，适合看板、视频和大屏页面。';
      case OrientationLock.autoRotate:
        return '允许横竖屏自动切换，不被旧逻辑固定成竖屏。';
    }
  }
}

class AppState extends ChangeNotifier {
  static const _kConfigured = 'configured_v2';
  static const _kHomeUrl = 'home_url';
  static const _kLastUrl = 'last_url';
  static const _kResumeLastUrl = 'resume_last_url';
  static const _kThemeMode = 'theme_mode';
  static const _kEffect = 'effect_type';
  static const _kAppTitle = 'app_title';
  static const _kUrlHistory = 'url_history';
  static const _kBookmarks = 'bookmarks_v1';
  static const _kDesktopMode = 'desktop_mode';
  static const _kJavascriptEnabled = 'javascript_enabled';
  static const _kOrientationLock = 'orientation_lock';
  static const _kFullscreenLandscape = 'fullscreen_landscape';
  static const _kMaxHistory = 50;

  final SharedPreferences _prefs;

  AppState._(this._prefs) {
    _configured = _prefs.getBool(_kConfigured) ?? _prefs.containsKey(_kHomeUrl);
    _homeUrl = _prefs.getString(_kHomeUrl) ?? '';
    _lastUrl = _prefs.getString(_kLastUrl) ?? '';
    _resumeLastUrl = _prefs.getBool(_kResumeLastUrl) ?? true;
    _themeMode = _readEnum(ThemeMode.values, _prefs.getInt(_kThemeMode), ThemeMode.system);
    _effect = _readEnum(EffectType.values, _prefs.getInt(_kEffect), EffectType.none);
    _orientationLock = _readEnum(
      OrientationLock.values,
      _prefs.getInt(_kOrientationLock),
      OrientationLock.followSystem,
    );
    _appTitle = (_prefs.getString(_kAppTitle) ?? 'LinkWeb').trim();
    if (_appTitle.isEmpty) _appTitle = 'LinkWeb';
    _urlHistory = _prefs.getStringList(_kUrlHistory) ?? <String>[];
    _desktopMode = _prefs.getBool(_kDesktopMode) ?? false;
    _javascriptEnabled = _prefs.getBool(_kJavascriptEnabled) ?? true;
    _fullscreenLandscape = _prefs.getBool(_kFullscreenLandscape) ?? true;

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

  static T _readEnum<T>(List<T> values, int? index, T fallback) {
    if (index == null || index < 0 || index >= values.length) return fallback;
    return values[index];
  }

  static Future<AppState> load() async {
    final prefs = await SharedPreferences.getInstance();
    return AppState._(prefs);
  }

  late bool _configured;
  late String _homeUrl;
  late String _lastUrl;
  late bool _resumeLastUrl;
  late ThemeMode _themeMode;
  late EffectType _effect;
  late OrientationLock _orientationLock;
  late String _appTitle;
  late List<String> _urlHistory;
  late List<Bookmark> _bookmarks;
  late bool _desktopMode;
  late bool _javascriptEnabled;
  late bool _fullscreenLandscape;

  bool get isConfigured => _configured && _homeUrl.trim().isNotEmpty;
  String get homeUrl => _homeUrl;
  String get lastUrl => _lastUrl;
  bool get resumeLastUrl => _resumeLastUrl;
  ThemeMode get themeMode => _themeMode;
  EffectType get effect => _effect;
  OrientationLock get orientationLock => _orientationLock;
  String get appTitle => _appTitle;
  List<String> get urlHistory => List.unmodifiable(_urlHistory);
  List<Bookmark> get bookmarks => List.unmodifiable(_bookmarks);
  bool get desktopMode => _desktopMode;
  bool get javascriptEnabled => _javascriptEnabled;
  bool get fullscreenLandscape => _fullscreenLandscape;

  String get launchUrl {
    if (_resumeLastUrl && _lastUrl.trim().isNotEmpty) return _lastUrl;
    if (_homeUrl.trim().isNotEmpty) return _homeUrl;
    return UrlUtils.fallback;
  }

  Future<void> saveInitialSetup({
    required String appTitle,
    required String homeUrl,
    OrientationLock? orientationLock,
    bool? desktopMode,
    bool? javascriptEnabled,
    bool? resumeLastUrl,
  }) async {
    final normalized = _requireUrl(homeUrl);
    _configured = true;
    _appTitle = _normalizeTitle(appTitle);
    _homeUrl = normalized;
    _lastUrl = normalized;
    if (orientationLock != null) _orientationLock = orientationLock;
    if (desktopMode != null) _desktopMode = desktopMode;
    if (javascriptEnabled != null) _javascriptEnabled = javascriptEnabled;
    if (resumeLastUrl != null) _resumeLastUrl = resumeLastUrl;

    await Future.wait([
      _prefs.setBool(_kConfigured, true),
      _prefs.setString(_kAppTitle, _appTitle),
      _prefs.setString(_kHomeUrl, _homeUrl),
      _prefs.setString(_kLastUrl, _lastUrl),
      _prefs.setInt(_kOrientationLock, _orientationLock.index),
      _prefs.setBool(_kDesktopMode, _desktopMode),
      _prefs.setBool(_kJavascriptEnabled, _javascriptEnabled),
      _prefs.setBool(_kResumeLastUrl, _resumeLastUrl),
    ]);
    await _addToHistory(_homeUrl);
    notifyListeners();
  }

  Future<void> setHomeUrl(String url) async {
    final normalized = _requireUrl(url);
    _configured = true;
    _homeUrl = normalized;
    _lastUrl = normalized;
    await Future.wait([
      _prefs.setBool(_kConfigured, true),
      _prefs.setString(_kHomeUrl, _homeUrl),
      _prefs.setString(_kLastUrl, _lastUrl),
    ]);
    await _addToHistory(_homeUrl);
    notifyListeners();
  }

  Future<void> rememberOpenedUrl(String url) async {
    final normalized = UrlUtils.normalize(url);
    _lastUrl = normalized;
    await _prefs.setString(_kLastUrl, _lastUrl);
    await _addToHistory(normalized);
    notifyListeners();
  }

  Future<void> rememberCurrentUrl(String url) async {
    final normalized = UrlUtils.normalize(url);
    if (normalized == _lastUrl) return;
    _lastUrl = normalized;
    await _prefs.setString(_kLastUrl, _lastUrl);
  }

  Future<void> setResumeLastUrl(bool enabled) async {
    _resumeLastUrl = enabled;
    await _prefs.setBool(_kResumeLastUrl, enabled);
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

  Future<void> setOrientationLock(OrientationLock lock) async {
    _orientationLock = lock;
    await _prefs.setInt(_kOrientationLock, lock.index);
    notifyListeners();
  }

  Future<void> setAppTitle(String title) async {
    _appTitle = _normalizeTitle(title);
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

  Future<void> setFullscreenLandscape(bool enabled) async {
    _fullscreenLandscape = enabled;
    await _prefs.setBool(_kFullscreenLandscape, enabled);
    notifyListeners();
  }

  String _normalizeTitle(String title) {
    final t = title.trim();
    return t.isEmpty ? 'LinkWeb' : t;
  }

  String _requireUrl(String url) {
    final raw = url.trim();
    if (raw.isEmpty) {
      throw ArgumentError('请输入网页地址');
    }
    return UrlUtils.normalize(raw);
  }

  Future<void> _addToHistory(String url) async {
    final normalized = UrlUtils.normalize(url);
    _urlHistory.remove(normalized);
    _urlHistory.insert(0, normalized);
    if (_urlHistory.length > _kMaxHistory) {
      _urlHistory = _urlHistory.sublist(0, _kMaxHistory);
    }
    await _prefs.setStringList(_kUrlHistory, _urlHistory);
  }

  Future<void> clearHistory() async {
    _urlHistory.clear();
    await _prefs.setStringList(_kUrlHistory, <String>[]);
    notifyListeners();
  }

  bool isBookmarked(String url) {
    final normalized = UrlUtils.normalize(url);
    return _bookmarks.any((b) => b.url == normalized);
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
    final normalized = UrlUtils.normalize(url);
    _bookmarks.removeWhere((b) => b.url == normalized);
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
      _kConfigured: _configured,
      _kHomeUrl: _homeUrl,
      _kLastUrl: _lastUrl,
      _kResumeLastUrl: _resumeLastUrl,
      _kThemeMode: _themeMode.index,
      _kEffect: _effect.index,
      _kOrientationLock: _orientationLock.index,
      _kAppTitle: _appTitle,
      _kUrlHistory: _urlHistory,
      _kBookmarks: _bookmarks.map((b) => b.toMap()).toList(),
      _kDesktopMode: _desktopMode,
      _kJavascriptEnabled: _javascriptEnabled,
      _kFullscreenLandscape: _fullscreenLandscape,
    };
    return jsonEncode(map);
  }
}
