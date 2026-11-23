import 'dart:async';

import 'package:eros_fe/adaptive/platform_capabilities.dart';
import 'package:eros_fe/common/controller/user_controller.dart';
import 'package:eros_fe/common/service/auth_session_service.dart';
import 'package:eros_fe/common/service/layout_service.dart';
import 'package:eros_fe/common/service/theme_service.dart';
import 'package:eros_fe/index.dart';
import 'package:eros_fe/pages/login/widget/login_material_chrome.dart';
import 'package:eros_fe/pages/setting/account_session_page.dart';
import 'package:eros_fe/pages/tab/controller/setting_controller.dart';
import 'package:flutter/cupertino.dart';
import 'package:get/get.dart';

/// 应用内页面顶部登录态到期小弹窗宿主（非系统推送通知）。
///
/// - 进入首页后延迟约 900ms 检查：若已登录且处于临期/超期、未在 24 小时冷却期内，则从页面顶部轻盈滑出；
/// - 跟随用户「液态玻璃 / 毛玻璃 / 纯色」三态材质设置；
/// - 停留 7 秒后自动收起，支持手势上滑或点 `×` 忽略（记录 24h 冷却）。
class AuthExpiryTopBannerHost extends StatefulWidget {
  const AuthExpiryTopBannerHost({
    super.key,
    required this.child,
    this.launchDelay = const Duration(milliseconds: 900),
    this.autoHideDuration = const Duration(seconds: 7),
  });

  final Widget child;
  final Duration launchDelay;
  final Duration autoHideDuration;

  @override
  State<AuthExpiryTopBannerHost> createState() =>
      _AuthExpiryTopBannerHostState();
}

class _AuthExpiryTopBannerHostState extends State<AuthExpiryTopBannerHost>
    with SingleTickerProviderStateMixin, WidgetsBindingObserver {
  late final AnimationController _animController;
  late final Animation<Offset> _slideAnimation;
  Timer? _launchTimer;
  Timer? _autoHideTimer;
  bool _visible = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _animController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 320),
    );
    _slideAnimation = Tween<Offset>(
      begin: const Offset(0, -1.35),
      end: Offset.zero,
    ).animate(
      CurvedAnimation(
        parent: _animController,
        curve: Curves.easeOutCubic,
        reverseCurve: Curves.easeInCubic,
      ),
    );
    _scheduleCheck(widget.launchDelay);
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _scheduleCheck(const Duration(milliseconds: 600));
    }
  }

  void _scheduleCheck(Duration delay) {
    _launchTimer?.cancel();
    _launchTimer = Timer(delay, _evaluateAndShowIfNeeded);
  }

  void _evaluateAndShowIfNeeded() {
    if (!mounted || _visible || !Get.isRegistered<UserController>()) {
      return;
    }
    final userCtrl = Get.find<UserController>();
    final authService = AuthSessionService.ensure();
    if (!authService.shouldShowStartupBanner(isLoggedIn: userCtrl.isLogin)) {
      return;
    }
    authService.markStartupBannerShown();
    setState(() => _visible = true);
    _animController.forward();
    _autoHideTimer?.cancel();
    _autoHideTimer = Timer(widget.autoHideDuration, () {
      _hide(recordCooldown: false);
    });
  }

  Future<void> _hide({required bool recordCooldown}) async {
    _autoHideTimer?.cancel();
    if (recordCooldown) {
      AuthSessionService.ensure().dismissStartupBannerForCooldown();
    }
    if (mounted && _visible) {
      await _animController.reverse();
      if (mounted) {
        setState(() => _visible = false);
      }
    }
  }

  void _openAccountCenter() {
    _hide(recordCooldown: false);
    if (usesDesktopSettingPanes && Get.isRegistered<LayoutServices>()) {
      Get.find<LayoutServices>().tabNavigation.select(EHRoutes.setting);
      if (Get.isRegistered<SettingViewController>()) {
        Get.find<SettingViewController>().open(EHRoutes.accountSession);
      }
      return;
    }
    Get.toNamed(EHRoutes.accountSession);
  }

  Future<void> _openReauthenticate() async {
    await _hide(recordCooldown: false);
    if (!mounted) {
      return;
    }
    await showReauthenticateSheet(context);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _launchTimer?.cancel();
    _autoHideTimer?.cancel();
    _animController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (!_visible) {
      return widget.child;
    }

    final authService = AuthSessionService.ensure();
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
    final strings = AuthStrings.of(context);
    final palette = ehTheme.palette;
    final isDesktop = PlatformCapabilities.isDesktop;

    return Stack(
      children: <Widget>[
        widget.child,
        Positioned(
          top: 0,
          left: isDesktop ? null : 12,
          right: isDesktop ? 18 : 12,
          child: SafeArea(
            bottom: false,
            child: Padding(
              padding: EdgeInsets.only(top: isDesktop ? 52 : 6),
              child: SlideTransition(
                position: _slideAnimation,
                child: GestureDetector(
                  key: const ValueKey<String>('auth-expiry-top-banner'),
                  onVerticalDragEnd: (details) {
                    if ((details.primaryVelocity ?? 0) < -80) {
                      _hide(recordCooldown: true);
                    }
                  },
                  onTap: _openAccountCenter,
                  child: ConstrainedBox(
                    constraints: BoxConstraints(
                      maxWidth: isDesktop ? 460 : 520,
                    ),
                    child: LoginFloatingMaterial(
                      radius: isDesktop ? 999 : 22,
                      tone: LoginGlassTone.regular,
                      padding: EdgeInsets.symmetric(
                        horizontal: isDesktop ? 14 : 13,
                        vertical: isDesktop ? 8 : 11,
                      ),
                      child: Row(
                        mainAxisSize:
                            isDesktop ? MainAxisSize.min : MainAxisSize.max,
                        children: <Widget>[
                          CountdownRingBadge(
                            remainingDays: remDays,
                            progress: progress,
                            status: tone,
                            size: isDesktop ? 32 : 38,
                            strokeWidth: 3.6,
                            compact: true,
                          ),
                          const SizedBox(width: 11),
                          Flexible(
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: <Widget>[
                                Text(
                                  strings.bannerTitle(remDays),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: TextStyle(
                                    fontSize: 13.5,
                                    fontWeight: FontWeight.w600,
                                    color: palette.text1.resolveFrom(context),
                                  ),
                                ),
                                if (!isDesktop)
                                  Text(
                                    strings.bannerSubtitle,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: TextStyle(
                                      fontSize: 12,
                                      color: palette.text2.resolveFrom(context),
                                    ),
                                  ),
                              ],
                            ),
                          ),
                          const SizedBox(width: 10),
                          LoginTintedActionPill(
                            key: const ValueKey<String>(
                              'auth-expiry-banner-action',
                            ),
                            label: strings.reauthenticate,
                            height: isDesktop ? 28 : 32,
                            horizontalPadding: 13,
                            onPressed: _openReauthenticate,
                          ),
                          if (isDesktop) ...<Widget>[
                            const SizedBox(width: 6),
                            GestureDetector(
                              onTap: () => _hide(recordCooldown: true),
                              child: Padding(
                                padding: const EdgeInsets.all(4),
                                child: EhSvgIcon(
                                  CupertinoIcons.xmark,
                                  size: 13,
                                  color: palette.text3.resolveFrom(context),
                                ),
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}
