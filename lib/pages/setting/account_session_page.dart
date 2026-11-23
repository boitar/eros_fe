import 'package:eros_fe/adaptive/platform_capabilities.dart';
import 'package:eros_fe/common/controller/user_controller.dart';
import 'package:eros_fe/common/service/auth_session_service.dart';
import 'package:eros_fe/common/service/theme_service.dart';
import 'package:eros_fe/component/exception/error.dart';
import 'package:eros_fe/component/setting/android_setting_group.dart';
import 'package:eros_fe/component/setting/setting_scaffold.dart';
import 'package:eros_fe/const/eh_palette.dart';
import 'package:eros_fe/index.dart';
import 'package:eros_fe/network/api.dart';
import 'package:eros_fe/network/request.dart';
import 'package:eros_fe/pages/login/controller/login_controller.dart';
import 'package:eros_fe/pages/login/view/login_cookie.dart';
import 'package:eros_fe/pages/login/widget/login_material_chrome.dart';
import 'package:eros_fe/pages/setting/avatar_manage.dart';
import 'package:eros_fe/pages/setting/webview/cf_verify_in.dart';
import 'package:eros_fe/pages/tab/controller/setting_controller.dart';
import 'package:eros_fe/widget/eh_buttons.dart';
import 'package:eros_fe/widget/eh_sheet.dart';
import 'package:eros_fe/widget/user_avatar_image.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';

/// 从任意上下文（账号页或启动顶部通知胶囊）唤起三态材质「重新认证」面板
Future<void> showReauthenticateSheet(BuildContext context) async {
  await showEhSheet<void>(
    context: context,
    builder: (sheetCtx) => const ReauthenticateSheetBody(),
  );
}

/// 常驻「账号与登录态」管理页（iOS / Android / Desktop 三端自适应）
class AccountSessionPage extends StatefulWidget {
  const AccountSessionPage({super.key});

  @override
  State<AccountSessionPage> createState() => _AccountSessionPageState();
}

class _AccountSessionPageState extends State<AccountSessionPage> {
  bool _retryingEx = false;

  bool get _isAndroid =>
      PlatformCapabilities.hostPlatform == TargetPlatform.android;

  Future<void> _handleRetryEx() async {
    if (_retryingEx) {
      return;
    }
    setState(() => _retryingEx = true);
    final authService = AuthSessionService.ensure();
    final userCtrl = Get.find<UserController>();
    await authService.probeExitRegion();

    bool hasEx = false;
    try {
      await clearExHentaiCookies();
      await getExIgneous();
      final jar = await Api.cookieJar;
      final exCookies =
          await jar.loadForRequest(Uri.parse(EHConst.EX_BASE_URL));
      final ig = exCookies
          .firstWhereOrNull((c) => c.name == 'igneous')
          ?.value
          .trim();
      if (ig != null && ig.isNotEmpty && ig != 'mystery') {
        userCtrl.user(userCtrl.user.value.copyWith(igneous: ig.oN));
        hasEx = true;
      }
    } catch (e) {
      if (isCfBlockedError(e)) {
        final verification = await openCfVerification(acquireExSession: true);
        if (verification != null) {
          await applyCfVerification(verification);
          final ig = userCtrl.user.value.igneous?.trim();
          hasEx = verification.hasValidIgneous ||
              (ig != null && ig.isNotEmpty && ig != 'mystery');
        }
      } else {
        showToast('$e');
      }
    } finally {
      authService.recordExRetryResult(hasExAccess: hasEx);
      if (mounted) {
        setState(() => _retryingEx = false);
      }
    }
  }

  void _copyValue(BuildContext context, String label, String? raw) {
    if (raw == null || raw.isEmpty) {
      return;
    }
    Clipboard.setData(ClipboardData(text: raw));
    showToast('$label: ${AuthStrings.of(context).copiedToast}');
  }

