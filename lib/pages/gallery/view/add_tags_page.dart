import 'package:eros_fe/adaptive/native_navigation.dart';
import 'package:eros_fe/adaptive/native_top_header.dart';
import 'package:eros_fe/adaptive/tab_navigation.dart';
import 'package:eros_fe/common/service/controller_tag_service.dart';
import 'package:eros_fe/common/service/layout_service.dart';
import 'package:eros_fe/common/service/theme_service.dart';
import 'package:eros_fe/component/setting/setting_scaffold.dart';
import 'package:eros_fe/const/const.dart';
import 'package:eros_fe/generated/l10n.dart';
import 'package:eros_fe/pages/gallery/controller/taginfo_controller.dart';
import 'package:eros_fe/const/eh_palette.dart';
import 'package:eros_fe/widget/canvas_grain.dart';
import 'package:eros_fe/widget/eh_buttons.dart';
import 'package:eros_fe/widget/tag_suggestions.dart';
import 'package:flutter/cupertino.dart';
import 'package:get/get.dart';

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

  Widget _inputRow({Key? key}) {
    final l10n = L10n.of(context);
    final palette = ehTheme.palette;
    final base = CupertinoTheme.of(context).textTheme.textStyle.copyWith(
          letterSpacing: 0,
          fontVariations: const [],
        );
    controller.tagsTextController.tokenColor =
        EhPalette.accent.resolveFrom(context);
    return Padding(
      key: key,
      padding: const EdgeInsets.fromLTRB(14, 6, 14, 8),
      child: Container(
        decoration: ehCardDecoration(context),
        padding: const EdgeInsets.fromLTRB(4, 4, 6, 8),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            CupertinoTextField(
              padding: const EdgeInsets.fromLTRB(10, 8, 10, 4),
              minLines: 2,
              maxLines: 6,
              textInputAction: TextInputAction.done,
              decoration: null,
              cursorColor: EhPalette.accent.resolveFrom(context),
              controller: controller.tagsTextController,
              focusNode: controller.focusNode,
              placeholder: l10n.add_tag_placeholder,
              placeholderStyle: base.copyWith(
                fontSize: 16,
                height: 1.4,
                color: palette.text3.resolveFrom(context),
              ),
              autofocus: true,
              style: base.copyWith(
                fontSize: 16,
                height: 1.4,
                color: palette.text1.resolveFrom(context),
              ),
              onEditingComplete: _done,
            ),
            GetBuilder<TagInfoController>(
              id: GetIds.TAG_ADD_CLEAR_BTN,
              tag: _tag,
              builder: (TagInfoController controller) {
                final count = TagTokenTextEditingController.finishedTags(
                        controller.tagsTextController.text)
                    .length;
                return Padding(
                  padding: const EdgeInsetsDirectional.only(start: 10, top: 2),
                  child: Row(
                    children: [
                      Expanded(
                        child: Text(
                          controller.showClearButton
                              ? l10n.sp_tags_added(count)
                              : l10n.sp_tags_example,
                          style: base.copyWith(
                            fontSize: 12.5,
                            fontWeight: FontWeight.w500,
                            color: palette.text2.resolveFrom(context),
                          ),
                        ),
                      ),
                      SizedBox(
                        width: 30,
                        height: 30,
                        child: controller.showClearButton
                            ? Semantics(
                                button: true,
                                label: l10n.sp_clear,
                                excludeSemantics: true,
                                onTap: controller.clear,
                                child: EhPressable(
                                  onPressed: controller.clear,
                                  child: Icon(
                                    CupertinoIcons.xmark_circle_fill,
                                    size: 19,
                                    color: palette.text3.resolveFrom(context),
                                  ),
                                ),
                              )
                            : null,
                      ),
                    ],
                  ),
                );
              },
            ),
          ],
        ),
      ),
    );
  }

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

  Widget _suggestions({List<Widget> slivers = const [
    QryTagSliverList(),
    SliverToBoxAdapter(child: SizedBox(height: 24)),
  ]}) =>
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
        trailing: Padding(
          padding: const EdgeInsetsDirectional.only(start: 4),
          child: EhButton(
            label: L10n.of(context).done,
            size: 32,
            style: EhButtonStyle.prominent,
            onPressed: _done,
          ),
        ),
        nativeBars: nativeBar ? _nativeInputRowHeight : 0,
        nativeForeground: nativeBar
            ? Positioned(
                top: safeTop,
                left: MediaQuery.viewPaddingOf(context).left,
                right: MediaQuery.viewPaddingOf(context).right,
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
                      const SliverToBoxAdapter(child: SizedBox(height: 24)),
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
    return Obx(() {
      if (controller.qryTags.isEmpty) {
        return const SliverToBoxAdapter(child: SizedBox.shrink());
      }
      return SliverMainAxisGroup(
        slivers: [
          SliverToBoxAdapter(
            child: EhSectionHeader(
              title: L10n.of(context).sp_suggestions,
              padding: const EdgeInsets.fromLTRB(20, 10, 16, 10),
            ),
          ),
          SliverTagSuggestions(
            tags: controller.qryTags.toList(),
            query: controller.currQry,
            onSelected: controller.addQryTag,
          ),
        ],
      );
    });
  }
}
