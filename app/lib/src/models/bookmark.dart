import 'dart:convert';

class Bookmark {
  final String url;
  final String title;
  final DateTime createdAt;

  const Bookmark({
    required this.url,
    required this.title,
    required this.createdAt,
  });

  Bookmark copyWith({String? url, String? title, DateTime? createdAt}) {
    return Bookmark(
      url: url ?? this.url,
      title: title ?? this.title,
      createdAt: createdAt ?? this.createdAt,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'url': url,
      'title': title,
      'createdAt': createdAt.toIso8601String(),
    };
  }

  static Bookmark fromMap(Map<String, dynamic> map) {
    return Bookmark(
      url: (map['url'] ?? '').toString(),
      title: (map['title'] ?? '').toString(),
      createdAt: DateTime.tryParse((map['createdAt'] ?? '').toString()) ??
          DateTime.now(),
    );
  }

  String toJson() => jsonEncode(toMap());

  static Bookmark fromJson(String json) {
    return fromMap(jsonDecode(json) as Map<String, dynamic>);
  }
}
