import 'package:eros_fe/common/service/auth_session_service.dart';
import 'package:eros_fe/common/service/theme_service.dart';
import 'package:eros_fe/component/setting/setting_scaffold.dart';
import 'package:eros_fe/const/eh_palette.dart';
import 'package:eros_fe/generated/l10n.dart';
import 'package:eros_fe/pages/login/controller/login_controller.dart';
import 'package:eros_fe/widget/eh_buttons.dart';
import 'package:flutter/cupertino.dart';
import 'package:get/get.dart';
import 'package:eros_fe/widget/eh_svg_icon.dart';

class LoginCookie extends GetView<LoginController> {
  const LoginCookie({super.key});

  @override
  Widget build(BuildContext context) {
    final palette = ehTheme.palette;
    final accent = EhPalette.accent.resolveFrom(context);
    final onAccent = EhPalette.onAccent.resolveFrom(context);
    final strings = AuthStrings.of(context);
    const monoStyle = TextStyle(
      fontSize: 14.5,
      fontFamily: 'Menlo',
      height: 1.25,
    );

    return SettingScaffold(
      title: strings.cookieSignIn,
      child: SafeArea(
        child: Align(
          alignment: Alignment.topCenter,
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 480),
            child: GetBuilder<LoginController>(
              builder: (logic) {
                return SingleChildScrollView(
                  padding: const EdgeInsets.fromLTRB(20, 18, 20, 32),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: <Widget>[
                      if (logic.clipboardHasCookieHint) ...<Widget>[
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 14,
                            vertical: 12,
                          ),
                          decoration: BoxDecoration(
                            color: EhPalette.accentSoft.resolveFrom(context),
                            borderRadius: BorderRadius.circular(14),
                          ),
                          child: Row(
                            children: <Widget>[
                              EhSvgIcon(
                                CupertinoIcons.doc_on_clipboard,
                                size: 18,
                                color: accent,
                              ),
                              const SizedBox(width: 10),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: <Widget>[
                                    Text(
                                      strings.zh
                                          ? '剪贴板中检测到 Cookie'
                                          : 'Cookies detected in clipboard',
                                      style: TextStyle(
                                        fontSize: 13.5,
                                        fontWeight: FontWeight.w600,
                                        color: palette.text1.resolveFrom(context),
                                      ),
                                    ),
                                    Text(
                                      'ipb_member_id · ipb_pass_hash',
                                      style: TextStyle(
                                        fontSize: 12,
                                        color: palette.text2.resolveFrom(context),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              CupertinoButton(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 10,
                                  vertical: 4,
                                ),
                                minimumSize: Size.zero,
                                onPressed: logic.readCookieFromClipboard,
                                child: Text(
                                  strings.zh ? '填入' : 'Paste',
                                  style: TextStyle(
                                    fontSize: 13.5,
                                    fontWeight: FontWeight.w600,
                                    color: accent,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 18),
                      ],
                      _FieldSectionLabel(label: 'ipb_member_id'),
                      _MonoInputCard(
                        controller: logic.idController,
                        placeholder: '1234567',
                        style: monoStyle,
                        textInputAction: TextInputAction.next,
                        onEditingComplete: () =>
                            FocusScope.of(context).requestFocus(logic.nodeHash),
                      ),
                      const SizedBox(height: 16),
                      _FieldSectionLabel(label: 'ipb_pass_hash'),
                      _MonoInputCard(
                        controller: logic.hashController,
                        focusNode: logic.nodeHash,
                        placeholder: strings.zh ? '32 位十六进制字符串' : '32-char hex string',
                        style: monoStyle,
                        textInputAction: TextInputAction.next,
                        onEditingComplete: () => FocusScope.of(context)
                            .requestFocus(logic.nodeIgneous),
                      ),
                      const SizedBox(height: 16),
                      _FieldSectionLabel(
                        label: strings.zh
                            ? 'igneous（可选，里站访问凭据）'
                            : 'igneous (optional, EX access)',
                      ),
                      _MonoInputCard(
                        controller: logic.igneousController,
                        focusNode: logic.nodeIgneous,
                        placeholder: strings.zh
                            ? '留空将在登录时自动向里站请求'
                            : 'Leave blank to request automatically',
                        style: monoStyle,
                        textInputAction: TextInputAction.done,
                        onSubmitted: (_) => logic.pressLoginCookie(),
                      ),
                      const SizedBox(height: 24),
                      EhPressable(
                        onPressed:
                            logic.loadingLogin ? null : logic.pressLoginCookie,
                        child: Container(
                          height: 48,
                          decoration: BoxDecoration(
                            color: logic.loadingLogin
                                ? accent.withValues(alpha: 0.45)
                                : accent,
                            borderRadius: BorderRadius.circular(14),
                          ),
                          child: Center(
                            child: logic.loadingLogin
                                ? CupertinoActivityIndicator(color: onAccent)
                                : Text(
                                    L10n.of(context).login,
                                    style: TextStyle(
                                      fontSize: 16,
                                      fontWeight: FontWeight.w600,
                                      color: onAccent,
                                    ),
                                  ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 12),
                      EhPressable(
                        onPressed: logic.readCookieFromClipboard,
                        child: Container(
                          height: 44,
                          decoration: BoxDecoration(
                            color: palette.surface.resolveFrom(context),
                            borderRadius: BorderRadius.circular(14),
                            border: Border.all(
                              color: palette.hairline.resolveFrom(context),
                              width: 0.5,
                            ),
                          ),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: <Widget>[
                              EhSvgIcon(
                                CupertinoIcons.doc_on_clipboard,
                                size: 17,
                                color: palette.text1.resolveFrom(context),
                              ),
                              const SizedBox(width: 8),
                              Text(
                                L10n.of(context).read_from_clipboard,
                                style: TextStyle(
                                  fontSize: 14.5,
                                  fontWeight: FontWeight.w500,
                                  color: palette.text1.resolveFrom(context),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                );
              },
            ),
          ),
        ),
      ),
    );
  }
}

class _FieldSectionLabel extends StatelessWidget {
  const _FieldSectionLabel({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(left: 12, bottom: 6),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 12.5,
          fontWeight: FontWeight.w500,
          color: ehTheme.palette.text2.resolveFrom(context),
        ),
      ),
    );
  }
}

class _MonoInputCard extends StatelessWidget {
  const _MonoInputCard({
    required this.controller,
    required this.placeholder,
    required this.style,
    this.focusNode,
    this.textInputAction,
    this.onEditingComplete,
    this.onSubmitted,
  });

  final TextEditingController controller;
  final String placeholder;
  final TextStyle style;
  final FocusNode? focusNode;
  final TextInputAction? textInputAction;
  final VoidCallback? onEditingComplete;
  final ValueChanged<String>? onSubmitted;

  @override
  Widget build(BuildContext context) {
    final palette = ehTheme.palette;
    return DecoratedBox(
      decoration: BoxDecoration(
        color: palette.surface.resolveFrom(context),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: palette.hairline.resolveFrom(context),
          width: 0.5,
        ),
      ),
      child: SizedBox(
        height: 48,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14),
          child: CupertinoTextField.borderless(
            controller: controller,
            focusNode: focusNode,
            placeholder: placeholder,
            style: style.copyWith(color: palette.text1.resolveFrom(context)),
            placeholderStyle:
                style.copyWith(color: palette.text3.resolveFrom(context)),
            autocorrect: false,
            textInputAction: textInputAction,
            onEditingComplete: onEditingComplete,
            onSubmitted: onSubmitted,
          ),
        ),
      ),
    );
  }
}
