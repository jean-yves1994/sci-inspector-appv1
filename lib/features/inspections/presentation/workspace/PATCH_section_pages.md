# `section_pages.dart` — two edits

## Import

```dart
import '../../../../core/sync/data_changed.dart';
```

---

## 1. `_PhotosPageState._capture` — after a successful upload

```dart
      await ref.read(photosRepositoryProvider).upload(
            inspectionId: widget.inspectionId,
            file: file,
            category: category,
            clientRequestId: clientRequestId,
            capturedAt: DateTime.now(),
            latitude: fix?.latitude,
            longitude: fix?.longitude,
            accuracyM: fix?.accuracyM,
          );

      // Thumbnail appears immediately.
      ref.invalidate(inspectionPhotosProvider(widget.inspectionId));

      // Tells the workspace to refetch, which refreshes completeness from the
      // server. Replaces the old completenessProvider invalidate, which only
      // re-read a cached value and so never moved the gauge.
      ref.read(dataChangedProvider.notifier)
          .photosChanged(widget.inspectionId);
```

Remove any existing `ref.invalidate(completenessProvider(...))` here — it is
now redundant and was never effective.

## 2. `_PhotosPageState._delete` — the same two lines

Deleting can take completeness **below** a threshold, so the gauge must fall
as well as rise:

```dart
  Future<void> _delete(InspectionPhoto photo) async {
    try {
      await ref.read(photosRepositoryProvider).delete(photo.id);

      ref.invalidate(inspectionPhotosProvider(widget.inspectionId));
      ref.read(dataChangedProvider.notifier)
          .photosChanged(widget.inspectionId);
    } on ApiError catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(e.message)));
      }
    }
  }
```

---

## 3. Optional but recommended — honest progress while refetching

The gauge briefly shows its old value during the refetch, which on a slow
connection reads as "nothing happened".

In `_ProgressBar`:

```dart
    final completeness = ref.watch(completenessProvider(inspectionId));
    final pct = completeness.valueOrNull?.percentage ?? 0;
    final outstanding = completeness.valueOrNull?.outstanding.length ?? 0;
    final isRefreshing = completeness.isLoading;

    // ...
                Expanded(
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(8),
                    child: LinearProgressIndicator(
                      // Null renders as indeterminate — honest about not
                      // knowing yet, rather than confidently showing a stale
                      // number.
                      value: isRefreshing ? null : pct / 100,
                      minHeight: 6,
                      backgroundColor:
                          AppColors.primary.withValues(alpha: 0.12),
                    ),
                  ),
                ),
```

Worth doing: otherwise an inspector uploads the final photo, still sees 90%,
and wonders whether it worked.
