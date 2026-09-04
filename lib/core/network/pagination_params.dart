/// Builds pagination query parameters for the SCI API.
///
/// The backend runs `forbidNonWhitelisted: true`, so any query property absent
/// from the pagination DTO is rejected outright:
///
///   { "code": "VALIDATION_ERROR", "message": "property limit should not exist" }
///
/// That is why every request carrying `limit` returned 400. Rather than guess
/// the correct name across a dozen call sites, the contract lives here once.
///
/// [pageSizeParam] is null by default, meaning **no page-size parameter is
/// sent at all** and the server applies its own default — which always
/// validates. Once you confirm the real field name from Swagger
/// (`/api/docs`) or the pagination DTO, set it here and page sizes start
/// working again. One line, no call sites touched.
class PaginationParams {
  const PaginationParams._();

  /// Name of the page-number parameter.
  ///
  /// `page` is confirmed accepted: the 400 named only `limit`.
  static const String pageParam = 'page';

  /// Name of the page-size parameter, or null to omit it entirely.
  ///
  /// Common NestJS conventions, in rough order of likelihood:
  ///   'pageSize' | 'perPage' | 'take' | 'size' | 'count'
  ///
  /// Leave null until verified — a second wrong guess just produces another
  /// 400.
  static const String? pageSizeParam = null;

  /// Builds a query map, omitting anything the DTO would reject.
  static Map<String, dynamic> build({
    int? page,
    int? pageSize,
    Map<String, dynamic>? extra,
  }) {
    final query = <String, dynamic>{};

    if (page != null) query[pageParam] = page;

    const sizeKey = pageSizeParam;
    if (sizeKey != null && pageSize != null) query[sizeKey] = pageSize;

    if (extra != null) {
      // Never forward nulls or blank strings: under forbidNonWhitelisted the
      // safest request is the smallest one.
      extra.forEach((key, dynamic value) {
        if (value == null) return;
        if (value is String && value.trim().isEmpty) return;
        query[key] = value;
      });
    }

    return query;
  }
}
