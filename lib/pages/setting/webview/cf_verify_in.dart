import 'dart:convert';
import 'dart:io' as io;

import 'package:eros_fe/adaptive/platform_capabilities.dart';
import 'package:eros_fe/common/controller/user_controller.dart';
import 'package:eros_fe/common/service/auth_session_service.dart';
import 'package:eros_fe/common/service/theme_service.dart';
import 'package:eros_fe/const/eh_palette.dart';
import 'package:eros_fe/index.dart';
import 'package:eros_fe/network/api.dart';
import 'package:eros_fe/pages/login/widget/login_material_chrome.dart';
import 'package:eros_fe/utils/cf_verification.dart';
import 'package:eros_fe/widget/liquid_glass_popup.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart' show LinearProgressIndicator;
import 'package:flutter_inappwebview/flutter_inappwebview.dart';
import 'package:get/get.dart';

/// 打开内置 WebView 完成 Cloudflare 验证或直接完成浏览器登录与里站握手；取消时返回 null。
///
/// - 当传入 [username] 与 [password] 时，人机验证通过后自动在页面内提交登录并跳转一次里站获取 `igneous`；
/// - 当 [interactiveWebLogin] 为 true 且未传账号密码时，打开论坛登录页由用户手动输入并在拿到会话后自动握手返回；
/// - 默认无参调用时，保持免密安全验证行为（用于头像上传拦截或账号页「网页安全验证」）。
Future<CfVerification?> openCfVerification({
  String? username,
  String? password,
  bool interactiveWebLogin = false,
  bool acquireExSession = true,
}) async {
  final BuildContext? ctx = Get.context;
  if (PlatformCapabilities.isDesktop && ctx != null) {
    return showCupertinoDialog<CfVerification>(
      context: ctx,
      barrierDismissible: false,
      builder: (dialogCtx) => Center(
        child: Container(
          width: 480,
          height: 560,
          clipBehavior: Clip.antiAlias,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(18),
            boxShadow: const <BoxShadow>[
              BoxShadow(
                color: Color(0x470A0C18),
                blurRadius: 42,
                offset: Offset(0, 18),
              ),
            ],
          ),
          child: CfVerifyWebView(
            username: username,
            password: password,
            interactiveWebLogin: interactiveWebLogin,
            acquireExSession: acquireExSession,
            inDesktopDialog: true,
          ),
        ),
      ),
    );
  }

  return Get.to<CfVerification>(
    () => CfVerifyWebView(
      username: username,
      password: password,
      interactiveWebLogin: interactiveWebLogin,
      acquireExSession: acquireExSession,
    ),
  );
}

/// 把验证或网页登录结果写入 cookie jar 与当前用户，之后的 Dio 请求带上同一组 cookie 与 UA
Future<void> applyCfVerification(
  CfVerification verification, {
  void Function()? checkAccount,
}) async {
  final jar = await Api.cookieJar;
  checkAccount?.call();
  if (verification.cookies.isNotEmpty) {
    await jar.saveFromResponse(
      Uri.parse('https://forums.e-hentai.org/'),
      verification.cookies,
    );
    await jar.saveFromResponse(
      Uri.parse(EHConst.EH_BASE_URL),
      verification.cookies,
    );
    await jar.saveFromResponse(
      Uri.parse(EHConst.EX_BASE_URL),
      verification.cookies,
    );
  }
  checkAccount?.call();
  final UserController controller = Get.find();
  final cur = controller.user.value;
  final rawIgneous = verification.value('igneous');
  final validIgneous =
      (rawIgneous != null && rawIgneous.isNotEmpty && rawIgneous != 'mystery')
          ? rawIgneous
          : null;

  controller.user(cur.copyWith(
    memberId: (verification.value('ipb_member_id') ?? cur.memberId)?.oN,
    passHash: (verification.value('ipb_pass_hash') ?? cur.passHash)?.oN,
    igneous: (validIgneous ?? cur.igneous)?.oN,
    hathPerks: (verification.value('hath_perks') ?? cur.hathPerks)?.oN,
    sk: (verification.value('sk') ?? cur.sk)?.oN,
    cfClearance: (verification.value('cf_clearance') ?? cur.cfClearance)?.oN,
    cfDuid: (verification.value('cf_duid') ?? cur.cfDuid)?.oN,
    userAgent: (verification.userAgent ?? cur.userAgent)?.oN,
  ));
}

