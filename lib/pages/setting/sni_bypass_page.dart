import 'package:eros_fe/common/service/dns_service.dart';
import 'package:eros_fe/common/service/layout_service.dart';
import 'package:eros_fe/common/service/sni_bypass_service.dart';
import 'package:eros_fe/common/service/theme_service.dart';
import 'package:eros_fe/component/setting/setting_scaffold.dart';
import 'package:eros_fe/const/eh_palette.dart';
import 'package:eros_fe/generated/l10n.dart';
import 'package:eros_fe/network/sni_bypass/sni_bypass_models.dart';
import 'package:eros_fe/route/routes.dart';
import 'package:eros_fe/utils/toast.dart';
import 'package:eros_fe/utils/vibrate.dart';
import 'package:eros_fe/widget/cupertino/list_tile.dart';
import 'package:eros_fe/widget/cupertino/sliver_list_section.dart';
import 'package:eros_fe/widget/eh_svg_icon.dart';
import 'package:eros_fe/widget/soft_status_indicator.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart' show Colors, Icons;
import 'package:flutter_slidable/flutter_slidable.dart';
import 'package:get/get.dart';
import 'package:sliver_tools/sliver_tools.dart';

const EdgeInsetsDirectional _kAlignedTilePadding =
    EdgeInsetsDirectional.fromSTEB(16.0, 10.0, 16.0, 10.0);
const EdgeInsetsDirectional _kCompactDiagTilePadding =
    EdgeInsetsDirectional.fromSTEB(16.0, 8.0, 16.0, 8.0);

class SniBypassPage extends StatefulWidget {
  const SniBypassPage({super.key});

  @override
  State<SniBypassPage> createState() => _SniBypassPageState();
}

class _SniBypassPageState extends State<SniBypassPage> {
  bool _diagExpanded = false;

  SniBypassService get _service => Get.find<SniBypassService>();

  @override
  void initState() {
    super.initState();
    if (_service.mode.isBypassEnabled) {
      _service.detectProxyConflict();
    }
  }

  Future<void> _handleSyncCatalog() async {
    vibrateUtil.selection();
    final ok = await _service.syncCatalog();
    if (!mounted) {
      return;
    }
    final l10n = L10n.of(context);
    showToast(ok ? l10n.sni_doh_sync_success : l10n.sni_doh_sync_failed);
  }

  Future<void> _handleSpeedTest() async {
    vibrateUtil.selection();
    await _service.runDohSpeedTest();
  }

  Future<void> _handleSiteDiag() async {
    vibrateUtil.selection();
    if (!_diagExpanded) {
      setState(() => _diagExpanded = true);
    }
    await _service.runSiteConnectivityCheck();
  }

  void _toggleDiagExpanded() {
    vibrateUtil.selection();
    final next = !_diagExpanded;
    setState(() => _diagExpanded = next);
    if (next && _service.siteResults.isEmpty && !_service.isTestingSites.value) {
      _service.runSiteConnectivityCheck();
    }
  }

