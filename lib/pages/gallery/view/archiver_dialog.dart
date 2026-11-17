import 'package:eros_fe/adaptive/native_sheet.dart';
import 'package:eros_fe/common/service/controller_tag_service.dart';
import 'package:eros_fe/common/service/theme_service.dart';
import 'package:eros_fe/const/eh_palette.dart';
import 'package:eros_fe/index.dart';
import 'package:eros_fe/pages/gallery/controller/archiver_controller.dart';
import 'package:eros_fe/widget/eh_buttons.dart';
import 'package:eros_fe/widget/eh_sheet.dart';
import 'package:flutter/cupertino.dart';
import 'package:get/get.dart';

/// What the archiver sheet shows, derived once for both renderers.
class _ArchiverModel {
  _ArchiverModel(BuildContext context, ArchiverSheetSource source) {
    final l10n = L10n.of(context);
    final status = source.status;
    state = status.isSuccess
        ? 'ready'
        : (status.isError ? 'error' : 'loading');
    final provider = source.provider;
    gp = provider?.gp?.numberFormat ?? '';
    credits = provider?.credits?.numberFormat ?? '';
    local = [
      if (source.showLocal)
        for (final item in provider?.dlItems ?? <ArchiverProviderItem>[])
          if ((item.dltype ?? '').isNotEmpty)
            _ArchiverOption(
              id: item.dltype!,
              title: item.dltype == 'org'
                  ? l10n.sp_archive_original
                  : l10n.sp_archive_resample,
              detail: item.size ?? '',
              price: _price(l10n, item.price),
              free: _isFree(item.price),
              symbol: item.dltype == 'org' ? 'archivebox' : 'arrow.down.circle',
              icon: item.dltype == 'org'
                  ? CupertinoIcons.archivebox
                  : CupertinoIcons.arrow_down_circle,
            ),
    ];
    hath = [
      for (final item in provider?.hItems ?? <ArchiverProviderItem>[])
        if ((item.dlres ?? '').isNotEmpty)
          _ArchiverOption(
            id: item.dlres!,
            title: (item.resolution ?? '').toLowerCase() == 'original'
                ? l10n.sp_original
                : (item.resolution ?? ''),
            detail:
                '${item.size ?? ''} · ${_price(l10n, item.price)}'.trim(),
            price: _price(l10n, item.price),
            free: _isFree(item.price),
          ),
    ];
  }

  late final String state;
  late final String gp;
  late final String credits;
  late final List<_ArchiverOption> local;
  late final List<_ArchiverOption> hath;

  static bool _isFree(String? price) =>
      (price ?? '').trim().toLowerCase().startsWith('free');

  static String _price(L10n l10n, String? price) =>
      _isFree(price) ? l10n.sp_free : (price ?? '').trim();

  Map<String, Object?> native(BuildContext context) {
    final l10n = L10n.of(context);
    return {
      ...NativeSheet.style(context),
      'title': l10n.p_Archiver,
      'state': state,
      'loadingText': l10n.sp_archiver_loading,
      'errorText': l10n.sp_archiver_error,
      'retryLabel': l10n.sp_retry,
      'gp': gp,
      'credits': credits,
      'localTitle': l10n.sp_archiver_local,
      'hathTitle': l10n.sp_archiver_hath,
      'local': [
        for (final option in local)
          {
            'id': option.id,
            'title': option.title,
            'size': option.detail,
            'price': option.price,
            'free': option.free,
            'symbol': option.symbol,
          },
      ],
      'hath': [
        for (final option in hath)
          {'id': option.id, 'title': option.title, 'caption': option.detail},
      ],
    };
  }
}

class _ArchiverOption {
  const _ArchiverOption({
    required this.id,
    required this.title,
    required this.detail,
    required this.price,
    required this.free,
    this.symbol = '',
    this.icon = CupertinoIcons.archivebox,
  });

  final String id;
  final String title;
  final String detail;
  final String price;
  final bool free;
  final String symbol;
  final IconData icon;
}

/// What the archiver sheet reads and does; [ArchiverController] in the app,
/// fixture data in the debug preview.
abstract class ArchiverSheetSource {
  RxStatus get status;
  ArchiverProvider? get provider;

  /// Local downloads exist on mobile only, as before.
  bool get showLocal => GetPlatform.isMobile;
  void addListener(VoidCallback listener);
  void removeListener(VoidCallback listener);
  void retry();
  void downloadLocal(String dltype);
  void downloadRemote(String dlres);
}

class _ControllerArchiverSource extends ArchiverSheetSource {
  _ControllerArchiverSource(this.controller);

  final ArchiverController controller;
  final Map<VoidCallback, void Function()> _listeners = {};

  @override
  RxStatus get status => controller.status;

  @override
  ArchiverProvider? get provider => controller.state;