/// 询问用户是否去验证；验证完成并已保存时返回 true
Future<bool> promptCfVerification() async {
  final context = Get.context;
  if (context == null) {
    return false;
  }
  final l10n = L10n.of(context);
  final confirmed = await showCupertinoDialog<bool>(
    context: context,
    barrierDismissible: true,
    builder: (dialogContext) => EhAlertDialog(
      title: Text(l10n.cf_verify_required),
      content: Text(l10n.cf_verify_prompt),
      actions: <CupertinoDialogAction>[
        CupertinoDialogAction(
          child: Text(l10n.cancel),
          onPressed: () => Navigator.pop(dialogContext),
        ),
        CupertinoDialogAction(
          isDefaultAction: true,
          child: Text(l10n.cf_verify_action),
          onPressed: () => Navigator.pop(dialogContext, true),
        ),
      ],
    ),
  );
  if (confirmed != true) {
    return false;
  }
  final verification = await openCfVerification(acquireExSession: false);
  if (verification == null ||
      (!verification.isComplete && !verification.hasLoginSession)) {
    return false;
  }
  await applyCfVerification(verification);
  return true;
}

class CfVerifyWebView extends StatefulWidget {
  const CfVerifyWebView({
    super.key,
    this.username,
    this.password,
    this.interactiveWebLogin = false,
    this.acquireExSession = true,
    this.inDesktopDialog = false,
  });

  static const kVerifyUrl = 'https://forums.e-hentai.org/index.php';
  static const kSignInUrl =
      'https://forums.e-hentai.org/index.php?act=Login&CODE=00';
  static const kExUrl = 'https://exhentai.org/';

  static bool isForumUri(Uri? uri) =>
      uri?.scheme == 'https' && uri?.host == 'forums.e-hentai.org';

  static bool isEhFamilyUri(Uri? uri) =>
      uri?.scheme == 'https' &&
      (uri?.host == 'forums.e-hentai.org' ||
          uri?.host == 'e-hentai.org' ||
          uri?.host == 'exhentai.org');

  final String? username;
  final String? password;
  final bool interactiveWebLogin;
  final bool acquireExSession;
  final bool inDesktopDialog;

  bool get hasAutoCredentials =>
      (username?.isNotEmpty ?? false) && (password?.isNotEmpty ?? false);

  bool get expectsLoginSession => hasAutoCredentials || interactiveWebLogin;

  @override
  State<CfVerifyWebView> createState() => _CfVerifyWebViewState();
}

class _CfVerifyWebViewState extends State<CfVerifyWebView> {
  final CookieManager _cookieManager = CookieManager.instance();
  InAppWebViewController? _controller;

  bool _finishing = false;
  bool _done = false;
  bool _submittedCredentials = false;
  bool _navigatedEx = false;
  bool _showTroubleActions = false;

  /// 1: 完成验证, 2: 自动登录 / 获取里站, 3: 准备返回
  int _step = 1;
  double _loadProgress = 0.0;
  String _currentHost = 'forums.e-hentai.org';

  String get _initialUrl => widget.expectsLoginSession
      ? CfVerifyWebView.kSignInUrl
      : CfVerifyWebView.kVerifyUrl;

