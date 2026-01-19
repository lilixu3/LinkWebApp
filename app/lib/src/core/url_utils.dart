class UrlUtils {
  static const fallback = 'https://example.com';

  /// Normalizes user input into a safe, absolute URL.
  /// - Trims whitespace
  /// - Adds https:// if missing
  /// - If looks like a search query, converts to a search URL
  static String normalize(String raw, {String searchEngine = 'https://www.google.com/search?q='}) {
    final trimmed = raw.trim();
    if (trimmed.isEmpty) return fallback;

    // If user typed something without dots/spaces but with spaces, treat as search.
    final hasSpaces = trimmed.contains(RegExp(r'\s'));
    final looksLikeUrl = trimmed.contains('.') || trimmed.startsWith('http') || trimmed.contains('://');
    if (hasSpaces && !looksLikeUrl) {
      final q = Uri.encodeComponent(trimmed);
      return '$searchEngine$q';
    }

    final uri = Uri.tryParse(trimmed);
    if (uri == null) return fallback;

    // If scheme missing, assume https.
    if (!uri.hasScheme) {
      return 'https://$trimmed';
    }

    // Only allow http/https/file schemes for in-app webview. Others should be opened externally.
    return trimmed;
  }

  static bool isWebScheme(Uri uri) {
    final s = uri.scheme.toLowerCase();
    return s == 'http' || s == 'https' || s == 'file';
  }
}
