import 'dart:convert';

import 'package:collection/collection.dart';
import 'package:eros_fe/common/controller/webdav_controller.dart';
import 'package:eros_fe/common/service/layout_service.dart';
import 'package:eros_fe/common/service/locale_service.dart';
import 'package:eros_fe/index.dart';
import 'package:eros_fe/widget/liquid_glass_popup.dart';
import 'package:executor/executor.dart';
import 'package:flutter/cupertino.dart';
import 'package:get/get.dart';

import '../../comm.dart';
import '../../fetch_list.dart';
import '../default_tabview_controller.dart';
import '../tabhome_controller.dart';
import 'custom_sublist_controller.dart';

final CustomProfile profileChinese = CustomProfile(
    uuid: generateUuidv4(), name: '汉语', searchText: const ['l:chinese']);

/// 控制所有自定义列表
class CustomTabbarController extends DefaultTabViewController {
  final WebdavController webdavController = Get.find();

  final executor = Executor(concurrency: 1);

  CustomTabConfig? get customTabConfig => Global.profile.customTabConfig;
  set customTabConfig(CustomTabConfig? val) =>
      Global.profile = Global.profile.copyWith(customTabConfig: val.oN);

  final RxList<CustomProfile> profiles = <CustomProfile>[].obs;
  Map<String, CustomProfile> get profileMap {
    Map<String, CustomProfile> _map = {};
    for (final profile in profiles) {
      _map[profile.uuid] = profile;
    }
    return _map;
  }

  // 登记删除的profile和时间
  final RxList<CustomProfile> delProfiles = <CustomProfile>[].obs;

  // 显示的分组
  List<CustomProfile> get profilesShow =>
      profiles.whereNot((element) => element.hideTab ?? false).toList();

  final _currProfileUuid = ''.obs;
  String get currProfileUuid => _currProfileUuid.value;
  set currProfileUuid(String val) => _currProfileUuid.value = val;

  final _index = 0.obs;
  int get index => _index.value;
  set index(int val) => _index.value = val;

  final _reorderable = false.obs;
  bool get reorderable => _reorderable.value;
  set reorderable(bool val) => _reorderable.value = val;

  Map<String, CustomSubListController> subControllerMap = {};
  CustomSubListController? get _currSubController =>
      subControllerMap[currProfileUuid];

  PageController? _pageController;
  PageController get pageController =>
      _pageController ??= PageController(initialPage: index);
  set pageController(PageController value) => _pageController = value;

  int _selectionEpoch = 0;
  bool _pendingPageSync = false;

  EhTabController? get currentPageScrollController =>
      _currSubController?.tabScrollController;

  final LinkScrollBarController linkScrollBarController =
      LinkScrollBarController();

  @override
  void onInit() {
    super.onInit();

    logger.t('CustomProfile onInit');

    heroTag = EHRoutes.gallery;

    // 初始化分组
    profiles.value = customTabConfig?.profiles ??
        [
          CustomProfile(
                  name: L10n.of(Get.context!).tab_popular,
                  uuid: generateUuidv4())
              .copyWithListType(GalleryListType.popular),
          CustomProfile(
                  name: L10n.of(Get.context!).tab_gallery,
                  uuid: generateUuidv4())
              .copyWithListType(GalleryListType.gallery),
          CustomProfile(
                  name: L10n.of(Get.context!).tab_watched,
                  uuid: generateUuidv4())
              .copyWithListType(GalleryListType.watched),
          if (Get.find<LocaleService>().isLanguageCodeZh) profileChinese,
          CustomProfile(
              uuid: generateUuidv4(),
              name: 'Anthology',
              searchText: const ['o:anthology'])
        ];

    ever<List<CustomProfile>>(profiles, (value) {
      _reconcileSelection();
      customTabConfig = customTabConfig?.copyWith(profiles: value.oN) ??
          CustomTabConfig(profiles: value);
      Global.saveProfile();
    });

    final savedIndex = customTabConfig?.lastIndex ?? 0;
    _reconcileSelection(fallbackIndex: savedIndex, synchronizePage: false);
    ever<int>(_index, (value) {
      customTabConfig = customTabConfig?.copyWith(lastIndex: value.oN) ??
          CustomTabConfig(lastIndex: value);
      Global.saveProfile();
    });

    delProfiles(hiveHelper.getProfileDelList());
    debounce<List<CustomProfile>>(delProfiles, (value) {
      hiveHelper.setProfileDelList(value);
    }, time: const Duration(seconds: 2));

    if (index != savedIndex) {
      customTabConfig = customTabConfig?.copyWith(lastIndex: index.oN);
      Global.saveProfile();
    }

    for (final profile in profiles) {
      Get.lazyPut(() => CustomSubListController(profileUuid: profile.uuid),
          tag: profile.uuid);
    }

    syncProfiles();
  }

