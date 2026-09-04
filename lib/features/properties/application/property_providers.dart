import 'dart:async';

import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/network/api_error.dart';
import '../data/properties_repository.dart';
import '../domain/property.dart';

class PropertySearchNotifier extends Notifier<String> {
  Timer? _debounce;

  @override
  String build() {
    ref.onDispose(() => _debounce?.cancel());
    return '';
  }

  void onChanged(String v) {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 350), () {
      if (state != v) state = v;
    });
  }

  void clear() {
    _debounce?.cancel();
    state = '';
  }
}

final propertySearchProvider =
    NotifierProvider<PropertySearchNotifier, String>(
        PropertySearchNotifier.new);

class PropertyListState {
  const PropertyListState({
    this.items = const <Property>[],
    this.page = 0,
    this.total = 0,
    this.hasMore = false,
    this.isLoadingMore = false,
  });

  final List<Property> items;
  final int page;
  final int total;
  final bool hasMore;
  final bool isLoadingMore;

  PropertyListState copyWith({
    List<Property>? items,
    int? page,
    int? total,
    bool? hasMore,
    bool? isLoadingMore,
  }) =>
      PropertyListState(
        items: items ?? this.items,
        page: page ?? this.page,
        total: total ?? this.total,
        hasMore: hasMore ?? this.hasMore,
        isLoadingMore: isLoadingMore ?? this.isLoadingMore,
      );
}

class PropertyListNotifier extends AsyncNotifier<PropertyListState> {
  static const int _pageSize = 20;

  @override
  Future<PropertyListState> build() async {
    final search = ref.watch(propertySearchProvider);
    final token = CancelToken();
    ref.onDispose(() => token.cancel('disposed'));

    final r = await ref
        .read(propertiesRepositoryProvider)
        .list(search: search, limit: _pageSize, cancelToken: token);

    return PropertyListState(
      items: r.items,
      page: r.page,
      total: r.total,
      hasMore: r.hasMore,
    );
  }

  Future<void> refresh() async => state = await AsyncValue.guard(build);

  Future<void> loadMore() async {
    final c = state.valueOrNull;
    if (c == null || !c.hasMore || c.isLoadingMore) return;
    state = AsyncData(c.copyWith(isLoadingMore: true));
    try {
      final r = await ref.read(propertiesRepositoryProvider).list(
            search: ref.read(propertySearchProvider),
            page: c.page + 1,
            limit: _pageSize,
          );
      state = AsyncData(c.copyWith(
        items: <Property>[...c.items, ...r.items],
        page: r.page,
        total: r.total,
        hasMore: r.hasMore,
        isLoadingMore: false,
      ));
    } on ApiError {
      // Keep loaded pages on screen rather than blanking the list.
      state = AsyncData(c.copyWith(isLoadingMore: false));
    }
  }

  void prepend(Property p) {
    final c = state.valueOrNull ?? const PropertyListState();
    state = AsyncData(c.copyWith(
        items: <Property>[p, ...c.items], total: c.total + 1));
  }
}

final propertyListProvider =
    AsyncNotifierProvider<PropertyListNotifier, PropertyListState>(
        PropertyListNotifier.new);

final propertyDetailProvider =
    FutureProvider.autoDispose.family<Property, String>(
        (ref, id) => ref.watch(propertiesRepositoryProvider).byId(id));
