import 'dart:async';

import 'package:eros_fe/adaptive/native_sheet.dart';
import 'package:eros_fe/common/service/theme_service.dart';
import 'package:eros_fe/const/eh_palette.dart';
import 'package:eros_fe/generated/l10n.dart';
import 'package:eros_fe/utils/app_cupertino_localizations_delegate.dart';
import 'package:eros_fe/utils/vibrate.dart';
import 'package:eros_fe/widget/eh_buttons.dart';
import 'package:eros_fe/widget/eh_sheet.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';

/// Quick navigation actions shared by the top row of both jump sheets.
enum JumpNavAction {
  first,
  prev,
  next,
  last;

  static JumpNavAction? tryParse(Object? raw) {
    return switch (raw) {
      'first' => JumpNavAction.first,
      'prev' => JumpNavAction.prev,
      'next' => JumpNavAction.next,
      'last' => JumpNavAction.last,
      _ => null,
    };
  }
}

/// Outcome of [showPageJumpSheet]: either an exact 1-based [PageJumpTarget]
/// or a quick-navigation [PageJumpNav] with its resolved 1-based [page].
sealed class PageJumpResult {
  const PageJumpResult({required this.page, this.nav});

  const factory PageJumpResult.page(int page) = PageJumpTarget;

  const factory PageJumpResult.nav(
    JumpNavAction action, {
    required int page,
  }) = PageJumpNav;

  /// Resolved 1-based target page.
  final int page;

  /// Non-null when triggered by one of the 4 quick-navigation buttons.
  final JumpNavAction? nav;

  bool get isNav => nav != null;

  @override
  String toString() =>
      nav == null ? '$page' : '${nav!.name}($page)';
}

final class PageJumpTarget extends PageJumpResult {
  const PageJumpTarget(int page) : super(page: page);
}

final class PageJumpNav extends PageJumpResult {
  const PageJumpNav(JumpNavAction action, {required super.page})
      : super(nav: action);

  JumpNavAction get action => nav!;
}

int _resolveNavPage(
  JumpNavAction action, {
  required int current,
  required int max,
}) {
  return switch (action) {
    JumpNavAction.first => 1,
    JumpNavAction.prev => (current - 1).clamp(1, max),
    JumpNavAction.next => (current + 1).clamp(1, max),
    JumpNavAction.last => max,
  };
}

/// Page picker for list pages and the thumbnail grid: a top 4-key navigation
/// row plus a number field and slider kept in step.
///
/// Returns the chosen [PageJumpResult], or null when dismissed.
Future<PageJumpResult?> showPageJumpSheet(
  BuildContext context, {
  required String title,
  required String subtitle,
  required int current,
  required int max,
  bool autofocus = true,
}) async {
  final l10n = L10n.of(context);
  final maxPage = max < 1 ? 1 : max;
  final start = current.clamp(1, maxPage);
  final canPrev = start > 1;
  final canNext = start < maxPage;
  if (NativeSheet.available) {
    PageJumpResult? result;
    final session = await NativeSheet.present(
      kind: 'pageJump',
      config: {
        ...NativeSheet.style(context),
        'title': title,
        'subtitle': subtitle,
        'current': start,
        'max': maxPage,
        'autofocus': autofocus,
        'go': l10n.sp_go,
        'navFirst': l10n.sp_page_first,
        'navPrev': l10n.sp_page_prev,
        'navNext': l10n.sp_page_next,
        'navLast': l10n.sp_page_last,
        'canPrev': canPrev,
        'canNext': canNext,
      },
      onEvent: (_, name, value) {
        if (name == 'jump' && value is int) {
          result = PageJumpResult.page(value);
        } else if (name == 'nav') {
          final action = JumpNavAction.tryParse(value);
          if (action != null) {
            result = PageJumpResult.nav(
              action,
              page: _resolveNavPage(action, current: start, max: maxPage),
            );
          }
        }
      },
    );
    if (session != null) {
      await session.closed;
      return result;
    }
  }
  if (!context.mounted) {
    return null;
  }
  return showEhSheet<PageJumpResult>(
    context: context,
    builder: (_) => _PageJumpSheet(
      title: title,
      subtitle: subtitle,
      current: start,
      max: maxPage,
      autofocus: autofocus,
    ),
  );
}

