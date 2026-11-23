import 'package:eros_fe/adaptive/native_sheet.dart';
import 'package:eros_fe/common/service/controller_tag_service.dart';
import 'package:eros_fe/common/service/theme_service.dart';
import 'package:eros_fe/const/const.dart';
import 'package:eros_fe/generated/l10n.dart';
import 'package:eros_fe/models/base/eh_models.dart';
import 'package:eros_fe/pages/gallery/controller/torrent_controller.dart';
import 'package:eros_fe/utils/logger.dart';
import 'package:eros_fe/utils/share_service.dart';
import 'package:eros_fe/widget/eh_buttons.dart';
import 'package:eros_fe/widget/eh_sheet.dart';
import 'package:flutter/cupertino.dart';
import 'package:get/get.dart';
import 'package:url_launcher/url_launcher_string.dart';
import 'package:eros_fe/widget/eh_svg_icon.dart';

/// Data and actions for the torrent sheet: [TorrentController] in the app,
/// fixture data in debug preview and tests.
abstract class TorrentSheetSource {
  RxStatus get status;
  TorrentProvider? get provider;
  void addListener(VoidCallback listener);
  void removeListener(VoidCallback listener);
  void retry();
  Future<void> downloadTorrent(String token, GalleryTorrent torrent);
  Future<void> shareMagnet(GalleryTorrent torrent, BuildContext context);
}

class _ControllerTorrentSource extends TorrentSheetSource {
  _ControllerTorrentSource(this.controller);

  final TorrentController controller;
  final Map<VoidCallback, void Function()> _listeners = {};

  @override
  RxStatus get status => controller.status;

  @override
  TorrentProvider? get provider => controller.state;

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
  Future<void> downloadTorrent(String token, GalleryTorrent torrent) async {
    final hash = torrent.hash ?? '';
    if (hash.isEmpty) {
      return;
    }
    final torrentUrl = '${EHConst.EH_TORRENT_URL}/$token/$hash.torrent';
    logger.d('${torrent.name}\n$hash\n$torrentUrl');
    if (await canLaunchUrlString(torrentUrl)) {
      await launchUrlString(
        torrentUrl,
        mode: LaunchMode.externalApplication,
      );
    } else {
      throw 'Could not launch $torrentUrl';
    }
  }

  @override
  Future<void> shareMagnet(
    GalleryTorrent torrent,
    BuildContext context,
  ) async {
    final hash = torrent.hash ?? '';
    if (hash.isEmpty) {
      return;
    }
    final magnet = 'magnet:?xt=urn:btih:$hash';
    logger.t('share torrent magnet');
    await ShareService.shareText(magnet, context: context);
  }
}

class _TorrentEntry {
  const _TorrentEntry({
    required this.torrent,
    required this.hash,
    required this.name,
    required this.meta,
    required this.seeds,
    required this.peers,
    required this.downloads,
  });

  final GalleryTorrent torrent;
  final String hash;
  final String name;
  final String meta;
  final String seeds;
  final String peers;
  final String downloads;
}

class _TorrentModel {
  _TorrentModel(TorrentSheetSource source) {
    final status = source.status;
    final provider = source.provider;
    token = provider?.torrentToken ?? '';
    final sorted = List<GalleryTorrent>.of(
      provider?.torrents ?? const <GalleryTorrent>[],
    )..sort((a, b) => _parseCount(b.seeds).compareTo(_parseCount(a.seeds)));

    items = [
      for (final t in sorted)
        _TorrentEntry(
          torrent: t,
          hash: t.hash ?? '',
          name: (t.name ?? '').trim(),
          meta: [
            if ((t.sizeText ?? '').trim().isNotEmpty) t.sizeText!.trim(),
            if ((t.posted ?? '').trim().isNotEmpty) t.posted!.trim(),
          ].join(' · '),
          seeds: (t.seeds ?? '0').trim(),
          peers: (t.peerd ?? '0').trim(),
          downloads: (t.downloads ?? '0').trim(),
        ),
    ];

    if (status.isError) {
      state = 'error';
    } else if (status.isSuccess) {
      state = items.isEmpty ? 'empty' : 'ready';
    } else {
      state = 'loading';
    }
  }

  late final String state;
  late final String token;
  late final List<_TorrentEntry> items;

  static int _parseCount(String? raw) => int.tryParse((raw ?? '').trim()) ?? -1;