  Future<List<io.Cookie>> _collectAllSiteCookies() async {
    final merged = <String, io.Cookie>{};
    for (final rawUrl in const <String>[
      'https://forums.e-hentai.org/',
      'https://e-hentai.org/',
      'https://exhentai.org/',
    ]) {
      try {
        final list = await _cookieManager.getCookies(url: WebUri(rawUrl));
        for (final c in list) {
          final val = '${c.value}';
          if (val.isEmpty) {
            continue;
          }
          if (c.name == 'igneous' &&
              val == 'mystery' &&
              merged.containsKey('igneous')) {
            continue;
          }
          if (CfVerification.sessionCookieNames.contains(c.name) ||
              CfVerification.cookieNames.contains(c.name)) {
            merged[c.name] = io.Cookie(c.name, val);
          }
        }
      } catch (e) {
        logger.d('collect cookies from $rawUrl error: $e');
      }
    }
    return merged.values.toList();
  }

  Future<void> _onPageReady(Uri? uri) async {
    if (_finishing || _done || !mounted) {
      return;
    }
    final controller = _controller;
    if (controller == null || !CfVerifyWebView.isEhFamilyUri(uri)) {
      return;
    }

    _finishing = true;
    try {
      final title = await controller.getTitle() ?? '';
      if (title.contains('Just a moment') ||
          title.contains('Attention Required')) {
        return;
      }

      final cookies = await _collectAllSiteCookies();
      final rawUa =
          await controller.evaluateJavascript(source: 'navigator.userAgent');
      final userAgent =
          rawUa?.toString().trim().replaceAll(RegExp(r'^"|"$'), '');
      final probe = CfVerification(
        cookies,
        userAgent,
        exVisited: _navigatedEx,
      );

      // 场景 A：仅做免密 Cloudflare 验证（例如账号页点「网页安全验证」或上传头像前过盾）
      if (!widget.expectsLoginSession) {
        if (!probe.isComplete) {
          return;
        }
        if (widget.acquireExSession &&
            !_navigatedEx &&
            probe.hasLoginSession) {
          _navigatedEx = true;
          if (mounted) {
            setState(() => _step = 2);
          }
          await controller.loadUrl(
            urlRequest: URLRequest(url: WebUri(CfVerifyWebView.kExUrl)),
          );
          return;
        }
        await _completeWith(probe);
        return;
      }

      // 场景 B：需要完整登录态（带自动提交账号密码或应用内网页登录）
      if (!probe.hasLoginSession) {
        if (widget.hasAutoCredentials &&
            !_submittedCredentials &&
            CfVerifyWebView.isForumUri(uri)) {
          final injected = await _trySubmitLoginForm(controller);
          if (injected) {
            _submittedCredentials = true;
            if (mounted) {
              setState(() => _step = 2);
            }
          }
        }
        return;
      }

      // 已拿到 ipb_member_id + ipb_pass_hash，顺手在同一个真实 WebView 内握手一次里站拿 igneous
      if (widget.acquireExSession && !_navigatedEx) {
        _navigatedEx = true;
        if (mounted) {
          setState(() => _step = 2);
        }
        await _cookieManager.deleteCookies(
          url: WebUri(CfVerifyWebView.kExUrl),
          domain: '.exhentai.org',
        );
        await controller.loadUrl(
          urlRequest: URLRequest(url: WebUri(CfVerifyWebView.kExUrl)),
        );
        return;
      }

      // 如果正在 remoteapi 跨站握手中间页，等待跳回 exhentai.org
      if (uri?.host == 'forums.e-hentai.org' &&
          (uri?.path.contains('remoteapi.php') ?? false)) {
        return;
      }

      final finalCookies = await _collectAllSiteCookies();
      await _completeWith(
        CfVerification(
          finalCookies,
          userAgent,
          exVisited: _navigatedEx,
        ),
      );
    } catch (error) {
      logger.e('cloudflare / web auth flow error: $error');
    } finally {
      _finishing = false;
    }
  }

