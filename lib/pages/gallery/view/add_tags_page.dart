import 'package:eros_fe/adaptive/native_navigation.dart';
import 'package:eros_fe/adaptive/native_top_header.dart';
import 'package:eros_fe/adaptive/tab_navigation.dart';
import 'package:eros_fe/common/service/controller_tag_service.dart';
import 'package:eros_fe/common/service/layout_service.dart';
import 'package:eros_fe/common/service/theme_service.dart';
import 'package:eros_fe/component/setting/setting_scaffold.dart';
import 'package:eros_fe/const/const.dart';
import 'package:eros_fe/extension.dart';
import 'package:eros_fe/generated/l10n.dart';
import 'package:eros_fe/models/base/eh_models.dart';
import 'package:eros_fe/pages/gallery/controller/taginfo_controller.dart';
import 'package:eros_fe/widget/canvas_grain.dart';
import 'package:flutter/cupertino.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:get/get.dart';

const CupertinoDynamicColor _kClearButtonColor =
    CupertinoDynamicColor.withBrightness(
      color: Color(0xFF636366),
      darkColor: Color(0xFFAEAEB2),
    );

class AddTagPage extends StatefulWidget {
  const AddTagPage({super.key});

  @override
  State<AddTagPage> createState() => _AddTagPageState();
}

class _AddTagPageState extends State<AddTagPage> {
  late final String _tag;
  late final TagInfoController controller;
  final GlobalKey _nativeInputRowKey = GlobalKey();
  double _nativeInputRowHeight = 0;
  String? _nativeInputRowLayoutSignature;
  bool _nativeInputRowMeasured = false;
  bool _nativeInputRowMeasurePending = false;

  @override
  void initState() {
    super.initState();
    _tag = pageCtrlTagOf(context);
    controller = Get.find(tag: _tag);
    controller.tagsTextController.addListener(_onNativeInputChanged);
  }

  @override
  void dispose() {
    controller.tagsTextController.removeListener(_onNativeInputChanged);
    super.dispose();
    if (Get.isRegistered<TagInfoController>(tag: _tag)) {
      Get.delete<TagInfoController>(tag: _tag);
    }
  }

  void _done() => Get.back(result: controller.tags, id: detailNavigatorId);

  String _nativeInputLayoutSignature(BuildContext context) {
    final media = MediaQuery.of(context);
    return '${media.size.width}|${media.textScaler}|${media.devicePixelRatio}|'
        '${Localizations.localeOf(context)}';
  }