  @override
  void onClose() {
    super.onClose();
    _pageController?.dispose();
    linkScrollBarController.dispose();
  }

  /// The page a tap is animating to. The pages it passes on the way there
  /// are not selections.
  int? _landingPage;

  /// Update the rail immediately and let the PageView animate to the same
  /// destination. Waiting for PageView.onPageChanged made the page and its
  /// Liquid Glass selection visibly lag behind one another.
  Future<void> selectPage(int target) async {
    final visibleProfiles = profilesShow;
    if (target < 0 || target >= visibleProfiles.length) {
      return;
    }

    linkScrollBarController.scrollToItem(target);
    onPageChanged(target);
    if (!pageController.hasClients) {
      return;
    }

    final currentPage = pageController.page;
    if (currentPage != null && (currentPage - target).abs() < 0.001) {
      return;
    }
    _landingPage = target;
    try {
      await pageController.animateToPage(
        target,
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeOutCubic,
      );
    } finally {
      if (_landingPage == target) {
        _landingPage = null;
      }
    }
  }

  void onPageChanged(int index) {
    if (_pendingPageSync) {
      return;
    }
    final landing = _landingPage;
    if (landing != null && index != landing) {
      return;
    }
    final visible = profilesShow;
    if (visible.isEmpty) {
      _reconcileSelection(synchronizePage: false);
      return;
    }
    if (index < 0 || index >= visible.length) {
      return;
    }
    if (currProfileUuid != visible[index].uuid &&
        Get.isRegistered<TabHomeController>()) {
      Get.find<TabHomeController>().resetTabTapSequence();
    }
    currProfileUuid = visible[index].uuid;
    this.index = index;
  }

