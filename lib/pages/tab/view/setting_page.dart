import 'package:eros_fe/common/controller/user_controller.dart';
import 'package:eros_fe/common/service/ehsetting_service.dart';
import 'package:eros_fe/common/service/theme_service.dart';
import 'package:eros_fe/component/setting/setting_scaffold.dart';
import 'package:eros_fe/index.dart';
import 'package:eros_fe/pages/setting/layout_setting_page.dart';
import 'package:eros_fe/pages/setting/read_setting_page.dart';
import 'package:eros_fe/pages/tab/controller/setting_controller.dart';
import 'package:eros_fe/widget/canvas_grain.dart';
import 'package:eros_fe/widget/user_avatar_image.dart';
import 'package:flutter/cupertino.dart';
import 'package:get/get.dart';
import 'package:sliver_tools/sliver_tools.dart';

/// Scroll offset past which the in-content large title sits under the bar.
const double _kLargeTitleExtent = 44;

class SettingTab extends GetView<SettingViewController> {
  const SettingTab({super.key});

  @override
  Widget build(BuildContext context) {
    final L10n l10n = L10n.of(context);
    final String title = l10n.tab_setting;
    final EhSettingService ehSettingService = Get.find();
    final bool nativeBar = NativeNavigationScope.isEnabled(context);

    return Obx(() {
      final bool safeMode = ehSettingService.isSafeMode.value;
      final bool glassBar = !nativeBar && SettingGlassBar.isActive;
      final bool titleInContent = nativeBar || glassBar;
      return NativeNavigationPage(
        tabId: EHRoutes.setting,
        chrome: NativePageChrome(
          title: title,
          titleVisible: controller.titleInBar.value,
        ),
        child: CupertinoPageScaffold(
          navigationBar: glassBar
              ? SettingGlassBar(
                  title: title,
                  titleVisible: controller.titleInBar.value,
                  edgeVisible: controller.contentUnderBar.value,
                )
              : null,
          child: CanvasGrain(
              child: NotificationListener<ScrollUpdateNotification>(
            onNotification: (notification) {
              if (notification.depth == 0) {
                controller.titleInBar.value =
                    notification.metrics.pixels > _kLargeTitleExtent;
                controller.contentUnderBar.value =
                    notification.metrics.pixels > 0;
              }
              return false;
            },
            child: CustomScrollView(
              physics: const AlwaysScrollableScrollPhysics(),
              slivers: <Widget>[
                if (titleInContent)
                  SliverSafeArea(
                    bottom: false,
                    sliver: SliverToBoxAdapter(
                      child: SettingLargeTitle(title),
                    ),
                  )
                else
                  CupertinoSliverNavigationBar(
                    heroTag: 'setting',
                    largeTitle: Text(title),
                  ),
                SliverSafeArea(
                  top: false,
                  sliver: MultiSliver(children: <Widget>[
                    if (!safeMode)
                      SliverCupertinoListSection.listInsetGrouped(
                        children: const <Widget>[_ProfileRow()],
                      ),
                    _section(
                      header: l10n.setting_group_browse,
                      rows: <Widget>[
                        _SettingLink(
                          icon: CupertinoIcons.square_grid_2x2,
                          title: l10n.appearance_and_layout,
                          route: EHRoutes.layoutSetting,
                          value: () => listModeLabels(
                              context)[ehSettingService.listMode.value],
                        ),
                        _SettingLink(
                          icon: CupertinoIcons.book,
                          title: l10n.read,
                          route: EHRoutes.readSetting,
                          value: () => readingDirectionLabels(
                              context)[ehSettingService.viewMode.value],
                        ),
                        _SettingLink(
                          icon: CupertinoIcons.search,
                          title: l10n.search,
                          route: EHRoutes.searchSetting,
                        ),
                      ],
                    ),
                    _section(
                      header: l10n.setting_group_content,
                      rows: <Widget>[
                        _SettingLink(
                          icon: CupertinoIcons.globe,
                          title: l10n.setting_site,
                          route: EHRoutes.ehSetting,
                          value: () => ehSettingService.isSiteEx.value
                              ? 'ExHentai'
                              : 'E-Hentai',
                        ),
                        _SettingLink(
                          icon: CupertinoIcons.arrow_down_to_line,
                          title: l10n.download,
                          route: EHRoutes.downloadSetting,
                        ),
                      ],
                    ),
                    _section(
                      header: l10n.setting_group_system,
                      rows: <Widget>[
                        _SettingLink(
                          icon: CupertinoIcons.shield,
                          title: l10n.security,
                          route: EHRoutes.securitySetting,
                        ),
                        _SettingLink(
                          icon: CupertinoIcons.slider_horizontal_3,
                          title: l10n.advanced,
                          route: EHRoutes.advancedSetting,
                        ),
                        _SettingLink(
                          icon: CupertinoIcons.info_circle,
                          title: l10n.about,
                          route: EHRoutes.about,
                          value: () => Global.packageInfo.version,
                        ),
                      ],
                    ),
                    const SliverToBoxAdapter(child: SizedBox(height: 24)),
                  ]),
                ),
              ],
            ),
          )),
        ),
      );
    });
  }

