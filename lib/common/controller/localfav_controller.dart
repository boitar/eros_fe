import 'package:eros_fe/common/global.dart';
import 'package:eros_fe/extension.dart';
import 'package:eros_fe/models/index.dart';
import 'package:flutter/foundation.dart';
import 'package:get/get.dart';

import 'base_controller.dart';

class LocalFavController extends ProfileController {
  RxList<GalleryProvider> loacalFavs = <GalleryProvider>[].obs;

  static GalleryProvider normalizeProvider(GalleryProvider provider) {
    return provider.copyWith(
      localFav: true.oN,
      favcat: ''.oN,
      favTitle: ''.oN,
      favNote: ''.oN,
      galleryImages: (null as List<GalleryImage>?).oN,
      galleryComment: (null as List<GalleryComment>?).oN,
    );
  }

  static ({List<GalleryProvider> items, bool changed}) normalizeAndDedupe(
    Iterable<GalleryProvider> raw,
  ) {
    final items = <GalleryProvider>[];
    final seenGids = <String>{};
    var changed = false;

    for (final entry in raw) {
      final gid = entry.gid;
      if (gid != null && gid.isNotEmpty && !seenGids.add(gid)) {
        changed = true;
        continue;
      }
      final normalized = normalizeProvider(entry);
      if (normalized != entry) {
        changed = true;
      }
      items.add(normalized);
    }

    return (items: items, changed: changed);
  }

  @protected
  List<GalleryProvider> readPersistedLocalFavs() =>
      Global.profile.localFav.gallerys ?? const <GalleryProvider>[];

  @protected
  void persistLocalFavsSnapshot(List<GalleryProvider> items) {
    Global.profile = Global.profile.copyWith(
      localFav: Global.profile.localFav.copyWith(gallerys: items.oN),
    );
    Global.saveProfile();
  }

  void addLocalFav(GalleryProvider? galleryProvider) {
    if (galleryProvider == null) {
      return;
    }
    final normalized = normalizeProvider(galleryProvider);
    final existingIndex =
        loacalFavs.indexWhere((element) => element.gid == normalized.gid);
    if (existingIndex == -1) {
      loacalFavs.insert(0, normalized);
    } else {
      loacalFavs[existingIndex] = normalized;
    }
  }

  void removeFav(GalleryProvider? galleryProvider) {
    if (galleryProvider == null) {
      return;
    }
    loacalFavs.removeWhere((element) => element.gid == galleryProvider.gid);
  }

  void removeFavByGid(String gid) {
    loacalFavs.removeWhere((element) => element.gid == gid);
  }

  @override
  void onInit() {
    super.onInit();
    final sanitized = normalizeAndDedupe(readPersistedLocalFavs());
    loacalFavs.assignAll(sanitized.items);
    if (sanitized.changed) {
      persistLocalFavsSnapshot(List<GalleryProvider>.of(loacalFavs));
    }
    everProfile<List<GalleryProvider>>(
      loacalFavs,
      (List<GalleryProvider> value) {
        Global.profile = Global.profile.copyWith(
          localFav: Global.profile.localFav.copyWith(gallerys: value.oN),
        );
      },
    );
  }
}
