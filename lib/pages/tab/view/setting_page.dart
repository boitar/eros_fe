import 'package:eros_fe/adaptive/browse_layout.dart';
import 'package:eros_fe/adaptive/native_single_bar_edge.dart';
import 'package:eros_fe/adaptive/platform_capabilities.dart';
import 'package:eros_fe/adaptive/tab_navigation.dart';
import 'package:eros_fe/common/controller/user_controller.dart';
import 'package:eros_fe/common/service/auth_session_service.dart';
import 'package:eros_fe/common/service/ehsetting_service.dart';
import 'package:eros_fe/common/service/layout_service.dart';
import 'package:eros_fe/common/service/sni_bypass_service.dart';
import 'package:eros_fe/common/service/theme_service.dart';
import 'package:eros_fe/component/setting/android_setting_group.dart';
import 'package:eros_fe/component/setting/setting_scaffold.dart';
import 'package:eros_fe/const/eh_palette.dart';
import 'package:eros_fe/index.dart';
import 'package:eros_fe/network/sni_bypass/sni_bypass_models.dart';
import 'package:eros_fe/pages/setting/advanced_setting_page.dart';
import 'package:eros_fe/pages/setting/layout_setting_page.dart';
import 'package:eros_fe/pages/setting/read_setting_page.dart';
import 'package:eros_fe/pages/tab/controller/setting_controller.dart';
import 'package:eros_fe/utils/liquid_glass.dart';
import 'package:eros_fe/widget/canvas_grain.dart';
import 'package:eros_fe/widget/desktop_browse_style.dart';
import 'package:eros_fe/widget/user_avatar_image.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';
import 'package:sliver_tools/sliver_tools.dart';

/// Scroll offset past which the in-content large title sits under the bar.
const double _kLargeTitleExtent = 44;

/// Android lays the settings home out as Android 16 groups: separate rounded
/// rows, a tonal icon and the current value under each title.
bool get _androidGroups =>
    PlatformCapabilities.hostPlatform == TargetPlatform.android;

class SettingTab extends GetView<SettingViewController> {
  const SettingTab({super.key});