  Future<void> _pickRemindDays(
    BuildContext context,
    AuthSessionService service,
    int current,
  ) async {
    final strings = AuthStrings.of(context);
    const options = <int>[1, 3, 5, 7];
    await showEhSheet<void>(
      context: context,
      builder: (sheetCtx) => Padding(
        padding: const EdgeInsets.fromLTRB(12, 16, 12, 12),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            for (final d in options)
              EhSheetOptionRow(
                icon: CupertinoIcons.bell,
                label: strings.beforeDaysLabel(d),
                selected: d == current,
                onPressed: () {
                  service.updateRemindDaysBefore(d);
                  Navigator.of(sheetCtx).pop();
                },
              ),
          ],
        ),
      ),
    );
  }

  Future<void> _pickTtlDays(
    BuildContext context,
    AuthSessionService service,
    int current,
  ) async {
    final strings = AuthStrings.of(context);
    const options = <int>[15, 30, 60, 90];
    await showEhSheet<void>(
      context: context,
      builder: (sheetCtx) => Padding(
        padding: const EdgeInsets.fromLTRB(12, 16, 12, 12),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            for (final d in options)
              EhSheetOptionRow(
                icon: CupertinoIcons.timer,
                label: strings.cycleDaysLabel(d),
                selected: d == current,
                onPressed: () {
                  service.updateTtlDays(d);
                  Navigator.of(sheetCtx).pop();
                },
              ),
          ],
        ),
      ),
    );
  }

  void _openAllCredentialsSheet(BuildContext context, User user) {
    final strings = AuthStrings.of(context);
    final entries = <(String, String?)>[
      ('ipb_member_id', user.memberId),
      ('ipb_pass_hash', user.passHash),
      ('igneous', user.igneous),
      ('sk', user.sk),
      ('hath_perks', user.hathPerks),
      ('cf_clearance', user.cfClearance),
      ('cf_duid', user.cfDuid),
      ('User-Agent', user.userAgent),
    ];

    showEhSheet<void>(
      context: context,
      builder: (sheetCtx) {
        final palette = ehTheme.palette;
        return Padding(
          padding: const EdgeInsets.fromLTRB(18, 18, 18, 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: <Widget>[
              Text(
                strings.sectionCredentials,
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: palette.text1.resolveFrom(sheetCtx),
                ),
              ),
              const SizedBox(height: 12),
              Flexible(
                child: SingleChildScrollView(
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      color: palette.surface.resolveFrom(sheetCtx),
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: Column(
                      children: <Widget>[
                        for (int i = 0; i < entries.length; i++) ...<Widget>[
                          if (i > 0)
                            Padding(
                              padding: const EdgeInsets.only(left: 14),
                              child: Container(
                                height: 0.5,
                                color: EhPalette.separator.resolveFrom(sheetCtx),
                              ),
                            ),
                          GestureDetector(
                            behavior: HitTestBehavior.opaque,
                            onTap: () => _copyValue(
                              sheetCtx,
                              entries[i].$1,
                              entries[i].$2,
                            ),
                            child: Padding(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 14,
                                vertical: 11,
                              ),
                              child: Row(
                                children: <Widget>[
                                  Text(
                                    entries[i].$1,
                                    style: TextStyle(
                                      fontSize: 13,
                                      fontFamily: 'Menlo',
                                      color:
                                          palette.text1.resolveFrom(sheetCtx),
                                    ),
                                  ),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: Text(
                                      AuthStrings.maskSecret(entries[i].$2),
                                      textAlign: TextAlign.right,
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: TextStyle(
                                        fontSize: 12.5,
                                        fontFamily: 'Menlo',
                                        color:
                                            palette.text2.resolveFrom(sheetCtx),
                                      ),
                                    ),
                                  ),
                                  if (entries[i].$2?.isNotEmpty ?? false) ...<Widget>[
                                    const SizedBox(width: 6),
                                    EhSvgIcon(
                                      CupertinoIcons.doc_on_doc,
                                      size: 13,
                                      color:
                                          palette.text3.resolveFrom(sheetCtx),
                                    ),
                                  ],
                                ],
                              ),
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final userCtrl = Get.find<UserController>();
    final authService = AuthSessionService.ensure();
    final strings = AuthStrings.of(context);
    final palette = ehTheme.palette;
    final inDesktopSplitPane = usesDesktopSettingPanes;

    return Obx(() {
      if (!userCtrl.isLogin) {
        return SettingScaffold(
          title: strings.accountPageTitle,
          child: SafeArea(
            child: Center(
              child: CupertinoButton.filled(
                onPressed: () => Get.toNamed(EHRoutes.login),
                child: Text(strings.signIn),
              ),
            ),
          ),
        );
      }

      final user = userCtrl.user.value;
      final snap = authService.snapshot.value;
      final now = authService.now;
      final remDays = snap.remainingDaysAt(now);
      final progress = snap.progressAt(now);
      final status = snap.statusAt(now);
      final tone = switch (status) {
        AuthCountdownStatus.valid => AuthCountdownTone.valid,
        AuthCountdownStatus.expiring => AuthCountdownTone.expiring,
        AuthCountdownStatus.expired => AuthCountdownTone.expired,
      };
      final ig = user.igneous?.trim();
      final hasEx = ig != null && ig.isNotEmpty && ig != 'mystery';

      if (inDesktopSplitPane) {
        return _buildDesktopPaneView(
          context,
          userCtrl: userCtrl,
          user: user,
          authService: authService,
          snap: snap,
          remDays: remDays,
          progress: progress,
          status: status,
          tone: tone,
          hasEx: hasEx,
          strings: strings,
        );
      }

      return CupertinoPageScaffold(
        backgroundColor: palette.canvas.resolveFrom(context),
        child: CustomScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          slivers: <Widget>[
            SliverToBoxAdapter(
              child: _buildMobileCurtainHeader(
                context,
                user: user,
                strings: strings,
              ),
            ),
            SliverSafeArea(
              top: false,
              sliver: SliverPadding(
                padding: const EdgeInsets.fromLTRB(20, 0, 20, 36),
                sliver: SliverToBoxAdapter(
                  child: Center(
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 520),
                      child: _buildMobileContentSections(
                        context,
                        userCtrl: userCtrl,
                        user: user,
                        authService: authService,
                        snap: snap,
                        remDays: remDays,
                        progress: progress,
                        status: status,
                        tone: tone,
                        hasEx: hasEx,
                        strings: strings,
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      );
    });
  }

  /// 移动端方案 B 顶部封面色块幕布 + 压边大圆角头像区
  Widget _buildMobileCurtainHeader(
    BuildContext context, {
    required User user,
    required AuthStrings strings,
  }) {
    final palette = ehTheme.palette;
    final displayName = user.nickName ?? user.username ?? 'E-Hentai';
    final maskedId = AuthStrings.maskSecret(user.memberId);

    return SizedBox(
      height: 256,
      child: Stack(
        children: <Widget>[
          const Positioned(
            top: 0,
            left: 0,
            right: 0,
            height: 205,
            child: CoverMosaicCurtain(columns: 3),
          ),
          SafeArea(
            bottom: false,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 6, 16, 0),
              child: Align(
                alignment: Alignment.topLeft,
                child: LoginFloatingCircleButton(
                  key: const ValueKey<String>('account-back-button'),
                  icon: _isAndroid
                      ? CupertinoIcons.arrow_left
                      : CupertinoIcons.chevron_back,
                  onPressed: () => Navigator.of(context).maybePop(),
                ),
              ),
            ),
          ),
          Positioned(
            left: 0,
            right: 0,
            top: 150,
            bottom: 0,
            child: DecoratedBox(
              decoration: BoxDecoration(
                color: palette.canvas.resolveFrom(context),
                borderRadius: BorderRadius.vertical(
                  top: Radius.circular(_isAndroid ? 28 : 30),
                ),
              ),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Transform.translate(
                      offset: const Offset(0, -32),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: <Widget>[
                          Container(
                            padding: const EdgeInsets.all(4),
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: palette.canvas.resolveFrom(context),
                            ),
                            child: UserAvatarImage(
                              url: user.avatarUrl ?? '',
                              size: 68,
                            ),
                          ),
                          const Spacer(),
                          EhPressable(
                            onPressed: () => showAvatarManageFlow(context),
                            child: Container(
                              height: 32,
                              padding:
                                  const EdgeInsets.symmetric(horizontal: 12),
                              decoration: BoxDecoration(
                                color: palette.fill.resolveFrom(context),
                                borderRadius: BorderRadius.circular(999),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: <Widget>[
                                  EhSvgIcon(
                                    CupertinoIcons.person_crop_circle,
                                    size: 15,
                                    color: palette.text1.resolveFrom(context),
                                  ),
                                  const SizedBox(width: 5),
                                  Text(
                                    strings.changeAvatar,
                                    style: TextStyle(
                                      fontSize: 12.5,
                                      fontWeight: FontWeight.w500,
                                      color:
                                          palette.text1.resolveFrom(context),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          Positioned(
            left: 22,
            right: 22,
            bottom: 6,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(
                  displayName,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: _isAndroid ? 25 : 27,
                    fontWeight: _isAndroid ? FontWeight.w500 : FontWeight.w700,
                    letterSpacing: -0.4,
                    color: palette.text1.resolveFrom(context),
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  'E-Hentai · ID $maskedId',
                  style: TextStyle(
                    fontSize: 13.5,
                    color: palette.text2.resolveFrom(context),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMobileContentSections(
    BuildContext context, {
    required UserController userCtrl,
    required User user,
    required AuthSessionService authService,
    required AuthSessionSnapshot snap,
    required int remDays,
    required double progress,
    required AuthCountdownStatus status,
    required AuthCountdownTone tone,
    required bool hasEx,
    required AuthStrings strings,
  }) {
    final palette = ehTheme.palette;
    final exitSummary = snap.lastExit?.compactWithColo(zh: strings.zh) ??
        authService.currentExit.value?.compactWithColo(zh: strings.zh) ??
        '—';

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        const SizedBox(height: 12),
        _CountdownMonitorCard(
          snap: snap,
          remDays: remDays,
          progress: progress,
          status: status,
          tone: tone,
          isAndroid: _isAndroid,
          strings: strings,
          onReauthenticate: () => showReauthenticateSheet(context),
        ),

        _SectionHeader(title: strings.sectionSiteStatus),
        if (_isAndroid)
          AndroidSettingGroup(
            children: <Widget>[
              AndroidSettingTile(
                title: Text(strings.surfaceSite),
                trailing: _PillBadge(label: strings.statusSignedIn, ok: true),
              ),
              AndroidSettingTile(
                title: Text(strings.innerSite),
                trailing: _PillBadge(
                  label:
                      hasEx ? strings.statusGranted : strings.statusNotGranted,
                  ok: hasEx,
                ),
                onTap: hasEx ? null : _handleRetryEx,
              ),
              AndroidSettingTile(
                title: Text(strings.exitAtAuth),
                subtitle: Text(exitSummary),
              ),
            ],
          )
        else
          _SurfaceCardGroup(
            rows: <Widget>[
              _AccountInfoRow(
                label: strings.surfaceSite,
                trailing: _PillBadge(label: strings.statusSignedIn, ok: true),
              ),
              _AccountInfoRow(
                label: strings.innerSite,
                trailing: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: <Widget>[
                    _PillBadge(
                      label: hasEx
                          ? strings.statusGranted
                          : strings.statusNotGranted,
                      ok: hasEx,
                    ),
                    if (!hasEx) ...<Widget>[
                      const SizedBox(width: 8),
                      _retryingEx
                          ? const CupertinoActivityIndicator(radius: 8)
                          : GestureDetector(
                              onTap: _handleRetryEx,
                              child: EhSvgIcon(
                                CupertinoIcons.refresh,
                                size: 15,
                                color: EhPalette.accent.resolveFrom(context),
                              ),
                            ),
                    ],
                  ],
                ),
              ),
              _AccountInfoRow(
                label: strings.exitAtAuth,
                value: exitSummary,
              ),
            ],
          ),

        _SectionHeader(title: strings.sectionCredentials),
        _SurfaceCardGroup(
          rows: <Widget>[
            _AccountInfoRow(
              label: 'ipb_member_id',
              mono: true,
              value: AuthStrings.maskSecret(user.memberId),
              onTap: () => _copyValue(context, 'ipb_member_id', user.memberId),
            ),
            _AccountInfoRow(
              label: 'ipb_pass_hash',
              mono: true,
              value: AuthStrings.maskSecret(user.passHash),
              onTap: () => _copyValue(context, 'ipb_pass_hash', user.passHash),
            ),
            _AccountInfoRow(
              label: 'igneous',
              mono: true,
              value: AuthStrings.maskSecret(user.igneous),
              onTap: () => _copyValue(context, 'igneous', user.igneous),
            ),
            _AccountInfoRow(
              label: 'cf_clearance',
              mono: true,
              value: (user.cfClearance?.isNotEmpty ?? false)
                  ? (strings.zh ? '已保存' : 'Saved')
                  : '—',
              onTap: () =>
                  _copyValue(context, 'cf_clearance', user.cfClearance),
            ),
            _AccountInfoRow(
              label: strings.viewAllCredentials,
              value: strings.credentialCount(8),
              showChevron: true,
              onTap: () => _openAllCredentialsSheet(context, user),
            ),
          ],
        ),

        if (snap.history.isNotEmpty) ...<Widget>[
          _SectionHeader(title: strings.sectionHistory),
          _SurfaceCardGroup(
            rows: <Widget>[
              for (final item in snap.history.take(4))
                _HistoryRow(entry: item, strings: strings),
            ],
          ),
        ],

        _SectionHeader(title: strings.sectionReminder),
        _SurfaceCardGroup(
          rows: <Widget>[
            _AccountInfoRow(
              label: strings.inAppTopReminder,
              trailing: CupertinoSwitch(
                value: snap.remindEnabled,
                onChanged: authService.updateRemindEnabled,
              ),
            ),
            _AccountInfoRow(
              label: strings.remindAdvance,
              value: strings.beforeDaysLabel(snap.remindDaysBefore),
              showChevron: true,
              onTap: () => _pickRemindDays(
                context,
                authService,
                snap.remindDaysBefore,
              ),
            ),
            _AccountInfoRow(
              label: strings.monitorCycle,
              value: strings.cycleDaysLabel(snap.ttlDays),
              showChevron: true,
              onTap: () => _pickTtlDays(context, authService, snap.ttlDays),
            ),
          ],
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(14, 8, 14, 0),
          child: Text(
            strings.reminderFooter,
            style: TextStyle(
              fontSize: 12,
              height: 1.5,
              color: palette.text3.resolveFrom(context),
            ),
          ),
        ),

        const SizedBox(height: 22),
        EhPressable(
          key: const ValueKey<String>('account-logout-button'),
          onPressed: () => userCtrl.showLogOutDialog(context),
          child: Container(
            height: 48,
            decoration: BoxDecoration(
              color: palette.surface.resolveFrom(context),
              borderRadius: BorderRadius.circular(_isAndroid ? 999 : 16),
              border: Border.all(
                color: _isAndroid
                    ? const Color(0x66C9353B)
                    : palette.hairline.resolveFrom(context),
                width: _isAndroid ? 1.0 : 0.5,
              ),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: <Widget>[
                const EhSvgIcon(
                  CupertinoIcons.square_arrow_right,
                  size: 17,
                  color: Color(0xFFC9353B),
                ),
                const SizedBox(width: 7),
                Text(
                  strings.signOut,
                  style: const TextStyle(
                    fontSize: 15.5,
                    fontWeight: FontWeight.w600,
                    color: Color(0xFFC9353B),
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  /// Desktop 三栏浮岛设置右栏宽屏视图（无顶栏硬边底板，直接露出 canvas）
  Widget _buildDesktopPaneView(
    BuildContext context, {
    required UserController userCtrl,
    required User user,
    required AuthSessionService authService,
    required AuthSessionSnapshot snap,
    required int remDays,
    required double progress,
    required AuthCountdownStatus status,
    required AuthCountdownTone tone,
    required bool hasEx,
    required AuthStrings strings,
  }) {
    final palette = ehTheme.palette;
    final accent = EhPalette.accent.resolveFrom(context);
    final onAccent = EhPalette.onAccent.resolveFrom(context);
    final displayName = user.nickName ?? user.username ?? 'E-Hentai';
    final exitSummary = snap.lastExit?.compactWithColo(zh: strings.zh) ??
        authService.currentExit.value?.compactWithColo(zh: strings.zh) ??
        '—';
    final expDate = snap.expiresAt != null
        ? AuthStrings.formatMonthDay(snap.expiresAt!, zh: strings.zh)
        : '—';
    final lastAuth = snap.lastAuthAt != null
        ? AuthStrings.formatMonthDayTime(snap.lastAuthAt!, zh: strings.zh)
        : '—';

    return CupertinoPageScaffold(
      backgroundColor: palette.canvas.resolveFrom(context),
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(28, 26, 28, 32),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 780),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: <Widget>[
              // 顶部身份与主操作条
              Row(
                children: <Widget>[
                  UserAvatarImage(url: user.avatarUrl ?? '', size: 54),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: <Widget>[
                        Text(
                          displayName,
                          style: TextStyle(
                            fontSize: 21,
                            fontWeight: FontWeight.w700,
                            letterSpacing: -0.3,
                            color: palette.text1.resolveFrom(context),
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          'E-Hentai · ID ${AuthStrings.maskSecret(user.memberId)} · ${strings.exitAtAuth}: $exitSummary',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: 12.5,
                            color: palette.text2.resolveFrom(context),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 12),
                  EhPressable(
                    onPressed: () => showAvatarManageFlow(context),
                    child: Container(
                      height: 34,
                      padding: const EdgeInsets.symmetric(horizontal: 12),
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        color: palette.surface.resolveFrom(context),
                        borderRadius: BorderRadius.circular(9),
                        border: Border.all(
                          color: palette.hairline.resolveFrom(context),
                          width: 0.75,
                        ),
                      ),
                      child: Text(
                        strings.changeAvatar,
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w500,
                          color: palette.text1.resolveFrom(context),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  EhPressable(
                    key: const ValueKey<String>('desktop-reauth-button'),
                    onPressed: () => showReauthenticateSheet(context),
                    child: Container(
                      height: 34,
                      padding: const EdgeInsets.symmetric(horizontal: 14),
                      decoration: BoxDecoration(
                        color: accent,
                        borderRadius: BorderRadius.circular(9),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: <Widget>[
                          EhSvgIcon(
                            CupertinoIcons.refresh,
                            size: 14,
                            color: onAccent,
                          ),
                          const SizedBox(width: 6),
                          Text(
                            strings.reauthenticate,
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                              color: onAccent,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 18),
              // 30 天倒计时横卡
              DecoratedBox(
                decoration: BoxDecoration(
                  color: palette.surface.resolveFrom(context),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    color: palette.hairline.resolveFrom(context),
                    width: 0.5,
                  ),
                ),
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 18,
                    vertical: 15,
                  ),
                  child: Row(
                    children: <Widget>[
                      CountdownRingBadge(
                        remainingDays: remDays,
                        progress: progress,
                        status: tone,
                        size: 54,
                        strokeWidth: 5,
                        compact: true,
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: <Widget>[
                            Row(
                              children: <Widget>[
                                Text(
                                  switch (status) {
                                    AuthCountdownStatus.valid =>
                                      strings.sessionValid,
                                    AuthCountdownStatus.expiring =>
                                      strings.sessionExpiring,
                                    AuthCountdownStatus.expired =>
                                      strings.sessionExpired,
                                  },
                                  style: TextStyle(
                                    fontSize: 15,
                                    fontWeight: FontWeight.w600,
                                    color: palette.text1.resolveFrom(context),
                                  ),
                                ),
                                const SizedBox(width: 8),
                                _PillBadge(
                                  label: strings.cycleDaysLabel(snap.ttlDays),
                                  ok: status == AuthCountdownStatus.valid,
                                ),
                                const Spacer(),
                                Flexible(
                                  child: Text(
                                    '${strings.expiresOnText(expDate, snap.ttlDays)} · ${strings.lastAuthText(lastAuth)}',
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: TextStyle(
                                      fontSize: 12,
                                      color: palette.text2.resolveFrom(context),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 10),
                            ClipRRect(
                              borderRadius: BorderRadius.circular(3),
                              child: SizedBox(
                                height: 6,
                                child: Stack(
                                  fit: StackFit.expand,
                                  children: <Widget>[
                                    ColoredBox(
                                      color: palette.fill.resolveFrom(context),
                                    ),
                                    FractionallySizedBox(
                                      alignment: Alignment.centerLeft,
                                      widthFactor: progress.clamp(0.03, 1.0),
                                      child: ColoredBox(
                                        color: switch (status) {
                                          AuthCountdownStatus.valid => accent,
                                          AuthCountdownStatus.expiring =>
                                            const Color(0xFFE39A2A),
                                          AuthCountdownStatus.expired =>
                                            const Color(0xFFC9353B),
                                        },
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),

              const SizedBox(height: 18),
              // 下方双列：左凭据，右到期提醒与退出
              LayoutBuilder(
                builder: (context, constraints) {
                  final wideCols = constraints.maxWidth >= 560;
                  final leftCol = Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: <Widget>[
                      _SectionHeader(
                        title: strings.sectionCredentials,
                        topPadding: 0,
                      ),
                      _SurfaceCardGroup(
                        rows: <Widget>[
                          _AccountInfoRow(
                            label: strings.sectionSiteStatus,
                            trailing: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: <Widget>[
                                const _PillBadge(label: 'E-Hentai', ok: true),
                                const SizedBox(width: 6),
                                _PillBadge(
                                  label: hasEx
                                      ? 'EX ✓'
                                      : strings.statusNotGranted,
                                  ok: hasEx,
                                ),
                              ],
                            ),
                          ),
                          _AccountInfoRow(
                            label: 'ipb_member_id',
                            mono: true,
                            value: AuthStrings.maskSecret(user.memberId),
                            onTap: () => _copyValue(
                              context,
                              'ipb_member_id',
                              user.memberId,
                            ),
                          ),
                          _AccountInfoRow(
                            label: 'ipb_pass_hash',
                            mono: true,
                            value: AuthStrings.maskSecret(user.passHash),
                            onTap: () => _copyValue(
                              context,
                              'ipb_pass_hash',
                              user.passHash,
                            ),
                          ),
                          _AccountInfoRow(
                            label: 'igneous',
                            mono: true,
                            value: AuthStrings.maskSecret(user.igneous),
                            onTap: () =>
                                _copyValue(context, 'igneous', user.igneous),
                          ),
                          _AccountInfoRow(
                            label: strings.viewAllCredentials,
                            value: strings.credentialCount(8),
                            showChevron: true,
                            onTap: () => _openAllCredentialsSheet(context, user),
                          ),
                        ],
                      ),
                    ],
                  );

                  final rightCol = Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: <Widget>[
                      _SectionHeader(
                        title: strings.sectionReminder,
                        topPadding: wideCols ? 0 : 16,
                      ),
                      _SurfaceCardGroup(
                        rows: <Widget>[
                          _AccountInfoRow(
                            label: strings.inAppTopReminder,
                            trailing: Transform.scale(
                              scale: 0.85,
                              child: CupertinoSwitch(
                                value: snap.remindEnabled,
                                onChanged: authService.updateRemindEnabled,
                              ),
                            ),
                          ),
                          _AccountInfoRow(
                            label: strings.remindAdvance,
                            value:
                                strings.beforeDaysLabel(snap.remindDaysBefore),
                            showChevron: true,
                            onTap: () => _pickRemindDays(
                              context,
                              authService,
                              snap.remindDaysBefore,
                            ),
                          ),
                          _AccountInfoRow(
                            label: strings.monitorCycle,
                            value: strings.cycleDaysLabel(snap.ttlDays),
                            showChevron: true,
                            onTap: () => _pickTtlDays(
                              context,
                              authService,
                              snap.ttlDays,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      EhPressable(
                        key: const ValueKey<String>(
                          'desktop-account-logout-button',
                        ),
                        onPressed: () => userCtrl.showLogOutDialog(context),
                        child: Container(
                          height: 42,
                          decoration: BoxDecoration(
                            color: palette.surface.resolveFrom(context),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                              color: palette.hairline.resolveFrom(context),
                              width: 0.5,
                            ),
                          ),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: <Widget>[
                              const EhSvgIcon(
                                CupertinoIcons.square_arrow_right,
                                size: 15,
                                color: Color(0xFFC9353B),
                              ),
                              const SizedBox(width: 6),
                              Text(
                                strings.signOut,
                                style: const TextStyle(
                                  fontSize: 13.5,
                                  fontWeight: FontWeight.w600,
                                  color: Color(0xFFC9353B),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  );

                  if (!wideCols) {
                    return Column(children: <Widget>[leftCol, rightCol]);
                  }
                  return Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      Expanded(child: leftCol),
                      const SizedBox(width: 16),
                      Expanded(child: rightCol),
                    ],
                  );
                },
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// 替代原设置页独立「Cloudflare 验证」的三态材质「重新认证」面板
class ReauthenticateSheetBody extends StatefulWidget {
  const ReauthenticateSheetBody({super.key});

  @override
  State<ReauthenticateSheetBody> createState() =>
      _ReauthenticateSheetBodyState();
}

class _ReauthenticateSheetBodyState extends State<ReauthenticateSheetBody> {
  final TextEditingController _pwdController = TextEditingController();
  bool _obscure = true;
  bool _busy = false;
  bool _cfNeeded = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    AuthSessionService.ensure().probeExitRegion();
  }

  @override
  void dispose() {
    _pwdController.dispose();
    super.dispose();
  }

  Future<void> _submitPasswordReauth() async {
    if (_busy) {
      return;
    }
    final userCtrl = Get.find<UserController>();
    final strings = AuthStrings.of(context);
    final username =
        (userCtrl.user.value.username ?? userCtrl.user.value.nickName ?? '')
            .trim();
    final pwd = _pwdController.text;

    if (pwd.isEmpty) {
      setState(() {
        _error = strings.zh ? '请输入密码，或点击下方「网页安全验证」' : 'Enter password or use Web Security Check';
      });
      return;
    }

    setState(() {
      _busy = true;
      _error = null;
      _cfNeeded = false;
    });

    try {
      final result = await userLogin(username, pwd);
      if (result != null && (result.memberId?.isNotEmpty ?? false)) {
        userCtrl.user(
          userCtrl.user.value.copyWith(
            memberId: result.memberId?.oN,
            passHash: result.passHash?.oN,
            igneous: (result.igneous ?? userCtrl.user.value.igneous)?.oN,
            sk: (result.sk ?? userCtrl.user.value.sk)?.oN,
          ),
        );
        bool hasEx = _hasValidIgneous(userCtrl);
        if (!hasEx) {
          try {
            await clearExHentaiCookies();
            await getExIgneous();
            hasEx = _hasValidIgneous(userCtrl);
          } catch (_) {}
        }
        AuthSessionService.ensure().recordAuthSuccess(
          memberId: result.memberId!,
          method: AuthMethodKind.password,
          hasExAccess: hasEx,
          zh: strings.zh,
        );
        if (mounted) {
          Navigator.of(context).pop();
        }
        return;
      }
    } catch (e) {
      if (isCfBlockedError(e)) {
        if (mounted) {
          setState(() {
            _busy = false;
            _cfNeeded = true;
          });
        }
        return;
      }
      if (mounted) {
        setState(() {
          _busy = false;
          _error = (e is EhError && e.type == EhErrorType.login)
              ? (strings.zh ? '密码不正确，请重试。' : 'Incorrect password.')
              : '$e';
        });
      }
      return;
    }

    if (mounted) {
      setState(() => _busy = false);
    }
  }

  /// 免密或带密直接打开应用内验证浏览器（原「重新经过 Cloudflare 验证」的完整升级）
  Future<void> _openWebVerifyFlow({required bool withPassword}) async {
    final userCtrl = Get.find<UserController>();
    final strings = AuthStrings.of(context);
    final username =
        (userCtrl.user.value.username ?? userCtrl.user.value.nickName ?? '')
            .trim();
    final pwd = withPassword ? _pwdController.text : null;

    final verification = await openCfVerification(
      username: (withPassword && username.isNotEmpty) ? username : null,
      password: (withPassword && (pwd?.isNotEmpty ?? false)) ? pwd : null,
      acquireExSession: true,
    );
    if (verification == null) {
      return;
    }

    await applyCfVerification(verification);
    final memberId =
        verification.value('ipb_member_id') ?? userCtrl.user.value.memberId;
    if (memberId != null && memberId.isNotEmpty) {
      AuthSessionService.ensure().recordAuthSuccess(
        memberId: memberId,
        method: withPassword ? AuthMethodKind.password : AuthMethodKind.cfVerify,
        hasExAccess:
            verification.hasValidIgneous || _hasValidIgneous(userCtrl),
        verifiedCf: true,
        zh: strings.zh,
      );
    }
    if (mounted) {
      showToast(L10n.of(context).cf_verify_success);
      Navigator.of(context).pop();
    }
  }

  bool _hasValidIgneous(UserController userCtrl) {
    final ig = userCtrl.user.value.igneous?.trim();
    return ig != null && ig.isNotEmpty && ig != 'mystery';
  }

  @override
  Widget build(BuildContext context) {
    final userCtrl = Get.find<UserController>();
    final authService = AuthSessionService.ensure();
    final strings = AuthStrings.of(context);
    final palette = ehTheme.palette;
    final accent = EhPalette.accent.resolveFrom(context);
    final onAccent = EhPalette.onAccent.resolveFrom(context);
    final accountName = userCtrl.user.value.nickName ??
        userCtrl.user.value.username ??
        AuthStrings.maskSecret(userCtrl.user.value.memberId);

    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(20, 14, 20, 20),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          Center(
            child: Container(
              width: 34,
              height: 4,
              margin: const EdgeInsets.only(bottom: 14),
              decoration: BoxDecoration(
                color: palette.text3.resolveFrom(context),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          Row(
            children: <Widget>[
              Expanded(
                child: Text(
                  strings.reauthenticate,
                  style: TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.w700,
                    color: palette.text1.resolveFrom(context),
                  ),
                ),
              ),
              Obx(() {
                final info = authService.currentExit.value;
                if (info == null) {
                  return const SizedBox.shrink();
                }
                return Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: palette.surface.resolveFrom(context),
                    borderRadius: BorderRadius.circular(999),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: <Widget>[
                      Container(
                        width: 7,
                        height: 7,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: info.isAsianRegion
                              ? const Color(0xFFE39A2A)
                              : const Color(0xFF3FA86B),
                        ),
                      ),
                      const SizedBox(width: 6),
                      Text(
                        info.displayLabel(zh: strings.zh),
                        style: TextStyle(
                          fontSize: 12,
                          color: palette.text1.resolveFrom(context),
                        ),
                      ),
                    ],
                  ),
                );
              }),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            strings.reauthSheetSubtitle,
            style: TextStyle(
              fontSize: 13.5,
              color: palette.text2.resolveFrom(context),
            ),
          ),
          const SizedBox(height: 16),

          // 锁定账号 + 密码输入组
          DecoratedBox(
            decoration: BoxDecoration(
              color: palette.surface.resolveFrom(context),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: palette.hairline.resolveFrom(context),
                width: 0.5,
              ),
            ),
            child: Column(
              children: <Widget>[
                SizedBox(
                  height: 48,
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 14),
                    child: Row(
                      children: <Widget>[
                        EhSvgIcon(
                          CupertinoIcons.person,
                          size: 18,
                          color: palette.text3.resolveFrom(context),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            accountName,
                            style: TextStyle(
                              fontSize: 15,
                              color: palette.text2.resolveFrom(context),
                            ),
                          ),
                        ),
                        EhSvgIcon(
                          CupertinoIcons.lock_fill,
                          size: 14,
                          color: palette.text3.resolveFrom(context),
                        ),
                      ],
                    ),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.only(left: 42),
                  child: Container(
                    height: 0.5,
                    color: EhPalette.separator.resolveFrom(context),
                  ),
                ),
                SizedBox(
                  height: 48,
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 14),
                    child: Row(
                      children: <Widget>[
                        EhSvgIcon(
                          CupertinoIcons.lock,
                          size: 18,
                          color: palette.text3.resolveFrom(context),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: CupertinoTextField.borderless(
                            controller: _pwdController,
                            obscureText: _obscure,
                            placeholder: strings.passwordHint,
                            style: TextStyle(
                              fontSize: 15.5,
                              color: palette.text1.resolveFrom(context),
                            ),
                            placeholderStyle: TextStyle(
                              fontSize: 15,
                              color: palette.text3.resolveFrom(context),
                            ),
                            onSubmitted: (_) => _submitPasswordReauth(),
                          ),
                        ),
                        GestureDetector(
                          onTap: () => setState(() => _obscure = !_obscure),
                          child: EhSvgIcon(
                            _obscure
                                ? CupertinoIcons.eye_slash
                                : CupertinoIcons.eye,
                            size: 18,
                            color: palette.text3.resolveFrom(context),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),

          if (_error != null) ...<Widget>[
            const SizedBox(height: 8),
            Text(
              _error!,
              style: const TextStyle(fontSize: 12.5, color: Color(0xFFC9353B)),
            ),
          ],

          if (_cfNeeded) ...<Widget>[
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: const Color(0x1FE89614),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(
                strings.cfContinueHint,
                style: TextStyle(
                  fontSize: 12.5,
                  color: palette.text1.resolveFrom(context),
                ),
              ),
            ),
          ],

          const SizedBox(height: 14),
          EhPressable(
            onPressed: _busy
                ? null
                : (_cfNeeded
                    ? () => _openWebVerifyFlow(withPassword: true)
                    : _submitPasswordReauth),
            child: Container(
              height: 46,
              decoration: BoxDecoration(
                color: accent,
                borderRadius: BorderRadius.circular(14),
              ),
              child: Center(
                child: _busy
                    ? CupertinoActivityIndicator(color: onAccent)
                    : Text(
                        _cfNeeded ? strings.goVerify : strings.reauthResetTtl,
                        style: TextStyle(
                          fontSize: 15.5,
                          fontWeight: FontWeight.w600,
                          color: onAccent,
                        ),
                      ),
              ),
            ),
          ),

          const SizedBox(height: 14),
          Row(
            children: <Widget>[
              Expanded(
                child: EhPressable(
                  key: const ValueKey<String>('reauth-web-verify-button'),
                  onPressed: () => _openWebVerifyFlow(withPassword: false),
                  child: Container(
                    height: 42,
                    decoration: BoxDecoration(
                      color: palette.surface.resolveFrom(context),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: palette.hairline.resolveFrom(context),
                        width: 0.5,
                      ),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: <Widget>[
                        EhSvgIcon(
                          CupertinoIcons.shield_lefthalf_fill,
                          size: 16,
                          color: palette.text1.resolveFrom(context),
                        ),
                        const SizedBox(width: 6),
                        Text(
                          strings.webSecurityVerify,
                          style: TextStyle(
                            fontSize: 13.5,
                            fontWeight: FontWeight.w500,
                            color: palette.text1.resolveFrom(context),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: EhPressable(
                  onPressed: () {
                    Navigator.of(context).pop();
                    if (!Get.isRegistered<LoginController>()) {
                      Get.put(LoginController());
                    }
                    Get.to<bool>(() => const LoginCookie());
                  },
                  child: Container(
                    height: 42,
                    decoration: BoxDecoration(
                      color: palette.surface.resolveFrom(context),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: palette.hairline.resolveFrom(context),
                        width: 0.5,
                      ),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: <Widget>[
                        EhSvgIcon(
                          CupertinoIcons.tickets,
                          size: 16,
                          color: palette.text1.resolveFrom(context),
                        ),
                        const SizedBox(width: 6),
                        Text(
                          strings.updateCookie,
                          style: TextStyle(
                            fontSize: 13.5,
                            fontWeight: FontWeight.w500,
                            color: palette.text1.resolveFrom(context),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _CountdownMonitorCard extends StatelessWidget {
  const _CountdownMonitorCard({
    required this.snap,
    required this.remDays,
    required this.progress,
    required this.status,
    required this.tone,
    required this.isAndroid,
    required this.strings,
    required this.onReauthenticate,
  });

  final AuthSessionSnapshot snap;
  final int remDays;
  final double progress;
  final AuthCountdownStatus status;
  final AuthCountdownTone tone;
  final bool isAndroid;
  final AuthStrings strings;
  final VoidCallback onReauthenticate;

  @override
  Widget build(BuildContext context) {
    final palette = ehTheme.palette;
    final accent = EhPalette.accent.resolveFrom(context);
    final onAccent = EhPalette.onAccent.resolveFrom(context);
    final expDate = snap.expiresAt != null
        ? AuthStrings.formatMonthDay(snap.expiresAt!, zh: strings.zh)
        : '—';
    final lastAuth = snap.lastAuthAt != null
        ? AuthStrings.formatMonthDayTime(snap.lastAuthAt!, zh: strings.zh)
        : '—';

    final isUrgent = status != AuthCountdownStatus.valid;
    final borderColor = switch (status) {
      AuthCountdownStatus.valid => palette.hairline.resolveFrom(context),
      AuthCountdownStatus.expiring => const Color(0x73E39A2A),
      AuthCountdownStatus.expired => const Color(0x66C9353B),
    };

    return DecoratedBox(
      decoration: BoxDecoration(
        color: palette.surface.resolveFrom(context),
        borderRadius: BorderRadius.circular(isAndroid ? 20 : 16),
        border: Border.all(
          color: borderColor,
          width: isUrgent ? 1.0 : 0.5,
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            Row(
              children: <Widget>[
                CountdownRingBadge(
                  remainingDays: remDays,
                  progress: progress,
                  status: tone,
                  unitLabel: strings.remainingDaysUnit,
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      Text(
                        switch (status) {
                          AuthCountdownStatus.valid => strings.sessionValid,
                          AuthCountdownStatus.expiring =>
                            strings.sessionExpiring,
                          AuthCountdownStatus.expired => strings.sessionExpired,
                        },
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                          color: palette.text1.resolveFrom(context),
                        ),
                      ),
                      const SizedBox(height: 3),
                      Text(
                        '${strings.expiresOnText(expDate, snap.ttlDays)}\n${strings.lastAuthText(lastAuth)}',
                        style: TextStyle(
                          fontSize: 12.5,
                          height: 1.45,
                          color: palette.text2.resolveFrom(context),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 14),
            EhPressable(
              key: const ValueKey<String>('account-reauthenticate-button'),
              onPressed: onReauthenticate,
              child: Container(
                height: isAndroid ? 44 : 42,
                decoration: BoxDecoration(
                  color: isUrgent
                      ? accent
                      : EhPalette.accentSoft.resolveFrom(context),
                  borderRadius: BorderRadius.circular(isAndroid ? 999 : 12),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: <Widget>[
                    EhSvgIcon(
                      CupertinoIcons.refresh,
                      size: 16,
                      color: isUrgent ? onAccent : accent,
                    ),
                    const SizedBox(width: 7),
                    Text(
                      isUrgent
                          ? strings.reauthenticateNow
                          : strings.reauthenticate,
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                        color: isUrgent ? onAccent : accent,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  const _SectionHeader({required this.title, this.topPadding = 18});

  final String title;
  final double topPadding;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.fromLTRB(12, topPadding, 12, 6),
      child: Text(
        title,
        style: TextStyle(
          fontSize: 12.5,
          fontWeight: FontWeight.w600,
          color: ehTheme.palette.text2.resolveFrom(context),
        ),
      ),
    );
  }
}

class _SurfaceCardGroup extends StatelessWidget {
  const _SurfaceCardGroup({required this.rows});

  final List<Widget> rows;

  @override
  Widget build(BuildContext context) {
    final palette = ehTheme.palette;
    final list = <Widget>[];
    for (int i = 0; i < rows.length; i++) {
      if (i > 0) {
        list.add(
          Padding(
            padding: const EdgeInsets.only(left: 16),
            child: Container(
              height: 0.5,
              color: EhPalette.separator.resolveFrom(context),
            ),
          ),
        );
      }
      list.add(rows[i]);
    }
    return DecoratedBox(
      decoration: BoxDecoration(
        color: palette.surface.resolveFrom(context),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: palette.hairline.resolveFrom(context),
          width: 0.5,
        ),
      ),
      child: Column(children: list),
    );
  }
}

class _AccountInfoRow extends StatelessWidget {
  const _AccountInfoRow({
    required this.label,
    this.value,
    this.trailing,
    this.mono = false,
    this.showChevron = false,
    this.onTap,
  });

  final String label;
  final String? value;
  final Widget? trailing;
  final bool mono;
  final bool showChevron;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final palette = ehTheme.palette;
    final row = SizedBox(
      height: 44,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16),
        child: Row(
          children: <Widget>[
            Text(
              label,
              style: TextStyle(
                fontSize: mono ? 13 : 14,
                fontFamily: mono ? 'Menlo' : null,
                color: palette.text1.resolveFrom(context),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Align(
                alignment: Alignment.centerRight,
                child: trailing ??
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: <Widget>[
                        if (value != null)
                          Flexible(
                            child: Text(
                              value!,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                fontSize: mono ? 12.5 : 13.5,
                                fontFamily: mono ? 'Menlo' : null,
                                color: palette.text2.resolveFrom(context),
                              ),
                            ),
                          ),
                        if (mono && onTap != null) ...<Widget>[
                          const SizedBox(width: 6),
                          EhSvgIcon(
                            CupertinoIcons.doc_on_doc,
                            size: 13,
                            color: palette.text3.resolveFrom(context),
                          ),
                        ],
                        if (showChevron) ...<Widget>[
                          const SizedBox(width: 4),
                          EhSvgIcon(
                            CupertinoIcons.chevron_forward,
                            size: 14,
                            color: palette.text3.resolveFrom(context),
                          ),
                        ],
                      ],
                    ),
              ),
            ),
          ],
        ),
      ),
    );

    if (onTap == null) {
      return row;
    }
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: row,
    );
  }
}

class _HistoryRow extends StatelessWidget {
  const _HistoryRow({required this.entry, required this.strings});

  final AuthHistoryEntry entry;
  final AuthStrings strings;

  @override
  Widget build(BuildContext context) {
    final palette = ehTheme.palette;
    final dt = DateTime.fromMillisecondsSinceEpoch(entry.timestampMs);
    final timeStr = AuthStrings.formatMonthDayTime(dt, zh: strings.zh);
    final sub = <String>[
      timeStr,
      if (entry.exitSummary != null && entry.exitSummary!.isNotEmpty)
        entry.exitSummary!,
    ].join(' · ');

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Container(
            width: 8,
            height: 8,
            margin: const EdgeInsets.only(top: 5, right: 12),
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: entry.hasExAccess
                  ? const Color(0xFF3FA86B)
                  : const Color(0xFFE39A2A),
            ),
          ),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(
                  strings.methodLabel(
                    entry.method,
                    verifiedCf: entry.verifiedCf,
                  ),
                  style: TextStyle(
                    fontSize: 13.5,
                    fontWeight: FontWeight.w500,
                    color: palette.text1.resolveFrom(context),
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  sub,
                  style: TextStyle(
                    fontSize: 12,
                    color: palette.text2.resolveFrom(context),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _PillBadge extends StatelessWidget {
  const _PillBadge({required this.label, required this.ok});

  final String label;
  final bool ok;

  @override
  Widget build(BuildContext context) {
    final bg = ok ? const Color(0x1F1F8A4C) : const Color(0x1FE89614);
    final fg = ok ? const Color(0xFF1F8A4C) : const Color(0xFFB26A00);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 11.5,
          fontWeight: FontWeight.w600,
          color: fg,
        ),
      ),
    );
  }
}
