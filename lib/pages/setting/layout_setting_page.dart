import 'package:eros_fe/common/controller/tag_trans_controller.dart';
import 'package:eros_fe/common/controller/user_controller.dart';
import 'package:eros_fe/common/service/ehsetting_service.dart';
import 'package:eros_fe/common/service/layout_service.dart';
import 'package:eros_fe/common/service/locale_service.dart';
import 'package:eros_fe/common/service/theme_service.dart';
import 'package:eros_fe/component/setting/setting_scaffold.dart';
import 'package:eros_fe/const/theme_colors.dart';
import 'package:eros_fe/debug/offline_glass.dart';
import 'package:eros_fe/index.dart';
import 'package:eros_fe/pages/login/controller/login_controller.dart';
import 'package:eros_fe/pages/setting/card_size_preview.dart';
import 'package:eros_fe/pages/setting/setting_items/selector_Item.dart';
import 'package:eros_fe/pages/tab/view/list/card_size.dart';
import 'package:eros_fe/utils/liquid_glass.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/foundation.dart';
import 'package:get/get.dart';
import 'package:sliver_tools/sliver_tools.dart';

class LayoutSettingPage extends StatelessWidget {
  const LayoutSettingPage({super.key});

  @override
  Widget build(BuildContext context) {
    return SettingScaffold(
      title: L10n.of(context).appearance_and_layout,
      child: CustomScrollView(slivers: [
        SliverSafeArea(sliver: LayoutSettingList()),
      ]),
    );
  }
}

class LayoutSettingList extends StatelessWidget {
  LayoutSettingList({super.key});

  final EhSettingService _ehSettingService = Get.find();
  final UserController userController = Get.find();
  final TagTransController transController = Get.find();
  final LocaleService localeService = Get.find();
  final LoginController loginController = Get.put(LoginController());