  @override
  Widget build(BuildContext context) {
    final L10n l10n = L10n.of(context);
    final String title = l10n.tab_setting;
    final EhSettingService ehSettingService = Get.find();
    final bool nativeBar = NativeNavigationScope.isEnabled(context);
    final bool splitSettings =
        !_androidGroups &&
        (BrowsePaneScope.isSplit(context) || usesDesktopSettingPanes);

    return _SettingSplitPaneSync(
      split: splitSettings,
      child: Obx(() {
        final bool safeMode = ehSettingService.isSafeMode.value;
        if (splitSettings) {
          return NativeNavigationPage(
            tabId: EHRoutes.setting,
            chrome: NativePageChrome(title: title, titleVisible: true),
            child: _SplitMasterSettingsView(safeMode: safeMode),
          );
        }

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
                child: NativeSingleBarEdge(
                  child: CustomScrollView(
                    physics: const AlwaysScrollableScrollPhysics(),
                    slivers: <Widget>[
                      if (titleInContent)
                        SliverSafeArea(
                          bottom: false,
                          sliver: SliverToBoxAdapter(
                            // Fade the large title out as the inline bar title
                            // appears, so no blurred copy lingers under the edge.
                            child: AnimatedOpacity(
                              key: const ValueKey<String>(
                                'setting-large-title-fade',
                              ),
                              opacity: controller.titleInBar.value ? 0 : 1,
                              duration: const Duration(milliseconds: 180),
                              child: SettingLargeTitle(title),
                            ),
                          ),
                        )
                      else
                        CupertinoSliverNavigationBar(
                          heroTag: 'setting',
                          largeTitle: Text(title),
                        ),
                      SliverSafeArea(
                        top: false,
                        sliver: MultiSliver(
                          children: <Widget>[
                            if (!safeMode && _androidGroups)
                              const SliverToBoxAdapter(
                                child: Padding(
                                  padding: EdgeInsets.only(top: 12),
                                  child: AndroidSettingGroup(
                                    children: <Widget>[_ProfileRow()],
                                  ),
                                ),
                              )
                            else if (!safeMode)
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
                                    context,
                                  )[ehSettingService.listMode.value],
                                ),
                                _SettingLink(
                                  icon: CupertinoIcons.book,
                                  title: l10n.read,
                                  route: EHRoutes.readSetting,
                                  value: () => readingDirectionLabels(
                                    context,
                                  )[ehSettingService.viewMode.value],
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
                                  value: SniBypassService.maybeFind != null
                                      ? () => sniBypassModeLabel(
                                            context,
                                            SniBypassService.maybeFind!.mode,
                                          )
                                      : null,
                                  staticValue: SniBypassService.maybeFind == null
                                      ? sniBypassModeLabel(
                                          context,
                                          SniBypassMode.standard,
                                        )
                                      : null,
                                ),
                                _SettingLink(
                                  icon: CupertinoIcons.info_circle,
                                  title: l10n.about,
                                  route: EHRoutes.about,
                                  staticValue: Global.packageInfo.version,
                                ),
                              ],
                            ),
                            const SliverToBoxAdapter(
                              child: SizedBox(height: 24),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        );
      }),
    );
  }

  Widget _section({required String header, required List<Widget> rows}) {
    if (_androidGroups) {
      return SliverToBoxAdapter(
        child: AndroidSettingGroup(header: header, children: rows),
      );
    }
    return SliverCupertinoListSection.listInsetGrouped(
      header: Text(header),
      hasLeading: true,
      children: rows,
    );
  }
}

/// Keeps the settings split pane's selection state synced with the settings
/// detail stack across desktop and non-desktop split hosts (such as iOS split
/// view), and ensures desktop never leaves its detail pane empty.
class _SettingSplitPaneSync extends StatefulWidget {
  const _SettingSplitPaneSync({required this.split, required this.child});

  final bool split;
  final Widget child;

  @override
  State<_SettingSplitPaneSync> createState() => _SettingSplitPaneSyncState();
}

class _SettingSplitPaneSyncState extends State<_SettingSplitPaneSync> {
  final SettingViewController _controller = Get.find();
  TabNavigationRegistry? _navigation;
  bool _scheduled = false;

  void _bindNavigation() {
    final next = Get.isRegistered<LayoutServices>()
        ? Get.find<LayoutServices>().tabNavigation
        : null;
    if (identical(_navigation, next)) {
      return;
    }
    _navigation?.removeListener(_schedule);
    _navigation = next;
    _navigation?.addListener(_schedule);
  }

  @override
  void initState() {
    super.initState();
    _bindNavigation();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _bindNavigation();
    // A window resize or rotation can turn the split on or off.
    MediaQuery.sizeOf(context);
    _schedule();
  }

  @override
  void didUpdateWidget(_SettingSplitPaneSync oldWidget) {
    super.didUpdateWidget(oldWidget);
    _bindNavigation();
    if (oldWidget.split != widget.split) {
      _schedule();
    }
  }

  /// Navigation must not change while the navigators report their own
  /// changes, so the pane is synced after the frame.
  void _schedule() {
    if (_scheduled) {
      return;
    }
    _scheduled = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _scheduled = false;
      if (mounted) {
        _controller.syncPane(split: widget.split);
      }
    });
  }