  void _scheduleNativeInputRowMeasure() {
    if (_nativeInputRowMeasurePending) {
      return;
    }
    _nativeInputRowMeasurePending = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _nativeInputRowMeasurePending = false;
      if (!mounted) {
        return;
      }
      final rowContext = _nativeInputRowKey.currentContext;
      final height = rowContext?.size?.height;
      if (rowContext == null || height == null) {
        return;
      }
      final signature = _nativeInputLayoutSignature(rowContext);
      if (_nativeInputRowMeasured &&
          (height - _nativeInputRowHeight).abs() < 0.5 &&
          signature == _nativeInputRowLayoutSignature) {
        return;
      }
      setState(() {
        _nativeInputRowHeight = height;
        _nativeInputRowLayoutSignature = signature;
        _nativeInputRowMeasured = true;
      });
    });
  }

  void _onNativeInputChanged() {
    if (!mounted || !NativeNavigationScope.isEnabled(context)) {
      return;
    }
    if (_nativeInputRowMeasured) {
      setState(() => _nativeInputRowMeasured = false);
    }
    _scheduleNativeInputRowMeasure();
  }

  Widget _inputRow({Key? key}) => Padding(
    key: key,
    padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 10),
    child: CupertinoTextField(
      padding: const EdgeInsets.symmetric(horizontal: 14.0, vertical: 6.0),
      maxLines: null,
      textInputAction: TextInputAction.done,
      decoration: BoxDecoration(
        color: ehTheme.textFieldBackgroundColor,
        borderRadius: const BorderRadius.all(Radius.circular(8.0)),
      ),
      controller: controller.tagsTextController,
      focusNode: controller.focusNode,
      placeholder: L10n.of(context).add_tag_placeholder,
      placeholderStyle: const TextStyle(
        fontWeight: FontWeight.w400,
        color: CupertinoColors.placeholderText,
        height: 1.25,
      ),
      suffix: GetBuilder<TagInfoController>(
        id: GetIds.TAG_ADD_CLEAR_BTN,
        tag: _tag,
        builder: (TagInfoController controller) {
          return controller.showClearButton
              ? GestureDetector(
                  onTap: controller.clear,
                  child: FaIcon(
                    FontAwesomeIcons.circleXmark,
                    size: 16.0,
                    color: CupertinoDynamicColor.resolve(
                      _kClearButtonColor,
                      context,
                    ),
                  ).paddingSymmetric(horizontal: 9),
                )
              : const SizedBox();
        },
      ),
      autofocus: true,
      style: const TextStyle(height: 1.25),
      onEditingComplete: _done,
    ),
  );

  Widget _nativeInputRow() =>
      NotificationListener<SizeChangedLayoutNotification>(
        onNotification: (_) {
          _scheduleNativeInputRowMeasure();
          return false;
        },
        child: SizeChangedLayoutNotifier(
          key: _nativeInputRowKey,
          child: _inputRow(
            key: const ValueKey<String>('nativeAddTags.inputRow'),
          ),
        ),
      );

  Widget _suggestions({List<Widget> slivers = const [QryTagSliverList()]}) =>
      GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: () {
          FocusScope.of(context).requestFocus(FocusNode());
        },
        onPanDown: (DragDownDetails details) {
          FocusScope.of(context).requestFocus(FocusNode());
        },
        child: CustomScrollView(slivers: slivers),
      );

  @override
  Widget build(BuildContext context) {
    final nativeBar = NativeNavigationScope.isEnabled(context);
    final safeTop = MediaQuery.viewPaddingOf(context).top;
    final layoutSignature = _nativeInputLayoutSignature(context);
    if (nativeBar) {
      _scheduleNativeInputRowMeasure();
    }
    return RetainedDraft(
      controller: controller.tagsTextController,
      child: SettingScaffold(
        title: L10n.of(context).add_tags,
        actions: [
          NativeNavigationAction(
            id: 'addTag.done',
            title: L10n.of(context).done,
            symbol: 'checkmark',
            prominent: true,
            onPressed: _done,
          ),
        ],
        trailing: CupertinoButton(
          minSize: 40,
          padding: const EdgeInsets.only(left: 4),
          onPressed: _done,
          child: Text(L10n.of(context).done),
        ),
        nativeBars: nativeBar ? _nativeInputRowHeight : 0,
        nativeForeground: nativeBar
            ? Positioned(
                top: safeTop,
                left: 0,
                right: 0,
                child: CanvasGrain(child: _nativeInputRow()),
              )
            : null,
        child: SafeArea(
          child: nativeBar
              ? Offstage(
                  key: const ValueKey<String>(
                    'nativeAddTags.suggestionsVisibility',
                  ),
                  offstage:
                      !_nativeInputRowMeasured ||
                      _nativeInputRowLayoutSignature != layoutSignature,
                  child: _suggestions(
                    slivers: [
                      SliverToBoxAdapter(
                        child: SizedBox(
                          key: const ValueKey<String>(
                            'nativeAddTags.contentGap',
                          ),
                          height:
                              _nativeInputRowHeight +
                              NativeTopTabHeader.contentGapFor(context),
                        ),
                      ),
                      const QryTagSliverList(),
                    ],
                  ),
                )
              : Column(
                  children: [
                    _inputRow(),
                    Expanded(child: _suggestions()),
                  ],
                ),
        ),
      ),
    );
  }
}

class QryTagSliverList extends StatelessWidget {
  const QryTagSliverList({super.key});

  @override
  Widget build(BuildContext context) {
    final controller = Get.find<TagInfoController>(tag: pageCtrlTagOf(context));
    final textStyle = TextStyle(
      fontSize: 16,
      color: CupertinoDynamicColor.resolve(CupertinoColors.label, context),
    );

    final translateStyle = TextStyle(
      fontSize: 14,
      color: CupertinoDynamicColor.resolve(
        CupertinoColors.secondaryLabel,
        context,
      ),
    );

    final highLightTextStyle = TextStyle(
      fontSize: 16,
      color: CupertinoDynamicColor.resolve(CupertinoColors.systemBlue, context),
    );

    final highLightTranslateStyle = TextStyle(
      fontSize: 14,
      color: CupertinoDynamicColor.resolve(CupertinoColors.systemBlue, context),
    );

    return Obx(
      () => SliverList(
        delegate: SliverChildBuilderDelegate((BuildContext context, int index) {
          final input = controller.currQry;
          final text = controller.qryTags[index].fullTagText ?? '';
          final translate = controller.qryTags[index].fullTagTranslate;

          final textSpans = text
              .split(input)
              .map((e) => TextSpan(text: e, style: textStyle))
              .separat(
                separator: TextSpan(text: input, style: highLightTextStyle),
              );

          final translateTextSpans = translate
              ?.split(input)
              .map((e) => TextSpan(text: e, style: translateStyle))
              .separat(
                separator: TextSpan(
                  text: input,
                  style: highLightTranslateStyle,
                ),
              );

          return GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: () {
              controller.addQryTag(index);
            },
            child: Column(
              mainAxisSize: MainAxisSize.min,
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                RichText(text: TextSpan(children: textSpans)),
                if (translate != null) const SizedBox(height: 6),
                if (translate != null)
                  RichText(text: TextSpan(children: translateTextSpans)),
              ],
            ).paddingSymmetric(vertical: 4, horizontal: 20),
          );
        }, childCount: controller.qryTags.length),
      ),
    );
  }
}
