import 'package:flutter_test/flutter_test.dart';
import 'package:linkweb/src/core/url_utils.dart';

void main() {
  group('UrlUtils.normalize', () {
    test('adds https when scheme missing', () {
      expect(UrlUtils.normalize('example.com'), 'https://example.com');
    });

    test('keeps http/https urls', () {
      expect(UrlUtils.normalize('https://flutter.dev'), 'https://flutter.dev');
      expect(UrlUtils.normalize('http://example.com'), 'http://example.com');
    });

    test('turns search query into google search url', () {
      final u = UrlUtils.normalize('flutter webview settings');
      expect(u.startsWith('https://www.google.com/search?q='), true);
    });
  });
}