  @override
  Widget build(BuildContext context) {
    return MultiSliver(children: [
      SliverCupertinoListSection.listInsetGrouped(children: [
        _buildThemeItem(context),

        // dark_mode_effect: graphite or pure black (OLED)
        EhCupertinoListTile(
          title: Text(L10n.of(context).dark_mode_effect),
          trailing: Obx(() {
            return CupertinoSlidingSegmentedControl<bool>(
              groupValue: _ehSettingService.isPureDarkTheme,
              children: {
                false: Text(L10n.of(context).gray_black,
                    textScaler: const TextScaler.linear(0.8)),
                true: Text(L10n.of(context).pure_black,
                    textScaler: const TextScaler.linear(0.8))
              },
              onValueChanged: (bool? val) {
                if (val != null) {
                  _ehSettingService.isPureDarkTheme = val;
                }
              },
            );
          }),
        ),

        if (context.isTablet) _buildTableLayoutItem(context),

        // tabbar_setting
        EhCupertinoListTile(
          title: Text(L10n.of(context).tabbar_setting),
          trailing: const CupertinoListTileChevron(),
          onTap: () {
            Get.toNamed(
              EHRoutes.pageSetting,
              id: detailNavigatorId,
            );
          },
        ),
      ]),
      SliverCupertinoListSection.listInsetGrouped(
        footer: Text(L10n.of(context).japanese_title_in_gallery_summary),
        children: [
          if (localeService.isLanguageCodeZh)
            EhCupertinoListTile(
              title: const Text('标签翻译'),
              subtitle: Text('当前版本:${_ehSettingService.tagTranslatVer.value}'),
              additionalInfo: Text(_ehSettingService.isTagTranslate
                  ? L10n.of(context).on
                  : L10n.of(context).off),
              trailing: const CupertinoListTileChevron(),
              onTap: () {
                Get.toNamed(
                  EHRoutes.tagTranslate,
                  id: detailNavigatorId,
                );
              },
            ),
          // japanese_title_in_gallery
          EhCupertinoListTile(
            title: Text(L10n.of(context).japanese_title_in_gallery),
            trailing: Obx(() {
              return CupertinoSwitch(
                value: _ehSettingService.jpnTitleInGalleryPage,
                onChanged: (bool val) {
                  _ehSettingService.jpnTitleInGalleryPage = val;
                },
              );
            }),
          ),
        ],
      ),
      SliverCupertinoListSection.listInsetGrouped(
        children: [
          // showComments switch
          EhCupertinoListTile(
            title: Text(L10n.of(context).show_comments),
            trailing: Obx(() {
              return CupertinoSwitch(
                value: _ehSettingService.showComments,
                onChanged: (bool val) {
                  _ehSettingService.showComments = val;
                },
              );
            }),
          ),

          Obx(() {
            return AnimatedCrossFade(
              firstChild: const SizedBox(),
              secondChild: EhCupertinoListTile(
                title: Text(L10n.of(context).show_only_uploader_comment),
                trailing: Obx(() {
                  return CupertinoSwitch(
                    value: _ehSettingService.showOnlyUploaderComment,
                    onChanged: _ehSettingService.showComments
                        ? (bool val) {
                            _ehSettingService.showOnlyUploaderComment = val;
                          }
                        : null,
                  );
                }),
              ),
              crossFadeState: _ehSettingService.showComments
                  ? CrossFadeState.showSecond
                  : CrossFadeState.showFirst,
              secondCurve: Curves.easeOut,
              duration: const Duration(milliseconds: 200),
            );
          }),

          // showGalleryTags switch
          EhCupertinoListTile(
            title: Text(L10n.of(context).show_gallery_tags),
            trailing: Obx(() {
              return CupertinoSwitch(
                value: _ehSettingService.showGalleryTags,
                onChanged: (bool val) {
                  _ehSettingService.showGalleryTags = val;
                },
              );
            }),
          ),

          // hideGalleryThumbnails switch
          EhCupertinoListTile(
            title: Text(L10n.of(context).hide_gallery_thumbnails),
            trailing: Obx(() {
              return CupertinoSwitch(
                value: _ehSettingService.hideGalleryThumbnails,
                onChanged: (bool val) {
                  _ehSettingService.hideGalleryThumbnails = val;
                },
              );
            }),
          ),

          // horizontalThumbnails
          EhCupertinoListTile(
            title: Text(L10n.of(context).horizontal_thumbnails),
            trailing: Obx(() {
              return CupertinoSwitch(
                value: _ehSettingService.horizontalThumbnails,
                onChanged: (bool val) {
                  _ehSettingService.horizontalThumbnails = val;
                },
              );
            }),
          ),
        ],
      ),
      if (LiquidGlassPlatform.isSupported)
        SliverCupertinoListSection.listInsetGrouped(
          footer: Obx(() {
            return Text(_ehSettingService.liquidGlass
                ? 'iOS 26+ 使用原生 Liquid Glass；与“滚动隐藏顶栏”独立，支持灵动岛或刘海安全区收束。\n'
                    '“使用系统 Liquid Glass 外观”开启时使用系统原生 Liquid Glass；关闭时使用传统材质，并遵循辅助功能中的降低透明度。'
                : 'iOS 26+ 使用原生 Liquid Glass；与“滚动隐藏顶栏”独立，支持灵动岛或刘海安全区收束。');
          }),
          children: [
            EhCupertinoListTile(
              title: const Text('iOS 液态玻璃'),
              trailing: Obx(() {
                return offlineGlassControl(
                    'enabled',
                    CupertinoSwitch(
                      value: _ehSettingService.liquidGlass,
                      onChanged: (bool val) {
                        _ehSettingService.liquidGlass = val;
                      },
                    ));
              }),
            ),
            Obx(() {
              if (!_ehSettingService.liquidGlass) {
                return const SizedBox.shrink();
              }
              return EhCupertinoListTile(
                title: const Text('使用系统 Liquid Glass 外观'),
                trailing: CupertinoSwitch(
                  value: _ehSettingService.liquidGlassFollowSystemTransparency,
                  onChanged: (bool val) {
                    _ehSettingService.liquidGlassFollowSystemTransparency = val;
                  },
                ),
              );
            }),
            Obx(() {
              if (!_ehSettingService.liquidGlass) {
                return const SizedBox.shrink();
              }
              final l10n = L10n.of(context);
              String name(LiquidGlassTopBarLayout layout) =>
                  layout == LiquidGlassTopBarLayout.twoRow
                      ? l10n.liquid_glass_two_row
                      : l10n.liquid_glass_inline;
              return SelectorCupertinoListTile<LiquidGlassTopBarLayout>(
                title: l10n.liquid_glass_top_layout,
                actionMap: {
                  for (final layout in LiquidGlassTopBarLayout.values)
                    layout: name(layout),
                },
                subtitleMap: {
                  for (final layout in LiquidGlassTopBarLayout.values)
                    layout: layout == LiquidGlassTopBarLayout.twoRow
                        ? l10n.liquid_glass_two_row_detail
                        : l10n.liquid_glass_inline_detail,
                },
                initVal: _ehSettingService.liquidGlassTopBarLayout,
                onValueChanged: (selected) =>
                    _ehSettingService.liquidGlassTopBarLayout = selected,
              );
            }),
          ],
        ),
      SliverCupertinoListSection.listInsetGrouped(children: [
        // hide_top_bar_on_scroll switch
        EhCupertinoListTile(
          title: Text(L10n.of(context).hide_top_bar_on_scroll),
          trailing: Obx(() {
            return CupertinoSwitch(
              value: _ehSettingService.hideTopBarOnScroll,
              onChanged: (bool val) {
                _ehSettingService.hideTopBarOnScroll = val;
              },
            );
          }),
        ),

        // isGalleryImgBlur
        if (localeService.isLanguageCodeZh)
          EhCupertinoListTile(
            title: Text('画廊列表封面模糊处理'),
            trailing: Obx(() {
              return CupertinoSwitch(
                value: _ehSettingService.isGalleryImgBlur.value,
                onChanged: (bool val) {
                  _ehSettingService.isGalleryImgBlur.value = val;
                },
              );
            }),
          ),

        _buildListModeItem(context),

        // Card style of the large waterfall
        Obx(() {
          if (_ehSettingService.listMode.value != ListModeEnum.waterfallLarge) {
            return const SizedBox.shrink();
          }
          final l10n = L10n.of(context);
          return SelectorCupertinoListTile<bool>(
            title: l10n.card_style,
            actionMap: <bool, String>{
              false: l10n.card_style_standard,
              true: l10n.card_style_immersive,
            },
            subtitleMap: <bool, String>{
              false: l10n.card_style_standard_detail,
              true: l10n.card_style_immersive_detail,
            },
            initVal: _ehSettingService.immersiveLargeCards,
            onValueChanged: (bool value) =>
                _ehSettingService.immersiveLargeCards = value,
          );
        }),

        // card_size
        EhCupertinoListTile(
          title: Text(L10n.of(context).card_size),
          additionalInfo: Obx(() {
            final mode = _ehSettingService.listMode.value;
            if (!CardSize.modes.contains(mode)) {
              return const SizedBox.shrink();
            }
            final step = CardSize.of(mode, _ehSettingService.getItemConfig(mode),
                phone: context.isPhone);
            return Text(CardSizeSlider.labels(L10n.of(context))[step]);
          }),
          trailing: const CupertinoListTileChevron(),
          onTap: () {
            Get.toNamed(
              EHRoutes.itemWidthSetting,
              id: detailNavigatorId,
            );
          },
        ),

        _buildTagLimitItem(context),

        // blurring_cover_background switch
        EhCupertinoListTile(
          title: Text(L10n.of(context).blurring_cover_background),
          trailing: Obx(() {
            return CupertinoSwitch(
              value: _ehSettingService.blurringOfCoverBackground,
              onChanged: _ehSettingService.listMode.value == ListModeEnum.list
                  ? (bool val) {
                      _ehSettingService.blurringOfCoverBackground = val;
                    }
                  : null,
            );
          }),
        ),

        EhCupertinoListTile(
          title: Text(L10n.of(context).detail_ambient_background),
          trailing: Obx(() {
            return CupertinoSwitch(
              value: _ehSettingService.detailAmbientBackground,
              onChanged: (bool val) =>
                  _ehSettingService.detailAmbientBackground = val,
            );
          }),
        ),

        // fixed_height_of_list_items switch
        EhCupertinoListTile(
          title: Text(L10n.of(context).fixed_height_of_list_items),
          trailing: Obx(() {
            return CupertinoSwitch(
              value: _ehSettingService.fixedHeightOfListItems,
              onChanged: _ehSettingService.listMode.value == ListModeEnum.list
                  ? (bool val) {
                      _ehSettingService.fixedHeightOfListItems = val;
                    }
                  : null,
            );
          }),
        ),
      ]),
      SliverCupertinoListSection.listInsetGrouped(
          footer: localeService.isLanguageCodeZh && GetPlatform.isMobile
              ? const Text('评论机翻按钮会用机器翻译将评论翻译为简体中文。')
              : null,
          children: [
            // to avatar
            EhCupertinoListTile(
              title: Text(L10n.of(context).avatar),
              trailing: const CupertinoListTileChevron(),
              onTap: () {
                Get.toNamed(
                  EHRoutes.avatarSetting,
                  id: detailNavigatorId,
                );
              },
            ),

            // commentTrans switch
            if (localeService.isLanguageCodeZh && GetPlatform.isMobile)
              EhCupertinoListTile(
                title: const Text('评论机翻按钮'),
                trailing: Obx(() {
                  return CupertinoSwitch(
                    value: _ehSettingService.commentTrans.value,
                    onChanged: (bool val) {
                      _ehSettingService.commentTrans.value = val;
                    },
                  );
                }),
              ),
          ]),
    ]);
  }
}

