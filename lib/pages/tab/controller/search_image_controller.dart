import 'package:dio/dio.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/cupertino.dart';
import 'package:get/get.dart';

import '../../../component/exception/error.dart';
import '../../../index.dart';
import '../../../network/request.dart';
import 'default_tabview_controller.dart';
import 'enum.dart';
import 'search_page_controller.dart';

class SearchImageController extends DefaultTabViewController {
  final String tabIndex = 'search_image';

  final _imagePath = ''.obs;
  String get imagePath => _imagePath.value;
  set imagePath(String val) => _imagePath.value = val;

  final RxBool similarScan = true.obs;
  final RxBool onlyCovers = false.obs;
  final RxBool includeExpunged = false.obs;

  final Rx<ListType> _listType = ListType.init.obs;
  ListType get listType => _listType.value;
  set listType(ListType val) => _listType.value = val;

  bool _pickingImage = false;

  void clearImage() {
    imagePath = '';
    listType = ListType.init;
    change(null, status: RxStatus.empty());
  }

  Future<void> selectSearchImage(BuildContext context) async {
    if (_pickingImage || isClosed || !context.mounted) {
      return;
    }

    // The system picker grants access to the selected image. Requesting broad
    // storage access first blocks Android 13+ and desktop, and PHPicker does
    // not require photo-library access on supported iOS versions either.
    _pickingImage = true;
    try {
      final result = await FilePicker.platform.pickFiles(type: FileType.image);
      if (isClosed || !context.mounted || result?.files.length != 1) {
        return;
      }
      final picked = result!.files.single.path;
      if (picked != null && picked.isNotEmpty) {
        imagePath = picked;
      }
    } on Exception catch (e) {
      logger.e('Pick file failed', error: e);
    } finally {
      _pickingImage = false;
    }
  }

  Future<void> startSearch({bool clear = true}) async {
    if (imagePath.isEmpty) {
      return;
    }

    listType = ListType.gallery;

    resetResultPage();

    if (clear) {
      change(state, status: RxStatus.loading());
    }

    try {
      logger.d('startSearch');
      final rult = await fetchData(refresh: true);
      if (rult == null) {
        change(null, status: RxStatus.loading());
        return;
      }

      nextGid = rult.nextGid;
      prevGid = rult.prevGid;
      nextPage = rult.nextPage;
      prevPage = rult.prevPage;
      maxPage = rult.maxPage;

      change(rult.gallerys ?? [], status: RxStatus.success());
    } catch (err) {
      change(null, status: RxStatus.error(err.toString()));
    }
  }

  @override
  Future<void> firstLoad() async {
    change(<GalleryProvider>[], status: RxStatus.empty());
  }

  @override
  Future<GalleryList?> fetchData({bool refresh = false}) async {
    cancelToken = CancelToken();

    pageState = PageState.Loading;

    try {
      final GalleryList? rult = await searchImage(
        imagePath,
        similar: similarScan.value,
        covers: onlyCovers.value,
        exp: includeExpunged.value,
        cancelToken: cancelToken,
      );

      if (cancelToken?.isCancelled ?? false) {
        return null;
      }

      pageState = PageState.None;

      final _list =
          rult?.gallerys
              ?.map((e) => e.simpleTags ?? [])
              .expand((List<SimpleTag> element) => element)
              .toList() ??
          [];

      tagController.addAllSimpleTag(_list);
      return rult;
    } on EhError catch (eherror) {
      logger.e('type:${eherror.type}\n${eherror.message}');
      showToast(eherror.message);
      pageState = PageState.LoadingError;
      rethrow;
    } on Exception catch (e) {
      pageState = PageState.LoadingError;
      rethrow;
    }
  }
}