  @override
  void dispose() {
    _navigation?.removeListener(_schedule);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => widget.child;
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
    this.staticValue,
  });

  final IconData icon;
  final String title;
  final String route;

  /// Read inside an [Obx], so the row follows the setting.
  final String? Function()? value;

  /// A value that never changes, such as the app version: no [Obx] needed.
  final String? staticValue;

  @override
  Widget build(BuildContext context) {
    final SettingViewController controller = Get.find();
    Widget row(String? current) => _androidGroups
        ? MergeSemantics(
            child: Semantics(
              button: true,
              child: AndroidSettingTile(
                icon: icon,
                title: Text(title),
                subtitle:
                    current == null || current.isEmpty ? null : Text(current),
                onTap: () => controller.open(route),
              ),
            ),
          )
        : Obx(() {
            // Two panes: the open category is highlighted and rows lead
            // beside the pane rather than into a new page, so no chevron.
            final panes = controller.openCategory.value != null;
            final selected = controller.openCategory.value == route;
            final accent = EhPalette.accent.resolveFrom(context);
            return MergeSemantics(
              child: Semantics(
                button: true,
                selected: selected,
                child: EhCupertinoListTile(
                  key: ValueKey<String>('setting-link-$route'),
                  backgroundColor: selected
                      ? EhPalette.accentSoft.resolveFrom(context)
                      : null,
                  leading: EhSvgIcon(
                    icon,
                    size: 22,
                    color: selected
                        ? accent
                        : ehTheme.palette.text2.resolveFrom(context),
                  ),
                  title: selected
                      ? Text(
                          title,
                          style: TextStyle(
                            color: accent,
                            fontWeight: FontWeight.w600,
                          ),
                        )
                      : Text(title),
                  additionalInfo: current == null || current.isEmpty
                      ? null
                      : Text(current),
                  trailing: panes ? null : const CupertinoListTileChevron(),
                  onTap: () => controller.open(route),
                ),
              ),
            );
          });
    final value = this.value;
    if (value == null) {
      return row(staticValue);
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
    final SettingViewController settingController = Get.find();
    final AuthSessionService authService = AuthSessionService.ensure();
    final palette = ehTheme.palette;
    return Obx(() {
      final bool signedIn = userController.isLogin;
      final user = userController.user();
      final strings = AuthStrings.of(context);
      final snap = authService.snapshot.value;
      final now = authService.now;
      final remDays = snap.remainingDaysAt(now);
      final status = snap.statusAt(now);
      final panes = settingController.openCategory.value != null;
      final selected =
          signedIn && settingController.openCategory.value == EHRoutes.accountSession;

      final String name = signedIn
          ? (user.nickName ?? user.username ?? '')
          : L10n.of(context).login;

      void open() {
        if (signedIn) {
          settingController.open(EHRoutes.accountSession);
        } else {
          Get.toNamed(EHRoutes.login);
        }
      }

      final Color dotColor = switch (status) {
        AuthCountdownStatus.valid => const Color(0xFF3FA86B),
        AuthCountdownStatus.expiring => const Color(0xFFE39A2A),
        AuthCountdownStatus.expired => const Color(0xFFC9353B),
      };
      final String siteLabel =
          ehSettingService.isSiteEx.value ? 'EX' : 'E-Hentai';
      final Widget? signedInSubtitle = signedIn
          ? Row(
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                Container(
                  width: 7,
                  height: 7,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: dotColor,
                  ),
                ),
                const SizedBox(width: 6),
                Flexible(
                  child: Text(
                    '$siteLabel · ${strings.remainingDaysSummary(remDays)}',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            )
          : null;

      if (_androidGroups) {
        return MergeSemantics(
          child: Semantics(
            button: true,
            child: AndroidSettingTile(
              key: const ValueKey<String>('setting-profile-row'),
              minHeight: 80,
              leading: UserAvatarImage(
                url: signedIn ? user.avatarUrl ?? '' : '',
                size: 52,
              ),
              title: Text(
                name,
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w500,
                ),
              ),
              subtitle: signedInSubtitle,
              trailing: EhSvgIcon(
                CupertinoIcons.chevron_right,
                size: 14,
                strokeWidth: 1.9,
                color: palette.text3.resolveFrom(context),
              ),
              onTap: open,
            ),
          ),
        );
      }

      final accent = EhPalette.accent.resolveFrom(context);
      return MergeSemantics(
        child: Semantics(
          button: true,
          selected: selected,
          child: EhCupertinoListTile(
            key: const ValueKey<String>('setting-profile-row'),
            backgroundColor:
                selected ? EhPalette.accentSoft.resolveFrom(context) : null,
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
                color: selected ? accent : palette.text1.resolveFrom(context),
              ),
            ),
            subtitle: signedInSubtitle,
            trailing: panes ? null : const CupertinoListTileChevron(),
            onTap: open,
          ),
        ),
      );
    });
  }
}

class _SplitCategoryItem {
  const _SplitCategoryItem({
    required this.icon,
    required this.title,
    required this.route,
    this.currentValue,
    this.tabular = false,
  });

  final IconData icon;
  final String title;
  final String route;
  final String? currentValue;
  final bool tabular;
}

/// iOS 27 split-view master column: pure flat surface, monochrome SVG icons,
/// 44px stadium capsule rows with neutral gray selection, no bar mask smear,
/// and a floating Liquid Glass search capsule at the bottom.
class _SplitMasterSettingsView extends StatefulWidget {
  const _SplitMasterSettingsView({required this.safeMode});

  final bool safeMode;

  @override
  State<_SplitMasterSettingsView> createState() =>
      _SplitMasterSettingsViewState();
}