  @override
  void addListener(VoidCallback listener) {
    _listeners[listener] = controller.addListener(listener);
  }

  @override
  void removeListener(VoidCallback listener) {
    _listeners.remove(listener)?.call();
  }

  @override
  void retry() => controller.reload();

  @override
  void downloadLocal(String dltype) {
    controller
        .downloadLoacal(
          dltype: dltype,
          dlcheck: dltype == 'org' ? 'Original Archive' : 'Resample Archive',
        )
        .catchError((Object _) {});
  }

  @override
  void downloadRemote(String dlres) => controller.downloadRemote(dlres);
}

/// Archive download choices: balance, local download (mobile) and H@H.
Future<void> showArchiverDialog() {
  final context = Get.overlayContext ?? Get.context!;
  final ArchiverController controller = Get.find(tag: pageCtrlTag);
  return presentArchiverSheet(context, _ControllerArchiverSource(controller));
}

Future<void> presentArchiverSheet(
  BuildContext context,
  ArchiverSheetSource source,
) async {
  if (NativeSheet.available) {
    String? localType;
    String? hathRes;
    final session = await NativeSheet.present(
      kind: 'archiver',
      config: _ArchiverModel(context, source).native(context),
      onEvent: (_, name, value) {
        switch (name) {
          case 'retry':
            source.retry();
          case 'local':
            localType = value as String?;
          case 'hath':
            hathRes = value as String?;
        }
      },
    );
    if (session != null) {
      void push() {
        if (context.mounted) {
          session.update(_ArchiverModel(context, source).native(context));
        }
      }

      source.addListener(push);
      await session.closed;
      source.removeListener(push);
      if (localType != null) {
        source.downloadLocal(localType!);
      } else if (hathRes != null) {
        source.downloadRemote(hathRes!);
      }
      return;
    }
  }
  if (!context.mounted) {
    return;
  }
  return showEhSheet<void>(
    context: context,
    builder: (_) => _ArchiverSheet(source: source),
  );
}

class _ArchiverSheet extends StatefulWidget {
  const _ArchiverSheet({required this.source});

  final ArchiverSheetSource source;

  @override
  State<_ArchiverSheet> createState() => _ArchiverSheetState();
}

class _ArchiverSheetState extends State<_ArchiverSheet> {
  ArchiverSheetSource get source => widget.source;

  void _changed() {
    if (mounted) {
      setState(() {});
    }
  }

  @override
  void initState() {
    super.initState();
    source.addListener(_changed);
  }

  @override
  void dispose() {
    source.removeListener(_changed);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = L10n.of(context);
    final model = _ArchiverModel(context, source);
    return SingleChildScrollView(
      child: Padding(
        padding: const EdgeInsets.only(bottom: 20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            EhSheetHeader(title: l10n.p_Archiver),
            AnimatedSize(
              duration: const Duration(milliseconds: 260),
              curve: Curves.easeInOut,
              alignment: Alignment.topCenter,
              child: switch (model.state) {
                'ready' => _ready(context, model),
                'error' => _message(context,
                    icon: CupertinoIcons.exclamationmark_triangle,
                    text: l10n.sp_archiver_error,
                    retry: true),
                _ => _message(context,
                    text: l10n.sp_archiver_loading, retry: false),
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _message(BuildContext context,
      {IconData? icon, required String text, required bool retry}) {
    final palette = ehTheme.palette;
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 24, 20, 20),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null)
            Icon(icon, size: 28, color: palette.text2.resolveFrom(context))
          else
            const CupertinoActivityIndicator(radius: 11),
          const SizedBox(height: 12),
          Text(
            text,
            textAlign: TextAlign.center,
            style: CupertinoTheme.of(context).textTheme.textStyle.copyWith(
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                  letterSpacing: 0,
                  color: palette.text2.resolveFrom(context),
                ),
          ),
          if (retry) ...[
            const SizedBox(height: 14),
            EhButton(
              label: L10n.of(context).sp_retry,
              style: EhButtonStyle.tonal,
              selected: true,
              size: 36,
              onPressed: source.retry,
            ),
          ],
        ],
      ),
    );
  }

  Widget _ready(BuildContext context, _ArchiverModel model) {
    final l10n = L10n.of(context);
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (model.gp.isNotEmpty || model.credits.isNotEmpty)
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              _BalanceChip(letter: 'G', value: model.gp, label: 'GP'),
              const SizedBox(width: 8),
              _BalanceChip(
                  letter: 'C', value: model.credits, label: 'Credits'),
            ],
          ),
        if (model.local.isNotEmpty) ...[
          EhSheetSectionLabel(l10n.sp_archiver_local),
          EhSheetGroup(
            dividerIndent: 58,
            children: [
              for (final option in model.local)
                _LocalRow(
                  option: option,
                  onPressed: () {
                    Navigator.of(context).pop();
                    source.downloadLocal(option.id);
                  },
                ),
            ],
          ),
        ],
        if (model.hath.isNotEmpty) ...[
          EhSheetSectionLabel(l10n.sp_archiver_hath),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: LayoutBuilder(builder: (context, constraints) {
              final width = (constraints.maxWidth - 16) / 3;
              return Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  for (final option in model.hath)
                    SizedBox(
                      width: width,
                      child: _HathTile(
                        option: option,
                        onPressed: () {
                          Navigator.of(context).pop();
                          source.downloadRemote(option.id);
                        },
                      ),
                    ),
                ],
              );
            }),
          ),
        ],
      ],
    );
  }
}

