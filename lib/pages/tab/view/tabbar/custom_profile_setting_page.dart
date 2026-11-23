import 'dart:convert';

import 'package:eros_fe/adaptive/platform_capabilities.dart';
import 'package:eros_fe/common/controller/tag_trans_controller.dart';
import 'package:eros_fe/common/service/ehsetting_service.dart';
import 'package:eros_fe/common/service/layout_service.dart';
import 'package:eros_fe/common/service/locale_service.dart';
import 'package:eros_fe/common/service/theme_service.dart';
import 'package:eros_fe/component/setting/setting_scaffold.dart';
import 'package:eros_fe/component/setting_base.dart';
import 'package:eros_fe/const/eh_palette.dart';
import 'package:eros_fe/index.dart';
import 'package:eros_fe/pages/filter/filter.dart';
import 'package:eros_fe/pages/setting/setting_items/selector_Item.dart';
import 'package:eros_fe/pages/tab/controller/group/custom_tabbar_controller.dart';
import 'package:eros_fe/pages/tab/controller/group/profile_edit_controller.dart';
import 'package:eros_fe/pages/tab/fetch_list.dart';
import 'package:eros_fe/pages/tab/view/tabbar/search_text_dialog.dart';
import 'package:eros_fe/widget/desktop_browse_style.dart';
import 'package:eros_fe/widget/desktop_control.dart';
import 'package:eros_fe/widget/desktop_display_mode_menu.dart'
    show desktopMenuAnchor;
import 'package:eros_fe/widget/desktop_gallery_actions.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_slidable/flutter_slidable.dart';
import 'package:get/get.dart';
import 'package:sliver_tools/sliver_tools.dart';

const kSegmentedPadding = EdgeInsets.symmetric(horizontal: 6, vertical: 4);
const kSegmentedTextStyle = TextStyle(height: 1.1, fontSize: 14);

class CustomProfileSettingPage extends StatefulWidget {
  const CustomProfileSettingPage({super.key});

  @override
  State<CustomProfileSettingPage> createState() =>
      _CustomProfileSettingPageState();
}

class _CustomProfileSettingPageState extends State<CustomProfileSettingPage> {
  CustomTabbarController get controller => Get.find();

  LocaleService get localeService => Get.find();

  final _searchWithMinRating = false.obs;
  final _searchBetweenPage = false.obs;
  final _enableAdvance = false.obs;
  final _listModeIsPopular = false.obs;

  late CustomProfile _customProfile;
  late final TextEditingController _nameController;
  late final bool _isExisting;

  @override
  void initState() {
    super.initState();

    if (Get.isRegistered<TagTransController>() &&
        Get.isRegistered<LocaleService>() &&
        Get.isRegistered<EhSettingService>()) {
      Get.put(ProfileEditController());
    }

    logger.d('Get.arguments runtimeType ${Get.arguments.runtimeType}');

    // _customProfile = Get.arguments is CustomProfile
    //     ? Get.arguments as CustomProfile
    //     : CustomProfile(name: '', uuid: generateUuidv4());

    // arguments 方式不能跨栈传递，改回依赖注入
    _customProfile = Get.find<CustomProfile>();
    _nameController = TextEditingController(text: _customProfile.name);
    _isExisting =
        Get.isRegistered<CustomTabbarController>() &&
        controller.profileMap.containsKey(_customProfile.uuid);

    _searchWithMinRating.value =
        _customProfile.advSearch?.searchWithMinRating ?? false;
    _searchBetweenPage.value =
        _customProfile.advSearch?.searchBetweenPage ?? false;
    _enableAdvance.value = _customProfile.enableAdvance ?? false;

    _listModeIsPopular.value =
        _customProfile.listType == GalleryListType.popular;
  }

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    FocusScope.of(context).requestFocus(FocusNode());
    logger.d('_customProfile ${jsonEncode(_customProfile)}');

    if (_customProfile.name.trim().isEmpty) {
      showToast('Name is empty');
      return;
    }