class _SplitMasterSettingsViewState extends State<_SplitMasterSettingsView> {
  final TextEditingController _searchController = TextEditingController();
  String _query = '';

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  void _updateQuery(String value) {
    final trimmed = value.trim();
    if (trimmed != _query) {
      setState(() => _query = trimmed);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = L10n.of(context);
    final palette = ehTheme.palette;
    final masterBg = palette.surface.resolveFrom(context);
    final ehSettingService = Get.find<EhSettingService>();
    final settingController = Get.find<SettingViewController>();

    return CupertinoPageScaffold(
      backgroundColor: masterBg,
      child: CupertinoTheme(
        data: CupertinoTheme.of(context).copyWith(
          scaffoldBackgroundColor: masterBg,
        ),
        child: Obx(() {
          final openCategory = settingController.openCategory.value;
          final groups = <List<_SplitCategoryItem>>[
            <_SplitCategoryItem>[
              _SplitCategoryItem(
                icon: CupertinoIcons.square_grid_2x2,
                title: l10n.appearance_and_layout,
                route: EHRoutes.layoutSetting,
                currentValue:
                    listModeLabels(context)[ehSettingService.listMode.value],
              ),
              _SplitCategoryItem(
                icon: CupertinoIcons.book,
                title: l10n.read,
                route: EHRoutes.readSetting,
                currentValue: readingDirectionLabels(
                  context,
                )[ehSettingService.viewMode.value],
              ),
              _SplitCategoryItem(
                icon: CupertinoIcons.search,
                title: l10n.search,
                route: EHRoutes.searchSetting,
              ),
            ],
            <_SplitCategoryItem>[
              _SplitCategoryItem(
                icon: CupertinoIcons.globe,
                title: l10n.setting_site,
                route: EHRoutes.ehSetting,
                currentValue:
                    ehSettingService.isSiteEx.value ? 'ExHentai' : 'E-Hentai',
              ),
              _SplitCategoryItem(
                icon: CupertinoIcons.arrow_down_to_line,
                title: l10n.download,
                route: EHRoutes.downloadSetting,
              ),
            ],
            <_SplitCategoryItem>[
              _SplitCategoryItem(
                icon: CupertinoIcons.shield,
                title: l10n.security,
                route: EHRoutes.securitySetting,
              ),
              _SplitCategoryItem(
                icon: CupertinoIcons.slider_horizontal_3,
                title: l10n.advanced,
                route: EHRoutes.advancedSetting,
                currentValue: sniBypassModeLabel(
                  context,
                  SniBypassService.maybeFind?.mode ?? SniBypassMode.standard,
                ),
              ),
              _SplitCategoryItem(
                icon: CupertinoIcons.info_circle,
                title: l10n.about,
                route: EHRoutes.about,
                currentValue: Global.packageInfo.version,
                tabular: true,
              ),
            ],
          ];

          final q = _query.toLowerCase();
          final visibleGroups = <List<_SplitCategoryItem>>[
            for (final group in groups)
              [
                for (final item in group)
                  if (q.isEmpty ||
                      item.title.toLowerCase().contains(q) ||
                      (item.currentValue?.toLowerCase().contains(q) ?? false))
                    item,
              ],
          ].where((group) => group.isNotEmpty).toList();

          final zh = Localizations.localeOf(context).languageCode == 'zh';

          return Stack(
            fit: StackFit.expand,
            children: <Widget>[
              CustomScrollView(
                physics: const AlwaysScrollableScrollPhysics(),
                slivers: <Widget>[
                  SliverSafeArea(
                    sliver: SliverPadding(
                      padding: const EdgeInsets.fromLTRB(10, 16, 10, 84),
                      sliver: SliverList.list(
                        children: <Widget>[
                          if (!widget.safeMode) ...<Widget>[
                            const _SplitProfileHeader(),
                            const SizedBox(height: 16),
                          ],
                          if (visibleGroups.isEmpty)
                            Padding(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 16,
                                vertical: 32,
                              ),
                              child: Text(
                                zh ? '没有匹配的设置项' : 'No matching settings',
                                textAlign: TextAlign.center,
                                style: TextStyle(
                                  fontSize: 13.5,
                                  color: palette.text2.resolveFrom(context),
                                ),
                              ),
                            )
                          else
                            for (var g = 0; g < visibleGroups.length; g++) ...<
                              Widget
                            >[
                              if (g > 0) const SizedBox(height: 18),
                              for (
                                var i = 0;
                                i < visibleGroups[g].length;
                                i++
                              ) ...<Widget>[
                                if (i > 0) const SizedBox(height: 2),
                                _SplitSettingCapsuleRow(
                                  key: ValueKey<String>(
                                    'setting-link-${visibleGroups[g][i].route}',
                                  ),
                                  item: visibleGroups[g][i],
                                  selected:
                                      openCategory ==
                                      visibleGroups[g][i].route,
                                  onTap: () => settingController.open(
                                    visibleGroups[g][i].route,
                                    split: true,
                                  ),
                                ),
                              ],
                            ],
                        ],
                      ),
                    ),
                  ),
                ],
              ),
              Positioned(
                left: 0,
                right: 0,
                bottom: 0,
                child: _SplitSettingSearchBar(
                  controller: _searchController,
                  query: _query,
                  masterBg: masterBg,
                  placeholder: l10n.search,
                  onChanged: _updateQuery,
                  onClear: () {
                    _searchController.clear();
                    _updateQuery('');
                  },
                ),
              ),
            ],
          );
        }),
      ),
    );
  }
}