  Widget _section({required String header, required List<Widget> rows}) {
    return SliverCupertinoListSection.listInsetGrouped(
      header: Text(header),
      hasLeading: true,
      children: rows,
    );
  }
}

/// The page title at the top of the content; the native bar shows it inline
/// once it scrolls away.
class SettingLargeTitle extends StatelessWidget {
  const SettingLargeTitle(this.title, {super.key});

  final String title;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsetsDirectional.fromSTEB(20, 4, 20, 6),
      child: Semantics(
        header: true,
        child: Text(
          title,
          // Like the system large title, grow with Dynamic Type but stop well
          // short of filling the screen at accessibility sizes.
          textScaler:
              MediaQuery.textScalerOf(context).clamp(maxScaleFactor: 1.5),
          style: CupertinoTheme.of(context)
              .textTheme
              .navLargeTitleTextStyle
              .copyWith(color: ehTheme.palette.text1.resolveFrom(context)),
        ),
      ),
    );
  }
}

/// A row that opens a settings page, with the page's current value.
class _SettingLink extends StatelessWidget {
  const _SettingLink({
    required this.icon,
    required this.title,
    required this.route,
    this.value,
  });

  final IconData icon;
  final String title;
  final String route;

  /// Read inside an [Obx], so the row follows the setting.
  final String? Function()? value;

  @override
  Widget build(BuildContext context) {
    final SettingViewController controller = Get.find();
    Widget row(String? current) => MergeSemantics(
          child: Semantics(
            button: true,
            child: EhCupertinoListTile(
              leading: Icon(
                icon,
                size: 22,
                color: ehTheme.palette.text2.resolveFrom(context),
              ),
              title: Text(title),
              additionalInfo:
                  current == null || current.isEmpty ? null : Text(current),
              trailing: const CupertinoListTileChevron(),
              onTap: () => controller.open(route),
            ),
          ),
        );
    final value = this.value;
    if (value == null) {
      return row(null);
    }
    return Obx(() => row(value()));
  }
}

/// The signed-in account, or the way to sign in.
class _ProfileRow extends StatelessWidget {
  const _ProfileRow();

  @override
  Widget build(BuildContext context) {
    final UserController userController = Get.find();
    final EhSettingService ehSettingService = Get.find();
    final palette = ehTheme.palette;
    return Obx(() {
      final bool signedIn = userController.isLogin;
      final user = userController.user();
      final String name = signedIn
          ? (user.nickName ?? user.username ?? '')
          : L10n.of(context).login;
      return MergeSemantics(
        child: Semantics(
          button: true,
          child: EhCupertinoListTile(
            padding: const EdgeInsetsDirectional.fromSTEB(16, 11, 16, 11),
            leadingSize: 56,
            leadingToTitle: 14,
            leading: ExcludeSemantics(
              child: UserAvatarImage(
                url: signedIn ? user.avatarUrl ?? '' : '',
                size: 56,
              ),
            ),
            title: Text(
              name,
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.w600,
                letterSpacing: -0.4,
                color: palette.text1.resolveFrom(context),
              ),
            ),
            subtitle: signedIn
                ? Text(
                    ehSettingService.isSiteEx.value ? 'ExHentai' : 'E-Hentai')
                : null,
            trailing: const CupertinoListTileChevron(),
            onTap: () {
              if (signedIn) {
                userController.showLogOutDialog(context);
              } else {
                Get.toNamed(EHRoutes.login);
              }
            },
          ),
        ),
      );
    });
  }
}
