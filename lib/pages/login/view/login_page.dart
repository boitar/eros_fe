import 'dart:math' as math;

import 'package:eros_fe/adaptive/platform_capabilities.dart';
import 'package:eros_fe/common/service/app_icon_service.dart';
import 'package:eros_fe/common/service/auth_session_service.dart';
import 'package:eros_fe/common/service/ehsetting_service.dart';
import 'package:eros_fe/common/service/theme_service.dart';
import 'package:eros_fe/const/eh_palette.dart';
import 'package:eros_fe/pages/login/controller/login_controller.dart';
import 'package:eros_fe/pages/login/widget/login_material_chrome.dart';
import 'package:eros_fe/widget/eh_buttons.dart';
import 'package:eros_fe/widget/macos_window_chrome.dart';
import 'package:eros_fe/widget/user_avatar_image.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart' show LinearProgressIndicator;
import 'package:get/get.dart';
import 'package:url_launcher/url_launcher_string.dart';
import 'package:eros_fe/widget/eh_svg_icon.dart';

class LoginPage extends GetView<LoginController> {
  const LoginPage({super.key});

  static const String _registerUrl =
      'https://forums.e-hentai.org/index.php?act=Reg&CODE=00';

  bool get _isAndroid =>
      PlatformCapabilities.hostPlatform == TargetPlatform.android;

  @override
  Widget build(BuildContext context) {
    final palette = ehTheme.palette;
    final media = MediaQuery.of(context);
    final isWideDesktop =
        PlatformCapabilities.isDesktop && media.size.width >= 760;

    return CupertinoPageScaffold(
      backgroundColor: palette.canvas.resolveFrom(context),
      resizeToAvoidBottomInset: false,
      child: SizedBox.expand(
        child: GetBuilder<LoginController>(
          builder: (logic) {
            if (isWideDesktop) {
              return _buildDesktopSplitLayout(context, logic);
            }
            return _buildMobileCurtainLayout(context, logic);
          },
        ),
      ),
    );
  }