class _SplitProfileHeader extends StatefulWidget {
  const _SplitProfileHeader();

  @override
  State<_SplitProfileHeader> createState() => _SplitProfileHeaderState();
}

class _SplitProfileHeaderState extends State<_SplitProfileHeader>
    with SingleTickerProviderStateMixin {
  bool _hover = false;
  bool _focus = false;
  int _pressEpoch = 0;

  late final AnimationController _pressController = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 85),
    reverseDuration: const Duration(milliseconds: 190),
  );

  @override
  void dispose() {
    _pressController.dispose();
    super.dispose();
  }

  void _handlePressDown() {
    _pressEpoch++;
    if (MediaQuery.disableAnimationsOf(context)) {
      _pressController.value = 1.0;
    } else {
      _pressController.forward();
    }
  }

  void _handlePressUp() {
    final int epoch = ++_pressEpoch;
    if (MediaQuery.disableAnimationsOf(context)) {
      _pressController.value = 0.0;
      return;
    }
    if (_pressController.value < 0.65) {
      _pressController
          .animateTo(
            1.0,
            duration: const Duration(milliseconds: 55),
            curve: Curves.easeOut,
          )
          .then((_) {
            if (mounted && _pressEpoch == epoch) {
              _pressController.reverse();
            }
          });
    } else {
      _pressController.reverse();
    }
  }

  void _handlePressCancel() {
    _pressEpoch++;
    if (!_pressController.isAnimating && _pressController.value == 0.0) {
      return;
    }
    if (MediaQuery.disableAnimationsOf(context)) {
      _pressController.value = 0.0;
    } else {
      _pressController.reverse();
    }
  }

  @override
  Widget build(BuildContext context) {
    final userController = Get.find<UserController>();
    final ehSettingService = Get.find<EhSettingService>();
    final settingController = Get.find<SettingViewController>();
    final authService = AuthSessionService.ensure();
    final palette = ehTheme.palette;
    final dark = CupertinoTheme.brightnessOf(context) == Brightness.dark;
    final zh = Localizations.localeOf(context).languageCode == 'zh';
    final disableAnimations = MediaQuery.disableAnimationsOf(context);

    return Obx(() {
      final signedIn = userController.isLogin;
      final user = userController.user();
      final strings = AuthStrings.of(context);
      final snap = authService.snapshot.value;
      final now = authService.now;
      final remDays = snap.remainingDaysAt(now);
      final status = snap.statusAt(now);
      final selected =
          signedIn &&
          settingController.openCategory.value == EHRoutes.accountSession;

      final String name = signedIn
          ? (user.nickName ?? user.username ?? '')
          : L10n.of(context).login;

      void open() {
        if (signedIn) {
          settingController.open(EHRoutes.accountSession, split: true);
        } else {
          Get.toNamed(EHRoutes.login);
        }
      }

      final Color dotColor = switch (status) {
        AuthCountdownStatus.valid => const Color(0xFF3FA86B),
        AuthCountdownStatus.expiring => const Color(0xFFE39A2A),
        AuthCountdownStatus.expired => const Color(0xFFC9353B),
      };
      final String siteLabel =
          ehSettingService.isSiteEx.value ? 'EX' : 'E-Hentai';
      final Widget subtitleWidget = signedIn
          ? Row(
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                Container(
                  width: 6,
                  height: 6,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: dotColor,
                  ),
                ),
                const SizedBox(width: 6),
                Flexible(
                  child: Text(
                    '$siteLabel · ${strings.remainingDaysSummary(remDays)}',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 12.5,
                      color: palette.text2.resolveFrom(context),
                    ),
                  ),
                ),
              ],
            )
          : Text(
              zh
                  ? '登录 E-Hentai 账号以同步收藏与里站'
                  : 'Sign in to sync favorites and ExHentai',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: 12.5,
                color: palette.text2.resolveFrom(context),
              ),
            );

      final avatarUrl = signedIn ? (user.avatarUrl?.trim() ?? '') : '';
      final Widget avatar = avatarUrl.isNotEmpty
          ? SizedBox.square(
              dimension: 50,
              child: ClipOval(
                child: UserAvatarImage(url: avatarUrl, size: 50),
              ),
            )
          : Container(
              width: 50,
              height: 50,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: dark
                    ? const Color(0xFF262830)
                    : const Color(0xFFEAECEF),
                border: Border.all(
                  color: palette.hairline.resolveFrom(context),
                ),
              ),
              alignment: Alignment.center,
              child: EhSvgIcon(
                CupertinoIcons.person,
                size: 23,
                color: signedIn
                    ? palette.text1.resolveFrom(context)
                    : palette.text2.resolveFrom(context),
              ),
            );

      final Color hoverFill = DesktopBrowseStyle.capsuleHover(context);
      final Color baseBackground = selected
          ? (_hover
                ? DesktopBrowseStyle.capsuleSelectedHover(context)
                : DesktopBrowseStyle.capsuleSelected(context))
          : (_hover ? hoverFill : hoverFill.withValues(alpha: 0));
      final Color pressTarget = selected
          ? DesktopBrowseStyle.capsuleSelectedPressed(context)
          : DesktopBrowseStyle.capsulePressed(context);
      final Color focusBorderColor = _focus
          ? EhPalette.accent.resolveFrom(context)
          : const Color(0x00000000);
      final Widget rowContent = Row(
        children: <Widget>[
          ExcludeSemantics(child: avatar),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                Text(
                  name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.w600,
                    letterSpacing: -0.3,
                    color: palette.text1.resolveFrom(context),
                  ),
                ),
                const SizedBox(height: 2),
                subtitleWidget,
              ],
            ),
          ),
        ],
      );

      return Semantics(
        key: const ValueKey<String>('setting-profile-row'),
        button: true,
        selected: selected,
        label: name,
        onTap: open,
        child: FocusableActionDetector(
          mouseCursor: MouseCursor.defer,
          onShowFocusHighlight: (v) => setState(() => _focus = v),
          shortcuts: const <ShortcutActivator, Intent>{
            SingleActivator(LogicalKeyboardKey.enter): ActivateIntent(),
            SingleActivator(LogicalKeyboardKey.space): ActivateIntent(),
          },
          actions: <Type, Action<Intent>>{
            ActivateIntent: CallbackAction<ActivateIntent>(
              onInvoke: (_) {
                open();
                return null;
              },
            ),
          },
          child: MouseRegion(
            cursor: DesktopBrowseStyle.interactionCursor,
            onEnter: (_) => setState(() => _hover = true),
            onExit: (_) {
              if (_hover) {
                setState(() => _hover = false);
              }
              _handlePressCancel();
            },
            child: GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTapDown: (_) => _handlePressDown(),
              onTapUp: (_) => _handlePressUp(),
              onTapCancel: _handlePressCancel,
              onTap: open,
              child: TweenAnimationBuilder<Color?>(
                tween: ColorTween(end: baseBackground),
                duration: DesktopBrowseStyle.hoverDuration(
                  context,
                  entering: _hover,
                ),
                curve: _hover
                    ? DesktopBrowseStyle.hoverEnterCurve
                    : DesktopBrowseStyle.hoverExitCurve,
                child: rowContent,
                builder: (context, animatedBase, innerChild) => AnimatedBuilder(
                  animation: _pressController,
                  child: innerChild,
                  builder: (context, child) {
                    final double t = Curves.easeOutCubic.transform(
                      _pressController.value,
                    );
                    final Color resolvedBase = animatedBase ?? baseBackground;
                    final Color fill = t > 0
                        ? (Color.lerp(resolvedBase, pressTarget, t) ??
                              pressTarget)
                        : resolvedBase;
                    return Transform.scale(
                      scale: disableAnimations ? 1.0 : 1.0 - 0.01 * t,
                      child: AnimatedContainer(
                        duration: Duration.zero,
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 10,
                        ),
                        decoration: BoxDecoration(
                          color: fill,
                          borderRadius: BorderRadius.circular(22),
                          border: Border.all(
                            color: focusBorderColor,
                            width: 1.5,
                          ),
                        ),
                        child: child,
                      ),
                    );
                  },
                ),
              ),
            ),
          ),
        ),
      );
    });
  }
}

