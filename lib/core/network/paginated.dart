/// Tolerant wrapper around the backend pagination envelope.
///
/// The exact shape is read defensively (items / data / results, root or
/// nested meta) because it was not verifiable against the live API. Nothing
/// is invented: absent values fall back to derived ones.
class Paginated<T> {
  const Paginated({
    required this.items,
    required this.page,
    required this.limit,
    required this.total,
  });

  final List<T> items;
  final int page;
  final int limit;
  final int total;

  bool get hasMore => items.isNotEmpty && (page * limit) < total;
  int get nextPage => page + 1;

  static Paginated<T> fromJson<T>(
    Map<String, dynamic> json,
    T Function(Map<String, dynamic>) fromItem,
  ) {
    final raw = json['items'] ?? json['data'] ?? json['results'];
    final list = raw is List
        ? raw.whereType<Map<String, dynamic>>().map(fromItem).toList()
        : <T>[];

    final meta = json['meta'] is Map<String, dynamic>
        ? json['meta'] as Map<String, dynamic>
        : json;

    return Paginated<T>(
      items: List<T>.from(list),
      page: _int(meta['page']) ?? 1,
      limit: _int(meta['limit']) ?? _int(meta['pageSize']) ?? list.length,
      total: _int(meta['total']) ?? _int(meta['totalCount']) ?? list.length,
    );
  }

  static int? _int(Object? v) {
    if (v is int) return v;
    if (v is num) return v.toInt();
    if (v is String) return int.tryParse(v);
    return null;
  }
}

/// Unwraps `{ data: {...} }` envelopes when present.
Map<String, dynamic> unwrap(Map<String, dynamic> json) =>
    json['data'] is Map<String, dynamic>
        ? json['data'] as Map<String, dynamic>
        : json;