    final result = _customProfile.copyWith(
      lastEditTime: DateTime.now().millisecondsSinceEpoch.oN,
    );
    if (PlatformCapabilities.isDesktop) {
      Navigator.of(context).maybePop(result);
    } else {
      Get.back(
        id: detailNavigatorId,
        result: result,
      );
    }
  }

  Future<void> _confirmDelete() async {
    if (!Get.isRegistered<CustomTabbarController>()) {
      return;
    }
    final deleted = await controller.confirmDeleteGroup(
      context,
      _customProfile,
    );
    if (deleted && mounted && Navigator.of(context).canPop()) {
      Navigator.of(context).pop();
    }
  }

  String _desktopListModeLabel(L10n l10n, ListModeEnum mode) {
    if (mode == ListModeEnum.global) {
      return l10n.global_setting;
    }
    final includeDebug =
        !kReleaseMode ||
        (Get.isRegistered<EhSettingService>() &&
            Get.find<EhSettingService>().debugMode);
    final labels = desktopListModeLabels(l10n, includeDebug: includeDebug);
    return labels[mode] ?? l10n.global_setting;
  }

  Future<void> _showListModeMenu(BuildContext anchor) {
    final l10n = L10n.of(context);
    final includeDebug =
        !kReleaseMode ||
        (Get.isRegistered<EhSettingService>() &&
            Get.find<EhSettingService>().debugMode);
    final labels = desktopListModeLabels(l10n, includeDebug: includeDebug);
    final entries = <DesktopMenuEntry>[
      DesktopMenuEntry(
        label: l10n.global_setting,
        icon: CupertinoIcons.globe,
        selected: _customProfile.listMode == ListModeEnum.global,
        onSelected: () {
          setState(() {
            _customProfile = _customProfile.copyWith(
              listModeValue: ListModeEnum.global.name.oN,
            );
          });
        },
      ),
      for (final entry in labels.entries)
        DesktopMenuEntry(
          label: entry.value,
          icon: CupertinoIcons.square_grid_2x2,
          selected: _customProfile.listMode == entry.key,
          onSelected: () {
            setState(() {
              _customProfile = _customProfile.copyWith(
                listModeValue: entry.key.name.oN,
              );
            });
          },
        ),
    ];
    return showDesktopGalleryMenu(
      context,
      position: desktopMenuAnchor(anchor),
      entries: entries,
    );
  }

  void _invertCats() {
    final catMap = EHUtils.convNumToCatMap(_customProfile.cats ?? 0);
    catMap.updateAll((_, selected) => !selected);
    setState(() {
      _customProfile = _customProfile.copyWith(
        cats: EHUtils.convCatMapToNum(catMap).oN,
      );
    });
  }

  Future<String?> _translateKeyword(String keyword) async {
    if (!Get.isRegistered<TagTransController>() ||
        !Get.isRegistered<LocaleService>() ||
        !Get.isRegistered<EhSettingService>()) {
      return null;
    }
    final ehSetting = Get.find<EhSettingService>();
    final locale = Get.find<LocaleService>();
    if (!ehSetting.isTagTranslate || !locale.isLanguageCodeZh) {
      return null;
    }
    final translated = await Get.find<TagTransController>()
        .getTranTagWithNameSpaseAuto(keyword);
    if (translated != null && translated.trim() != keyword) {
      return translated;
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    if (PlatformCapabilities.isDesktop) {
      return _buildDesktop(context);
    }
    return SettingScaffold(
      title: '',
      // Beside the group list, which keeps its own buttons.
      nativeChrome: false,
      trailing: CupertinoButton(
        minSize: 40,
        padding: EdgeInsets.zero,
        onPressed: _save,
        child: const EhSvgIcon(CupertinoIcons.checkmark, size: 22),
      ),
      child: CustomScrollView(
        slivers: [
          SliverSafeArea(
            sliver: buildCustomProfileEditView(),
          ),
        ],
      ),
    );
  }

  Widget _buildDesktop(BuildContext context) {
    final l10n = L10n.of(context);
    final palette = ehTheme.palette;
    final title = _customProfile.name.trim().isNotEmpty
        ? _customProfile.name.trim()
        : l10n.newGroup;
    final isPopular = _customProfile.listType == GalleryListType.popular;
    final adv = _customProfile.advSearch ?? const AdvanceSearch();
    final keywords = (_customProfile.searchText ?? const <dynamic>[])
        .map((e) => '$e')
        .toList();
    final catNum = _customProfile.cats ?? 0;

    return NativeNavigationPage(
      chrome: NativePageChrome(
        title: title,
        navigationBarVisible: false,
        ownBar: true,
      ),
      child: CupertinoPageScaffold(
        backgroundColor: CupertinoTheme.of(context).scaffoldBackgroundColor,
        child: Column(
          children: [
            DesktopPaneHeader(
              title: title,
              leading: [
                if (Navigator.of(context).canPop())
                  DesktopControl(
                    key: const ValueKey('desktop-profile-back'),
                    label: l10n.back,
                    minSize: 30,
                    radius: 8,
                    padding: const EdgeInsets.all(6),
                    onPressed: () => Navigator.of(context).maybePop(),
                    child: const EhSvgIcon(CupertinoIcons.chevron_back, size: 16),
                  ),
              ],
              trailing: [
                if (_isExisting) ...[
                  DesktopControl(
                    key: const ValueKey('desktop-profile-delete'),
                    label: l10n.delete,
                    minSize: 30,
                    radius: 8,
                    padding: const EdgeInsets.all(6),
                    onPressed: _confirmDelete,
                    child: EhSvgIcon(
                      CupertinoIcons.trash,
                      size: 15,
                      color: CupertinoDynamicColor.resolve(
                        CupertinoColors.systemRed,
                        context,
                      ),
                    ),
                  ),
                  const SizedBox(width: 6),
                ],
                DesktopToolbarPill(
                  key: const ValueKey('desktop-profile-save'),
                  label: l10n.save,
                  icon: CupertinoIcons.checkmark,
                  iconSize: 13,
                  tone: DesktopPillTone.prominent,
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  onPressed: _save,
                ),
              ],
            ),
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
                child: Align(
                  alignment: Alignment.topCenter,
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 640),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        _DesktopFormCard(
                          children: [
                            Padding(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 14,
                                vertical: 10,
                              ),
                              child: Row(
                                children: [
                                  SizedBox(
                                    width: 96,
                                    child: Text(
                                      l10n.groupName,
                                      style: TextStyle(
                                        fontSize: 13,
                                        color: palette.text2.resolveFrom(
                                          context,
                                        ),
                                      ),
                                    ),
                                  ),
                                  Expanded(
                                    child: CupertinoTextField(
                                      key: const ValueKey(
                                        'desktop-profile-name-input',
                                      ),
                                      controller: _nameController,
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 10,
                                        vertical: 7,
                                      ),
                                      decoration: BoxDecoration(
                                        color: palette.surface.resolveFrom(
                                          context,
                                        ),
                                        borderRadius: BorderRadius.circular(7),
                                        border: Border.all(
                                          color: palette.hairline.resolveFrom(
                                            context,
                                          ),
                                        ),
                                      ),
                                      style: TextStyle(
                                        fontSize: 13.5,
                                        color: palette.text1.resolveFrom(
                                          context,
                                        ),
                                      ),
                                      onChanged: (val) {
                                        setState(() {
                                          _customProfile =
                                              _customProfile.copyWith(
                                                name: val,
                                              );
                                        });
                                      },
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            Padding(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 14,
                                vertical: 8,
                              ),
                              child: Row(
                                children: [
                                  SizedBox(
                                    width: 96,
                                    child: Text(
                                      l10n.list_mode,
                                      style: TextStyle(
                                        fontSize: 13,
                                        color: palette.text2.resolveFrom(
                                          context,
                                        ),
                                      ),
                                    ),
                                  ),
                                  const Spacer(),
                                  Builder(
                                    builder: (anchor) => DesktopControl(
                                      key: const ValueKey(
                                        'desktop-profile-list-mode',
                                      ),
                                      label: l10n.list_mode,
                                      minSize: 30,
                                      radius: 8,
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 10,
                                        vertical: 5,
                                      ),
                                      onPressed: () =>
                                          _showListModeMenu(anchor),
                                      child: Row(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          Text(
                                            _desktopListModeLabel(
                                              l10n,
                                              _customProfile.listMode,
                                            ),
                                            style: TextStyle(
                                              fontSize: 13,
                                              color: palette.text1.resolveFrom(
                                                context,
                                              ),
                                            ),
                                          ),
                                          const SizedBox(width: 6),
                                          EhSvgIcon(
                                            CupertinoIcons
                                                .chevron_up_chevron_down,
                                            size: 12,
                                            color: palette.text3.resolveFrom(
                                              context,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            Padding(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 14,
                                vertical: 10,
                              ),
                              child: Row(
                                children: [
                                  SizedBox(
                                    width: 96,
                                    child: Text(
                                      l10n.groupType,
                                      style: TextStyle(
                                        fontSize: 13,
                                        color: palette.text2.resolveFrom(
                                          context,
                                        ),
                                      ),
                                    ),
                                  ),
                                  Expanded(
                                    child: _ListTypeSelector(
                                      initValue: _customProfile.listType,
                                      embedded: true,
                                      onChanged: (GalleryListType value) {
                                        setState(() {
                                          _customProfile = _customProfile
                                              .copyWith(
                                                listTypeValue: value.name.oN,
                                              );
                                          _listModeIsPopular.value =
                                              value == GalleryListType.popular;
                                        });
                                      },
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                        if (!isPopular) ...[
                          const SizedBox(height: 16),
                          _DesktopFormCard(
                            header: l10n.sp_category,
                            headerTrailing: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                DesktopToolbarPill(
                                  key: const ValueKey(
                                    'desktop-profile-cat-select-all',
                                  ),
                                  label: l10n.sp_select_all,
                                  tone: DesktopPillTone.tonal,
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 8,
                                  ),
                                  onPressed: catNum == 0
                                      ? null
                                      : () {
                                          setState(() {
                                            _customProfile = _customProfile
                                                .copyWith(cats: 0.oN);
                                          });
                                        },
                                ),
                                const SizedBox(width: 6),
                                DesktopToolbarPill(
                                  key: const ValueKey(
                                    'desktop-profile-cat-invert',
                                  ),
                                  label: l10n.sp_invert_selection,
                                  tone: DesktopPillTone.subtle,
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 8,
                                  ),
                                  onPressed: _invertCats,
                                ),
                              ],
                            ),
                            children: [
                              GalleryCatFilter(
                                catNum: catNum,
                                maxCrossAxisExtent: 140,
                                padding: const EdgeInsets.all(12),
                                onCatNumChanged: (int value) {
                                  setState(() {
                                    _customProfile = _customProfile.copyWith(
                                      cats: value.oN,
                                    );
                                  });
                                },
                              ),
                            ],
                          ),
                          const SizedBox(height: 16),
                          _DesktopFormCard(
                            header: l10n.searchTexts,
                            children: [
                              for (var i = 0; i < keywords.length; i++)
                                _DesktopSearchKeywordRow(
                                  keyword: keywords[i],
                                  translateFuture: _translateKeyword(
                                    keywords[i],
                                  ),
                                  onRemove: () {
                                    setState(() {
                                      final updated = List<String>.of(keywords)
                                        ..removeAt(i);
                                      _customProfile = _customProfile.copyWith(
                                        searchText: updated.oN,
                                      );
                                    });
                                  },
                                ),
                              _DesktopSearchAddRow(
                                label: '${l10n.newText} ...',
                                onPressed: () async {
                                  if (!Get.isRegistered<
                                    ProfileEditController
                                  >()) {
                                    return;
                                  }
                                  final result = await showSearchTextDialog(
                                    context,
                                  );
                                  if (result != null && result.isNotEmpty) {
                                    setState(() {
                                      final updated = List<String>.of(keywords)
                                        ..add(result);
                                      _customProfile = _customProfile.copyWith(
                                        searchText: updated.oN,
                                      );
                                    });
                                  }
                                },
                              ),
                            ],
                          ),
                          const SizedBox(height: 16),
                          _DesktopFormCard(
                            children: [
                              _DesktopSwitchRow(
                                label: l10n.s_Advanced_Options,
                                value: _customProfile.enableAdvance ?? false,
                                onChanged: (val) {
                                  setState(() {
                                    _enableAdvance.value = val;
                                    _customProfile = _customProfile.copyWith(
                                      enableAdvance: val.oN,
                                    );
                                  });
                                },
                              ),
                            ],
                          ),
                          if (_customProfile.enableAdvance ?? false) ...[
                            const SizedBox(height: 12),
                            _DesktopFormCard(
                              children: [
                                _DesktopSwitchRow(
                                  label: l10n.s_Only_Show_Galleries_With_Torrents,
                                  value: adv.requireGalleryTorrent ?? false,
                                  onChanged: (val) {
                                    setState(() {
                                      _customProfile = _customProfile.copyWith(
                                        advSearch: adv
                                            .copyWith(
                                              requireGalleryTorrent: val.oN,
                                            )
                                            .oN,
                                      );
                                    });
                                  },
                                ),
                                _DesktopSwitchRow(
                                  label: l10n.s_Show_Expunged_Galleries,
                                  value: adv.browseExpungedGalleries ?? false,
                                  onChanged: (val) {
                                    setState(() {
                                      _customProfile = _customProfile.copyWith(
                                        advSearch: adv
                                            .copyWith(
                                              browseExpungedGalleries: val.oN,
                                            )
                                            .oN,
                                      );
                                    });
                                  },
                                ),
                              ],
                            ),
                            const SizedBox(height: 12),
                            _DesktopFormCard(
                              children: [
                                _DesktopSwitchRow(
                                  label: l10n.s_Minimum_Rating,
                                  value: adv.searchWithMinRating ?? false,
                                  onChanged: (val) {
                                    setState(() {
                                      _customProfile = _customProfile.copyWith(
                                        advSearch: adv
                                            .copyWith(
                                              searchWithMinRating: val.oN,
                                            )
                                            .oN,
                                      );
                                    });
                                  },
                                ),
                                if (adv.searchWithMinRating ?? false)
                                  _MinRatingSelector(
                                    initValue: adv.minRating ?? 2,
                                    embedded: true,
                                    onChanged: (int value) {
                                      setState(() {
                                        _customProfile = _customProfile
                                            .copyWith(
                                              advSearch: adv
                                                  .copyWith(
                                                    minRating: value == 2
                                                        ? null
                                                        : value.oN,
                                                  )
                                                  .oN,
                                            );
                                      });
                                    },
                                  ),
                              ],
                            ),
                            const SizedBox(height: 12),
                            _DesktopFormCard(
                              children: [
                                _DesktopSwitchRow(
                                  label: l10n.s_pages,
                                  value: adv.searchBetweenPage ?? false,
                                  onChanged: (val) {
                                    setState(() {
                                      _customProfile = _customProfile.copyWith(
                                        advSearch: adv
                                            .copyWith(searchBetweenPage: val.oN)
                                            .oN,
                                      );
                                    });
                                  },
                                ),
                                if (adv.searchBetweenPage ?? false)
                                  _BetweenPageTile(
                                    enable: adv.searchBetweenPage ?? false,
                                    startPage: adv.startPage,
                                    endPage: adv.endPage,
                                    onStartPageChanged: (val) {
                                      _customProfile = _customProfile.copyWith(
                                        advSearch: adv
                                            .copyWith(startPage: val.trim().oN)
                                            .oN,
                                      );
                                    },
                                    onEndPageChanged: (val) {
                                      _customProfile = _customProfile.copyWith(
                                        advSearch: adv
                                            .copyWith(endPage: val.trim().oN)
                                            .oN,
                                      );
                                    },
                                  ),
                              ],
                            ),
                            const SizedBox(height: 16),
                            _DesktopFormCard(
                              header: l10n.s_Disable_default_filters,
                              children: [
                                _DesktopSwitchRow(
                                  label: l10n.language,
                                  value:
                                      adv.disableCustomFilterLanguage ?? false,
                                  onChanged: (val) {
                                    setState(() {
                                      _customProfile = _customProfile.copyWith(
                                        advSearch: adv
                                            .copyWith(
                                              disableCustomFilterLanguage:
                                                  val.oN,
                                            )
                                            .oN,
                                      );
                                    });
                                  },
                                ),
                                _DesktopSwitchRow(
                                  label: l10n.uploader,
                                  value:
                                      adv.disableCustomFilterUploader ?? false,
                                  onChanged: (val) {
                                    setState(() {
                                      _customProfile = _customProfile.copyWith(
                                        advSearch: adv
                                            .copyWith(
                                              disableCustomFilterUploader:
                                                  val.oN,
                                            )
                                            .oN,
                                      );
                                    });
                                  },
                                ),
                                _DesktopSwitchRow(
                                  label: l10n.tags,
                                  value: adv.disableCustomFilterTags ?? false,
                                  onChanged: (val) {
                                    setState(() {
                                      _customProfile = _customProfile.copyWith(
                                        advSearch: adv
                                            .copyWith(
                                              disableCustomFilterTags: val.oN,
                                            )
                                            .oN,
                                      );
                                    });
                                  },
                                ),
                              ],
                            ),
                          ],
                        ],
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget buildCustomProfileEditView() {
    List<Widget> _mainTiles = [
      SliverCupertinoListSection.listInsetGrouped(children: [
        CupertinoTextInputListTile(
          title: L10n.of(context).groupName,
          initValue: _customProfile.name,
          onChanged: (String val) {
            _customProfile = _customProfile.copyWith(name: val);
          },
        )
      ]),

      //
      SliverCupertinoListSection.listInsetGrouped(children: [
        _buildListModeItem(
          context,
          listMode: _customProfile.listMode,
          onValueChanged: (ListModeEnum val) {
            _customProfile =
                _customProfile.copyWith(listModeValue: val.name.oN);
          },
        ),
      ]),

      //
      SliverCupertinoListSection.listInsetGrouped(
        header: Text(L10n.of(context).groupType),
        children: [
          _ListTypeSelector(
            initValue: _customProfile.listType,
            onChanged: (GalleryListType value) {
              _customProfile =
                  _customProfile.copyWith(listTypeValue: value.name.oN);
              _listModeIsPopular.value = value == GalleryListType.popular;
            },
          ),
        ],
      ),
    ];

    List<Widget> _slivers = [
      //
      SliverCupertinoListSection.listInsetGrouped(children: [
        GalleryCatFilter(
          catNum: _customProfile.cats ?? 0,
          maxCrossAxisExtent: 150,
          padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 20),
          onCatNumChanged: (int value) {
            logger.d('onCatNumChanged $value');
            _customProfile = _customProfile.copyWith(cats: value.oN);
          },
        ),
      ]),

      _SearchTextTile(
        searchTextList:
            _customProfile.searchText?.map((e) => '$e').toList() ?? [],
        onChanged: (List<String> val) {
          _customProfile = _customProfile.copyWith(searchText: val.oN);
        },
      ),

      // 高级选项开关
      SliverCupertinoListSection.listInsetGrouped(children: [
        // switch s_Advanced_Options
        Obx(() {
          // 使用 _enableAdvance obs 变量，避免和下发开关展开情况不同步
          return EhCupertinoSwitchListTile(
            title: Text(L10n.of(context).s_Advanced_Options),
            value: _enableAdvance.value,
            onChanged: (val) {
              _customProfile = _customProfile.copyWith(enableAdvance: val.oN);
              _enableAdvance.value = val;
            },
          );
        }),
      ]),
    ];

    return SliverAnimatedPaintExtent(
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeInOut,
      child: Obx(() {
        return MultiSliver(
          children: [
            MultiSliver(children: _mainTiles),
            if (!_listModeIsPopular.value)
              MultiSliver(
                children: [
                  MultiSliver(
                    children: _slivers,
                  ),
                  if (_enableAdvance.value)
                    _AdvanceView(
                      advanceSearch:
                          _customProfile.advSearch ?? const AdvanceSearch(),
                      onChanged: (AdvanceSearch val) {
                        _customProfile =
                            _customProfile.copyWith(advSearch: val.oN);
                      },
                    )
                ],
              ),
          ],
        );
      }),
    );
  }
}

/// 列表模式切换
Widget _buildListModeItem(
  BuildContext context, {
  required ListModeEnum listMode,
  required ValueChanged<ListModeEnum> onValueChanged,
}) {
  final String _title = L10n.of(context).list_mode;

  final Map<ListModeEnum, String> modeMap = <ListModeEnum, String>{
    ListModeEnum.global: L10n.of(context).global_setting,
    ListModeEnum.list: L10n.of(context).listmode_medium,
    ListModeEnum.simpleList: L10n.of(context).listmode_small,
    ListModeEnum.waterfall: L10n.of(context).listmode_waterfall,
    ListModeEnum.waterfallLarge: L10n.of(context).listmode_waterfall_large,
    ListModeEnum.grid: L10n.of(context).listmode_grid,
    ListModeEnum.gridTags: L10n.of(context).listmode_grid_tags,
    if (!kReleaseMode || Get.find<EhSettingService>().debugMode)
      ListModeEnum.debugSimple: 'debugSimple',
  };
  return SelectorCupertinoListTile<ListModeEnum>(
    title: _title,
    actionMap: modeMap,
    initVal: listMode,
    onValueChanged: onValueChanged,
  );
}

class _MinRatingSelector extends StatefulWidget {
  const _MinRatingSelector({
    this.onChanged,
    this.initValue,
    this.embedded = false,
  });

  final ValueChanged<int>? onChanged;
  final int? initValue;
  final bool embedded;

  @override
  State<_MinRatingSelector> createState() => _MinRatingSelectorState();
}

class _MinRatingSelectorState extends State<_MinRatingSelector> {
  int? _initValue;

  Widget _buildSlidingSegmentedAction(String title) {
    return Padding(
      padding: kSegmentedPadding,
      child: Text(title),
      // constraints: BoxConstraints(minWidth: 10),
    );
  }

  @override
  void initState() {
    super.initState();
    _initValue = widget.initValue;
  }

  @override
  Widget build(BuildContext context) {
    final control = CupertinoSlidingSegmentedControl<int>(
      children: <int, Widget>{
        2: _buildSlidingSegmentedAction(L10n.of(context).s_stars('2')),
        3: _buildSlidingSegmentedAction(L10n.of(context).s_stars('3')),
        4: _buildSlidingSegmentedAction(L10n.of(context).s_stars('4')),
        5: _buildSlidingSegmentedAction(L10n.of(context).s_stars('5')),
      },
      groupValue: _initValue,
      onValueChanged: (int? value) {
        if (value == null) {
          return;
        }
        setState(() {
          _initValue = value;
        });
        widget.onChanged?.call(value);
      },
    );
    if (widget.embedded) {
      return Padding(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        child: SizedBox(width: double.infinity, child: control),
      );
    }
    return Container(
      width: double.infinity,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
        constraints: const BoxConstraints(minHeight: kItemHeight),
        child: SafeArea(child: control),
      ),
    );
  }
}

class _ListTypeSelector extends StatefulWidget {
  const _ListTypeSelector({
    this.onChanged,
    this.initValue,
    this.embedded = false,
  });

  final ValueChanged<GalleryListType>? onChanged;
  final GalleryListType? initValue;
  final bool embedded;

  @override
  State<_ListTypeSelector> createState() => _ListTypeSelectorState();
}

class _ListTypeSelectorState extends State<_ListTypeSelector> {
  GalleryListType? _initValue;

  Widget _buildSlidingSegmentedAction(String title) {
    return Container(
      padding: kSegmentedPadding,
      child: Text(
        title,
        style: kSegmentedTextStyle,
        maxLines: 2,
        overflow: TextOverflow.ellipsis,
        textAlign: TextAlign.center,
      ),
      // constraints: BoxConstraints(minWidth: 10),
    );
  }

  @override
  void initState() {
    super.initState();
    _initValue = widget.initValue;
  }

  @override
  Widget build(BuildContext context) {
    final control = CupertinoSlidingSegmentedControl<GalleryListType>(
      children: <GalleryListType, Widget>{
        GalleryListType.popular: _buildSlidingSegmentedAction(
          L10n.of(context).tab_popular,
        ),
        GalleryListType.gallery: _buildSlidingSegmentedAction(
          L10n.of(context).tab_gallery,
        ),
        GalleryListType.watched: _buildSlidingSegmentedAction(
          L10n.of(context).tab_watched,
        ),
      },
      groupValue: _initValue,
      onValueChanged: (GalleryListType? value) {
        if (value == null) {
          return;
        }
        setState(() {
          _initValue = value;
        });
        widget.onChanged?.call(value);
      },
    );
    if (widget.embedded) {
      return control;
    }
    return Container(
      width: double.infinity,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
        constraints: const BoxConstraints(minHeight: kItemHeight),
        child: SafeArea(child: control),
      ),
    );
  }
}

class _BetweenPageTile extends StatefulWidget {
  const _BetweenPageTile({
    this.enable = false,
    this.startPage,
    this.endPage,
    this.onStartPageChanged,
    this.onEndPageChanged,
  });

  final bool enable;
  final String? startPage;
  final String? endPage;
  final ValueChanged<String>? onStartPageChanged;
  final ValueChanged<String>? onEndPageChanged;

  @override
  State<_BetweenPageTile> createState() => _BetweenPageTileState();
}

class _BetweenPageTileState extends State<_BetweenPageTile> {
  late final TextEditingController _start;
  late final TextEditingController _end;

  @override
  void initState() {
    super.initState();
    _start = TextEditingController(text: widget.startPage);
    _end = TextEditingController(text: widget.endPage);
  }

  @override
  void dispose() {
    _start.dispose();
    _end.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      height: kItemHeight,
      padding: const EdgeInsetsDirectional.only(start: 20.0, end: 14.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.start,
        children: [
          // start page
          Expanded(
            child: CupertinoTextField(
                keyboardType: TextInputType.number,
                // cursorHeight: 14,
                textAlign: TextAlign.center,
                enabled: widget.enable,
                style: const TextStyle(
                  height: 1.2,
                  textBaseline: TextBaseline.alphabetic,
                ),
                onChanged: widget.onStartPageChanged,
                controller: _start),
          ),

          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 10),
            child: Text(L10n.of(context).s_and),
          ),

          // end page
          Expanded(
            child: CupertinoTextField(
              keyboardType: TextInputType.number,
              textAlign: TextAlign.center,
              // cursorHeight: 14,
              enabled: widget.enable,
              style: const TextStyle(
                height: 1.2,
                textBaseline: TextBaseline.alphabetic,
              ),
              onChanged: widget.onEndPageChanged,
              controller: _end,
            ),
          ),
        ],
      ),
    );
  }
}

class _SearchTextTile extends StatefulWidget {
  const _SearchTextTile({
    required this.searchTextList,
    this.onChanged,
  });

  final List<String> searchTextList;
  final ValueChanged<List<String>>? onChanged;

  @override
  State<_SearchTextTile> createState() => _SearchTextTileState();
}

class _SearchTextTileState extends State<_SearchTextTile> {
  Future<String?> _getTextTranslate(String text) async {
    final String? tranText =
        await Get.find<TagTransController>().getTranTagWithNameSpaseAuto(text);
    if (tranText?.trim() != text) {
      return tranText;
    }
    return null;
  }

  late ProfileEditController controller;

  late List<String> _searchTextList;

  @override
  void initState() {
    super.initState();
    controller = Get.put(ProfileEditController());
    _searchTextList = widget.searchTextList;
  }

  @override
  Widget build(BuildContext context) {
    return SliverCupertinoListSection.listInsetGrouped(
      header: Text(L10n.of(context).searchTexts),
      children: [
        ..._searchTextList.map((element) => Slidable(
            endActionPane: ActionPane(
              extentRatio: 0.25,
              motion: const ScrollMotion(),
              children: [
                SlidableAction(
                  onPressed: (_) {
                    setState(() {
                      _searchTextList.remove(element);
                      widget.onChanged?.call(_searchTextList);
                    });
                  },
                  backgroundColor: CupertinoDynamicColor.resolve(
                      CupertinoColors.systemRed, context),
                  icon: CupertinoIcons.delete,
                ),
              ],
            ),
            child: controller.isTagTranslate
                ? FutureBuilder<String?>(
                    future: _getTextTranslate(element),
                    initialData: element,
                    builder: (context, snapshot) {
                      return EhCupertinoListTile(
                        title: Text(element),
                        subtitle:
                            snapshot.data != null ? Text(snapshot.data!) : null,
                        key: ValueKey(element),
                      );
                    })
                : EhCupertinoListTile(
                    title: Text(element),
                    key: ValueKey(element),
                  ))),
        EhCupertinoListTile(
          title: Text(
            '${L10n.of(context).newText} ...',
            style: const TextStyle(
              color: CupertinoColors.activeBlue,
            ),
          ),
          onTap: () async {
            final result = await showSearchTextDialog(context);
            if (result != null && result.isNotEmpty) {
              setState(() {
                _searchTextList.add(result);
                widget.onChanged?.call(_searchTextList);
              });
            }
          },
        ),
      ],
    );
  }
}

class _AdvanceView extends StatefulWidget {
  const _AdvanceView({required this.advanceSearch, this.onChanged});

  final AdvanceSearch advanceSearch;
  final ValueChanged<AdvanceSearch>? onChanged;

  @override
  State<_AdvanceView> createState() => _AdvanceViewState();
}

class _AdvanceViewState extends State<_AdvanceView> {
  late AdvanceSearch _advanceSearch;

  @override
  void initState() {
    super.initState();
    _advanceSearch = widget.advanceSearch;
  }

  @override
  Widget build(BuildContext context) {
    return MultiSliver(
      children: [
        SliverCupertinoListSection.listInsetGrouped(
          children: [
            // s_Only_Show_Galleries_With_Torrents switch
            EhCupertinoSwitchListTile(
              title: Text(L10n.of(context).s_Only_Show_Galleries_With_Torrents),
              value: _advanceSearch.requireGalleryTorrent ?? false,
              onChanged: (val) {
                _advanceSearch =
                    _advanceSearch.copyWith(requireGalleryTorrent: val.oN);
                widget.onChanged?.call(_advanceSearch);
              },
            ),

            // s_Show_Expunged_Galleries switch
            EhCupertinoSwitchListTile(
              title: Text(L10n.of(context).s_Show_Expunged_Galleries),
              value: _advanceSearch.browseExpungedGalleries ?? false,
              onChanged: (val) {
                _advanceSearch =
                    _advanceSearch.copyWith(browseExpungedGalleries: val.oN);
                widget.onChanged?.call(_advanceSearch);
              },
            ),
          ],
        ),

        StatefulBuilder(builder: (context, setState) {
          return SliverCupertinoListSection.listInsetGrouped(
            children: [
              // s_Minimum_Rating switch
              Column(
                children: [
                  EhCupertinoSwitchListTile(
                    title: Text(L10n.of(context).s_Minimum_Rating),
                    value: _advanceSearch.searchWithMinRating ?? false,
                    onChanged: (val) {
                      _advanceSearch =
                          _advanceSearch.copyWith(searchWithMinRating: val.oN);

                      setState(() {});
                      widget.onChanged?.call(_advanceSearch);
                    },
                  ),
                  AnimatedCrossFade(
                    firstCurve: Curves.easeIn,
                    secondCurve: Curves.easeOut,
                    firstChild: const SizedBox(width: double.infinity),
                    secondChild: _MinRatingSelector(
                      initValue: _advanceSearch.minRating ?? 2,
                      onChanged: (int value) {
                        _advanceSearch = _advanceSearch.copyWith(
                            minRating: value == 2 ? null : value.oN);
                        widget.onChanged?.call(_advanceSearch);
                      },
                    ),
                    crossFadeState: _advanceSearch.searchWithMinRating ?? false
                        ? CrossFadeState.showSecond
                        : CrossFadeState.showFirst,
                    duration: const Duration(milliseconds: 300),
                  ),
                ],
              ),
            ],
          );
        }),

        //
        StatefulBuilder(builder: (context, setState) {
          return SliverCupertinoListSection.listInsetGrouped(
            children: [
              Column(
                children: [
                  // searchBetweenPage switch
                  EhCupertinoSwitchListTile(
                    title: Text(L10n.of(context).s_pages),
                    value: _advanceSearch.searchBetweenPage ?? false,
                    onChanged: (val) {
                      _advanceSearch =
                          _advanceSearch.copyWith(searchBetweenPage: val.oN);

                      widget.onChanged?.call(_advanceSearch);
                      setState(() {});
                    },
                  ),

                  AnimatedCrossFade(
                    crossFadeState: _advanceSearch.searchBetweenPage ?? false
                        ? CrossFadeState.showSecond
                        : CrossFadeState.showFirst,
                    duration: const Duration(milliseconds: 300),
                    firstCurve: Curves.easeIn,
                    secondCurve: Curves.easeOut,
                    firstChild: const SizedBox(width: double.infinity),
                    secondChild: _BetweenPageTile(
                      enable: _advanceSearch.searchBetweenPage ?? false,
                      startPage: _advanceSearch.startPage,
                      endPage: _advanceSearch.endPage,
                      onStartPageChanged: (val) {
                        _advanceSearch =
                            _advanceSearch.copyWith(startPage: val.trim().oN);
                        widget.onChanged?.call(_advanceSearch);
                      },
                      onEndPageChanged: (val) {
                        _advanceSearch =
                            _advanceSearch.copyWith(endPage: val.trim().oN);
                        widget.onChanged?.call(_advanceSearch);
                      },
                    ),
                  ),
                ],
              ),
            ],
          );
        }),

        //
        SliverCupertinoListSection.listInsetGrouped(
          header: Text(L10n.of(context).s_Disable_default_filters),
          children: [
            // disableCustomFilterLanguage switch
            EhCupertinoSwitchListTile(
              title: Text(L10n.of(context).language),
              value: _advanceSearch.disableCustomFilterLanguage ?? false,
              onChanged: (val) {
                _advanceSearch = _advanceSearch.copyWith(
                    disableCustomFilterLanguage: val.oN);
                widget.onChanged?.call(_advanceSearch);
              },
            ),

            // disableCustomFilterUploader switch
            EhCupertinoSwitchListTile(
              title: Text(L10n.of(context).uploader),
              value: _advanceSearch.disableCustomFilterUploader ?? false,
              onChanged: (val) {
                _advanceSearch = _advanceSearch.copyWith(
                    disableCustomFilterUploader: val.oN);
                widget.onChanged?.call(_advanceSearch);
              },
            ),

            // disableCustomFilterTags switch
            EhCupertinoSwitchListTile(
              title: Text(L10n.of(context).tags),
              value: _advanceSearch.disableCustomFilterTags ?? false,
              onChanged: (val) {
                _advanceSearch =
                    _advanceSearch.copyWith(disableCustomFilterTags: val.oN);
                widget.onChanged?.call(_advanceSearch);
              },
            ),
          ],
        ),
      ],
    );
  }
}

class _DesktopFormCard extends StatelessWidget {
  const _DesktopFormCard({
    this.header,
    this.headerTrailing,
    required this.children,
  });

  final String? header;
  final Widget? headerTrailing;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    final palette = ehTheme.palette;
    final radius = DesktopBrowseStyle.cardRadius;
    final fill = DesktopBrowseStyle.cardSurface(context);
    final hairline = palette.hairline.resolveFrom(context);
    final borderRadius = BorderRadius.circular(radius);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (header != null || headerTrailing != null)
          Padding(
            padding: const EdgeInsets.fromLTRB(4, 0, 0, 8),
            child: Row(
              children: [
                if (header != null)
                  Expanded(
                    child: Text(
                      header!,
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: palette.text2.resolveFrom(context),
                      ),
                    ),
                  )
                else
                  const Spacer(),
                if (headerTrailing != null) headerTrailing!,
              ],
            ),
          ),
        DecoratedBox(
          decoration: BoxDecoration(
            color: fill,
            borderRadius: borderRadius,
            border: Border.all(color: hairline, width: 1),
          ),
          child: ClipRRect(
            borderRadius: borderRadius,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                for (var i = 0; i < children.length; i++) ...[
                  children[i],
                  if (i < children.length - 1) Container(height: 1, color: hairline),
                ],
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class _DesktopSwitchRow extends StatelessWidget {
  const _DesktopSwitchRow({
    required this.label,
    required this.value,
    required this.onChanged,
  });

  final String label;
  final bool value;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    final palette = ehTheme.palette;
    return ConstrainedBox(
      constraints: const BoxConstraints(minHeight: 44),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        child: Row(
          children: [
            Expanded(
              child: Text(
                label,
                style: TextStyle(
                  fontSize: 13.5,
                  color: palette.text1.resolveFrom(context),
                ),
              ),
            ),
            const SizedBox(width: 12),
            Transform.scale(
              scale: 0.85,
              child: CupertinoSwitch(value: value, onChanged: onChanged),
            ),
          ],
        ),
      ),
    );
  }
}

class _DesktopSearchKeywordRow extends StatelessWidget {
  const _DesktopSearchKeywordRow({
    required this.keyword,
    required this.translateFuture,
    required this.onRemove,
  });

  final String keyword;
  final Future<String?> translateFuture;
  final VoidCallback onRemove;

  @override
  Widget build(BuildContext context) {
    final l10n = L10n.of(context);
    final palette = ehTheme.palette;
    return ConstrainedBox(
      constraints: const BoxConstraints(minHeight: 44),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(14, 8, 10, 8),
        child: Row(
          children: [
            Expanded(
              child: FutureBuilder<String?>(
                future: translateFuture,
                builder: (context, snapshot) {
                  final translated = snapshot.data;
                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        keyword,
                        style: TextStyle(
                          fontSize: 13.5,
                          fontWeight: FontWeight.w500,
                          color: palette.text1.resolveFrom(context),
                        ),
                      ),
                      if (translated != null && translated.isNotEmpty) ...[
                        const SizedBox(height: 2),
                        Text(
                          translated,
                          style: TextStyle(
                            fontSize: 12,
                            color: palette.text2.resolveFrom(context),
                          ),
                        ),
                      ],
                    ],
                  );
                },
              ),
            ),
            const SizedBox(width: 8),
            DesktopControl(
              key: ValueKey('desktop-search-text-remove-$keyword'),
              label: l10n.delete,
              minSize: 26,
              radius: 6,
              padding: const EdgeInsets.all(4),
              onPressed: onRemove,
              child: EhSvgIcon(
                CupertinoIcons.xmark,
                size: 13,
                color: palette.text3.resolveFrom(context),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _DesktopSearchAddRow extends StatefulWidget {
  const _DesktopSearchAddRow({
    required this.label,
    required this.onPressed,
  });

  final String label;
  final VoidCallback onPressed;

  @override
  State<_DesktopSearchAddRow> createState() => _DesktopSearchAddRowState();
}

class _DesktopSearchAddRowState extends State<_DesktopSearchAddRow> {
  bool _hover = false;

  @override
  Widget build(BuildContext context) {
    final palette = ehTheme.palette;
    final accent = EhPalette.accent.resolveFrom(context);
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_) => setState(() => _hover = true),
      onExit: (_) => setState(() => _hover = false),
      child: GestureDetector(
        key: const ValueKey('desktop-search-text-add'),
        behavior: HitTestBehavior.opaque,
        onTap: widget.onPressed,
        child: Container(
          constraints: const BoxConstraints(minHeight: 44),
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          color: _hover
              ? palette.fill.resolveFrom(context)
              : const Color(0x00000000),
          child: Row(
            children: [
              EhSvgIcon(CupertinoIcons.add, size: 14, color: accent),
              const SizedBox(width: 6),
              Text(
                widget.label,
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w500,
                  color: accent,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
