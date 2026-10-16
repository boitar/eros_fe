import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:eros_fe/common/service/ehsetting_service.dart';
import 'package:eros_fe/utils/liquid_glass.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';

bool get liquidGlassPopupsEnabled =>
    defaultTargetPlatform == TargetPlatform.iOS &&
    Get.isRegistered<EhSettingService>() &&
    Get.find<EhSettingService>().liquidGlass;

/// Use the app's system font without inheriting a route's tracking or weight.
abstract final class EhPopupTextStyles {
  static TextStyle body(BuildContext context) =>
      CupertinoTheme.of(context).textTheme.textStyle.copyWith(
            fontSize: 15,
            fontWeight: FontWeight.w400,
            fontVariations: const [],
            letterSpacing: 0,
            height: 1.35,
            color:
                CupertinoDynamicColor.resolve(CupertinoColors.label, context),
          );

  static TextStyle title(BuildContext context) => body(context).copyWith(
        fontSize: 19,
        fontWeight: FontWeight.w600,
        height: 1.3,
      );

  static TextStyle secondary(BuildContext context) => body(context).copyWith(
        color: CupertinoDynamicColor.resolve(
          CupertinoColors.secondaryLabel,
          context,
        ).withValues(alpha: .9),
      );

  static TextStyle sheetTitle(BuildContext context) =>
      secondary(context).copyWith(
        fontWeight: FontWeight.w500,
      );

  static TextStyle action(BuildContext context) => body(context).copyWith(
        fontSize: 17,
        height: 1.3,
      );
}

class EhActionSheetAction extends StatelessWidget {
  const EhActionSheetAction({
    super.key,
    required this.onPressed,
    required this.child,
    this.isDefaultAction = false,
    this.isDestructiveAction = false,
    required this.icon,
    required this.systemIcon,
  });

  final IconData icon;
  final String systemIcon;
  final VoidCallback onPressed;
  final Widget child;
  final bool isDefaultAction;
  final bool isDestructiveAction;

  @override
  Widget build(BuildContext context) => CupertinoActionSheetAction(
        onPressed: onPressed,
        isDefaultAction: isDefaultAction,
        isDestructiveAction: isDestructiveAction,
        child: DefaultTextStyle.merge(
          textAlign: TextAlign.start,
          child: Row(
            children: [
              Expanded(child: child),
              const SizedBox(width: 16),
              ExcludeSemantics(child: Icon(icon, size: 20)),
            ],
          ),
        ),
      );
}

class EhPopupSurface extends StatelessWidget {
  const EhPopupSurface({
    super.key,
    this.isSurfacePainted = true,
    this.child,
  });

  final bool isSurfacePainted;
  final Widget? child;

  @override
  Widget build(BuildContext context) => liquidGlassPopupsEnabled
      ? LiquidGlassPopupSurface(child: child ?? const SizedBox.shrink())
      : CupertinoPopupSurface(
          isSurfacePainted: isSurfacePainted,
          child: child ?? const SizedBox.shrink(),
        );
}

/// Flutter forms stay in the Flutter scene. A UIKit background would otherwise
/// composite above their text, inputs, selection and accessibility nodes.
class LiquidGlassPopupSurface extends StatelessWidget {
  const LiquidGlassPopupSurface({
    super.key,
    required this.child,
    this.borderRadius = const BorderRadius.all(Radius.circular(28)),
    this.enabled,
  });

  final Widget child;
  final BorderRadius borderRadius;
  final bool? enabled;