  Future<bool> _trySubmitLoginForm(InAppWebViewController controller) async {
    final uJson = jsonEncode(widget.username ?? '');
    final pJson = jsonEncode(widget.password ?? '');
    final script = '''
(function() {
  var u = document.querySelector('input[name="UserName"]');
  var p = document.querySelector('input[name="PassWord"]');
  if (!u || !p) return false;
  u.value = $uJson;
  p.value = $pJson;
  var c = document.querySelector('input[name="CookieDate"]');
  if (c) c.checked = true;
  var f = u.form || p.form || document.querySelector('form[action*="Login"]');
  if (!f) return false;
  f.submit();
  return true;
})();
''';
    final res = await controller.evaluateJavascript(source: script);
    return res == true || res?.toString() == 'true';
  }

  Future<void> _completeWith(CfVerification verification) async {
    final route = ModalRoute.of(context);
    if (!mounted || route?.isCurrent != true || _done) {
      return;
    }
    setState(() => _step = 3);
    _done = true;
    Navigator.of(context).pop(verification);
  }

  Future<void> _clearSiteDataAndReload() async {
    try {
      await _cookieManager.deleteAllCookies();
    } catch (_) {}
    _submittedCredentials = false;
    _navigatedEx = false;
    if (mounted) {
      setState(() {
        _step = 1;
        _showTroubleActions = false;
      });
    }
    await _controller?.loadUrl(
      urlRequest: URLRequest(url: WebUri(_initialUrl)),
    );
  }