/// 主题设置部件
Widget _buildThemeItem(BuildContext context) {
  final String _title = L10n.of(context).theme;
  final ThemeService themeService = Get.find();

  final Map<ThemesModeEnum, String> themeMap = <ThemesModeEnum, String>{
    ThemesModeEnum.system: L10n.of(context).follow_system,
    ThemesModeEnum.lightMode: L10n.of(context).light,
    ThemesModeEnum.darkMode: L10n.of(context).dark,
  };

  return Obx(() {
    return SelectorCupertinoListTile<ThemesModeEnum>(
      title: _title,
      actionMap: themeMap,
      initVal: themeService.themeModel,
      onValueChanged: (val) => themeService.themeModel = val,
    );
  });
}

/// 列表模式切换
/// Names of the list modes the user can pick.
Map<ListModeEnum, String> listModeLabels(BuildContext context) {
  final EhSettingService ehSettingService = Get.find();
  return <ListModeEnum, String>{
    ListModeEnum.list: L10n.of(context).listmode_medium,
    ListModeEnum.simpleList: L10n.of(context).listmode_small,
    ListModeEnum.waterfall: L10n.of(context).listmode_waterfall,
    ListModeEnum.waterfallLarge: L10n.of(context).listmode_waterfall_large,
    ListModeEnum.grid: L10n.of(context).listmode_grid,
    ListModeEnum.gridTags: L10n.of(context).listmode_grid_tags,
    if (!kReleaseMode || ehSettingService.debugMode)
      ListModeEnum.debugSimple: 'debugSimple',
  };
}