class _BalanceChip extends StatelessWidget {
  const _BalanceChip({
    required this.letter,
    required this.value,
    required this.label,
  });

  final String letter;
  final String value;
  final String label;

  @override
  Widget build(BuildContext context) {
    final palette = ehTheme.palette;
    final base = CupertinoTheme.of(context).textTheme.textStyle;
    return Semantics(
      label: '$label $value',
      excludeSemantics: true,
      child: Container(
        height: 28,
        padding: const EdgeInsetsDirectional.only(start: 4, end: 12),
        decoration: BoxDecoration(
          color: EhSheetGroup.trayColor(context),
          borderRadius: BorderRadius.circular(14),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 20,
              height: 20,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: palette.text1.resolveFrom(context),
                shape: BoxShape.circle,
              ),
              child: Text(
                letter,
                style: base.copyWith(
                  fontSize: 10.5,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 0,
                  height: 1,
                  color: palette.raised.resolveFrom(context),
                ),
              ),
            ),
            const SizedBox(width: 7),
            Text(
              value,
              style: base.copyWith(
                fontSize: 13.5,
                fontWeight: FontWeight.w600,
                letterSpacing: 0,
                fontFeatures: const [FontFeature.tabularFigures()],
                color: palette.text1.resolveFrom(context),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _LocalRow extends StatelessWidget {
  const _LocalRow({required this.option, required this.onPressed});

  final _ArchiverOption option;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final palette = ehTheme.palette;
    final base = CupertinoTheme.of(context).textTheme.textStyle
        .copyWith(letterSpacing: 0);
    final accent = EhPalette.accent.resolveFrom(context);
    return Semantics(
      button: true,
      label: '${option.title}, ${option.detail}, ${option.price}',
      excludeSemantics: true,
      onTap: onPressed,
      child: EhPressable(
        onPressed: onPressed,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          child: Row(
            children: [
              Container(
                width: 32,
                height: 32,
                decoration: BoxDecoration(
                  color: EhPalette.accentSoft.resolveFrom(context),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(option.icon, size: 17, color: accent),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      option.title,
                      style: base.copyWith(
                        fontSize: 15.5,
                        fontWeight: FontWeight.w600,
                        color: palette.text1.resolveFrom(context),
                      ),
                    ),
                    if (option.detail.isNotEmpty)
                      Text(
                        option.detail,
                        style: base.copyWith(
                          fontSize: 12.5,
                          fontWeight: FontWeight.w500,
                          fontFeatures: const [FontFeature.tabularFigures()],
                          color: palette.text2.resolveFrom(context),
                        ),
                      ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Text(
                option.price,
                style: base.copyWith(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  fontFeatures: const [FontFeature.tabularFigures()],
                  color: option.free
                      ? CupertinoDynamicColor.resolve(
                          CupertinoColors.systemGreen, context)
                      : palette.text2.resolveFrom(context),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _HathTile extends StatelessWidget {
  const _HathTile({required this.option, required this.onPressed});

  final _ArchiverOption option;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final palette = ehTheme.palette;
    final base = CupertinoTheme.of(context).textTheme.textStyle.copyWith(
          letterSpacing: 0,
          fontFeatures: const [FontFeature.tabularFigures()],
        );
    return Semantics(
      button: true,
      label: '${option.title}, ${option.detail}',
      excludeSemantics: true,
      onTap: onPressed,
      child: EhPressable(
        onPressed: onPressed,
        child: Container(
          padding: const EdgeInsets.fromLTRB(11, 10, 8, 10),
          decoration: BoxDecoration(
            color: EhSheetGroup.trayColor(context),
            borderRadius: BorderRadius.circular(14),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                option.title,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: base.copyWith(
                  fontSize: 15.5,
                  fontWeight: FontWeight.w600,
                  color: palette.text1.resolveFrom(context),
                ),
              ),
              const SizedBox(height: 2),
              Text(
                option.detail,
                maxLines: 2,
                style: base.copyWith(
                  fontSize: 11,
                  fontWeight: FontWeight.w500,
                  color: palette.text2.resolveFrom(context),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
