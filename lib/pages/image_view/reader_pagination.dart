import 'common.dart';

/// Maps original (zero-based) image indices to visible pages, never the reverse
/// during a layout change. A paired page can still be anchored to its second
/// image so returning to single-page reading does not silently go back a page.
class ReaderPagination {
  const ReaderPagination({required this.mode, required this.imageCount});

  final ViewColumnMode mode;
  final int imageCount;

  int get pageCount {
    if (imageCount <= 0) {
      return 0;
    }
    return switch (mode) {
      ViewColumnMode.single => imageCount,
      ViewColumnMode.oddLeft => (imageCount + 1) ~/ 2,
      ViewColumnMode.evenLeft => 1 + imageCount ~/ 2,
    };
  }

  int pageForImage(int imageIndex) {
    final image = clampImage(imageIndex);
    return switch (mode) {
      ViewColumnMode.single => image,
      ViewColumnMode.oddLeft => image ~/ 2,
      ViewColumnMode.evenLeft => (image + 1) ~/ 2,
    };
  }

  List<int> imagesForPage(int pageIndex) {
    if (imageCount <= 0 || pageIndex < 0 || pageIndex >= pageCount) {
      return const <int>[];
    }
    final first = switch (mode) {
      ViewColumnMode.single => pageIndex,
      ViewColumnMode.oddLeft => pageIndex * 2,
      ViewColumnMode.evenLeft => pageIndex * 2 - 1,
    };
    return <int>[
      if (first >= 0 && first < imageCount) first,
      if (mode != ViewColumnMode.single &&
          first + 1 >= 0 &&
          first + 1 < imageCount)
        first + 1,
    ];
  }

  int imageAfterPageChange(int pageIndex, {required int currentImage}) {
    final images = imagesForPage(pageIndex);
    if (images.isEmpty || images.contains(currentImage)) {
      return clampImage(currentImage);
    }
    return images.first;
  }

  int clampImage(int imageIndex) =>
      imageIndex.clamp(0, imageCount > 0 ? imageCount - 1 : 0).toInt();
}