class _JumpNavRow extends StatelessWidget {
  const _JumpNavRow({
    required this.canPrev,
    required this.canNext,
    required this.onSelect,
  });

  final bool canPrev;
  final bool canNext;
  final ValueChanged<JumpNavAction> onSelect;

  @override
  Widget build(BuildContext context) {
    final l10n = L10n.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 14),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final buttonWidth = (constraints.maxWidth - 18) / 4;
          final scale = ((buttonWidth - 44) / 42).clamp(0.8, 1.0);
          final row = Row(
            children: [
              Expanded(
                child: EhButton(
                  key: const ValueKey('jump_nav_first'),
                  icon: CupertinoIcons.backward_end,
                  label: l10n.sp_page_first,
                  size: 34,
                  expand: true,
                  style: EhButtonStyle.tonal,
                  selected: canPrev,
                  onPressed:
                      canPrev ? () => onSelect(JumpNavAction.first) : null,
                ),
              ),
              const SizedBox(width: 6),
              Expanded(
                child: EhButton(
                  key: const ValueKey('jump_nav_prev'),
                  icon: CupertinoIcons.chevron_left,
                  label: l10n.sp_page_prev,
                  size: 34,
                  expand: true,
                  style: EhButtonStyle.tonal,
                  selected: canPrev,
                  onPressed:
                      canPrev ? () => onSelect(JumpNavAction.prev) : null,
                ),
              ),
              const SizedBox(width: 6),
              Expanded(
                child: EhButton(
                  key: const ValueKey('jump_nav_next'),
                  trailingIcon: CupertinoIcons.chevron_right,
                  label: l10n.sp_page_next,
                  size: 34,
                  expand: true,
                  style: EhButtonStyle.tonal,
                  selected: canNext,
                  onPressed:
                      canNext ? () => onSelect(JumpNavAction.next) : null,
                ),
              ),
              const SizedBox(width: 6),
              Expanded(
                child: EhButton(
                  key: const ValueKey('jump_nav_last'),
                  trailingIcon: CupertinoIcons.forward_end,
                  label: l10n.sp_page_last,
                  size: 34,
                  expand: true,
                  style: EhButtonStyle.tonal,
                  selected: canNext,
                  onPressed:
                      canNext ? () => onSelect(JumpNavAction.last) : null,
                ),
              ),
            ],
          );
          if (scale >= 1.0) {
            return row;
          }
          return MediaQuery(
            data: MediaQuery.of(context).copyWith(
              textScaler: TextScaler.linear(scale),
            ),
            child: row,
          );
        },
      ),
    );
  }
}

class _PageJumpSheet extends StatefulWidget {
  const _PageJumpSheet({
    required this.title,
    required this.subtitle,
    required this.current,
    required this.max,
    required this.autofocus,
  });

  final String title;
  final String subtitle;
  final int current;
  final int max;
  final bool autofocus;

  @override
  State<_PageJumpSheet> createState() => _PageJumpSheetState();
}

class _PageJumpSheetState extends State<_PageJumpSheet> {
  late final TextEditingController _text = TextEditingController(
    text: '${widget.current}',
  );
  late double _slider = widget.current.toDouble();

  int? get _page {
    final value = int.tryParse(_text.text.trim());
    return value != null && value >= 1 && value <= widget.max ? value : null;
  }

  @override
  void initState() {
    super.initState();
    if (widget.autofocus) {
      _text.selection = TextSelection(
        baseOffset: 0,
        extentOffset: _text.text.length,
      );
    }
  }

  @override
  void dispose() {
    _text.dispose();
    super.dispose();
  }