  Future<void> _showAddCustomDohDialog() async {
    final l10n = L10n.of(context);
    final nameCtrl = TextEditingController();
    final urlCtrl = TextEditingController();
    final ipCtrl = TextEditingController();
    String? errorText;

    try {
      await showCupertinoDialog<void>(
        context: context,
        builder: (dialogContext) {
          return StatefulBuilder(
            builder: (ctx, setDialogState) {
              return CupertinoAlertDialog(
                title: Text(l10n.sni_add_custom_doh),
                content: Padding(
                  padding: const EdgeInsets.only(top: 12),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: <Widget>[
                      CupertinoTextField(
                        controller: nameCtrl,
                        placeholder: l10n.sni_add_custom_doh_name,
                        textInputAction: TextInputAction.next,
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 8,
                        ),
                      ),
                      const SizedBox(height: 8),
                      CupertinoTextField(
                        controller: urlCtrl,
                        placeholder: l10n.sni_add_custom_doh_url,
                        keyboardType: TextInputType.url,
                        autocorrect: false,
                        textInputAction: TextInputAction.next,
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 8,
                        ),
                      ),
                      const SizedBox(height: 8),
                      CupertinoTextField(
                        controller: ipCtrl,
                        placeholder: l10n.sni_add_custom_doh_bootstrap,
                        keyboardType: TextInputType.text,
                        autocorrect: false,
                        textInputAction: TextInputAction.done,
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 8,
                        ),
                      ),
                      if (errorText != null) ...<Widget>[
                        const SizedBox(height: 8),
                        Text(
                          errorText!,
                          style: TextStyle(
                            fontSize: 12,
                            color: SoftStatusPalette.textColor(
                              ctx,
                              SoftStatusTone.err,
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
                actions: <Widget>[
                  CupertinoDialogAction(
                    onPressed: () => Navigator.of(dialogContext).pop(),
                    child: Text(l10n.cancel),
                  ),
                  CupertinoDialogAction(
                    isDefaultAction: true,
                    onPressed: () async {
                      final err = await _service.addCustomDohServer(
                        url: urlCtrl.text,
                        name: nameCtrl.text,
                        bootstrapIp: ipCtrl.text,
                      );
                      if (err != null) {
                        setDialogState(() => errorText = err);
                        return;
                      }
                      if (dialogContext.mounted) {
                        Navigator.of(dialogContext).pop();
                      }
                    },
                    child: Text(l10n.ok),
                  ),
                ],
              );
            },
          );
        },
      );
    } finally {
      nameCtrl.dispose();
      urlCtrl.dispose();
      ipCtrl.dispose();
    }
  }

  Future<void> _confirmRemoveCustomServer(DohServerConfig server) async {
    final l10n = L10n.of(context);
    final confirmed = await showCupertinoDialog<bool>(
      context: context,
      builder: (dialogContext) => CupertinoAlertDialog(
        title: Text(l10n.delete),
        content: Padding(
          padding: const EdgeInsets.only(top: 6),
          child: Text('${server.name}\n${server.url}'),
        ),
        actions: <Widget>[
          CupertinoDialogAction(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: Text(l10n.cancel),
          ),
          CupertinoDialogAction(
            isDestructiveAction: true,
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: Text(l10n.delete),
          ),
        ],
      ),
    );
    if (confirmed == true) {
      await _service.removeCustomDohServer(server.id);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = L10n.of(context);

    return SettingScaffold(
      title: l10n.sni_bypass,
      child: Obx(() {
        final mode = _service.mode;
        final conflict = _service.proxyConflict.value;
        // Touch map lengths so GetX always subscribes even when empty.
        final _ = _service.probeResults.length + _service.siteResults.length;
        final showConflict = mode.isBypassEnabled && conflict != null;

        return CustomScrollView(
          slivers: <Widget>[
            SliverSafeArea(
              sliver: MultiSliver(
                children: <Widget>[
                  if (showConflict) _buildConflictSection(context, conflict),
                  _buildModeSection(context, mode),
                  if (mode.isBypassEnabled) _buildDohSection(context),
                  _buildDiagnosticsSection(context),
                  if (mode.isBypassEnabled) _buildCustomHostsSection(context),
                  const SliverToBoxAdapter(child: SizedBox(height: 24)),
                ],
              ),
            ),
          ],
        );
      }),
    );
  }

  Widget _buildConflictSection(
    BuildContext context,
    ProxyConflictInfo conflict,
  ) {
    final l10n = L10n.of(context);
    final accent = EhPalette.accent.resolveFrom(context);
    final warnText = SoftStatusPalette.textColor(context, SoftStatusTone.warn);
    final secondary = ehTheme.palette.text2.resolveFrom(context);

    return SliverCupertinoListSection.listInsetGrouped(
      children: <Widget>[
        EhCupertinoListTile(
          padding: const EdgeInsetsDirectional.fromSTEB(16, 12, 16, 12),
          title: Row(
            children: <Widget>[
              const SoftStatusLed(tone: SoftStatusTone.warn),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  l10n.sni_conflict_title,
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                    color: warnText,
                  ),
                ),
              ),
            ],
          ),
          subtitle: Padding(
            padding: const EdgeInsets.only(top: 4),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(
                  (conflict.detail == null || conflict.detail!.isEmpty)
                      ? l10n.sni_conflict_desc
                      : '${l10n.sni_conflict_desc} (${conflict.detail})',
                  style: TextStyle(fontSize: 13, height: 1.35, color: secondary),
                ),
                const SizedBox(height: 8),
                CupertinoButton(
                  padding: EdgeInsets.zero,
                  minimumSize: Size.zero,
                  onPressed: () {
                    vibrateUtil.selection();
                    _service.setMode(SniBypassMode.standard);
                  },
                  child: Text(
                    l10n.sni_switch_to_standard,
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
        ),
      ],
    );
  }

  Widget _buildModeSection(BuildContext context, SniBypassMode currentMode) {
    final l10n = L10n.of(context);
    final accent = EhPalette.accent.resolveFrom(context);

    Widget buildModeTile({
      required SniBypassMode target,
      required String title,
      required String subtitle,
    }) {
      final selected = currentMode == target;
      return EhCupertinoListTile(
        padding: _kAlignedTilePadding,
        title: Text(title),
        subtitle: Text(subtitle),
        trailing: SizedBox(
          width: AlignedStatusMetric.kTrailingSlotWidth,
          child: selected
              ? EhSvgIcon(
                  CupertinoIcons.checkmark_alt,
                  size: 15,
                  color: accent,
                )
              : const SizedBox.shrink(),
        ),
        onTap: () {
          vibrateUtil.selection();
          _service.setMode(target);
        },
      );
    }

    return SliverCupertinoListSection.listInsetGrouped(
      header: Text(l10n.sni_mode_section),
      children: <Widget>[
        buildModeTile(
          target: SniBypassMode.standard,
          title: l10n.sni_mode_standard,
          subtitle: l10n.sni_mode_standard_desc,
        ),
        buildModeTile(
          target: SniBypassMode.enhanced,
          title: l10n.sni_mode_enhanced,
          subtitle: l10n.sni_mode_enhanced_desc,
        ),
        buildModeTile(
          target: SniBypassMode.compat,
          title: l10n.sni_mode_compat,
          subtitle: l10n.sni_mode_compat_desc,
        ),
      ],
    );
  }

  Widget _buildDohSection(BuildContext context) {
    final l10n = L10n.of(context);
    final accent = EhPalette.accent.resolveFrom(context);
    final text1 = ehTheme.palette.text1.resolveFrom(context);
    final warnColor = SoftStatusPalette.textColor(context, SoftStatusTone.warn);

    final selectedId = _service.selectedDohId;
    final syncing = _service.isSyncing.value;
    final testing = _service.isTestingDoh.value;
    final servers = _service.sortedServers;
    final activeServer = _service.activeDohServer;
    final syncTime = _formatSyncTime(_service.lastCatalogSyncTime);

    final header = Row(
      children: <Widget>[
        Expanded(
          child: Text(
            syncTime == null
                ? l10n.sni_doh_section
                : '${l10n.sni_doh_section} ${l10n.sni_doh_synced_at(syncTime)}',
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ),
        const SizedBox(width: 8),
        _SectionHeaderAction(
          label: syncing ? l10n.sni_doh_syncing : l10n.sni_doh_sync,
          enabled: !syncing,
          onTap: _handleSyncCatalog,
        ),
        const SizedBox(width: 14),
        _SectionHeaderAction(
          label: testing ? l10n.sni_doh_testing : l10n.sni_doh_speed_test,
          enabled: !testing,
          onTap: _handleSpeedTest,
        ),
      ],
    );

    final isAutoSelected = selectedId == SniBypassDefaults.autoServerId;
    final autoActiveRes =
        activeServer != null ? _service.probeResults[activeServer.id] : null;

    final children = <Widget>[
      // Auto-select row
      EhCupertinoListTile(
        padding: _kAlignedTilePadding,
        title: Text(l10n.sni_doh_auto),
        subtitle: activeServer == null
            ? null
            : Text(l10n.sni_doh_auto_selected(activeServer.name)),
        trailing: autoActiveRes != null
            ? AlignedStatusMetric(
                tone: _toneForProbe(autoActiveRes.status),
                label: _labelForProbe(l10n, autoActiveRes),
                testing: autoActiveRes.status == ProbeStatus.testing,
                trailingSlot: isAutoSelected
                    ? EhSvgIcon(
                        CupertinoIcons.checkmark_alt,
                        size: 15,
                        color: accent,
                      )
                    : null,
              )
            : SizedBox(
                width: AlignedStatusMetric.kTrailingSlotWidth,
                child: isAutoSelected
                    ? EhSvgIcon(
                        CupertinoIcons.checkmark_alt,
                        size: 15,
                        color: accent,
                      )
                    : const SizedBox.shrink(),
              ),
        onTap: () {
          vibrateUtil.selection();
          _service.selectDohServer(SniBypassDefaults.autoServerId);
        },
      ),
      // Individual DoH servers
      for (final server in servers)
        _buildDohServerTile(
          context: context,
          l10n: l10n,
          server: server,
          result: _service.probeResults[server.id],
          selected: selectedId == server.id,
          accent: accent,
          text1: text1,
          warnColor: warnColor,
        ),
      // Add custom DoH row
      EhCupertinoListTile(
        padding: _kAlignedTilePadding,
        title: Text(
          l10n.sni_add_custom_doh,
          style: TextStyle(color: accent, fontWeight: FontWeight.w500),
        ),
        trailing: SizedBox(
          width: AlignedStatusMetric.kTrailingSlotWidth,
          child: Center(
            child: EhSvgIcon(
              CupertinoIcons.plus,
              size: 15,
              color: accent,
            ),
          ),
        ),
        onTap: _showAddCustomDohDialog,
      ),
    ];

    return SliverCupertinoListSection.listInsetGrouped(
      header: header,
      children: children,
    );
  }

  Widget _buildDohServerTile({
    required BuildContext context,
    required L10n l10n,
    required DohServerConfig server,
    required DohProbeResult? result,
    required bool selected,
    required Color accent,
    required Color text1,
    required Color warnColor,
  }) {
    final isPolluted = result?.status == ProbeStatus.polluted;
    final tone = result == null
        ? SoftStatusTone.idle
        : _toneForProbe(result.status);
    final readout = result == null
        ? l10n.sni_status_untested
        : _labelForProbe(l10n, result);

    final tile = GestureDetector(
      onLongPress: server.isCustom
          ? () => _confirmRemoveCustomServer(server)
          : null,
      child: EhCupertinoListTile(
        padding: _kAlignedTilePadding,
        title: Row(
          children: <Widget>[
            Flexible(
              child: Text(
                server.name,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(color: text1),
              ),
            ),
            if (isPolluted) ...<Widget>[
              const SizedBox(width: 6),
              Text(
                l10n.sni_doh_polluted,
                maxLines: 1,
                softWrap: false,
                style: TextStyle(
                  fontSize: 12.0,
                  fontWeight: FontWeight.w500,
                  color: warnColor,
                ),
              ),
            ],
          ],
        ),
        subtitle: server.isCustom
            ? Row(
                children: <Widget>[
                  Flexible(
                    child: Text(
                      server.host.isNotEmpty ? server.host : server.url,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  const SizedBox(width: 8),
                  CupertinoButton(
                    key: ValueKey<String>('delete_custom_doh_${server.id}'),
                    padding: EdgeInsets.zero,
                    minimumSize: Size.zero,
                    onPressed: () => _confirmRemoveCustomServer(server),
                    child: Text(
                      l10n.delete,
                      maxLines: 1,
                      softWrap: false,
                      style: TextStyle(
                        fontSize: 12.0,
                        fontWeight: FontWeight.w500,
                        color: SoftStatusPalette.textColor(
                          context,
                          SoftStatusTone.err,
                        ),
                      ),
                    ),
                  ),
                ],
              )
            : Text(
                server.host.isNotEmpty ? server.host : server.url,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
        trailing: AlignedStatusMetric(
          tone: tone,
          label: readout,
          testing: result?.status == ProbeStatus.testing,
          trailingSlot: selected
              ? EhSvgIcon(
                  CupertinoIcons.checkmark_alt,
                  size: 15,
                  color: accent,
                )
              : null,
        ),
        onTap: () {
          vibrateUtil.selection();
          _service.selectDohServer(server.id);
        },
      ),
    );

    if (!server.isCustom) {
      return tile;
    }

    return Slidable(
      key: ValueKey<String>('custom_doh_${server.id}'),
      endActionPane: ActionPane(
        motion: const ScrollMotion(),
        extentRatio: 0.25,
        children: <Widget>[
          SlidableAction(
            onPressed: (_) => _service.removeCustomDohServer(server.id),
            backgroundColor: CupertinoDynamicColor.resolve(
              CupertinoColors.systemRed,
              context,
            ),
            foregroundColor: Colors.white,
            icon: Icons.delete,
            label: l10n.delete,
          ),
        ],
      ),
      child: tile,
    );
  }

  Widget _buildDiagnosticsSection(BuildContext context) {
    final l10n = L10n.of(context);
    final testing = _service.isTestingSites.value;
    final results = _service.siteResults;
    const hosts = SniBypassDefaults.diagnosticHosts;
    final text2 = ehTheme.palette.text2.resolveFrom(context);
    final text3 = ehTheme.palette.text3.resolveFrom(context);

    final testedCount = hosts.where((h) {
      final s = results[h]?.status;
      return s != null && s != ProbeStatus.idle && s != ProbeStatus.testing;
    }).length;
    final okCount =
        hosts.where((h) => results[h]?.status == ProbeStatus.ok).length;

    final String summaryText;
    final SoftStatusTone summaryTone;
    if (testing) {
      summaryText = l10n.sni_doh_testing;
      summaryTone = SoftStatusTone.idle;
    } else if (testedCount == 0) {
      summaryText = l10n.sni_diag_tap_to_test;
      summaryTone = SoftStatusTone.idle;
    } else {
      summaryText = l10n.sni_diag_summary_ok(okCount, hosts.length);
      if (okCount == hosts.length) {
        summaryTone = SoftStatusTone.ok;
      } else if (okCount > 0) {
        summaryTone = SoftStatusTone.warn;
      } else {
        summaryTone = SoftStatusTone.err;
      }
    }

    final header = Row(
      children: <Widget>[
        Expanded(
          child: Text(
            l10n.sni_diag_section,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ),
        const SizedBox(width: 8),
        _SectionHeaderAction(
          label: testing ? l10n.sni_doh_testing : l10n.sni_diag_retest,
          enabled: !testing,
          onTap: _handleSiteDiag,
        ),
      ],
    );

    return SliverCupertinoListSection.listInsetGrouped(
      header: header,
      children: <Widget>[
        EhCupertinoListTile(
          padding: _kAlignedTilePadding,
          title: Text(l10n.sni_diag_eh_nodes),
          trailing: Row(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              if (testing)
                const CupertinoActivityIndicator(radius: 6)
              else
                Text(
                  summaryText,
                  style: TextStyle(
                    fontSize: 13.5,
                    fontWeight: FontWeight.w500,
                    color: testedCount == 0
                        ? text2
                        : SoftStatusPalette.textColor(context, summaryTone),
                    fontFeatures: const <FontFeature>[
                      FontFeature.tabularFigures(),
                    ],
                  ),
                ),
              const SizedBox(width: AlignedStatusMetric.kTextToSlotGap),
              SizedBox(
                width: AlignedStatusMetric.kTrailingSlotWidth,
                child: Center(
                  child: EhSvgIcon(
                    _diagExpanded
                        ? CupertinoIcons.chevron_up
                        : CupertinoIcons.chevron_down,
                    size: 13,
                    color: text3,
                  ),
                ),
              ),
            ],
          ),
          onTap: _toggleDiagExpanded,
        ),
        if (_diagExpanded)
          for (final host in hosts)
            _buildDiagnosticHostRow(
              context: context,
              l10n: l10n,
              host: host,
              result: results[host],
              text3: text3,
            ),
      ],
    );
  }

  Widget _buildDiagnosticHostRow({
    required BuildContext context,
    required L10n l10n,
    required String host,
    required SiteCheckResult? result,
    required Color text3,
  }) {
    final tone = result == null
        ? SoftStatusTone.idle
        : _toneForProbe(result.status);
    final label = result == null
        ? l10n.sni_status_untested
        : _labelForSite(l10n, result);

    return EhCupertinoListTile(
      padding: _kCompactDiagTilePadding,
      title: Row(
        children: <Widget>[
          Flexible(
            child: Text(
              host,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontSize: 14.5),
            ),
          ),
          if (result?.statusCode != null) ...<Widget>[
            const SizedBox(width: 6),
            Text(
              '${result!.statusCode}',
              maxLines: 1,
              softWrap: false,
              style: TextStyle(
                fontSize: 12.0,
                color: text3,
                fontFeatures: const <FontFeature>[FontFeature.tabularFigures()],
              ),
            ),
          ],
        ],
      ),
      trailing: AlignedStatusMetric(
        tone: tone,
        label: label,
        testing: result?.status == ProbeStatus.testing,
      ),
    );
  }

  Widget _buildCustomHostsSection(BuildContext context) {
    final l10n = L10n.of(context);
    final dns = Get.isRegistered<DnsService>() ? Get.find<DnsService>() : null;

    return SliverCupertinoListSection.listInsetGrouped(
      footer: Text(l10n.sni_custom_hosts_footer),
      children: <Widget>[
        EhCupertinoListTile(
          padding: _kAlignedTilePadding,
          title: Text(l10n.custom_hosts),
          additionalInfo: dns == null
              ? null
              : Obx(() {
                  if (!dns.enableCustomHosts || dns.hosts.isEmpty) {
                    return const SizedBox.shrink();
                  }
                  return Text('${dns.hosts.length}');
                }),
          trailing: const SizedBox(
            width: AlignedStatusMetric.kTrailingSlotWidth,
            child: Center(child: CupertinoListTileChevron()),
          ),
          onTap: () {
            Get.toNamed(
              EHRoutes.customHosts,
              id: detailNavigatorId,
            );
          },
        ),
      ],
    );
  }

  SoftStatusTone _toneForProbe(ProbeStatus status) {
    return switch (status) {
      ProbeStatus.ok => SoftStatusTone.ok,
      ProbeStatus.polluted => SoftStatusTone.warn,
      ProbeStatus.timeout || ProbeStatus.error => SoftStatusTone.err,
      ProbeStatus.idle || ProbeStatus.testing => SoftStatusTone.idle,
    };
  }

  String _labelForProbe(L10n l10n, DohProbeResult res) {
    return switch (res.status) {
      ProbeStatus.ok =>
        res.latencyMs != null ? '${res.latencyMs} ms' : l10n.sni_status_untested,
      ProbeStatus.polluted =>
        res.latencyMs != null ? '${res.latencyMs} ms' : l10n.sni_doh_polluted,
      ProbeStatus.timeout => l10n.sni_status_timeout,
      ProbeStatus.error => l10n.sni_status_failed,
      ProbeStatus.testing => '',
      ProbeStatus.idle => l10n.sni_status_untested,
    };
  }

  String _labelForSite(L10n l10n, SiteCheckResult res) {
    return switch (res.status) {
      ProbeStatus.ok =>
        res.latencyMs != null ? '${res.latencyMs} ms' : l10n.sni_status_untested,
      ProbeStatus.timeout => l10n.sni_status_timeout,
      ProbeStatus.error || ProbeStatus.polluted => l10n.sni_status_failed,
      ProbeStatus.testing => '',
      ProbeStatus.idle => l10n.sni_status_untested,
    };
  }

  String? _formatSyncTime(DateTime? dt) {
    if (dt == null) {
      return null;
    }
    final local = dt.toLocal();
    final mm = local.month.toString().padLeft(2, '0');
    final dd = local.day.toString().padLeft(2, '0');
    final hh = local.hour.toString().padLeft(2, '0');
    final min = local.minute.toString().padLeft(2, '0');
    return '$mm-$dd $hh:$min';
  }
}

class _SectionHeaderAction extends StatelessWidget {
  const _SectionHeaderAction({
    required this.label,
    required this.enabled,
    required this.onTap,
  });

  final String label;
  final bool enabled;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final accent = EhPalette.accent.resolveFrom(context);
    final disabled = ehTheme.palette.text3.resolveFrom(context);

    return CupertinoButton(
      padding: const EdgeInsets.symmetric(vertical: 2),
      minimumSize: Size.zero,
      onPressed: enabled ? onTap : null,
      child: Text(
        label,
        style: TextStyle(
          fontSize: 13.0,
          fontWeight: FontWeight.w500,
          color: enabled ? accent : disabled,
        ),
      ),
    );
  }
}