  /// 移动端 / 窄窗方案 B：上半屏瀑布流色块幕布（随键盘淡出上收） + 下半屏大圆角表单底板
  Widget _buildMobileCurtainLayout(
    BuildContext context,
    LoginController logic,
  ) {
    final palette = ehTheme.palette;
    final media = MediaQuery.of(context);
    final kbHeight = media.viewInsets.bottom;
    final keyboardVisible = kbHeight > 40;
    final isBreathing = logic.phase == LoginFlowPhase.authenticating;

    final double baseTopOffset = switch (logic.phase) {
      LoginFlowPhase.form => 246.0,
      LoginFlowPhase.authenticating => 236.0,
      LoginFlowPhase.cfRequired => 196.0,
      LoginFlowPhase.success || LoginFlowPhase.exDenied => 168.0,
    };
    final double minSheetTop = math.max(media.padding.top + 58, 96.0);
    final double desiredSheetTop = keyboardVisible
        ? minSheetTop
        : math.max(
            minSheetTop,
            math.min(baseTopOffset, media.size.height * 0.34),
          );
    final double maxSheetTop = math.max(0.0, media.size.height - 160.0);
    final double sheetTop = math.min(desiredSheetTop, maxSheetTop);
    final bool showBrandMark = logic.phase == LoginFlowPhase.form &&
        !keyboardVisible &&
        !_isAndroid &&
        sheetTop - 68 >= media.padding.top + 52;

    return Stack(
      fit: StackFit.expand,
      children: <Widget>[
        // 1. 顶部封面色块幕布
        Positioned(
          key: const ValueKey<String>('login-mosaic-curtain'),
          top: 0,
          left: 0,
          right: 0,
          height: sheetTop + 76,
          child: AnimatedOpacity(
            duration: const Duration(milliseconds: 220),
            opacity: keyboardVisible ? 0.32 : 1.0,
            child: CoverMosaicCurtain(
              columns: 3,
              breathing: isBreathing,
            ),
          ),
        ),

        // 2. 品牌角标（仅首屏且键盘收起时浮在底板上沿左侧）
        if (showBrandMark)
          AnimatedPositioned(
            key: const ValueKey<String>('login-brand-mark'),
            duration: const Duration(milliseconds: 240),
            curve: Curves.easeOutCubic,
            left: media.padding.left + 22,
            top: sheetTop - 68,
            child: const _BrandMarkBox(size: 52),
          ),

        // 3. 下半屏大圆角表单底板
        AnimatedPositioned(
          key: const ValueKey<String>('login-form-sheet'),
          duration: const Duration(milliseconds: 240),
          curve: Curves.easeOutCubic,
          left: 0,
          right: 0,
          top: sheetTop,
          bottom: 0,
          child: DecoratedBox(
            decoration: BoxDecoration(
              color: palette.canvas.resolveFrom(context),
              borderRadius: BorderRadius.vertical(
                top: Radius.circular(_isAndroid ? 28 : 30),
              ),
              boxShadow: const <BoxShadow>[
                BoxShadow(
                  color: Color(0x14000000),
                  blurRadius: 20,
                  offset: Offset(0, -2),
                ),
              ],
            ),
            child: SafeArea(
              top: false,
              child: SingleChildScrollView(
                padding: EdgeInsets.fromLTRB(
                  _isAndroid ? 24 : 20,
                  _isAndroid ? 14 : 26,
                  _isAndroid ? 24 : 20,
                  math.max(24, kbHeight + 16),
                ),
                child: Center(
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 460),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: <Widget>[
                        if (_isAndroid)
                          Center(
                            child: Container(
                              width: 32,
                              height: 4,
                              margin: const EdgeInsets.only(bottom: 18),
                              decoration: BoxDecoration(
                                color: palette.text3.resolveFrom(context),
                                borderRadius: BorderRadius.circular(2),
                              ),
                            ),
                          ),
                        _buildPhaseBody(
                          context,
                          logic,
                          isDesktop: false,
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),

        // 4. 左上角三态材质返回钮 + 右上角浮在幕布上的出口地区胶囊（置顶以确保极矮视口仍可点击返回）
        Positioned(
          key: const ValueKey<String>('login-top-bar'),
          top: 0,
          left: 0,
          right: 0,
          child: SafeArea(
            bottom: false,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 6, 16, 0),
              child: Row(
                children: <Widget>[
                  LoginFloatingCircleButton(
                    key: const ValueKey<String>('login-back-button'),
                    icon: _isAndroid
                        ? CupertinoIcons.arrow_left
                        : CupertinoIcons.chevron_back,
                    onPressed: () {
                      if (logic.phase == LoginFlowPhase.authenticating ||
                          logic.phase == LoginFlowPhase.cfRequired) {
                        logic.cancelActiveFlow();
                      } else {
                        Navigator.of(context).maybePop();
                      }
                    },
                  ),
                  const Spacer(),
                  const _ExitRegionFloatingPill(onWall: true),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }

  /// Desktop 宽窗方案 B：左侧倾斜瀑布流色块幕布 + 品牌字标，右侧窄列交互区
  Widget _buildDesktopSplitLayout(
    BuildContext context,
    LoginController logic,
  ) {
    final palette = ehTheme.palette;
    final strings = AuthStrings.of(context);
    final isMacOS =
        PlatformCapabilities.hostPlatform == TargetPlatform.macOS;

    return Row(
      children: <Widget>[
        Expanded(
          flex: 52,
          child: Stack(
            fit: StackFit.expand,
            children: <Widget>[
              CoverMosaicCurtain(
                columns: 4,
                tilted: true,
                fadeDirection: Axis.horizontal,
                breathing: logic.phase == LoginFlowPhase.authenticating,
              ),
              ValueListenableBuilder<MacOSWindowControls>(
                valueListenable: MacOSWindowChrome.controls,
                builder: (context, controls, _) {
                  final topPad = isMacOS
                      ? math.max(16.0, controls.systemSafeTop + 10)
                      : 16.0;
                  final leftPad = isMacOS
                      ? math.max(16.0, controls.leading + 8)
                      : 16.0;
                  return Positioned(
                    top: topPad,
                    left: leftPad,
                    child: LoginFloatingCircleButton(
                      key: const ValueKey<String>('desktop-login-back-button'),
                      icon: CupertinoIcons.chevron_back,
                      onPressed: () {
                        if (logic.phase == LoginFlowPhase.authenticating ||
                            logic.phase == LoginFlowPhase.cfRequired) {
                          logic.cancelActiveFlow();
                        } else {
                          Navigator.of(context).maybePop();
                        }
                      },
                    ),
                  );
                },
              ),
              Positioned(
                left: 40,
                bottom: 40,
                right: 40,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: <Widget>[
                    const _BrandMarkBox(size: 54),
                    const SizedBox(height: 16),
                    Text(
                      'FEhViewer',
                      style: TextStyle(
                        fontSize: 28,
                        fontWeight: FontWeight.w700,
                        letterSpacing: -0.5,
                        color: palette.text1.resolveFrom(context),
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      strings.loginSubtitle,
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
        ),
        Expanded(
          flex: 48,
          child: Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 48, vertical: 36),
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 380),
                child: _buildPhaseBody(
                  context,
                  logic,
                  isDesktop: true,
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildPhaseBody(
    BuildContext context,
    LoginController logic, {
    required bool isDesktop,
  }) {
    switch (logic.phase) {
      case LoginFlowPhase.form:
        return _buildFormBody(context, logic, isDesktop: isDesktop);
      case LoginFlowPhase.authenticating:
        return _buildAuthenticatingBody(context, logic, isDesktop: isDesktop);
      case LoginFlowPhase.cfRequired:
        return _buildCfRequiredBody(context, logic, isDesktop: isDesktop);
      case LoginFlowPhase.success:
        return _buildResultBody(
          context,
          logic,
          hasEx: true,
          isDesktop: isDesktop,
        );
      case LoginFlowPhase.exDenied:
        return _buildResultBody(
          context,
          logic,
          hasEx: false,
          isDesktop: isDesktop,
        );
    }
  }

  /// ① 首屏输入表单 + 亚洲出口温和提醒
  Widget _buildFormBody(
    BuildContext context,
    LoginController logic, {
    required bool isDesktop,
  }) {
    final strings = AuthStrings.of(context);
    final palette = ehTheme.palette;
    final accent = EhPalette.accent.resolveFrom(context);
    final hasError = logic.inlineError != null && logic.inlineError!.isNotEmpty;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: <Widget>[
            Expanded(
              child: Text(
                strings.welcomeBack,
                style: TextStyle(
                  fontSize: isDesktop ? 26 : 28,
                  fontWeight: _isAndroid ? FontWeight.w500 : FontWeight.w700,
                  letterSpacing: -0.4,
                  color: palette.text1.resolveFrom(context),
                ),
              ),
            ),
            if (isDesktop) _ExitRegionFloatingPill(onWall: false),
          ],
        ),
        const SizedBox(height: 6),
        Text(
          strings.loginSubtitle,
          style: TextStyle(
            fontSize: isDesktop ? 13.5 : 14.5,
            color: palette.text2.resolveFrom(context),
          ),
        ),
        const SizedBox(height: 22),

        if (isDesktop)
          _buildDesktopLabeledFields(context, logic, strings, hasError)
        else if (_isAndroid)
          _buildAndroidFilledFields(context, logic, strings, hasError)
        else
          _buildIosGroupedFields(context, logic, strings, hasError),

        if (hasError) ...<Widget>[
          const SizedBox(height: 10),
          Row(
            children: <Widget>[
              const EhSvgIcon(
                CupertinoIcons.exclamationmark_circle,
                size: 15,
                color: Color(0xFFC9353B),
              ),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  logic.inlineError!,
                  style: const TextStyle(
                    fontSize: 13,
                    color: Color(0xFFC9353B),
                  ),
                ),
              ),
            ],
          ),
        ],

        // 亚洲出口提示（仅提醒，不拦截登录）
        Obx(() {
          final exitInfo = logic.authService.currentExit.value;
          if (exitInfo == null || !exitInfo.isAsianRegion) {
            return const SizedBox.shrink();
          }
          final place = exitInfo.displayLabel(zh: strings.zh);
          return Padding(
            padding: const EdgeInsets.only(top: 14),
            child: _AmberNoticeCard(
              text: strings.asianExitNotice(place),
              actionLabel: strings.recheckExit,
              onAction: () => logic.authService.probeExitRegion(),
            ),
          );
        }),

        const SizedBox(height: 18),
        _PrimaryLoginButton(
          key: const ValueKey<String>('login-submit-button'),
          label: strings.signIn,
          isAndroid: _isAndroid,
          isDesktop: isDesktop,
          onPressed: logic.pressLogin,
        ),

        const SizedBox(height: 18),
        if (isDesktop) ...<Widget>[
          _SecondaryActionButton(
            key: const ValueKey<String>('login-web-button'),
            icon: CupertinoIcons.globe,
            label: strings.webSignIn,
            isAndroid: false,
            isDesktop: true,
            onPressed: logic.handOnWeblogin,
          ),
          const SizedBox(height: 8),
          _SecondaryActionButton(
            key: const ValueKey<String>('login-cookie-button'),
            icon: CupertinoIcons.doc_on_clipboard,
            label: strings.useCookieSignIn,
            isAndroid: false,
            isDesktop: true,
            onPressed: logic.hanOnCookieLogin,
          ),
          const SizedBox(height: 18),
          GestureDetector(
            onTap: () => launchUrlString(
              _registerUrl,
              mode: LaunchMode.externalApplication,
            ),
            child: Text(
              strings.zh ? '没有账号？前往论坛注册 ↗' : 'No account? Register on forum ↗',
              style: TextStyle(fontSize: 12.5, color: accent),
            ),
          ),
        ] else if (_isAndroid) ...<Widget>[
          Row(
            children: <Widget>[
              Expanded(
                child: _SecondaryActionButton(
                  icon: CupertinoIcons.globe,
                  label: strings.webSignIn,
                  isAndroid: true,
                  isDesktop: false,
                  onPressed: logic.handOnWeblogin,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _SecondaryActionButton(
                  icon: CupertinoIcons.tickets,
                  label: 'Cookie',
                  isAndroid: true,
                  isDesktop: false,
                  onPressed: logic.hanOnCookieLogin,
                ),
              ),
            ],
          ),
        ] else ...<Widget>[
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: <Widget>[
              CupertinoButton(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                minimumSize: Size.zero,
                onPressed: logic.handOnWeblogin,
                child: Text(
                  strings.webSignIn,
                  style: TextStyle(
                    fontSize: 14.5,
                    fontWeight: FontWeight.w500,
                    color: accent,
                  ),
                ),
              ),
              Container(
                width: 1,
                height: 14,
                margin: const EdgeInsets.symmetric(horizontal: 12),
                color: EhPalette.separator.resolveFrom(context),
              ),
              CupertinoButton(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                minimumSize: Size.zero,
                onPressed: logic.hanOnCookieLogin,
                child: Text(
                  strings.cookieSignIn,
                  style: TextStyle(
                    fontSize: 14.5,
                    fontWeight: FontWeight.w500,
                    color: accent,
                  ),
                ),
              ),
            ],
          ),
        ],
      ],
    );
  }

  Widget _buildIosGroupedFields(
    BuildContext context,
    LoginController logic,
    AuthStrings strings,
    bool hasError,
  ) {
    final palette = ehTheme.palette;
    return DecoratedBox(
      decoration: BoxDecoration(
        color: palette.surface.resolveFrom(context),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: hasError
              ? const Color(0x99D64045)
              : palette.hairline.resolveFrom(context),
          width: hasError ? 1.0 : 0.5,
        ),
      ),
      child: Column(
        children: <Widget>[
          SizedBox(
            height: 52,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Row(
                children: <Widget>[
                  EhSvgIcon(
                    CupertinoIcons.person,
                    size: 19,
                    color: palette.text3.resolveFrom(context),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: CupertinoTextField.borderless(
                      key: const ValueKey<String>('login-username-field'),
                      controller: logic.usernameController,
                      placeholder: strings.usernameHint,
                      style: kTextStyle.copyWith(
                        color: palette.text1.resolveFrom(context),
                      ),
                      placeholderStyle: kTextStyle.copyWith(
                        color: palette.text3.resolveFrom(context),
                      ),
                      textInputAction: TextInputAction.next,
                      autocorrect: false,
                      onChanged: (_) => logic.clearInlineError(),
                      onEditingComplete: () =>
                          FocusScope.of(context).requestFocus(logic.nodePwd),
                    ),
                  ),
                ],
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.only(left: 47),
            child: Container(
              height: 0.5,
              color: EhPalette.separator.resolveFrom(context),
            ),
          ),
          SizedBox(
            height: 52,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Row(
                children: <Widget>[
                  EhSvgIcon(
                    CupertinoIcons.lock,
                    size: 19,
                    color: palette.text3.resolveFrom(context),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: CupertinoTextField.borderless(
                      key: const ValueKey<String>('login-password-field'),
                      controller: logic.passwdController,
                      focusNode: logic.nodePwd,
                      obscureText: logic.obscurePasswd,
                      placeholder: strings.passwordHint,
                      style: kTextStyle.copyWith(
                        color: palette.text1.resolveFrom(context),
                      ),
                      placeholderStyle: kTextStyle.copyWith(
                        color: palette.text3.resolveFrom(context),
                      ),
                      textInputAction: TextInputAction.done,
                      onChanged: (_) => logic.clearInlineError(),
                      onSubmitted: (_) => logic.pressLogin(),
                    ),
                  ),
                  GestureDetector(
                    onTap: logic.switchObscure,
                    behavior: HitTestBehavior.opaque,
                    child: Padding(
                      padding: const EdgeInsets.all(6),
                      child: EhSvgIcon(
                        logic.obscurePasswd
                            ? CupertinoIcons.eye_slash
                            : CupertinoIcons.eye,
                        size: 19,
                        color: palette.text3.resolveFrom(context),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAndroidFilledFields(
    BuildContext context,
    LoginController logic,
    AuthStrings strings,
    bool hasError,
  ) {
    final palette = ehTheme.palette;
    return Column(
      children: <Widget>[
        Container(
          height: 56,
          padding: const EdgeInsets.symmetric(horizontal: 16),
          decoration: BoxDecoration(
            color: palette.surface.resolveFrom(context),
            borderRadius: BorderRadius.circular(16),
            border: hasError
                ? Border.all(color: const Color(0x99D64045), width: 1)
                : null,
          ),
          child: Row(
            children: <Widget>[
              EhSvgIcon(
                CupertinoIcons.person,
                size: 21,
                color: palette.text2.resolveFrom(context),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: CupertinoTextField.borderless(
                  key: const ValueKey<String>('login-username-field'),
                  controller: logic.usernameController,
                  placeholder: strings.usernameHint,
                  style: kTextStyle.copyWith(
                    color: palette.text1.resolveFrom(context),
                  ),
                  placeholderStyle: kTextStyle.copyWith(
                    color: palette.text2.resolveFrom(context),
                  ),
                  textInputAction: TextInputAction.next,
                  autocorrect: false,
                  onChanged: (_) => logic.clearInlineError(),
                  onEditingComplete: () =>
                      FocusScope.of(context).requestFocus(logic.nodePwd),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 10),
        Container(
          height: 56,
          padding: const EdgeInsets.symmetric(horizontal: 16),
          decoration: BoxDecoration(
            color: palette.surface.resolveFrom(context),
            borderRadius: BorderRadius.circular(16),
            border: hasError
                ? Border.all(color: const Color(0x99D64045), width: 1)
                : null,
          ),
          child: Row(
            children: <Widget>[
              EhSvgIcon(
                CupertinoIcons.lock,
                size: 21,
                color: palette.text2.resolveFrom(context),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: CupertinoTextField.borderless(
                  key: const ValueKey<String>('login-password-field'),
                  controller: logic.passwdController,
                  focusNode: logic.nodePwd,
                  obscureText: logic.obscurePasswd,
                  placeholder: strings.passwordHint,
                  style: kTextStyle.copyWith(
                    color: palette.text1.resolveFrom(context),
                  ),
                  placeholderStyle: kTextStyle.copyWith(
                    color: palette.text2.resolveFrom(context),
                  ),
                  textInputAction: TextInputAction.done,
                  onChanged: (_) => logic.clearInlineError(),
                  onSubmitted: (_) => logic.pressLogin(),
                ),
              ),
              GestureDetector(
                onTap: logic.switchObscure,
                child: Padding(
                  padding: const EdgeInsets.all(6),
                  child: EhSvgIcon(
                    logic.obscurePasswd
                        ? CupertinoIcons.eye_slash
                        : CupertinoIcons.eye,
                    size: 20,
                    color: palette.text2.resolveFrom(context),
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildDesktopLabeledFields(
    BuildContext context,
    LoginController logic,
    AuthStrings strings,
    bool hasError,
  ) {
    final palette = ehTheme.palette;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        Text(
          strings.usernameHint,
          style: TextStyle(
            fontSize: 12.5,
            fontWeight: FontWeight.w500,
            color: palette.text2.resolveFrom(context),
          ),
        ),
        const SizedBox(height: 6),
        Container(
          height: 40,
          padding: const EdgeInsets.symmetric(horizontal: 12),
          decoration: BoxDecoration(
            color: palette.surface.resolveFrom(context),
            borderRadius: BorderRadius.circular(10),
            border: Border.all(
              color: hasError
                  ? const Color(0x99D64045)
                  : palette.hairline.resolveFrom(context),
              width: hasError ? 1 : 0.75,
            ),
          ),
          child: CupertinoTextField.borderless(
            key: const ValueKey<String>('login-username-field'),
            controller: logic.usernameController,
            placeholder: strings.usernameHint,
            style: TextStyle(
              fontSize: 14,
              color: palette.text1.resolveFrom(context),
            ),
            placeholderStyle: TextStyle(
              fontSize: 14,
              color: palette.text3.resolveFrom(context),
            ),
            autocorrect: false,
            onChanged: (_) => logic.clearInlineError(),
            onEditingComplete: () =>
                FocusScope.of(context).requestFocus(logic.nodePwd),
          ),
        ),
        const SizedBox(height: 14),
        Text(
          strings.passwordHint,
          style: TextStyle(
            fontSize: 12.5,
            fontWeight: FontWeight.w500,
            color: palette.text2.resolveFrom(context),
          ),
        ),
        const SizedBox(height: 6),
        Container(
          height: 40,
          padding: const EdgeInsets.symmetric(horizontal: 12),
          decoration: BoxDecoration(
            color: palette.surface.resolveFrom(context),
            borderRadius: BorderRadius.circular(10),
            border: Border.all(
              color: hasError
                  ? const Color(0x99D64045)
                  : palette.hairline.resolveFrom(context),
              width: hasError ? 1 : 0.75,
            ),
          ),
          child: Row(
            children: <Widget>[
              Expanded(
                child: CupertinoTextField.borderless(
                  key: const ValueKey<String>('login-password-field'),
                  controller: logic.passwdController,
                  focusNode: logic.nodePwd,
                  obscureText: logic.obscurePasswd,
                  placeholder: '••••••••',
                  style: TextStyle(
                    fontSize: 14,
                    color: palette.text1.resolveFrom(context),
                  ),
                  placeholderStyle: TextStyle(
                    fontSize: 14,
                    color: palette.text3.resolveFrom(context),
                  ),
                  onChanged: (_) => logic.clearInlineError(),
                  onSubmitted: (_) => logic.pressLogin(),
                ),
              ),
              GestureDetector(
                onTap: logic.switchObscure,
                child: EhSvgIcon(
                  logic.obscurePasswd
                      ? CupertinoIcons.eye_slash
                      : CupertinoIcons.eye,
                  size: 17,
                  color: palette.text3.resolveFrom(context),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  /// ② 登录中就地步骤链动画
  Widget _buildAuthenticatingBody(
    BuildContext context,
    LoginController logic, {
    required bool isDesktop,
  }) {
    final strings = AuthStrings.of(context);
    final palette = ehTheme.palette;
    final exitText =
        logic.authService.currentExit.value?.displayLabel(zh: strings.zh);
    final userLabel = logic.usernameController.text.trim();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        Text(
          strings.signingInTitle,
          style: TextStyle(
            fontSize: isDesktop ? 24 : 26,
            fontWeight: _isAndroid ? FontWeight.w500 : FontWeight.w700,
            color: palette.text1.resolveFrom(context),
          ),
        ),
        const SizedBox(height: 6),
        Text(
          <String>[
            if (userLabel.isNotEmpty) userLabel,
            if (exitText != null) exitText,
          ].join(' · '),
          style: TextStyle(
            fontSize: 14,
            color: palette.text2.resolveFrom(context),
          ),
        ),
        if (_isAndroid) ...<Widget>[
          const SizedBox(height: 16),
          ClipRRect(
            borderRadius: BorderRadius.circular(2),
            child: LinearProgressIndicator(
              minHeight: 4,
              backgroundColor: EhPalette.accentSoft.resolveFrom(context),
              color: EhPalette.accent.resolveFrom(context),
            ),
          ),
        ],
        const SizedBox(height: 18),
        LoginStepChainCard(
          states: logic.stepStates,
          metas: logic.stepMetas,
        ),
        const SizedBox(height: 20),
        _SecondaryActionButton(
          label: strings.cancel,
          isAndroid: _isAndroid,
          isDesktop: isDesktop,
          onPressed: logic.cancelActiveFlow,
        ),
      ],
    );
  }

  /// ③ 遇到 Cloudflare 拦截：步骤链暂停 + 单一主按钮「前往验证」
  Widget _buildCfRequiredBody(
    BuildContext context,
    LoginController logic, {
    required bool isDesktop,
  }) {
    final strings = AuthStrings.of(context);
    final palette = ehTheme.palette;
    final accent = EhPalette.accent.resolveFrom(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        Row(
          children: <Widget>[
            Expanded(
              child: Text(
                strings.cfRequiredTitle,
                style: TextStyle(
                  fontSize: isDesktop ? 23 : 26,
                  fontWeight: _isAndroid ? FontWeight.w500 : FontWeight.w700,
                  color: palette.text1.resolveFrom(context),
                ),
              ),
            ),
            if (isDesktop) _ExitRegionFloatingPill(onWall: false),
          ],
        ),
        const SizedBox(height: 6),
        Text(
          strings.cfRequiredSubtitle,
          style: TextStyle(
            fontSize: 14,
            color: palette.text2.resolveFrom(context),
          ),
        ),
        const SizedBox(height: 18),
        LoginStepChainCard(
          states: logic.stepStates,
          metas: logic.stepMetas,
        ),
        const SizedBox(height: 14),
        Text(
          strings.cfContinueHint,
          style: TextStyle(
            fontSize: 13,
            height: 1.55,
            color: palette.text2.resolveFrom(context),
          ),
        ),
        const SizedBox(height: 18),
        _PrimaryLoginButton(
          key: const ValueKey<String>('login-cf-verify-button'),
          icon: CupertinoIcons.shield_lefthalf_fill,
          label: logic.verifyWindowOpen
              ? strings.showVerifyWindow
              : strings.goVerify,
          isAndroid: _isAndroid,
          isDesktop: isDesktop,
          onPressed: logic.continueWithCfBrowser,
        ),
        const SizedBox(height: 14),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: <Widget>[
            CupertinoButton(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              minimumSize: Size.zero,
              onPressed: logic.hanOnCookieLogin,
              child: Text(
                strings.switchToCookie,
                style: TextStyle(fontSize: 13.5, color: accent),
              ),
            ),
            Container(
              width: 1,
              height: 13,
              margin: const EdgeInsets.symmetric(horizontal: 12),
              color: EhPalette.separator.resolveFrom(context),
            ),
            CupertinoButton(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              minimumSize: Size.zero,
              onPressed: logic.cancelActiveFlow,
              child: Text(
                strings.cancel,
                style: TextStyle(
                  fontSize: 13.5,
                  color: palette.text2.resolveFrom(context),
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }

  /// ⑤ 登录成功（双站就绪） / ⑥ 表站已登录但里站未获权限
  Widget _buildResultBody(
    BuildContext context,
    LoginController logic, {
    required bool hasEx,
    required bool isDesktop,
  }) {
    final strings = AuthStrings.of(context);
    final palette = ehTheme.palette;
    final user = logic.userController.user.value;
    final displayName = user.nickName ?? user.username ?? 'E-Hentai';
    final snap = logic.authService.snapshot.value;
    final exitSummary = snap.lastExit?.compactWithColo(zh: strings.zh) ??
        logic.authService.currentExit.value?.compactWithColo(zh: strings.zh) ??
        '—';
    final nowTimeStr = AuthStrings.formatMonthDayTime(
      snap.lastAuthAt ?? DateTime.now(),
      zh: strings.zh,
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        Row(
          children: <Widget>[
            UserAvatarImage(url: user.avatarUrl ?? '', size: 54),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Text(
                    hasEx ? strings.welcomeUser(displayName) : strings.ehOnlyTitle,
                    style: TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.w700,
                      color: palette.text1.resolveFrom(context),
                    ),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    hasEx ? strings.bothSitesReady : strings.ehOnlySubtitle,
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
        const SizedBox(height: 18),
        _GroupedKeyValueCard(
          rows: <Widget>[
            _KvRow(
              label: strings.surfaceSite,
              trailing: _StatusBadge(label: strings.statusSignedIn, ok: true),
            ),
            _KvRow(
              label: strings.innerSite,
              trailing: _StatusBadge(
                label: hasEx ? strings.statusGranted : strings.statusNotGranted,
                ok: hasEx,
              ),
            ),
            _KvRow(
              label: strings.exitAtAuth,
              valueText: exitSummary,
            ),
          ],
        ),
        const SizedBox(height: 14),
        if (hasEx) ...<Widget>[
          _GroupedKeyValueCard(
            rows: <Widget>[
              _KvRow(
                label: 'ipb_member_id',
                mono: true,
                valueText: AuthStrings.maskSecret(user.memberId),
              ),
              _KvRow(
                label: 'igneous',
                mono: true,
                valueText: '${AuthStrings.maskSecret(user.igneous)} ✓',
              ),
              _KvRow(
                label: strings.zh ? '认证时间 · 监控周期' : 'Authenticated · Cycle',
                valueText: '$nowTimeStr · ${snap.ttlDays}d',
              ),
            ],
          ),
          const SizedBox(height: 20),
          _PrimaryLoginButton(
            key: const ValueKey<String>('login-finish-button'),
            label: strings.startBrowsing,
            isAndroid: _isAndroid,
            isDesktop: isDesktop,
            onPressed: logic.finishAndClose,
          ),
        ] else ...<Widget>[
          _AmberNoticeCard(text: strings.exDeniedReason),
          const SizedBox(height: 18),
          _PrimaryLoginButton(
            key: const ValueKey<String>('login-retry-ex-button'),
            icon: CupertinoIcons.refresh,
            label: strings.retryExAfterSwitch,
            loading: logic.loadingLogin,
            isAndroid: _isAndroid,
            isDesktop: isDesktop,
            onPressed: logic.loadingLogin ? null : logic.retryExAccessOnly,
          ),
          const SizedBox(height: 10),
          _SecondaryActionButton(
            label: strings.useEhOnlyForNow,
            isAndroid: _isAndroid,
            isDesktop: isDesktop,
            onPressed: logic.finishAndClose,
          ),
        ],
      ],
    );
  }
}

/// 登录与重新认证共用的四步进度卡片
class LoginStepChainCard extends StatelessWidget {
  const LoginStepChainCard({
    super.key,
    required this.states,
    required this.metas,
  });

  final List<LoginStepState> states;
  final List<String?> metas;

  @override
  Widget build(BuildContext context) {
    final strings = AuthStrings.of(context);
    final palette = ehTheme.palette;
    final titles = <String>[
      strings.stepConnectForum,
      strings.stepVerifyAccount,
      strings.stepExAccess,
      strings.stepSyncProfile,
    ];

    return DecoratedBox(
      decoration: BoxDecoration(
        color: palette.surface.resolveFrom(context),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: palette.hairline.resolveFrom(context),
          width: 0.5,
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 6),
        child: Column(
          children: List<Widget>.generate(titles.length, (i) {
            final st = i < states.length ? states[i] : LoginStepState.waiting;
            final meta = i < metas.length ? metas[i] : null;
            final dimmed = st == LoginStepState.waiting;
            return Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 9),
              child: Row(
                children: <Widget>[
                  _buildLeadingIcon(context, st),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      titles[i],
                      style: TextStyle(
                        fontSize: 14.5,
                        color: dimmed
                            ? palette.text3.resolveFrom(context)
                            : palette.text1.resolveFrom(context),
                      ),
                    ),
                  ),
                  if (meta != null && meta.isNotEmpty)
                    Text(
                      meta,
                      style: TextStyle(
                        fontSize: 12,
                        color: st == LoginStepState.warning
                            ? const Color(0xFFB26A00)
                            : palette.text3.resolveFrom(context),
                      ),
                    ),
                ],
              ),
            );
          }),
        ),
      ),
    );
  }

  Widget _buildLeadingIcon(BuildContext context, LoginStepState state) {
    final accent = EhPalette.accent.resolveFrom(context);
    final onAccent = EhPalette.onAccent.resolveFrom(context);
    switch (state) {
      case LoginStepState.done:
        return Container(
          width: 22,
          height: 22,
          decoration: BoxDecoration(shape: BoxShape.circle, color: accent),
          child: EhSvgIcon(CupertinoIcons.checkmark, size: 13, color: onAccent),
        );
      case LoginStepState.running:
        return const SizedBox(
          width: 22,
          height: 22,
          child: CupertinoActivityIndicator(radius: 9),
        );
      case LoginStepState.warning:
        return Container(
          width: 22,
          height: 22,
          decoration: const BoxDecoration(
            shape: BoxShape.circle,
            color: Color(0x24E39A2A),
          ),
          child: const EhSvgIcon(
            CupertinoIcons.shield_lefthalf_fill,
            size: 13,
            color: Color(0xFFB26A00),
          ),
        );
      case LoginStepState.waiting:
        return Container(
          width: 22,
          height: 22,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            border: Border.all(
              color: EhPalette.separator.resolveFrom(context),
              width: 1.5,
            ),
          ),
        );
    }
  }
}

class _ExitRegionFloatingPill extends StatelessWidget {
  const _ExitRegionFloatingPill({required this.onWall});

  final bool onWall;

  @override
  Widget build(BuildContext context) {
    final strings = AuthStrings.of(context);
    final palette = ehTheme.palette;
    final service = AuthSessionService.ensure();

    return Obx(() {
      final info = service.currentExit.value;
      final probing = service.probingExit.value;
      if (info == null && !probing) {
        return const SizedBox.shrink();
      }
      final label =
          info?.displayLabel(zh: strings.zh) ?? strings.probingExit;
      final dotColor = info == null
          ? palette.text3.resolveFrom(context)
          : (info.isAsianRegion
              ? const Color(0xFFE39A2A)
              : const Color(0xFF3FA86B));

      final row = Row(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          Container(
            width: 7,
            height: 7,
            decoration: BoxDecoration(shape: BoxShape.circle, color: dotColor),
          ),
          const SizedBox(width: 6),
          Text(
            label,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w500,
              color: palette.text1.resolveFrom(context),
            ),
          ),
        ],
      );

      if (onWall) {
        return EhPressable(
          onPressed: service.probeExitRegion,
          child: SizedBox(
            height: 32,
            child: LoginFloatingMaterial(
              radius: 16,
              tone: LoginGlassTone.clear,
              padding: const EdgeInsets.symmetric(horizontal: 12),
              child: row,
            ),
          ),
        );
      }

      return EhPressable(
        onPressed: service.probeExitRegion,
        child: Container(
          height: 28,
          padding: const EdgeInsets.symmetric(horizontal: 10),
          decoration: BoxDecoration(
            color: palette.surface.resolveFrom(context),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: palette.hairline.resolveFrom(context),
              width: 0.5,
            ),
          ),
          child: row,
        ),
      );
    });
  }
}

class _BrandMarkBox extends StatelessWidget {
  const _BrandMarkBox({required this.size});

  final double size;

  EhFeLogoStyle _resolveLogoStyle(EhAppIconStyle iconStyle) {
    return switch (iconStyle) {
      EhAppIconStyle.auto => EhFeLogoStyle.monochrome,
      EhAppIconStyle.light => EhFeLogoStyle.lightGlass,
      EhAppIconStyle.dark => EhFeLogoStyle.darkGlass,
      EhAppIconStyle.purple => EhFeLogoStyle.brandSquircle,
    };
  }

  @override
  Widget build(BuildContext context) {
    if (Get.isRegistered<EhSettingService>()) {
      final settings = Get.find<EhSettingService>();
      Rx<EhAppIconStyle>? iconObs;
      try {
        iconObs = settings.appIconStyleObs;
      } on Object {
        iconObs = null;
      }
      if (iconObs != null) {
        return Obx(
          () => EhFeAppLogo(
            size: size,
            style: _resolveLogoStyle(iconObs!.value),
          ),
        );
      }
    }
    return EhFeAppLogo(
      size: size,
      style: EhFeLogoStyle.monochrome,
    );
  }
}

class _PrimaryLoginButton extends StatelessWidget {
  const _PrimaryLoginButton({
    super.key,
    required this.label,
    required this.onPressed,
    required this.isAndroid,
    required this.isDesktop,
    this.icon,
    this.loading = false,
  });

  final String label;
  final VoidCallback? onPressed;
  final bool isAndroid;
  final bool isDesktop;
  final IconData? icon;
  final bool loading;

  @override
  Widget build(BuildContext context) {
    final accent = EhPalette.accent.resolveFrom(context);
    final onAccent = EhPalette.onAccent.resolveFrom(context);
    final double height = isDesktop ? 40 : (isAndroid ? 48 : 50);
    final double radius = isAndroid ? 999 : (isDesktop ? 10 : 14);

    return EhPressable(
      onPressed: onPressed,
      child: Container(
        height: height,
        decoration: BoxDecoration(
          color: onPressed == null ? accent.withValues(alpha: 0.45) : accent,
          borderRadius: BorderRadius.circular(radius),
        ),
        child: Center(
          child: loading
              ? CupertinoActivityIndicator(color: onAccent)
              : Row(
                  mainAxisSize: MainAxisSize.min,
                  children: <Widget>[
                    if (icon != null) ...<Widget>[
                      EhSvgIcon(icon, size: 18, color: onAccent),
                      const SizedBox(width: 8),
                    ],
                    Text(
                      label,
                      style: TextStyle(
                        fontSize: isDesktop ? 14 : 16,
                        fontWeight: FontWeight.w600,
                        color: onAccent,
                      ),
                    ),
                  ],
                ),
        ),
      ),
    );
  }
}

class _SecondaryActionButton extends StatelessWidget {
  const _SecondaryActionButton({
    super.key,
    required this.label,
    required this.onPressed,
    required this.isAndroid,
    required this.isDesktop,
    this.icon,
  });

  final String label;
  final VoidCallback? onPressed;
  final bool isAndroid;
  final bool isDesktop;
  final IconData? icon;

  @override
  Widget build(BuildContext context) {
    final palette = ehTheme.palette;
    final accent = EhPalette.accent.resolveFrom(context);
    final double height = isDesktop ? 38 : (isAndroid ? 46 : 46);
    final double radius = isAndroid ? 999 : (isDesktop ? 10 : 14);

    final bgColor = isAndroid
        ? EhPalette.accentSoft.resolveFrom(context)
        : (isDesktop
            ? palette.surface.resolveFrom(context)
            : palette.fill.resolveFrom(context));
    final fgColor = isAndroid ? accent : palette.text1.resolveFrom(context);

    return EhPressable(
      onPressed: onPressed,
      child: Container(
        height: height,
        decoration: BoxDecoration(
          color: bgColor,
          borderRadius: BorderRadius.circular(radius),
          border: isDesktop
              ? Border.all(
                  color: palette.hairline.resolveFrom(context),
                  width: 0.75,
                )
              : null,
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: <Widget>[
            if (icon != null) ...<Widget>[
              EhSvgIcon(icon, size: 16, color: fgColor),
              const SizedBox(width: 7),
            ],
            Text(
              label,
              style: TextStyle(
                fontSize: isDesktop ? 13.5 : 15,
                fontWeight: FontWeight.w500,
                color: fgColor,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _AmberNoticeCard extends StatelessWidget {
  const _AmberNoticeCard({
    required this.text,
    this.actionLabel,
    this.onAction,
  });

  final String text;
  final String? actionLabel;
  final VoidCallback? onAction;

  @override
  Widget build(BuildContext context) {
    final palette = ehTheme.palette;
    final accent = EhPalette.accent.resolveFrom(context);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 11),
      decoration: BoxDecoration(
        color: const Color(0x1FE89614),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          const Padding(
            padding: EdgeInsets.only(top: 2),
            child: EhSvgIcon(
              CupertinoIcons.exclamationmark_triangle,
              size: 16,
              color: Color(0xFFB26A00),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Wrap(
              spacing: 6,
              runSpacing: 2,
              children: <Widget>[
                Text(
                  text,
                  style: TextStyle(
                    fontSize: 12.5,
                    height: 1.5,
                    color: palette.text1.resolveFrom(context),
                  ),
                ),
                if (actionLabel != null && onAction != null)
                  GestureDetector(
                    onTap: onAction,
                    child: Text(
                      actionLabel!,
                      style: TextStyle(
                        fontSize: 12.5,
                        fontWeight: FontWeight.w600,
                        color: accent,
                      ),
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

class _GroupedKeyValueCard extends StatelessWidget {
  const _GroupedKeyValueCard({required this.rows});

  final List<Widget> rows;

  @override
  Widget build(BuildContext context) {
    final palette = ehTheme.palette;
    final children = <Widget>[];
    for (int i = 0; i < rows.length; i++) {
      if (i > 0) {
        children.add(
          Padding(
            padding: const EdgeInsets.only(left: 16),
            child: Container(
              height: 0.5,
              color: EhPalette.separator.resolveFrom(context),
            ),
          ),
        );
      }
      children.add(rows[i]);
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
      child: Column(children: children),
    );
  }
}

class _KvRow extends StatelessWidget {
  const _KvRow({
    required this.label,
    this.valueText,
    this.trailing,
    this.mono = false,
  });

  final String label;
  final String? valueText;
  final Widget? trailing;
  final bool mono;

  @override
  Widget build(BuildContext context) {
    final palette = ehTheme.palette;
    return SizedBox(
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
            const Spacer(),
            if (trailing != null)
              trailing!
            else if (valueText != null)
              Flexible(
                child: Text(
                  valueText!,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: mono ? 12.5 : 13.5,
                    fontFamily: mono ? 'Menlo' : null,
                    color: palette.text2.resolveFrom(context),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _StatusBadge extends StatelessWidget {
  const _StatusBadge({required this.label, required this.ok});

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