  String title(L10n l10n) =>
      state == 'ready' ? l10n.sp_torrent_title(items.length) : l10n.p_Torrent;

  Map<String, Object?> native(BuildContext context) {
    final l10n = L10n.of(context);
    return {
      ...NativeSheet.style(context),
      'title': title(l10n),
      'state': state,
      'loadingText': l10n.loading,
      'errorText': l10n.sp_archiver_error,
      'retryLabel': l10n.sp_retry,
      'emptyText': l10n.sp_torrent_empty,
      'downloadLabel': l10n.sp_torrent_download,
      'magnetLabel': l10n.sp_torrent_magnet,
      'seedsLabel': l10n.sp_torrent_seeds,
      'peersLabel': l10n.sp_torrent_peers,
      'completedLabel': l10n.sp_torrent_completed,
      'torrents': [
        for (final item in items)
          {
            'hash': item.hash,
            'name': item.name,
            'meta': item.meta,
            'seeds': item.seeds,
            'peers': item.peers,
            'downloads': item.downloads,
          },
      ],
    };
  }
}

/// Presents the torrent sheet for the active gallery.
Future<void> showTorrentDialog() {
  final context = Get.overlayContext ?? Get.context!;
  final TorrentController controller = Get.find(tag: pageCtrlTag);
  return presentTorrentSheet(context, _ControllerTorrentSource(controller));
}

/// Presents the torrent sheet backed by [source] (native on iOS 26 liquid
/// glass, Flutter [EhSheet] otherwise).
Future<void> presentTorrentSheet(
  BuildContext context,
  TorrentSheetSource source,
) async {
  if (NativeSheet.available) {
    String? downloadHash;
    String? magnetHash;
    final session = await NativeSheet.present(
      kind: 'torrent',
      config: _TorrentModel(source).native(context),
      onEvent: (_, name, value) {
        switch (name) {
          case 'retry':
            source.retry();
          case 'download':
            downloadHash = value as String?;
          case 'magnet':
            magnetHash = value as String?;
        }
      },
    );
    if (session != null) {
      void push() {
        if (context.mounted) {
          session.update(_TorrentModel(source).native(context));
        }
      }

      source.addListener(push);
      await session.closed;
      source.removeListener(push);
      final model = _TorrentModel(source);
      if (downloadHash != null) {
        final match =
            model.items.firstWhereOrNull((e) => e.hash == downloadHash);
        if (match != null) {
          await source.downloadTorrent(model.token, match.torrent);
        }
      } else if (magnetHash != null && context.mounted) {
        final match = model.items.firstWhereOrNull((e) => e.hash == magnetHash);
        if (match != null) {
          await source.shareMagnet(match.torrent, context);
        }
      }
      return;
    }
  }
  if (!context.mounted) {
    return;
  }
  return showEhSheet<void>(
    context: context,
    builder: (_) => _TorrentSheet(
      source: source,
      anchorContext: context,
    ),
  );
}

class _TorrentSheet extends StatefulWidget {
  const _TorrentSheet({
    required this.source,
    required this.anchorContext,
  });

  final TorrentSheetSource source;
  final BuildContext anchorContext;

  @override
  State<_TorrentSheet> createState() => _TorrentSheetState();
}