  void _nav(JumpNavAction action) {
    vibrateUtil.selection();
    Navigator.of(context).pop(
      PageJumpResult.nav(
        action,
        page: _resolveNavPage(
          action,
          current: widget.current,
          max: widget.max,
        ),
      ),
    );
  }

  void _go() {
    final page = _page;
    if (page != null) {
      Navigator.of(context).pop(PageJumpResult.page(page));
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = L10n.of(context);
    final palette = ehTheme.palette;
    final valid = _page != null;
    final canPrev = widget.current > 1;
    final canNext = widget.current < widget.max;
    final accent = EhPalette.accent.resolveFrom(context);
    final error = CupertinoDynamicColor.resolve(
      CupertinoColors.systemRed,
      context,
    );
    final base = CupertinoTheme.of(context).textTheme.textStyle;
    final digits = base.copyWith(
      letterSpacing: 0,
      fontFeatures: const [FontFeature.tabularFigures()],
    );
    return SingleChildScrollView(
      child: Padding(
        padding: const EdgeInsets.only(bottom: 20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            EhSheetHeader(
              title: widget.title,
              subtitle: widget.subtitle,
              trailing: EhButton(
                icon: CupertinoIcons.arrow_right,
                style: EhButtonStyle.prominent,
                semanticLabel: l10n.sp_go,
                onPressed: valid ? _go : null,
              ),
            ),
            const SizedBox(height: 6),
            _JumpNavRow(
              canPrev: canPrev,
              canNext: canNext,
              onSelect: _nav,
            ),
            const SizedBox(height: 14),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.baseline,
              textBaseline: TextBaseline.alphabetic,
              children: [
                SizedBox(
                  width: 128,
                  child: CupertinoTextField(
                    controller: _text,
                    autofocus: widget.autofocus,
                    keyboardType: TextInputType.number,
                    textInputAction: TextInputAction.go,
                    inputFormatters: [
                      FilteringTextInputFormatter.digitsOnly,
                      LengthLimitingTextInputFormatter(6),
                    ],
                    textAlign: TextAlign.center,
                    cursorColor: accent,
                    padding: const EdgeInsets.symmetric(vertical: 2),
                    style: digits.copyWith(
                      fontSize: 44,
                      fontWeight: FontWeight.w600,
                      height: 1.15,
                      color: valid ? palette.text1.resolveFrom(context) : error,
                    ),
                    decoration: BoxDecoration(
                      border: Border(
                        bottom: BorderSide(
                          color: valid ? accent : error,
                          width: 2,
                        ),
                      ),
                    ),
                    onChanged: (_) => setState(() {
                      final page = _page;
                      if (page != null) {
                        _slider = page.toDouble();
                      }
                    }),
                    onSubmitted: (_) => _go(),
                  ),
                ),
                const SizedBox(width: 6),
                Text(
                  '/ ${widget.max}',
                  style: digits.copyWith(
                    fontSize: 17,
                    fontWeight: FontWeight.w500,
                    color: palette.text2.resolveFrom(context),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 18),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: SizedBox(
                width: double.infinity,
                child: CupertinoSlider(
                  value: _slider.clamp(1, widget.max.toDouble()),
                  min: 1,
                  max: widget.max <= 1 ? 1.0001 : widget.max.toDouble(),
                  activeColor: accent,
                  onChanged: widget.max <= 1
                      ? null
                      : (value) {
                          final page = value.round();
                          if (page != _page) {
                            vibrateUtil.selection();
                            _text.text = '$page';
                          }
                          setState(() => _slider = value);
                        },
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: DefaultTextStyle(
                style: digits.copyWith(
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
                  color: palette.text2.resolveFrom(context),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [const Text('1'), Text('${widget.max}')],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Where a date / GID seek goes from the current list.
enum SeekDirection { prev, next }

sealed class SeekRequest {
  const SeekRequest({
    required this.direction,
    this.text = '',
    this.gid = '',
    this.nav,
  });

  const factory SeekRequest.seek(
    SeekDirection direction,
    String text,
    String gid,
  ) = SeekTargetRequest;

  const factory SeekRequest.nav(JumpNavAction action) = SeekNavRequest;

  final SeekDirection direction;
  final String text;
  final String gid;
  final JumpNavAction? nav;

  bool get isNav => nav != null;
}

final class SeekTargetRequest extends SeekRequest {
  const SeekTargetRequest(SeekDirection direction, String text, String gid)
      : super(direction: direction, text: text, gid: gid);
}

final class SeekNavRequest extends SeekRequest {
  const SeekNavRequest(JumpNavAction action)
      : super(
          direction: action == JumpNavAction.first ||
                  action == JumpNavAction.prev
              ? SeekDirection.prev
              : SeekDirection.next,
          nav: action,
        );

  JumpNavAction get action => nav!;
}

bool _validSeekText(String text) =>
    RegExp(r'^\d+[wmy]?$').hasMatch(text) ||
    RegExp(r'^\d{4}(-\d{2}){0,2}$').hasMatch(text) ||
    RegExp(r'^\d{2}(-\d{2}){1,2}$').hasMatch(text);

/// Date / offset / GID seek for lists without page numbers.
Future<SeekRequest?> showSeekSheet(
  BuildContext context, {
  required String text,
  required String gid,
  required bool pickerVisible,
  required DateTime pickerDate,
  required String prevGid,
  required String nextGid,
  ValueChanged<bool>? onPickerVisibleChanged,
}) async {
  final l10n = L10n.of(context);
  final canPrev = prevGid.isNotEmpty;
  final canNext = nextGid.isNotEmpty;
  if (NativeSheet.available) {
    SeekRequest? result;
    final session = await NativeSheet.present(
      kind: 'seek',
      config: {
        ...NativeSheet.style(context),
        'title': l10n.jump_or_seek,
        'navFirst': l10n.sp_page_first,
        'navPrev': l10n.sp_page_prev,
        'navNext': l10n.sp_page_next,
        'navLast': l10n.sp_page_last,
        'canPrev': canPrev,
        'canNext': canNext,
        'section': l10n.sp_seek_section,
        'dateLabel': l10n.sp_date,
        'datePlaceholder': l10n.date_or_offset,
        'gidPlaceholder': l10n.sp_optional,
        'text': text,
        'gid': gid,
        'pickerVisible': pickerVisible,
        'pickerLabel': l10n.sp_show_date_picker,
        'pickerDate': DateFormat('yyyy-MM-dd').format(pickerDate),
        'hint': l10n.sp_seek_hint,
        'newer': l10n.sp_seek_newer,
        'older': l10n.sp_seek_older,
        'errorEmpty': l10n.input_empty,
        'errorFormat': l10n.input_error,
      },
      onEvent: (_, name, value) {
        if (name == 'pickerVisible' && value is bool) {
          onPickerVisibleChanged?.call(value);
        } else if (name == 'nav') {
          final action = JumpNavAction.tryParse(value);
          if (action != null) {
            result = SeekRequest.nav(action);
          }
        } else if ((name == 'prev' || name == 'next') && value is Map) {
          result = SeekRequest.seek(
            name == 'prev' ? SeekDirection.prev : SeekDirection.next,
            '${value['text'] ?? ''}',
            '${value['gid'] ?? ''}',
          );
        }
      },
    );
    if (session != null) {
      await session.closed;
      return result;
    }
  }
  if (!context.mounted) {
    return null;
  }
  return showEhSheet<SeekRequest>(
    context: context,
    builder: (_) => _SeekSheet(
      text: text,
      gid: gid,
      pickerVisible: pickerVisible,
      pickerDate: pickerDate,
      prevGid: prevGid,
      nextGid: nextGid,
      onPickerVisibleChanged: onPickerVisibleChanged,
    ),
  );
}

class _SeekSheet extends StatefulWidget {
  const _SeekSheet({
    required this.text,
    required this.gid,
    required this.pickerVisible,
    required this.pickerDate,
    required this.prevGid,
    required this.nextGid,
    this.onPickerVisibleChanged,
  });

  final String text;
  final String gid;
  final bool pickerVisible;
  final DateTime pickerDate;
  final String prevGid;
  final String nextGid;
  final ValueChanged<bool>? onPickerVisibleChanged;

  @override
  State<_SeekSheet> createState() => _SeekSheetState();
}

class _SeekSheetState extends State<_SeekSheet> {
  late final TextEditingController _text = TextEditingController(
    text: widget.text,
  );
  late final TextEditingController _gid = TextEditingController(
    text: widget.gid,
  );
  final FocusNode _gidFocus = FocusNode();
  late bool _picker = widget.pickerVisible;
  String? _error;

  @override
  void dispose() {
    _text.dispose();
    _gid.dispose();
    _gidFocus.dispose();
    super.dispose();
  }

  void _nav(JumpNavAction action) {
    vibrateUtil.selection();
    Navigator.of(context).pop(SeekRequest.nav(action));
  }

  void _go(SeekDirection direction) {
    final text = _text.text.trim();
    final gid = _gid.text.trim();
    final l10n = L10n.of(context);
    if (text.isEmpty && gid.isEmpty) {
      vibrateUtil.error();
      setState(() => _error = l10n.input_empty);
      return;
    }
    if (text.isNotEmpty && !_validSeekText(text)) {
      vibrateUtil.error();
      setState(() => _error = l10n.input_error);
      return;
    }
    Navigator.of(context).pop(SeekRequest.seek(direction, text, gid));
  }

  Widget _field({
    required String label,
    required TextEditingController controller,
    required String placeholder,
    FocusNode? focusNode,
    TextInputAction? action,
    ValueChanged<String>? onSubmitted,
    Widget? accessory,
  }) {
    final palette = ehTheme.palette;
    final base = CupertinoTheme.of(context).textTheme.textStyle;
    return ConstrainedBox(
      constraints: const BoxConstraints(minHeight: 50),
      child: Padding(
        padding: EdgeInsetsDirectional.only(
          start: 14,
          end: accessory == null ? 6 : 6,
        ),
        child: Row(
          children: [
            SizedBox(
              width: 52,
              child: Text(
                label,
                style: base.copyWith(
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                  letterSpacing: 0,
                  color: palette.text2.resolveFrom(context),
                ),
              ),
            ),
            const SizedBox(width: 6),
            Expanded(
              child: CupertinoTextField(
                controller: controller,
                focusNode: focusNode,
                placeholder: placeholder,
                textInputAction: action,
                onSubmitted: onSubmitted,
                autocorrect: false,
                enableSuggestions: false,
                clearButtonMode: OverlayVisibilityMode.editing,
                cursorColor: EhPalette.accent.resolveFrom(context),
                decoration: null,
                padding: const EdgeInsets.symmetric(vertical: 12),
                style: base.copyWith(
                  fontSize: 16,
                  letterSpacing: 0,
                  fontFeatures: const [FontFeature.tabularFigures()],
                  color: palette.text1.resolveFrom(context),
                ),
                placeholderStyle: base.copyWith(
                  fontSize: 16,
                  letterSpacing: 0,
                  color: palette.text2.resolveFrom(context),
                ),
                onChanged: (_) {
                  if (_error != null) {
                    setState(() => _error = null);
                  }
                },
              ),
            ),
            if (accessory != null) accessory,
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = L10n.of(context);
    final palette = ehTheme.palette;
    final base = CupertinoTheme.of(context).textTheme.textStyle;
    final now = DateTime.now();
    final minimum = DateTime(2007, 3, 20);
    final initial = widget.pickerDate.isBefore(minimum)
        ? minimum
        : (widget.pickerDate.isAfter(now) ? now : widget.pickerDate);
    return SingleChildScrollView(
      child: Padding(
        padding: const EdgeInsets.only(bottom: 18),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            EhSheetHeader(title: l10n.jump_or_seek),
            const SizedBox(height: 6),
            _JumpNavRow(
              canPrev: widget.prevGid.isNotEmpty,
              canNext: widget.nextGid.isNotEmpty,
              onSelect: _nav,
            ),
            EhSheetSectionLabel(l10n.sp_seek_section),
            EhSheetGroup(
              children: [
                _field(
                  label: l10n.sp_date,
                  controller: _text,
                  placeholder: l10n.date_or_offset,
                  action: TextInputAction.next,
                  onSubmitted: (_) => _gidFocus.requestFocus(),
                  accessory: EhButton(
                    icon: CupertinoIcons.calendar,
                    size: 34,
                    style: EhButtonStyle.tonal,
                    selected: _picker,
                    semanticLabel: l10n.sp_show_date_picker,
                    onPressed: () {
                      vibrateUtil.selection();
                      FocusScope.of(context).unfocus();
                      setState(() => _picker = !_picker);
                      widget.onPickerVisibleChanged?.call(_picker);
                    },
                  ),
                ),
                Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    AnimatedSize(
                      duration: const Duration(milliseconds: 260),
                      curve: Curves.easeInOut,
                      alignment: Alignment.topCenter,
                      child: _picker
                          ? Container(
                              height: 150,
                              decoration: BoxDecoration(
                                border: Border(
                                  bottom: BorderSide(
                                    color: EhPalette.separator.resolveFrom(
                                      context,
                                    ),
                                    width: .5,
                                  ),
                                ),
                              ),
                              child: Localizations.override(
                                context: context,
                                delegates: const [
                                  AppGlobalCupertinoLocalizationsDelegate(),
                                ],
                                child: CupertinoDatePicker(
                                  mode: CupertinoDatePickerMode.date,
                                  initialDateTime: initial,
                                  dateOrder: DatePickerDateOrder.ymd,
                                  minimumYear: 2007,
                                  minimumDate: minimum,
                                  maximumYear: now.year,
                                  maximumDate: now.add(
                                    const Duration(minutes: 1),
                                  ),
                                  onDateTimeChanged: (value) {
                                    _text.text = DateFormat('yyyy-MM-dd')
                                        .format(value);
                                    if (_error != null) {
                                      setState(() => _error = null);
                                    }
                                  },
                                ),
                              ),
                            )
                          : const SizedBox(width: double.infinity),
                    ),
                    _field(
                      label: 'GID',
                      controller: _gid,
                      focusNode: _gidFocus,
                      placeholder: l10n.sp_optional,
                      action: TextInputAction.go,
                      onSubmitted: (_) => _go(SeekDirection.next),
                    ),
                  ],
                ),
              ],
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(22, 10, 22, 0),
              child: Text(
                _error ?? l10n.sp_seek_hint,
                style: base.copyWith(
                  fontSize: 12.5,
                  fontWeight: FontWeight.w500,
                  letterSpacing: 0,
                  color: _error != null
                      ? CupertinoDynamicColor.resolve(
                          CupertinoColors.systemRed,
                          context,
                        )
                      : palette.text2.resolveFrom(context),
                ),
              ),
            ),
            const SizedBox(height: 18),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Row(
                children: [
                  Expanded(
                    child: EhButton(
                      key: const ValueKey('seek_newer'),
                      icon: CupertinoIcons.arrow_up,
                      label: l10n.sp_seek_newer,
                      style: EhButtonStyle.glass,
                      size: 52,
                      expand: true,
                      onPressed: () => _go(SeekDirection.prev),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: EhButton(
                      key: const ValueKey('seek_older'),
                      trailingIcon: CupertinoIcons.arrow_down,
                      label: l10n.sp_seek_older,
                      style: EhButtonStyle.prominent,
                      size: 52,
                      expand: true,
                      onPressed: () => _go(SeekDirection.next),
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
}