  @override
  Widget build(BuildContext context) {
    if (!(enabled ?? liquidGlassPopupsEnabled)) {
      return child;
    }
    LiquidGlassAccessibilitySettings.watch();
    return ValueListenableBuilder<bool?>(
      valueListenable: LiquidGlassAccessibilitySettings.reduceTransparency,
      builder: (context, reduceTransparency, _) {
        final opaque =
            reduceTransparency != false || MediaQuery.highContrastOf(context);
        final dark = CupertinoTheme.brightnessOf(context) == Brightness.dark;
        final fill = CupertinoDynamicColor.resolve(
          CupertinoColors.secondarySystemBackground,
          context,
        );
        final background = DecoratedBox(
          decoration: BoxDecoration(
            color: fill.withValues(alpha: opaque ? 1 : (dark ? .9 : .82)),
            borderRadius: borderRadius,
            border: Border.all(
              color: CupertinoDynamicColor.resolve(
                CupertinoColors.separator,
                context,
              ).withValues(alpha: opaque ? .45 : .24),
              width: .5,
            ),
          ),
        );
        return DecoratedBox(
          decoration: BoxDecoration(
            borderRadius: borderRadius,
            boxShadow: const [
              BoxShadow(
                color: Color(0x24000000),
                blurRadius: 32,
                offset: Offset(0, 10),
              ),
            ],
          ),
          child: ClipRRect(
            borderRadius: borderRadius,
            child: Stack(
              children: [
                Positioned.fill(
                  child: IgnorePointer(
                    child: opaque
                        ? background
                        : BackdropFilter(
                            filter: ui.ImageFilter.blur(sigmaX: 24, sigmaY: 24),
                            child: background,
                          ),
                  ),
                ),
                if (!opaque)
                  Positioned.fill(
                    child: IgnorePointer(
                      child: DecoratedBox(
                        decoration: BoxDecoration(
                          borderRadius: borderRadius,
                          gradient: LinearGradient(
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                            colors: [
                              CupertinoColors.white.withValues(alpha: .10),
                              const Color(0x00FFFFFF),
                              CupertinoColors.black.withValues(alpha: .025),
                            ],
                          ),
                          border: Border.all(
                            color: CupertinoColors.white.withValues(
                              alpha: dark ? .20 : .62,
                            ),
                            width: .75,
                          ),
                        ),
                      ),
                    ),
                  ),
                DefaultTextStyle(
                  style: EhPopupTextStyles.body(context),
                  textAlign: TextAlign.start,
                  child: child,
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

class EhAlertDialog extends StatelessWidget {
  const EhAlertDialog({
    super.key,
    this.title,
    this.content,
    this.actions = const [],
    this.scrollController,
    this.actionScrollController,
    this.insetAnimationDuration = const Duration(milliseconds: 100),
    this.insetAnimationCurve = Curves.decelerate,
    this.glassEnabled,
    this.insetForm = false,
  });

  final Widget? title;
  final Widget? content;
  final List<Widget> actions;
  final ScrollController? scrollController;
  final ScrollController? actionScrollController;
  final Duration insetAnimationDuration;
  final Curve insetAnimationCurve;
  final bool? glassEnabled;
  final bool insetForm;

  @override
  Widget build(BuildContext context) {
    if (!(glassEnabled ?? liquidGlassPopupsEnabled)) {
      return CupertinoAlertDialog(
        title: title,
        content: content,
        actions: actions,
        scrollController: scrollController,
        actionScrollController: actionScrollController,
        insetAnimationDuration: insetAnimationDuration,
        insetAnimationCurve: insetAnimationCurve,
      );
    }
    return AnimatedPadding(
      padding: MediaQuery.viewInsetsOf(context) + const EdgeInsets.all(20),
      duration: MediaQuery.disableAnimationsOf(context)
          ? Duration.zero
          : insetAnimationDuration,
      curve: insetAnimationCurve,
      child: MediaQuery.removeViewInsets(
        context: context,
        removeBottom: true,
        child: SafeArea(
          child: LayoutBuilder(builder: (context, constraints) {
            final width = math.min(360.0, constraints.maxWidth);
            final maxHeight = constraints.maxHeight;
            final native = insetForm
                ? null
                : _nativePopup(
                    context,
                    title: title,
                    message: content,
                    actions: actions,
                    width: width,
                    maxHeight: maxHeight,
                  );
            return Center(
              child: SizedBox(
                width: width,
                child: native ??
                    ConstrainedBox(
                      constraints: BoxConstraints(maxHeight: maxHeight),
                      child: LiquidGlassPopupSurface(
                        enabled: true,
                        borderRadius: BorderRadius.all(
                            Radius.circular(insetForm ? 30 : 28)),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Flexible(
                              child: _PopupContentScrollView(
                                inset: insetForm,
                                controller: scrollController,
                                padding: EdgeInsets.fromLTRB(
                                    insetForm ? 20 : 22,
                                    insetForm ? 18 : 22,
                                    insetForm ? 20 : 22,
                                    insetForm ? 12 : 22),
                                child: Column(
                                  mainAxisSize: MainAxisSize.min,
                                  crossAxisAlignment:
                                      CrossAxisAlignment.stretch,
                                  children: [
                                    if (title != null)
                                      DefaultTextStyle.merge(
                                        style: EhPopupTextStyles.title(context),
                                        textAlign: insetForm
                                            ? TextAlign.start
                                            : TextAlign.center,
                                        child: title!,
                                      ),
                                    if (title != null && content != null)
                                      SizedBox(height: insetForm ? 12 : 16),
                                    if (content != null)
                                      DefaultTextStyle.merge(
                                        style: EhPopupTextStyles.body(context),
                                        textAlign: TextAlign.start,
                                        child: content!,
                                      ),
                                  ],
                                ),
                              ),
                            ),
                            if (actions.isNotEmpty)
                              ConstrainedBox(
                                constraints: BoxConstraints(
                                  maxHeight: maxHeight * .4,
                                ),
                                child: SingleChildScrollView(
                                  controller: actionScrollController,
                                  child: Padding(
                                    padding: insetForm
                                        ? const EdgeInsets.fromLTRB(
                                            20, 0, 20, 14)
                                        : EdgeInsets.zero,
                                    child: _PopupActions(
                                        actions: actions, inset: insetForm),
                                  ),
                                ),
                              ),
                          ],
                        ),
                      ),
                    ),
              ),
            );
          }),
        ),
      ),
    );
  }
}

class _PopupContentScrollView extends StatefulWidget {
  const _PopupContentScrollView({
    required this.inset,
    required this.padding,
    required this.child,
    this.controller,
  });

  final bool inset;
  final EdgeInsets padding;
  final Widget child;
  final ScrollController? controller;

  @override
  State<_PopupContentScrollView> createState() =>
      _PopupContentScrollViewState();
}

class _PopupContentScrollViewState extends State<_PopupContentScrollView> {
  final _ownedController = ScrollController();

  @override
  void dispose() {
    _ownedController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final controller =
        widget.controller ?? (widget.inset ? _ownedController : null);
    final scrollView = SingleChildScrollView(
      controller: controller,
      padding: widget.padding,
      child: widget.child,
    );
    if (!widget.inset) {
      return scrollView;
    }
    return CupertinoScrollbar(
      controller: controller,
      thumbVisibility: true,
      thickness: 2.5,
      radius: const Radius.circular(4),
      notificationPredicate: (notification) => notification.depth == 0,
      child: scrollView,
    );
  }
}

class EhActionSheet extends StatelessWidget {
  const EhActionSheet({
    super.key,
    this.title,
    this.message,
    this.actions,
    this.messageScrollController,
    this.actionScrollController,
    this.cancelButton,
    this.glassEnabled,
  });

  final Widget? title;
  final Widget? message;
  final List<Widget>? actions;
  final ScrollController? messageScrollController;
  final ScrollController? actionScrollController;
  final Widget? cancelButton;
  final bool? glassEnabled;

  @override
  Widget build(BuildContext context) {
    if (!(glassEnabled ?? liquidGlassPopupsEnabled)) {
      return CupertinoActionSheet(
        title: title,
        message: message,
        actions: actions,
        messageScrollController: messageScrollController,
        actionScrollController: actionScrollController,
        cancelButton: cancelButton,
      );
    }
    return Padding(
      padding: MediaQuery.viewInsetsOf(context),
      child: SafeArea(
        top: false,
        minimum: const EdgeInsets.fromLTRB(12, 12, 12, 8),
        child: LayoutBuilder(builder: (context, constraints) {
          final width = math.min(420.0, constraints.maxWidth);
          final maxHeight = math.max(0.0, constraints.maxHeight - 24);
          final native = _nativePopup(
            context,
            title: title,
            message: message,
            actions: actions ?? const [],
            cancelButton: cancelButton,
            width: width,
            maxHeight: maxHeight,
            sheet: true,
          );
          return SizedBox(
            width: width,
            child: native ??
                ConstrainedBox(
                  constraints: BoxConstraints(maxHeight: maxHeight),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Flexible(
                        child: LiquidGlassPopupSurface(
                          enabled: true,
                          child: SingleChildScrollView(
                            controller: actionScrollController ??
                                messageScrollController,
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                if (title != null || message != null)
                                  Padding(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 20,
                                      vertical: 16,
                                    ),
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.stretch,
                                      children: [
                                        if (title != null)
                                          DefaultTextStyle.merge(
                                            style: EhPopupTextStyles.sheetTitle(
                                                context),
                                            textAlign: TextAlign.start,
                                            child: title!,
                                          ),
                                        if (title != null && message != null)
                                          const SizedBox(height: 8),
                                        if (message != null)
                                          DefaultTextStyle.merge(
                                            style: EhPopupTextStyles.sheetTitle(
                                                    context)
                                                .copyWith(fontSize: 13),
                                            textAlign: TextAlign.start,
                                            child: message!,
                                          ),
                                      ],
                                    ),
                                  ),
                                _PopupActions(
                                  actions: actions ?? const [],
                                  sheet: true,
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                      if (cancelButton != null) ...[
                        const SizedBox(height: 8),
                        LiquidGlassPopupSurface(
                          enabled: true,
                          child: _PopupButton(
                            action: cancelButton!,
                            cancel: true,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
          );
        }),
      ),
    );
  }
}

class _PopupActions extends StatelessWidget {
  const _PopupActions({
    required this.actions,
    this.sheet = false,
    this.inset = false,
  });
  final List<Widget> actions;
  final bool sheet;
  final bool inset;

  @override
  Widget build(BuildContext context) {
    if (inset) {
      return LayoutBuilder(builder: (context, constraints) {
        final stacked = constraints.maxWidth < 280 ||
            MediaQuery.textScalerOf(context).scale(17) > 27 ||
            actions.length > 2;
        final buttons = [
          for (final action in actions)
            DecoratedBox(
              decoration: BoxDecoration(
                color: CupertinoDynamicColor.resolve(
                    action is CupertinoDialogAction && action.isDefaultAction
                        ? CupertinoTheme.of(context)
                            .primaryColor
                            .withValues(alpha: .12)
                        : CupertinoColors.tertiarySystemFill,
                    context),
                borderRadius: const BorderRadius.all(Radius.circular(16)),
              ),
              child: _PopupButton(action: action, compact: true),
            ),
        ];
        if (stacked || buttons.length == 1) {
          return Column(mainAxisSize: MainAxisSize.min, children: [
            for (var i = 0; i < buttons.length; i++) ...[
              if (i > 0) const SizedBox(height: 8),
              buttons[i],
            ],
          ]);
        }
        return Row(children: [
          for (var i = 0; i < buttons.length; i++) ...[
            if (i > 0) const SizedBox(width: 8),
            Expanded(child: buttons[i]),
          ],
        ]);
      });
    }
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        for (final action in actions) ...[
          Container(
            height: .5,
            color: CupertinoDynamicColor.resolve(
              CupertinoColors.separator,
              context,
            ),
          ),
          _PopupButton(action: action, sheet: sheet),
        ],
      ],
    );
  }
}

class _PopupButton extends StatelessWidget {
  const _PopupButton({
    required this.action,
    this.sheet = false,
    this.cancel = false,
    this.compact = false,
  });
  final Widget action;
  final bool sheet;
  final bool cancel;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final VoidCallback? callback;
    final Widget child;
    final bool destructive;
    final bool primary;
    if (action is EhActionSheetAction) {
      final value = action as EhActionSheetAction;
      callback = value.onPressed;
      child = value.child;
      destructive = value.isDestructiveAction;
      primary = value.isDefaultAction;
    } else if (action is CupertinoDialogAction) {
      final value = action as CupertinoDialogAction;
      callback = value.onPressed;
      child = value.child;
      destructive = value.isDestructiveAction;
      primary = value.isDefaultAction;
    } else if (action is CupertinoActionSheetAction) {
      final value = action as CupertinoActionSheetAction;
      callback = value.onPressed;
      child = value.child;
      destructive = value.isDestructiveAction;
      primary = value.isDefaultAction;
    } else {
      return action;
    }
    return SizedBox(
      width: double.infinity,
      child: CupertinoButton(
        minimumSize: Size(44, compact ? 44 : 52),
        padding:
            EdgeInsets.symmetric(horizontal: 20, vertical: compact ? 10 : 14),
        onPressed: callback,
        child: DefaultTextStyle.merge(
          style: EhPopupTextStyles.action(context).copyWith(
            fontWeight: primary || cancel ? FontWeight.w600 : FontWeight.w400,
            color: CupertinoDynamicColor.resolve(
              destructive
                  ? CupertinoColors.systemRed
                  : sheet
                      ? CupertinoColors.label
                      : CupertinoTheme.of(context).primaryColor,
              context,
            ),
          ),
          textAlign: sheet ? TextAlign.start : TextAlign.center,
          child: sheet
              ? Row(
                  children: [
                    Expanded(child: child),
                    if (action is EhActionSheetAction) ...[
                      const SizedBox(width: 16),
                      ExcludeSemantics(
                        child: Icon(
                          (action as EhActionSheetAction).icon,
                          size: 20,
                          color: destructive
                              ? CupertinoColors.systemRed
                              : CupertinoDynamicColor.resolve(
                                  CupertinoColors.secondaryLabel, context),
                        ),
                      ),
                    ],
                  ],
                )
              : child,
        ),
      ),
    );
  }
}

String? _plainText(Widget? widget) {
  if (widget == null) {
    return '';
  }
  return widget is Text ? widget.data : null;
}

Widget? _nativePopup(
  BuildContext context, {
  required Widget? title,
  required Widget? message,
  required List<Widget> actions,
  required double width,
  required double maxHeight,
  Widget? cancelButton,
  bool sheet = false,
}) {
  if (!LiquidGlassPlatform.isSupported) {
    return null;
  }
  final titleText = _plainText(title);
  final messageText = _plainText(message);
  if (titleText == null || messageText == null) {
    return null;
  }
  final serialized = <Map<String, dynamic>>[];
  final callbacks = <VoidCallback?>[];
  for (final action in [...actions, if (cancelButton != null) cancelButton]) {
    final Widget child;
    final VoidCallback? callback;
    final bool destructive;
    final bool primary;
    if (action is EhActionSheetAction) {
      child = action.child;
      callback = action.onPressed;
      destructive = action.isDestructiveAction;
      primary = action.isDefaultAction;
    } else if (action is CupertinoDialogAction) {
      child = action.child;
      callback = action.onPressed;
      destructive = action.isDestructiveAction;
      primary = action.isDefaultAction;
    } else if (action is CupertinoActionSheetAction) {
      child = action.child;
      callback = action.onPressed;
      destructive = action.isDestructiveAction;
      primary = action.isDefaultAction;
    } else {
      return null;
    }
    final label = _plainText(child);
    if (label == null) {
      return null;
    }
    final color = child is Text ? child.style?.color : null;
    serialized.add({
      'label': label,
      'destructive': destructive,
      'primary': primary,
      'enabled': callback != null,
      if (action is EhActionSheetAction) 'symbol': action.systemIcon,
      if (color != null)
        'color': CupertinoDynamicColor.resolve(color, context).toARGB32(),
    });
    callbacks.add(callback);
  }
  final scaler = MediaQuery.textScalerOf(context);
  double textHeight(String text, TextStyle style, {double trailing = 0}) {
    if (text.isEmpty) {
      return 0;
    }
    final painter = TextPainter(
      text: TextSpan(text: text, style: style),
      textDirection: Directionality.of(context),
      textScaler: scaler,
    )..layout(maxWidth: math.max(1, width - 44 - trailing));
    final height = painter.height;
    painter.dispose();
    return height;
  }

  final titleStyle = sheet
      ? EhPopupTextStyles.sheetTitle(context)
      : EhPopupTextStyles.title(context);
  final messageStyle =
      EhPopupTextStyles.body(context).copyWith(fontSize: sheet ? 13 : 15);
  final headerHeight =
      (titleText.isNotEmpty || messageText.isNotEmpty ? (sheet ? 32 : 44) : 0) +
          textHeight(titleText, titleStyle) +
          textHeight(messageText, messageStyle) +
          (titleText.isNotEmpty && messageText.isNotEmpty ? 8 : 0);
  final desiredHeight = headerHeight +
      serialized.fold<double>(
          0,
          (total, action) =>
              total +
              math.max(
                52,
                textHeight(
                      action['label'] as String,
                      EhPopupTextStyles.action(context),
                      trailing: action.containsKey('symbol') ? 36 : 0,
                    ) +
                    28,
              )) +
      (cancelButton != null ? 8 : 0) +
      2;
  return SizedBox(
    height: math.min(maxHeight, desiredHeight),
    child: _NativeGlassPopup(
      configuration: {
        'title': titleText,
        'message': messageText,
        'actions': serialized,
        'sheet': sheet,
        'hasCancel': cancelButton != null,
        'titleSize': scaler.scale(titleStyle.fontSize!),
        'messageSize': scaler.scale(messageStyle.fontSize!),
        'actionSize': scaler.scale(17),
        'tint': CupertinoDynamicColor.resolve(
          CupertinoTheme.of(context).primaryColor,
          context,
        ).toARGB32(),
        'rtl': Directionality.of(context) == TextDirection.rtl,
        'dark': CupertinoTheme.brightnessOf(context) == Brightness.dark,
        'followSystemTransparency': !Get.isRegistered<EhSettingService>() ||
            Get.find<EhSettingService>().liquidGlassFollowSystemTransparency,
      },
      callbacks: callbacks,
    ),
  );
}

class _NativeGlassPopup extends StatefulWidget {
  const _NativeGlassPopup({
    required this.configuration,
    required this.callbacks,
  });
  final Map<String, dynamic> configuration;
  final List<VoidCallback?> callbacks;

  @override
  State<_NativeGlassPopup> createState() => _NativeGlassPopupState();
}

class _NativeGlassPopupState extends State<_NativeGlassPopup> {
  MethodChannel? _channel;

  @override
  void didUpdateWidget(covariant _NativeGlassPopup oldWidget) {
    super.didUpdateWidget(oldWidget);
    _channel?.invokeMethod<void>('update', widget.configuration);
  }

  @override
  void dispose() {
    _channel?.setMethodCallHandler(null);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => UiKitView(
        viewType: 'eros/liquid-glass-popup',
        creationParams: widget.configuration,
        creationParamsCodec: const StandardMessageCodec(),
        onPlatformViewCreated: (id) {
          if (!mounted) {
            return;
          }
          _channel = MethodChannel('eros/liquid-glass-popup/$id');
          _channel!.setMethodCallHandler((call) async {
            if (!mounted || call.method != 'action') {
              return;
            }
            final index = call.arguments;
            if (index is int && index >= 0 && index < widget.callbacks.length) {
              widget.callbacks[index]?.call();
            }
          });
          _channel!.invokeMethod<void>('update', widget.configuration);
        },
      );
}
