import 'package:eros_fe/common/service/controller_tag_service.dart';
import 'package:eros_fe/pages/gallery/gallery_repository.dart';
import 'package:eros_fe/utils/logger.dart';
import 'package:get/get.dart';

import 'controller/archiver_controller.dart';
import 'controller/comment_controller.dart';
import 'controller/gallery_fav_controller.dart';
import 'controller/gallery_page_controller.dart';
import 'controller/rate_controller.dart';
import 'controller/taginfo_controller.dart';
import 'controller/torrent_controller.dart';

void initPageController({String? tag}) {
  final owner = tag ?? pageCtrlTag;
  Get.lazyPut(() => CommentController(galleryTag: owner), tag: owner);

  Get.lazyPut(() => RateController(galleryTag: owner), tag: owner);

  Get.lazyPut(() => TorrentController(galleryTag: owner), tag: owner);

  Get.lazyPut(() => ArchiverController(galleryTag: owner), tag: owner);

  Get.lazyPut(() => GalleryFavController(galleryTag: owner), tag: owner);

  Get.lazyPut(() => TagInfoController(galleryTag: owner), tag: owner);
}

void deletePageController({String? tag}) {
  logger.t('deletePageController ${tag ?? pageCtrlTag}');

  if (Get.isRegistered<GalleryFavController>(tag: tag ?? pageCtrlTag)) {
    Get.delete<GalleryFavController>(tag: tag ?? pageCtrlTag);
  }
  // GalleryPageController
  if (Get.isRegistered<GalleryPageController>(tag: tag ?? pageCtrlTag))
    Get.delete<GalleryPageController>(tag: tag ?? pageCtrlTag);

  if (Get.isRegistered<RateController>(tag: tag ?? pageCtrlTag))
    Get.delete<RateController>(tag: tag ?? pageCtrlTag);
  if (Get.isRegistered<TorrentController>(tag: tag ?? pageCtrlTag))
    Get.delete<TorrentController>(tag: tag ?? pageCtrlTag);
  if (Get.isRegistered<ArchiverController>(tag: tag ?? pageCtrlTag))
    Get.delete<ArchiverController>(tag: tag ?? pageCtrlTag);
  if (Get.isRegistered<CommentController>(tag: tag ?? pageCtrlTag))
    Get.delete<CommentController>(tag: tag ?? pageCtrlTag);

  if (Get.isRegistered<TagInfoController>(tag: tag ?? pageCtrlTag))
    Get.delete<TagInfoController>(tag: tag ?? pageCtrlTag);

  if (Get.isRegistered<GalleryRepository>(tag: tag ?? pageCtrlTag)) {
    Get.delete<GalleryRepository>(tag: tag ?? pageCtrlTag);
  }

  // Get.find<DepthService>().popPageCtrl();
}