  void _reconcileSelection({
    String? preferredUuid,
    int? fallbackIndex,
    bool synchronizePage = true,
  }) {
    final epoch = ++_selectionEpoch;
    final visible = profilesShow;
    _pendingPageSync = false;
    if (visible.isEmpty) {
      index = 0;
      currProfileUuid = '';
      return;
    }
    final retained = visible.indexWhere(
        (profile) => profile.uuid == (preferredUuid ?? currProfileUuid));
    final target = retained >= 0
        ? retained
        : (fallbackIndex ?? index).clamp(0, visible.length - 1).toInt();
    final selectedUuid = visible[target].uuid;
    currProfileUuid = selectedUuid;
    index = target;
    if (!synchronizePage) {
      return;
    }
    // Rebuilding a PageView can report its old numeric page before the new
    // children settle. Keep the selected UUID until that frame is reconciled.
    _pendingPageSync = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (isClosed || epoch != _selectionEpoch) {
        return;
      }
      final currentIndex =
          profilesShow.indexWhere((profile) => profile.uuid == selectedUuid);
      if (currentIndex >= 0) {
        final page = _pageController;
        if (page != null && page.hasClients && page.positions.length == 1) {
          page.jumpToPage(currentIndex);
        }
        linkScrollBarController.scrollToItem(currentIndex);
      }
      _pendingPageSync = false;
    });
  }

  @override
  Future<void> showJumpDialog(BuildContext context) async {
    await _currSubController?.showJumpDialog(context);
  }

  @override
  bool get afterJump => _currSubController?.afterJump ?? false;

  @override
  Future<void> jumpToTop() async {
    await _currSubController?.jumpToTop();
  }

  Future<void> reselectCurrentPage() async {
    await currentPageScrollController?.scrollToTopAndRefresh();
  }

  @override
  Future<void> reloadData() async {
    if (_currSubController?.reloadData != null) {
      await _currSubController!.reloadData();
    } else {
      update();
      await _currSubController?.reloadData();
    }
  }

  @override
  Future<void> firstLoad() async {}

  Future<void> pressedBar() async {
    await Get.toNamed(
      EHRoutes.customProfiles,
      id: primaryNavigatorId,
    );
  }

  // 编辑分组（新增或者修改现有）
  Future<void> toEditPage({String? uuid}) async {
    final topRoute =
        SecondNavigatorObserver().history.lastOrNull?.settings.name;
    logger.d('topRoute $topRoute');

    // 依赖注入
    Get.replace<CustomProfile>(
        profileMap[uuid] ?? CustomProfile(name: '', uuid: generateUuidv4()));

    // arguments 方式不能跨栈传递，改回依赖注入

    late final dynamic _result;

    if (isLayoutLarge && topRoute == EHRoutes.customProfileSetting) {
      _result = await Get.offNamed(
        EHRoutes.customProfileSetting,
        id: detailNavigatorId,
        preventDuplicates: false,
        // arguments: profileMap[uuid],
      );
    } else {
      _result = await Get.toNamed(
        EHRoutes.customProfileSetting,
        id: detailNavigatorId,
        preventDuplicates: false,
        // arguments: profileMap[uuid],
      );
    }

    if (_result != null && _result is CustomProfile) {
      addProfile(_result);
      syncProfiles();
    }
  }

  // 交换位置
  Future<void> onReorder(int oldIndex, int newIndex) async {
    if (oldIndex < 0 ||
        oldIndex >= profiles.length ||
        newIndex < 0 ||
        newIndex > profiles.length) {
      return;
    }
    final _profileUuid = currProfileUuid;
    final target = newIndex.clamp(0, profiles.length - 1).toInt();
    final _profile = profiles.removeAt(oldIndex);
    profiles.insert(target, _profile);
    _reconcileSelection(preferredUuid: _profileUuid);

    await syncProfiles();
  }

  // 删除分组配置
  Future<void> deleteProfile({required String uuid}) async {
    final _profileUuid = currProfileUuid;
    final profile = profiles.firstWhereOrNull((item) => item.uuid == uuid);
    if (profile == null) {
      return;
    }
    final oldVisibleIndex =
        profilesShow.indexWhere((item) => item.uuid == uuid);

    if (_profileUuid == uuid) {
      await 200.milliseconds.delay();
    }

    addDelProfile(profile);
    profiles.removeWhere((element) => element.uuid == uuid);
    _reconcileSelection(
        preferredUuid: _profileUuid, fallbackIndex: oldVisibleIndex);

    await syncProfiles();
  }

  // 添加到已删除列表 记录删除时间
  void addDelProfile(CustomProfile profile) {
    final nowTime = DateTime.now().millisecondsSinceEpoch;
    final _index = delProfiles.indexOf((e) => e.name == profile.name);
    if (_index > -1) {
      delProfiles[_index] =
          delProfiles[_index].copyWith(lastEditTime: nowTime.oN);
    } else {
      delProfiles.add(profile);
    }
  }

  void pressSubmitText() {}

  // 删除对话框
  void showDeleteGroupModalBottomSheet(String uuid, BuildContext context) {
    showCupertinoModalPopup(
        context: context,
        builder: (context) {
          return EhActionSheet(
              actions: [
                CupertinoActionSheetAction(
                    onPressed: () {
                      deleteProfile(uuid: uuid);
                      Get.back();
                    },
                    child: Text(
                      L10n.of(context).delete,
                      style: const TextStyle(
                          color: CupertinoColors.destructiveRed),
                    )),
              ],
              cancelButton: CupertinoActionSheetAction(
                  onPressed: () {
                    Get.back();
                  },
                  child: Text(L10n.of(context).cancel)));
        });
  }

  void addProfile(CustomProfile profile) {
    logger.t(' ${jsonEncode(profile)}');

    final oriIndexOfSameUuid =
        profiles.indexWhere((element) => element.uuid == profile.uuid);

    final oriIndexOfSameName =
        profiles.indexWhere((element) => element.name == profile.name);

    if (oriIndexOfSameUuid >= 0) {
      // 优先覆盖相同uuid
      profiles[oriIndexOfSameUuid] = profile;
    } else if (oriIndexOfSameName >= 0) {
      // 其次覆盖相同组名
      profiles[oriIndexOfSameName] = profile;
    } else {
      // 都不匹配则新增
      logger.d('new profile ${profile.name} ${profile.uuid}');
      profiles.add(profile);
    }

    Get.lazyPut(
      () => CustomSubListController(profileUuid: profile.uuid)
        ..heroTag = profile.uuid,
      tag: profile.uuid,
      fenix: true,
    );

    final CustomSubListController subController = Get.find(tag: profile.uuid);
    subController.listMode = profile.listMode;
    subController.onInit();
  }

  Future<void> syncProfiles() async {
    if (!webdavController.syncGroupProfile) {
      return;
    }
    final listLocal = List<CustomProfile>.from(profiles);
    logger.t('listLocal ${listLocal.length} \n${listLocal.map((e) => e.uuid)}');
    logger.t('${jsonEncode(listLocal)} ');

    // 下载远程文件名列表 包含： 分组名 uuid 时间戳
    final listRemote = await webdavController.getRemoteGroupList();
    // 远程列表为空 直接上传本地所有分组
    if (listRemote.isEmpty) {
      await _uploadProfiles(listLocal);
      return;
    }

    logger.t('listRemote size ${listRemote.length}');

    // 比较远程和本地的差异
    // 合并列表
    final allProfile = <CustomProfile?>{...listRemote, ...listLocal};
    final diff = allProfile
        .where(
          (CustomProfile? element) =>
              !listRemote.contains(element) || !listLocal.contains(element),
        )
        .toList()
        .toSet();
    logger.t('diff ${diff.map((e) => e?.toJson())}');

    // 本地分组中 编辑时间更靠后的
    final localNewer = listLocal.where(
      (eLocal) {
        final _eRemote = listRemote.firstWhereOrNull((eRemote) =>
            eRemote.uuid == eLocal.uuid || eRemote.name == eLocal.name);
        if (_eRemote == null) {
          return true;
        }

        return (eLocal.lastEditTime ?? 0) > (_eRemote.lastEditTime ?? 0);
      },
    );
    logger.t('localNewer count ${localNewer.length}');

    // 远程 编辑时间更靠后的
    final remoteNewer = listRemote.where(
      (eRemote) {
        final _eLocal = listLocal.firstWhereOrNull((eLocal) =>
            eLocal.uuid == eRemote.uuid || eLocal.name == eRemote.name);

        // delProfiles 中 name 和远程文件一样的
        final _eDelFlg = delProfiles.where(
            (eDel) => eDel.uuid == eRemote.uuid || eDel.name == eRemote.name);

        if (_eDelFlg.isNotEmpty) {
          return _eDelFlg.every(
              (e) => (eRemote.lastEditTime ?? 0) > (e.lastEditTime ?? 0));
        }

        if (_eLocal == null) {
          return true;
        }

        return (eRemote.lastEditTime ?? 0) > (_eLocal.lastEditTime ?? 0);
      },
    );
    logger.t('remoteNewer ${remoteNewer.map((e) => e.name).toList()}');

    await _downloadProfiles(remoteNewer.toSet().toList());

    await _uploadProfiles(localNewer.toList(), listRemote: listRemote);
  }

  Future _downloadProfiles(List<CustomProfile> remoteList) async {
    for (final remote in remoteList) {
      executor.scheduleTask(() async {
        final _remote = await webdavController.downloadGroupProfile(remote);
        if (_remote != null) {
          final ori = profiles.firstWhereOrNull((element) =>
              element.uuid == _remote.uuid || element.name == _remote.name);

          if (ori != null &&
              (remote.lastEditTime ?? 0) <= (ori.lastEditTime ?? 0)) {
            return;
          }
          addProfile(_remote);
        }
      });
    }

    await executor.join(withWaiting: true);
  }

  Future _uploadProfiles(
    List<CustomProfile?> localHisList, {
    List<CustomProfile?>? listRemote,
  }) async {
    for (final profile in localHisList) {
      executor.scheduleTask(() async {
        final _oriRemote = listRemote?.firstWhereOrNull((element) =>
            element?.uuid == profile?.uuid || element?.name == profile?.name);

        if (profile != null) {
          final upload = webdavController.uploadGroupProfile(profile);
          final delete = webdavController.deleteRemoteGroup(_oriRemote);
          await Future.wait([upload, delete]);
        }
      });
    }
    await executor.join(withWaiting: true);
  }
}