  @override
  Widget build(BuildContext context) {
    final strings = AuthStrings.of(context);
    final palette = ehTheme.palette;
    final isAndroid =
        PlatformCapabilities.hostPlatform == TargetPlatform.android;
    final exitInfo = AuthSessionService.ensure().currentExit.value;

    final webView = InAppWebView(
      initialUrlRequest: URLRequest(url: WebUri(_initialUrl)),
      // 不要开启无回调的 useShouldOverrideUrlLoading，避免 iOS 取消首次导航
      initialSettings: InAppWebViewSettings(
        mediaPlaybackRequiresUserGesture: false,
        useHybridComposition: true,
      ),
      onWebViewCreated: (controller) => _controller = controller,
      onProgressChanged: (_, progress) {
        if (mounted) {
          setState(() => _loadProgress = progress / 100.0);
        }
      },
      onLoadStart: (_, uri) {
        if (uri != null && uri.host.isNotEmpty && mounted) {
          setState(() => _currentHost = uri.host);
        }
      },
      onLoadStop: (controller, uri) async {
        if (uri != null && uri.host.isNotEmpty && mounted) {
          setState(() => _currentHost = uri.host);
        }
        await _onPageReady(uri);
      },
    );

    if (isAndroid) {
      return CupertinoPageScaffold(
        backgroundColor: palette.canvas.resolveFrom(context),
        child: SafeArea(
          bottom: false,
          child: Column(
            children: <Widget>[
              _buildAndroidHeader(context, strings),
              if (_loadProgress > 0 && _loadProgress < 1.0)
                SizedBox(
                  height: 3,
                  child: LinearProgressIndicator(
                    value: _loadProgress,
                    backgroundColor:
                        EhPalette.accentSoft.resolveFrom(context),
                    color: EhPalette.accent.resolveFrom(context),
                  ),
                ),
              Expanded(
                child: Stack(
                  children: <Widget>[
                    Positioned.fill(child: webView),
                    Positioned(
                      left: 0,
                      right: 0,
                      bottom: 0,
                      child: _buildAndroidBottomSheet(
                        context,
                        strings,
                        exitInfo,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      );
    }

    // iOS & Desktop：全画幅网页 + 顶部三态材质地址胶囊栏 + 底部三态材质进度坞
    return CupertinoPageScaffold(
      backgroundColor: palette.canvas.resolveFrom(context),
      child: Stack(
        children: <Widget>[
          Positioned.fill(
            child: Padding(
              padding: EdgeInsets.only(
                top: widget.inDesktopDialog ? 54 : 0,
              ),
              child: webView,
            ),
          ),
          SafeArea(
            bottom: false,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(12, 8, 12, 0),
              child: Row(
                children: <Widget>[
                  LoginFloatingCircleButton(
                    icon: CupertinoIcons.xmark,
                    tooltip: strings.cancel,
                    onPressed: () => Navigator.of(context).maybePop(),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: SizedBox(
                      height: 40,
                      child: LoginFloatingMaterial(
                        radius: 20,
                        tone: LoginGlassTone.regular,
                        padding: const EdgeInsets.symmetric(horizontal: 14),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: <Widget>[
                            Icon(
                              CupertinoIcons.lock_fill,
                              size: 13,
                              color: palette.text2.resolveFrom(context),
                            ),
                            const SizedBox(width: 6),
                            Flexible(
                              child: Text(
                                _currentHost,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                  fontSize: 13.5,
                                  fontWeight: FontWeight.w600,
                                  color: palette.text1.resolveFrom(context),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  LoginFloatingCircleButton(
                    icon: CupertinoIcons.refresh,
                    onPressed: () => _controller?.reload(),
                  ),
                ],
              ),
            ),
          ),
          Positioned(
            left: 12,
            right: 12,
            bottom: widget.inDesktopDialog ? 12 : 24,
            child: SafeArea(
              top: false,
              child: LoginFloatingMaterial(
                radius: 24,
                tone: LoginGlassTone.regular,
                padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
                child: _buildDockContent(context, strings, exitInfo),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAndroidHeader(BuildContext context, AuthStrings strings) {
    final palette = ehTheme.palette;
    return SizedBox(
      height: 60,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 4),
        child: Row(
          children: <Widget>[
            CupertinoButton(
              padding: const EdgeInsets.all(12),
              onPressed: () => Navigator.of(context).maybePop(),
              child: Icon(
                CupertinoIcons.xmark,
                size: 21,
                color: palette.text1.resolveFrom(context),
              ),
            ),
            Expanded(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Text(
                    strings.verifyBrowserTitle,
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w500,
                      color: palette.text1.resolveFrom(context),
                    ),
                  ),
                  Row(
                    children: <Widget>[
                      Icon(
                        CupertinoIcons.lock_fill,
                        size: 11,
                        color: palette.text2.resolveFrom(context),
                      ),
                      const SizedBox(width: 4),
                      Flexible(
                        child: Text(
                          _currentHost,
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
                ],
              ),
            ),
            CupertinoButton(
              padding: const EdgeInsets.all(12),
              onPressed: () => _controller?.reload(),
              child: Icon(
                CupertinoIcons.refresh,
                size: 20,
                color: palette.text1.resolveFrom(context),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAndroidBottomSheet(
    BuildContext context,
    AuthStrings strings,
    ExitTraceInfo? exitInfo,
  ) {
    final palette = ehTheme.palette;
    return DecoratedBox(
      decoration: BoxDecoration(
        color: palette.canvas.resolveFrom(context),
        borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
        boxShadow: const <BoxShadow>[
          BoxShadow(
            color: Color(0x1F000000),
            blurRadius: 24,
            offset: Offset(0, -4),
          ),
        ],
      ),
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(22, 12, 22, 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              Container(
                width: 32,
                height: 4,
                margin: const EdgeInsets.only(bottom: 14),
                decoration: BoxDecoration(
                  color: palette.text3.resolveFrom(context),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              _buildDockContent(context, strings, exitInfo),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildDockContent(
    BuildContext context,
    AuthStrings strings,
    ExitTraceInfo? exitInfo,
  ) {
    final palette = ehTheme.palette;
    final accent = EhPalette.accent.resolveFrom(context);
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Row(
          children: <Widget>[
            _TrackDot(number: 1, active: _step >= 1),
            const SizedBox(width: 6),
            Text(
              strings.trackStepVerify,
              style: TextStyle(
                fontSize: 12,
                fontWeight: _step == 1 ? FontWeight.w600 : FontWeight.w500,
                color: _step >= 1
                    ? palette.text1.resolveFrom(context)
                    : palette.text2.resolveFrom(context),
              ),
            ),
            Expanded(
              child: Container(
                height: 2,
                margin: const EdgeInsets.symmetric(horizontal: 8),
                color: _step >= 2 ? accent : palette.fill.resolveFrom(context),
              ),
            ),
            _TrackDot(number: 2, active: _step >= 2),
            const SizedBox(width: 6),
            Text(
              strings.trackStepAutoLogin,
              style: TextStyle(
                fontSize: 12,
                fontWeight: _step == 2 ? FontWeight.w600 : FontWeight.w500,
                color: _step >= 2
                    ? palette.text1.resolveFrom(context)
                    : palette.text2.resolveFrom(context),
              ),
            ),
            Expanded(
              child: Container(
                height: 2,
                margin: const EdgeInsets.symmetric(horizontal: 8),
                color: _step >= 3 ? accent : palette.fill.resolveFrom(context),
              ),
            ),
            _TrackDot(number: 3, active: _step >= 3),
            const SizedBox(width: 6),
            Text(
              strings.trackStepReturn,
              style: TextStyle(
                fontSize: 12,
                color: _step >= 3
                    ? palette.text1.resolveFrom(context)
                    : palette.text2.resolveFrom(context),
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),
        Text(
          widget.expectsLoginSession
              ? strings.dockHintVerify
              : strings.dockHintCfOnly,
          style: TextStyle(
            fontSize: 13,
            height: 1.45,
            color: palette.text1.resolveFrom(context),
          ),
        ),
        const SizedBox(height: 8),
        Row(
          children: <Widget>[
            if (exitInfo != null) ...<Widget>[
              Container(
                width: 7,
                height: 7,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: exitInfo.isAsianRegion
                      ? const Color(0xFFE39A2A)
                      : const Color(0xFF3FA86B),
                ),
              ),
              const SizedBox(width: 6),
              Text(
                exitInfo.displayLabel(zh: strings.zh),
                style: TextStyle(
                  fontSize: 12,
                  color: palette.text2.resolveFrom(context),
                ),
              ),
            ],
            const Spacer(),
            GestureDetector(
              onTap: () =>
                  setState(() => _showTroubleActions = !_showTroubleActions),
              child: Text(
                strings.troubleLink,
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: accent,
                ),
              ),
            ),
          ],
        ),
        if (_showTroubleActions) ...<Widget>[
          const SizedBox(height: 10),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: <Widget>[
              _SmallActionChip(
                label: strings.clearWebDataAndReload,
                onTap: _clearSiteDataAndReload,
              ),
              _SmallActionChip(
                label: strings.recheckExit,
                onTap: () => AuthSessionService.ensure().probeExitRegion(),
              ),
            ],
          ),
        ],
      ],
    );
  }
}

class _TrackDot extends StatelessWidget {
  const _TrackDot({required this.number, required this.active});

  final int number;
  final bool active;

  @override
  Widget build(BuildContext context) {
    final palette = ehTheme.palette;
    final accent = EhPalette.accent.resolveFrom(context);
    final onAccent = EhPalette.onAccent.resolveFrom(context);
    return Container(
      width: 20,
      height: 20,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: active ? accent : palette.fill.resolveFrom(context),
      ),
      child: Text(
        '$number',
        style: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w700,
          color: active ? onAccent : palette.text2.resolveFrom(context),
        ),
      ),
    );
  }
}

class _SmallActionChip extends StatelessWidget {
  const _SmallActionChip({required this.label, required this.onTap});

  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final palette = ehTheme.palette;
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: palette.fill.resolveFrom(context),
          borderRadius: BorderRadius.circular(999),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w500,
            color: palette.text1.resolveFrom(context),
          ),
        ),
      ),
    );
  }
}