class _TorrentSheetState extends State<_TorrentSheet> {
  TorrentSheetSource get source => widget.source;

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
    final model = _TorrentModel(source);
    return SingleChildScrollView(
      child: Padding(
        padding: const EdgeInsets.only(bottom: 20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            EhSheetHeader(title: model.title(l10n)),
            AnimatedSize(
              duration: const Duration(milliseconds: 240),
              curve: Curves.easeInOut,
              alignment: Alignment.topCenter,
              child: switch (model.state) {
                'ready' => _ready(context, model),
                'empty' => _message(
                    context,
                    icon: CupertinoIcons.tray,
                    text: l10n.sp_torrent_empty,
                    retry: false,
                  ),
                'error' => _message(
                    context,
                    icon: CupertinoIcons.exclamationmark_triangle,
                    text: l10n.sp_archiver_error,
                    retry: true,
                  ),
                _ => _loading(context),
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _loading(BuildContext context) {
    final palette = ehTheme.palette;
    final fill = palette.fill.resolveFrom(context);
    Widget skeletonCard() => EhSheetGroup(
          children: [
            Padding(
              padding: const EdgeInsets.all(14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    height: 15,
                    width: double.infinity,
                    decoration: BoxDecoration(
                      color: fill,
                      borderRadius: BorderRadius.circular(6),
                    ),
                  ),
                  const SizedBox(height: 8),
                  Container(
                    height: 12,
                    width: 140,
                    decoration: BoxDecoration(
                      color: fill,
                      borderRadius: BorderRadius.circular(6),
                    ),
                  ),
                  const SizedBox(height: 14),
                  Row(
                    children: [
                      Expanded(
                        child: Container(
                          height: 40,
                          decoration: BoxDecoration(
                            color: fill,
                            borderRadius: BorderRadius.circular(20),
                          ),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Container(
                          height: 40,
                          decoration: BoxDecoration(
                            color: fill,
                            borderRadius: BorderRadius.circular(20),
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        );

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        const SizedBox(height: 6),
        skeletonCard(),
        const SizedBox(height: 10),
        skeletonCard(),
      ],
    );
  }

  Widget _message(
    BuildContext context, {
    required IconData icon,
    required String text,
    required bool retry,
  }) {
    final palette = ehTheme.palette;
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 24, 20, 20),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          EhSvgIcon(icon, size: 28, color: palette.text2.resolveFrom(context)),
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
              key: const ValueKey('torrent_retry'),
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

  Widget _ready(BuildContext context, _TorrentModel model) {
    final l10n = L10n.of(context);
    final palette = ehTheme.palette;
    final base = CupertinoTheme.of(context).textTheme.textStyle;
    final digits = base.copyWith(
      fontSize: 12.5,
      fontWeight: FontWeight.w500,
      letterSpacing: 0,
      fontFeatures: const [FontFeature.tabularFigures()],
      color: palette.text2.resolveFrom(context),
    );

    Widget stat(IconData icon, String value, String label) => Semantics(
          label: '$label $value',
          excludeSemantics: true,
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              EhSvgIcon(icon, size: 13.5, color: palette.text2.resolveFrom(context)),
              const SizedBox(width: 4),
              Text(value, style: digits),
            ],
          ),
        );

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const SizedBox(height: 4),
        for (var i = 0; i < model.items.length; i++) ...[
          if (i > 0) const SizedBox(height: 10),
          EhSheetGroup(
            children: [
              Padding(
                padding: const EdgeInsets.all(14),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text(
                      model.items[i].name,
                      maxLines: 3,
                      overflow: TextOverflow.ellipsis,
                      style: base.copyWith(
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                        letterSpacing: 0,
                        height: 1.3,
                        color: palette.text1.resolveFrom(context),
                      ),
                    ),
                    if (model.items[i].meta.isNotEmpty) ...[
                      const SizedBox(height: 4),
                      Text(
                        model.items[i].meta,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: digits,
                      ),
                    ],
                    const SizedBox(height: 10),
                    Wrap(
                      spacing: 16,
                      runSpacing: 6,
                      children: [
                        stat(
                          CupertinoIcons.arrow_up_circle,
                          model.items[i].seeds,
                          l10n.sp_torrent_seeds,
                        ),
                        stat(
                          CupertinoIcons.arrow_down_circle,
                          model.items[i].peers,
                          l10n.sp_torrent_peers,
                        ),
                        stat(
                          CupertinoIcons.checkmark_circle,
                          model.items[i].downloads,
                          l10n.sp_torrent_completed,
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Expanded(
                          child: EhButton(
                            key: ValueKey('torrent_download_$i'),
                            icon: CupertinoIcons.arrow_down_circle,
                            label: l10n.sp_torrent_download,
                            style: i == 0
                                ? EhButtonStyle.prominent
                                : EhButtonStyle.tonal,
                            selected: i != 0,
                            size: 40,
                            expand: true,
                            onPressed: () {
                              Navigator.of(context).pop();
                              source.downloadTorrent(
                                model.token,
                                model.items[i].torrent,
                              );
                            },
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Builder(
                            builder: (btnContext) => EhButton(
                              key: ValueKey('torrent_magnet_$i'),
                              icon: CupertinoIcons.link,
                              label: l10n.sp_torrent_magnet,
                              style: EhButtonStyle.fill,
                              size: 40,
                              expand: true,
                              onPressed: () {
                                final shareCtx = widget.anchorContext.mounted
                                    ? widget.anchorContext
                                    : btnContext;
                                Navigator.of(context).pop();
                                source.shareMagnet(
                                  model.items[i].torrent,
                                  shareCtx,
                                );
                              },
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ],
      ],
    );
  }
}