class _SplitSettingCapsuleRow extends StatefulWidget {
  const _SplitSettingCapsuleRow({
    super.key,
    required this.item,
    required this.selected,
    required this.onTap,
  });

  final _SplitCategoryItem item;
  final bool selected;
  final VoidCallback onTap;

  @override
  State<_SplitSettingCapsuleRow> createState() =>
      _SplitSettingCapsuleRowState();
}

class _SplitSettingCapsuleRowState extends State<_SplitSettingCapsuleRow>
    with SingleTickerProviderStateMixin {
  bool _hover = false;
  bool _pressed = false;
  bool _focus = false;
  int _pressEpoch = 0;

  late final AnimationController _pressController = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 85),
    reverseDuration: const Duration(milliseconds: 190),
  );

  @override
  void dispose() {
    _pressController.dispose();
    super.dispose();
  }

  void _handlePressDown() {
    _pressEpoch++;
    if (!_pressed) {
      setState(() => _pressed = true);
    }
    if (MediaQuery.disableAnimationsOf(context)) {
      _pressController.value = 1.0;
    } else {
      _pressController.forward();
    }
  }

  void _handlePressUp() {
    final int epoch = ++_pressEpoch;
    if (_pressed) {
      setState(() => _pressed = false);
    }
    if (MediaQuery.disableAnimationsOf(context)) {
      _pressController.value = 0.0;
      return;
    }
    if (_pressController.value < 0.65) {
      _pressController
          .animateTo(
            1.0,
            duration: const Duration(milliseconds: 55),
            curve: Curves.easeOut,
          )
          .then((_) {
            if (mounted && _pressEpoch == epoch) {
              _pressController.reverse();
            }
          });
    } else {
      _pressController.reverse();
    }
  }

  void _handlePressCancel() {
    _pressEpoch++;
    if (_pressed) {
      setState(() => _pressed = false);
    }
    if (!_pressController.isAnimating && _pressController.value == 0.0) {
      return;
    }
    if (MediaQuery.disableAnimationsOf(context)) {
      _pressController.value = 0.0;
    } else {
      _pressController.reverse();
    }
  }

  @override
  Widget build(BuildContext context) {
    final palette = ehTheme.palette;
    final text1 = palette.text1.resolveFrom(context);
    final text2 = palette.text2.resolveFrom(context);
    final value = widget.item.currentValue;
    final bool emphasized = widget.selected || _hover || _pressed;
    final bool disableAnimations = MediaQuery.disableAnimationsOf(context);
    final Color hoverFill = DesktopBrowseStyle.capsuleHover(context);
    final Color baseBackground = widget.selected
        ? (_hover
              ? DesktopBrowseStyle.capsuleSelectedHover(context)
              : DesktopBrowseStyle.capsuleSelected(context))
        : (_hover ? hoverFill : hoverFill.withValues(alpha: 0));
    final Color pressTarget = widget.selected
        ? DesktopBrowseStyle.capsuleSelectedPressed(context)
        : DesktopBrowseStyle.capsulePressed(context);
    final Color focusBorderColor = _focus
        ? EhPalette.accent.resolveFrom(context)
        : const Color(0x00000000);
    final Widget rowContent = Row(
      children: <Widget>[
        SizedBox.square(
          dimension: 24,
          child: Center(
            child: TweenAnimationBuilder<Color?>(
              tween: ColorTween(end: emphasized ? text1 : text2),
              duration: DesktopBrowseStyle.hoverDuration(
                context,
                entering: emphasized,
              ),
              curve: Curves.easeOutCubic,
              builder: (context, iconColor, _) => EhSvgIcon(
                widget.item.icon,
                size: 19,
                strokeWidth: widget.selected ? 1.95 : 1.75,
                color: iconColor,
              ),
            ),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Text(
            widget.item.title,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontSize: 15,
              fontWeight: widget.selected ? FontWeight.w600 : FontWeight.w400,
              color: text1,
            ),
          ),
        ),
        if (value != null && value.isNotEmpty)
          Padding(
            padding: const EdgeInsets.only(left: 8, right: 2),
            child: Text(
              value,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: 14,
                fontFeatures: widget.item.tabular
                    ? const <FontFeature>[FontFeature.tabularFigures()]
                    : null,
                color: text2,
              ),
            ),
          ),
      ],
    );

    return MergeSemantics(
      child: Semantics(
        button: true,
        selected: widget.selected,
        label: widget.item.title,
        value: value,
        onTap: widget.onTap,
        child: FocusableActionDetector(
          mouseCursor: MouseCursor.defer,
          onShowFocusHighlight: (v) => setState(() => _focus = v),
          shortcuts: const <ShortcutActivator, Intent>{
            SingleActivator(LogicalKeyboardKey.enter): ActivateIntent(),
            SingleActivator(LogicalKeyboardKey.space): ActivateIntent(),
          },
          actions: <Type, Action<Intent>>{
            ActivateIntent: CallbackAction<ActivateIntent>(
              onInvoke: (_) {
                widget.onTap();
                return null;
              },
            ),
          },
          child: MouseRegion(
            cursor: DesktopBrowseStyle.interactionCursor,
            onEnter: (_) => setState(() => _hover = true),
            onExit: (_) {
              if (_hover) {
                setState(() => _hover = false);
              }
              _handlePressCancel();
            },
            child: GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTapDown: (_) => _handlePressDown(),
              onTapUp: (_) => _handlePressUp(),
              onTapCancel: _handlePressCancel,
              onTap: widget.onTap,
              child: TweenAnimationBuilder<Color?>(
                tween: ColorTween(end: baseBackground),
                duration: DesktopBrowseStyle.hoverDuration(
                  context,
                  entering: _hover,
                ),
                curve: _hover
                    ? DesktopBrowseStyle.hoverEnterCurve
                    : DesktopBrowseStyle.hoverExitCurve,
                child: rowContent,
                builder: (context, animatedBase, innerChild) => AnimatedBuilder(
                  animation: _pressController,
                  child: innerChild,
                  builder: (context, child) {
                    final double t = Curves.easeOutCubic.transform(
                      _pressController.value,
                    );
                    final Color resolvedBase = animatedBase ?? baseBackground;
                    final Color fill = t > 0
                        ? (Color.lerp(resolvedBase, pressTarget, t) ??
                              pressTarget)
                        : resolvedBase;
                    return Transform.scale(
                      scale: disableAnimations ? 1.0 : 1.0 - 0.01 * t,
                      child: AnimatedContainer(
                        duration: Duration.zero,
                        constraints: const BoxConstraints(minHeight: 44),
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 8,
                        ),
                        decoration: BoxDecoration(
                          color: fill,
                          borderRadius: BorderRadius.circular(999),
                          border: Border.all(
                            color: focusBorderColor,
                            width: 1.5,
                          ),
                        ),
                        child: child,
                      ),
                    );
                  },
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _SplitSettingSearchBar extends StatelessWidget {
  const _SplitSettingSearchBar({
    required this.controller,
    required this.query,
    required this.masterBg,
    required this.placeholder,
    required this.onChanged,
    required this.onClear,
  });

  final TextEditingController controller;
  final String query;
  final Color masterBg;
  final String placeholder;
  final ValueChanged<String> onChanged;
  final VoidCallback onClear;

  @override
  Widget build(BuildContext context) {
    final palette = ehTheme.palette;
    final dark = CupertinoTheme.brightnessOf(context) == Brightness.dark;
    final text1 = palette.text1.resolveFrom(context);
    final text2 = palette.text2.resolveFrom(context);

    return Stack(
      children: <Widget>[
        Positioned.fill(
          child: IgnorePointer(
            child: DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: <Color>[
                    masterBg.withValues(alpha: 0),
                    masterBg.withValues(alpha: .72),
                    masterBg,
                  ],
                  stops: const <double>[0, 0.45, 1],
                ),
              ),
            ),
          ),
        ),
        SafeArea(
          top: false,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(12, 20, 12, 12),
            child: LiquidGlassSurface(
              enabled: true,
              borderRadius: BorderRadius.circular(999),
              child: Container(
                height: 42,
                padding: const EdgeInsets.symmetric(horizontal: 14),
                decoration: BoxDecoration(
                  color: dark
                      ? const Color(0xC722232A)
                      : const Color(0xCCFFFFFF),
                  borderRadius: BorderRadius.circular(999),
                  border: Border.all(
                    color: palette.hairline.resolveFrom(context),
                  ),
                ),
                child: Row(
                  children: <Widget>[
                    EhSvgIcon(CupertinoIcons.search, size: 16, color: text2),
                    const SizedBox(width: 8),
                    Expanded(
                      child: CupertinoTextField.borderless(
                        key: const ValueKey<String>(
                          'setting-master-search-field',
                        ),
                        controller: controller,
                        placeholder: placeholder,
                        placeholderStyle: TextStyle(
                          fontSize: 14,
                          color: text2.withValues(alpha: .75),
                        ),
                        style: TextStyle(fontSize: 14, color: text1),
                        padding: EdgeInsets.zero,
                        onChanged: onChanged,
                      ),
                    ),
                    if (query.isNotEmpty)
                      GestureDetector(
                        key: const ValueKey<String>(
                          'setting-master-search-clear',
                        ),
                        behavior: HitTestBehavior.opaque,
                        onTap: onClear,
                        child: Container(
                          width: 20,
                          height: 20,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: palette.fill.resolveFrom(context),
                          ),
                          alignment: Alignment.center,
                          child: EhSvgIcon(
                            CupertinoIcons.xmark,
                            size: 11,
                            strokeWidth: 2.1,
                            color: text2,
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}