Widget _buildListModeItem(BuildContext context) {
  final String _title = L10n.of(context).list_mode;
  final EhSettingService ehSettingService = Get.find();

  final Map<ListModeEnum, String> modeMap = listModeLabels(context);
  return Obx(() {
    return SelectorCupertinoListTile<ListModeEnum>(
      title: _title,
      actionMap: modeMap,
      initVal: ehSettingService.listMode.value,
      onValueChanged: (val) => ehSettingService.listMode.value = val,
    );
  });
}

/// 平板布局
Widget _buildTableLayoutItem(BuildContext context) {
  final String _title = L10n.of(context).tablet_layout;
  final EhSettingService ehSettingService = Get.find();

  final localeMap = <TabletLayout, String>{
    TabletLayout.automatic: L10n.of(context).automatic,
    TabletLayout.landscape: L10n.of(context).landscape,
    TabletLayout.never: L10n.of(context).never,
  };

  return Obx(() {
    return SelectorCupertinoListTile<TabletLayout>(
      title: _title,
      actionMap: localeMap,
      initVal: ehSettingService.tabletLayoutType,
      onValueChanged: (val) => ehSettingService.tabletLayoutType = val,
    );
  });
}

/// tag上限
Widget _buildTagLimitItem(BuildContext context) {
  final String _title = L10n.of(context).tag_limit;
  final EhSettingService ehSettingService = Get.find();

  Map<int, String> modeMap = {};

  for (final lim in EHConst.tagLimit) {
    modeMap.putIfAbsent(
        lim, () => lim == -1 ? L10n.of(context).no_limit : '$lim');
  }

  return Obx(() {
    return SelectorCupertinoListTile<int>(
      title: _title,
      actionMap: modeMap,
      initVal: ehSettingService.listViewTagLimit,
      onValueChanged: (val) => ehSettingService.listViewTagLimit = val,
    );
  });
}
