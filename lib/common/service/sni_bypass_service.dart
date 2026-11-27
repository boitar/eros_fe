import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:eros_fe/common/enum.dart';
import 'package:eros_fe/common/global.dart';
import 'package:eros_fe/common/service/dns_service.dart';
import 'package:eros_fe/common/service/ehsetting_service.dart';
import 'package:eros_fe/network/app_dio/dio_http_cli.dart';
import 'package:eros_fe/network/app_dio/proxy.dart';
import 'package:eros_fe/network/sni_bypass/doh_client.dart';
import 'package:eros_fe/network/sni_bypass/local_sni_proxy.dart';
import 'package:eros_fe/network/sni_bypass/sni_bypass_models.dart';
import 'package:eros_fe/network/sni_bypass/tls_fragmenter.dart';
import 'package:eros_fe/utils/logger.dart';
import 'package:eros_fe/utils/storage.dart';
import 'package:get/get.dart';

const String _kSniSettingsKey = 'sni_bypass_settings_v1';
const String _kSniCatalogKey = 'sni_bypass_catalog_v1';

class _CachedDnsEntry {
  _CachedDnsEntry({
    required this.ips,
    required this.expiresAt,
  });

  final List<String> ips;
  final DateTime expiresAt;

  bool get isExpired => DateTime.now().isAfter(expiresAt);
}

typedef SystemDnsLookup = Future<List<InternetAddress>> Function(String host);

/// Central orchestrator for SNI bypass (local loopback proxy with TLS
/// record-layer fragmentation or TCP-segment fragmentation), DoH resolution /
/// speed-testing / catalog sync, and Surge / Fake-IP conflict detection.
class SniBypassService extends GetxService {
  SniBypassService({
    DohClient? dohClient,
    SystemDnsLookup? systemDnsLookup,
    this.autoLoadStorage = true,
  })  : _customDohClient = dohClient,
        _systemDnsLookup = systemDnsLookup ?? InternetAddress.lookup;

  static SniBypassService? get maybeFind =>
      Get.isRegistered<SniBypassService>() ? Get.find<SniBypassService>() : null;

  final DohClient? _customDohClient;
  final SystemDnsLookup _systemDnsLookup;
  final bool autoLoadStorage;

  final Rx<SniBypassMode> _mode = SniBypassMode.standard.obs;
  SniBypassMode get mode => _mode.value;

  final RxString _selectedDohId = SniBypassDefaults.autoServerId.obs;
  String get selectedDohId => _selectedDohId.value;

  final RxList<DohServerConfig> customServers = <DohServerConfig>[].obs;
  final Rxn<DohCatalogSnapshot> syncedCatalog = Rxn<DohCatalogSnapshot>();
  final RxMap<String, DohProbeResult> probeResults =
      <String, DohProbeResult>{}.obs;
  final RxMap<String, SiteCheckResult> siteResults =
      <String, SiteCheckResult>{}.obs;

  final RxBool isSyncing = false.obs;
  final RxBool isTestingDoh = false.obs;
  final RxBool isTestingSites = false.obs;
  final Rxn<ProxyConflictInfo> proxyConflict = Rxn<ProxyConflictInfo>();

  LocalSniProxy? _localProxy;
  int _generation = 0;
  int _configEpoch = 0;
  Future<void>? _configChain;

  final Map<String, _CachedDnsEntry> _dnsCache = <String, _CachedDnsEntry>{};
  final Map<String, int> _roundRobinCursor = <String, int>{};
  final Map<String, DateTime> _ipCooldownUntil = <String, DateTime>{};

  /// Current local loopback proxy directive (e.g. `PROXY 127.0.0.1:54321`)
  /// when a bypass mode is active and the local server is running.
  String? get activeLocalProxyDirective => _localProxy?.proxyDirective;

  /// True when the local loopback SNI proxy listener is actively bound.
  bool get isProxyRunning => _localProxy?.isRunning ?? false;

  /// Active fragmentation mode of the running local loopback proxy, if any.
  TlsFragmentMode? get activeFragmentMode => _localProxy?.fragmentMode;

  int get generation => _generation;

  /// Merged list of catalog/builtin servers followed by user custom servers.
  List<DohServerConfig> get servers {
    final base = syncedCatalog.value?.servers.isNotEmpty == true
        ? syncedCatalog.value!.servers
        : SniBypassDefaults.builtinServers;
    final seenUrls = <String>{};
    final merged = <DohServerConfig>[];
    for (final s in base) {
      final key = s.url.toLowerCase();
      if (seenUrls.add(key)) {
        merged.add(s);
      }
    }
    for (final s in customServers) {
      final key = s.url.toLowerCase();
      if (seenUrls.add(key)) {
        merged.add(s);
      }
    }
    return merged;
  }

  /// Servers sorted for display: healthy (lowest latency first) -> idle/testing
  /// -> polluted -> timeout/error.
  List<DohServerConfig> get sortedServers {
    final list = List<DohServerConfig>.from(servers);
    if (probeResults.isEmpty) {
      return list;
    }
    int rankOf(DohServerConfig s) {
      final res = probeResults[s.id];
      if (res == null) {
        return 1;
      }
      return switch (res.status) {
        ProbeStatus.ok => 0,
        ProbeStatus.idle || ProbeStatus.testing => 1,
        ProbeStatus.polluted => 2,
        ProbeStatus.timeout || ProbeStatus.error => 3,
      };
    }

    list.sort((a, b) {
      final rankCmp = rankOf(a).compareTo(rankOf(b));
      if (rankCmp != 0) {
        return rankCmp;
      }
      final msA = probeResults[a.id]?.latencyMs ?? 1 << 20;
      final msB = probeResults[b.id]?.latencyMs ?? 1 << 20;
      return msA.compareTo(msB);
    });
    return list;
  }

  /// Effective active DoH server (best healthy server in `auto` mode, or the
  /// explicitly selected server).
  DohServerConfig? get activeDohServer {
    final all = servers;
    if (all.isEmpty) {
      return null;
    }
    if (selectedDohId != SniBypassDefaults.autoServerId) {
      for (final s in all) {
        if (s.id == selectedDohId) {
          return s;
        }
      }
    }
    DohServerConfig? best;
    int bestMs = 1 << 30;
    for (final s in all) {
      final res = probeResults[s.id];
      if (res != null &&
          res.status == ProbeStatus.ok &&
          (res.latencyMs ?? 1 << 29) < bestMs) {
        best = s;
        bestMs = res.latencyMs ?? 1 << 29;
      }
    }
    if (best != null) {
      return best;
    }
    for (final s in all) {
      final res = probeResults[s.id];
      if (res == null ||
          (res.status != ProbeStatus.polluted &&
              res.status != ProbeStatus.timeout &&
              res.status != ProbeStatus.error)) {
        return s;
      }
    }
    return all.first;
  }

  DateTime? get lastCatalogSyncTime => syncedCatalog.value?.updatedAt;

  Map<String, List<String>> get fallbackHosts {
    final merged = <String, List<String>>{};
    SniBypassDefaults.builtinFallbackHosts.forEach((k, v) {
      merged[k] = List<String>.from(v);
    });
    syncedCatalog.value?.fallbackHosts.forEach((k, v) {
      final clean = v.where((ip) => !isLikelyPoisonedEhIp(ip)).toList();
      if (clean.isNotEmpty) {
        merged[k] = clean;
      }
    });
    return merged;
  }

  DohClient get _dohClient =>
      _customDohClient ??
      DohClient(
        proxyDirectiveProvider: (String dohHost) {
          if (_localProxy != null &&
              _localProxy!.isRunning &&
              _bootstrapIpsForHost(dohHost).isNotEmpty) {
            return _localProxy!.proxyDirective;
          }
          return null;
        },
      );

  @override
  void onInit() {
    super.onInit();
    if (autoLoadStorage) {
      _loadFromStorage();
    }
  }

  @override
  void onClose() {
    unawaited(_stopLocalProxy());
    super.onClose();
  }

  void _loadFromStorage() {
    try {
      final rawSettings = StorageUtil().getString(_kSniSettingsKey);
      if (rawSettings != null && rawSettings.isNotEmpty) {
        final decoded = jsonDecode(rawSettings);
        if (decoded is Map<String, dynamic>) {
          _mode.value =
              SniBypassMode.fromStorageKey(decoded['mode'] as String?);
          final savedDoh = decoded['selectedDohId'] as String?;
          if (savedDoh != null && savedDoh.trim().isNotEmpty) {
            _selectedDohId.value = savedDoh.trim();
          }
          final rawCustom = decoded['customServers'];
          if (rawCustom is List) {
            final loaded = <DohServerConfig>[];
            for (final item in rawCustom) {
              if (item is Map) {
                final parsed = DohServerConfig.fromJson(
                  Map<String, dynamic>.from(item),
                  defaultCustom: true,
                );
                if (isPermittedDohUrl(parsed.uri)) {
                  loaded.add(parsed);
                }
              }
            }
            customServers.assignAll(loaded);
          }
        }
      }
    } catch (e) {
      logger.w('Failed to load SNI bypass settings: $e');
    }

    try {
      final rawCatalog = StorageUtil().getString(_kSniCatalogKey);
      if (rawCatalog != null && rawCatalog.isNotEmpty) {
        final decoded = jsonDecode(rawCatalog);
        if (decoded is Map) {
          syncedCatalog.value = DohCatalogSnapshot.fromJson(
            Map<String, dynamic>.from(decoded),
          );
        }
      }
    } catch (e) {
      logger.w('Failed to load cached DoH catalog: $e');
    }
  }

  Future<void> _saveSettings() async {
    if (!autoLoadStorage) {
      return;
    }
    try {
      final payload = <String, dynamic>{
        'mode': mode.storageKey,
        'selectedDohId': selectedDohId,
        'customServers': customServers.map((s) => s.toJson()).toList(),
      };
      await StorageUtil().setString(_kSniSettingsKey, jsonEncode(payload));
    } catch (e) {
      logger.w('Failed to save SNI bypass settings: $e');
    }
  }

  Future<void> _saveCatalog(DohCatalogSnapshot snapshot) async {
    if (!autoLoadStorage) {
      return;
    }
    try {
      await StorageUtil()
          .setString(_kSniCatalogKey, jsonEncode(snapshot.toJson()));
    } catch (e) {
      logger.w('Failed to cache DoH catalog: $e');
    }
  }

  /// Initializes runtime networking (called at startup after proxy init).
  /// When mode is [SniBypassMode.standard], this is a complete no-op with
  /// zero sockets opened and zero DNS lookups performed.
  Future<void> initializeRuntime() async {
    if (mode == SniBypassMode.standard) {
      return;
    }
    await applyNetworkConfig();
  }

  /// Changes the active connection strategy and applies it immediately without
  /// requiring an app restart. Concurrent calls are serialized so the final
  /// mode always wins cleanly with zero leaked listeners.
  Future<void> setMode(SniBypassMode newMode) async {
    _mode.value = newMode;
    if (!newMode.isBypassEnabled) {
      proxyConflict.value = null;
    }
    await _saveSettings();
    await applyNetworkConfig();
    if (_mode.value.isBypassEnabled) {
      unawaited(detectProxyConflict());
    }
  }

  Future<void> selectDohServer(String serverId) async {
    _selectedDohId.value = serverId;
    _dnsCache.clear();
    await _saveSettings();
    if (mode.isBypassEnabled) {
      await applyNetworkConfig();
    }
  }

  /// Adds a user-defined HTTPS DoH server. Returns null on success or an error
  /// message string if invalid. Only public IPv4 bootstrap addresses are
  /// permitted to prevent loopback / private-network SSRF.
  Future<String?> addCustomDohServer({
    required String url,
    String? name,
    String? bootstrapIp,
  }) async {
    final trimmedUrl = url.trim();
    final uri = Uri.tryParse(trimmedUrl);
    if (!isPermittedDohUrl(uri)) {
      return 'URL must be a public https:// address (port 443)';
    }
    final validUri = uri!;
    final bootstrapIps = <String>[];
    if (bootstrapIp != null && bootstrapIp.trim().isNotEmpty) {
      for (final token in bootstrapIp.split(RegExp(r'[\s,;]+'))) {
        final ip = token.trim();
        if (ip.isEmpty) {
          continue;
        }
        if (!isValidPublicIpv4(ip)) {
          return 'Bootstrap IP must be a public IPv4 address: $ip';
        }
        if (!bootstrapIps.contains(ip)) {
          bootstrapIps.add(ip);
        }
      }
    }

    final existing = servers.firstWhereOrNull(
      (s) => s.url.toLowerCase() == trimmedUrl.toLowerCase(),
    );
    if (existing != null) {
      await selectDohServer(existing.id);
      return null;
    }

    final config = DohServerConfig(
      id: 'custom-${DateTime.now().millisecondsSinceEpoch}',
      name: (name != null && name.trim().isNotEmpty)
          ? name.trim()
          : validUri.host,
      url: trimmedUrl,
      bootstrapIps: bootstrapIps,
      isCustom: true,
    );
    customServers.add(config);
    _selectedDohId.value = config.id;
    _dnsCache.clear();
    await _saveSettings();
    if (mode.isBypassEnabled) {
      await applyNetworkConfig();
    }
    return null;
  }

  Future<void> removeCustomDohServer(String serverId) async {
    customServers.removeWhere((s) => s.id == serverId);
    probeResults.remove(serverId);
    if (_selectedDohId.value == serverId) {
      _selectedDohId.value = SniBypassDefaults.autoServerId;
    }
    _dnsCache.clear();
    await _saveSettings();
    if (mode.isBypassEnabled) {
      await applyNetworkConfig();
    }
  }

  /// Called when user edits custom hosts in [DnsService] so changes take effect
  /// immediately without restarting the app.
  Future<void> onCustomHostsChanged() async {
    _dnsCache.clear();
    if (mode.isBypassEnabled) {
      await applyNetworkConfig();
    }
  }

  /// Serialized start/stop of the local loopback proxy and atomic update of
  /// [globalDioConfig] + [ExtendedNetworkImageProvider.httpClient].
  Future<void> applyNetworkConfig() {
    final epoch = ++_configEpoch;
    final previous = _configChain;
    late final Future<void> current;
    current = (previous == null
            ? _applyNetworkConfigSerialized(epoch)
            : previous
                .catchError((Object _) {})
                .then((_) => _applyNetworkConfigSerialized(epoch)))
        .whenComplete(() {
      if (identical(_configChain, current)) {
        _configChain = null;
      }
    });
    _configChain = current;
    return current;
  }

  Future<void> _applyNetworkConfigSerialized(int epoch) async {
    final targetMode = _mode.value;
    if (targetMode.isBypassEnabled) {
      final desiredFrag = targetMode == SniBypassMode.compat
          ? TlsFragmentMode.tcpSegments
          : TlsFragmentMode.tlsRecords;
      await _ensureLocalProxyStarted(desiredFrag, epoch);
    } else {
      await _stopLocalProxy();
    }

    // Re-check live mode in case a newer transition superseded this epoch.
    if (epoch != _configEpoch || !_mode.value.isBypassEnabled) {
      if (!_mode.value.isBypassEnabled) {
        await _stopLocalProxy();
      }
      if (epoch != _configEpoch) {
        return;
      }
    }

    _generation++;
    globalDioConfig = globalDioConfig.copyWith(
      domainFronting: false,
      sniBypassMode: _mode.value.storageKey,
      localProxy: _mode.value.isBypassEnabled
          ? (activeLocalProxyDirective ?? '')
          : '',
      sniGeneration: _generation,
    );

    DioHttpClient.resetClients();
    try {
      Global.initImageHttpClient(
        maxConnectionsPerHost: globalDioConfig.maxConnectionsPerHost,
      );
    } catch (_) {
      // Widget test environments may not have ExtendedNetworkImageProvider ready.
    }
  }

  Future<void> _ensureLocalProxyStarted(
    TlsFragmentMode fragmentMode,
    int epoch,
  ) async {
    if (_localProxy != null &&
        _localProxy!.isRunning &&
        _localProxy!.fragmentMode == fragmentMode) {
      return;
    }
    await _stopLocalProxy();

    final proxy = LocalSniProxy(
      resolveIps: _resolveIpsForLocalProxy,
      isHostAllowed: _isHostAllowedForLocalProxy,
      onIpConnectFailure: markIpFailure,
      fragmentMode: fragmentMode,
      fragmentWriteDelay: fragmentMode == TlsFragmentMode.tcpSegments
          ? const Duration(milliseconds: 15)
          : const Duration(milliseconds: 5),
    );
    await proxy.start();

    // If mode changed away from this epoch while binding, close immediately so
    // no orphan loopback socket can ever remain open.
    if (epoch != _configEpoch || !_mode.value.isBypassEnabled) {
      await proxy.stop();
      return;
    }
    _localProxy = proxy;
  }

  Future<void> _stopLocalProxy() async {
    final proxy = _localProxy;
    _localProxy = null;
    if (proxy != null) {
      await proxy.stop();
    }
  }

  /// Returns true if [host] should be routed through SNI bypass (E-Hentai
  /// managed domains or any host explicitly configured in Custom Hosts).
  bool shouldBypassHost(String host) {
    final normalized = host.trim().toLowerCase();
    if (normalized.isEmpty || parseIpv4Octets(normalized) != null) {
      return false;
    }
    if (SniBypassDefaults.isManagedDomain(normalized)) {
      return true;
    }
    return _customHostIps(normalized).isNotEmpty;
  }

  bool _isHostAllowedForLocalProxy(String host) {
    final normalized = host.trim().toLowerCase();
    if (normalized.isEmpty) {
      return false;
    }
    if (shouldBypassHost(normalized)) {
      return true;
    }
    if (_bootstrapIpsForHost(normalized).isNotEmpty) {
      return true;
    }
    if (normalized == 'cdn.jsdelivr.net' ||
        normalized == 'fastly.jsdelivr.net' ||
        normalized == 'raw.githubusercontent.com') {
      return true;
    }
    return false;
  }

  List<String> _bootstrapIpsForHost(String host) {
    final normalized = host.trim().toLowerCase();
    for (final s in servers) {
      if (s.host.toLowerCase() == normalized) {
        final safe = s.bootstrapIps.where(isValidPublicIpv4).toList();
        if (safe.isNotEmpty) {
          return safe;
        }
      }
    }
    return const <String>[];
  }

  List<String> _customHostIps(String host) {
    if (!Get.isRegistered<DnsService>()) {
      return const <String>[];
    }
    final dns = Get.find<DnsService>();
    if (!dns.enableCustomHosts) {
      return const <String>[];
    }
    final raw = dns.hostMap[host] ?? dns.hostMap[host.toLowerCase()];
    if (raw == null || raw.isEmpty) {
      return const <String>[];
    }
    return raw
        .map((e) => e.trim())
        .where(isValidPublicIpv4)
        .toList();
  }

  /// Resolver used inside [LocalSniProxy]. Avoids recursive DoH lookups when
  /// resolving a DoH server's own hostname by returning its validated public
  /// bootstrap IPs immediately.
  Future<List<String>> _resolveIpsForLocalProxy(String host) async {
    final normalized = host.trim().toLowerCase();
    final bootstrap = _bootstrapIpsForHost(normalized);
    if (bootstrap.isNotEmpty) {
      return bootstrap;
    }
    return resolveCandidateIps(normalized);
  }

  /// Resolves ordered candidate public IPv4 addresses for [host]:
  /// 1. User Custom Hosts (if enabled, public IPv4 only)
  /// 2. Live / cached DoH lookup (filtered for pollution, ordered by round-robin)
  /// 3. Synced or built-in fallback IP pool (defense-in-depth pollution filtered)
  Future<List<String>> resolveCandidateIps(String host) async {
    final normalized = host.trim().toLowerCase();
    if (normalized.isEmpty) {
      return const <String>[];
    }
    if (isValidPublicIpv4(normalized)) {
      return <String>[normalized];
    }
    if (parseIpv4Octets(normalized) != null) {
      // Non-public IPv4 literals are never routed through the SNI bypass proxy.
      return const <String>[];
    }

    // 1. Custom hosts always win.
    final customIps = _customHostIps(normalized);
    if (customIps.isNotEmpty) {
      return _orderWithCooldownAndRoundRobin(normalized, customIps);
    }

    // 2. DoH cache hit.
    final cached = _dnsCache[normalized];
    if (cached != null && !cached.isExpired && cached.ips.isNotEmpty) {
      return _orderWithCooldownAndRoundRobin(normalized, cached.ips);
    }

    // 3. Query DoH server(s).
    final dohIps = await _queryDohWithFailover(normalized);
    if (dohIps.isNotEmpty) {
      return _orderWithCooldownAndRoundRobin(normalized, dohIps);
    }

    // 4. Fallback IP pool (re-filtered against pollution as defense-in-depth).
    final fallback = fallbackHosts[normalized]
        ?.where((ip) => !isLikelyPoisonedEhIp(ip))
        .toList();
    if (fallback != null && fallback.isNotEmpty) {
      return _orderWithCooldownAndRoundRobin(normalized, fallback);
    }

    return const <String>[];
  }

  Future<List<String>> _queryDohWithFailover(String domain) async {
    final orderedServers = <DohServerConfig>[];
    final primary = activeDohServer;
    if (primary != null) {
      orderedServers.add(primary);
    }
    if (selectedDohId == SniBypassDefaults.autoServerId) {
      for (final s in sortedServers) {
        if (s.id != primary?.id &&
            probeResults[s.id]?.status != ProbeStatus.polluted) {
          orderedServers.add(s);
        }
      }
    }

    for (final server in orderedServers.take(3)) {
      try {
        final response = await _dohClient.resolveA(
          server,
          domain,
          requestTimeout: const Duration(seconds: 4),
        );
        final cleanIps = response.ips
            .where((ip) => !isLikelyPoisonedEhIp(ip))
            .toList();
        if (cleanIps.isNotEmpty) {
          _dnsCache[domain] = _CachedDnsEntry(
            ips: cleanIps,
            expiresAt: DateTime.now().add(
              Duration(seconds: response.minTtlSeconds),
            ),
          );
          return cleanIps;
        }
      } catch (e) {
        logger.t('DoH lookup $domain via ${server.name} failed: $e');
      }
    }
    return const <String>[];
  }

  List<String> _orderWithCooldownAndRoundRobin(
    String host,
    List<String> rawIps,
  ) {
    if (rawIps.length <= 1) {
      return List<String>.from(rawIps);
    }
    final now = DateTime.now();
    final healthy = <String>[];
    final cooled = <String>[];
    for (final ip in rawIps) {
      final until = _ipCooldownUntil['$host|$ip'];
      if (until != null && now.isBefore(until)) {
        cooled.add(ip);
      } else {
        healthy.add(ip);
      }
    }

    final listToRotate = healthy.isNotEmpty ? healthy : cooled;
    final start = (_roundRobinCursor[host] ?? 0) % listToRotate.length;
    _roundRobinCursor[host] = (start + 1) % listToRotate.length;

    return <String>[
      ...listToRotate.sublist(start),
      ...listToRotate.sublist(0, start),
      if (healthy.isNotEmpty) ...cooled,
    ];
  }

  /// Deprioritizes [ip] for [host] for 2 minutes after a connection failure.
  void markIpFailure(String host, String ip) {
    final normalized = host.trim().toLowerCase();
    _ipCooldownUntil['$normalized|$ip'] =
        DateTime.now().add(const Duration(minutes: 2));
  }

  /// Syncs the daily curated DoH server list & fresh E-Hentai fallback IP pool
  /// from the `boitar/eros_fe@doh-data` branch via multi-CDN fallback with a
  /// strict response size cap ([kMaxCatalogResponseBytes]).
  Future<bool> syncCatalog({
    List<String>? overrideUrls,
    Duration requestTimeout = const Duration(seconds: 8),
  }) async {
    if (isSyncing.value) {
      return false;
    }
    isSyncing.value = true;
    try {
      final urls = overrideUrls ?? SniBypassDefaults.catalogUrls;
      for (final rawUrl in urls) {
        final uri = Uri.tryParse(rawUrl);
        if (uri == null) {
          continue;
        }
        final configuredProxy = globalDioConfig.proxy?.trim();
        final candidates = <String?>[
          if (configuredProxy != null &&
              configuredProxy.isNotEmpty &&
              configuredProxy != 'DIRECT')
            configuredProxy,
          null,
          if (activeLocalProxyDirective != null &&
              _isHostAllowedForLocalProxy(uri.host))
            activeLocalProxyDirective,
        ];
        for (final proxyDirective in candidates) {
          final client = HttpClient()
            ..connectionTimeout = requestTimeout
            ..badCertificateCallback = null;
          try {
            if (proxyDirective != null) {
              client.findProxy = (_) => proxyDirective;
            }
            final req = await client.getUrl(uri).timeout(requestTimeout);
            req.headers.set(HttpHeaders.acceptHeader, 'application/json');
            req.headers.set(HttpHeaders.userAgentHeader, 'Eros-FE/DoHSync');
            final resp = await req.close().timeout(requestTimeout);
            if (resp.statusCode != 200) {
              // Do not drain arbitrary non-200 bodies; finally closes forcefully.
              continue;
            }
            final rawBytes = await readBoundedBytes(
              resp,
              maxBytes: kMaxCatalogResponseBytes,
              timeout: requestTimeout,
            );
            final body = utf8.decode(rawBytes);
            final decoded = jsonDecode(body);
            if (decoded is! Map) {
              continue;
            }
            final snapshot = DohCatalogSnapshot.fromJson(
              Map<String, dynamic>.from(decoded),
            );
            if (snapshot.servers.isEmpty) {
              continue;
            }
            final stamped = DohCatalogSnapshot(
              version: snapshot.version,
              updatedAt: snapshot.updatedAt ?? DateTime.now().toUtc(),
              servers: snapshot.servers,
              fallbackHosts: snapshot.fallbackHosts,
            );
            syncedCatalog.value = stamped;
            _dnsCache.clear();
            await _saveCatalog(stamped);
            if (mode.isBypassEnabled) {
              await applyNetworkConfig();
            }
            return true;
          } catch (e) {
            logger.t(
              'DoH catalog sync failed from $rawUrl '
              '(${proxyDirective ?? 'DIRECT'}): $e',
            );
          } finally {
            client.close(force: true);
          }
        }
      }
      return false;
    } finally {
      isSyncing.value = false;
    }
  }

  /// Concurrently probes all configured DoH servers for latency and pollution.
  Future<void> runDohSpeedTest() async {
    if (isTestingDoh.value) {
      return;
    }
    isTestingDoh.value = true;
    final targetServers = List<DohServerConfig>.from(servers);
    for (final s in targetServers) {
      probeResults[s.id] = DohProbeResult(
        serverId: s.id,
        status: ProbeStatus.testing,
      );
    }
    probeResults.refresh();

    try {
      await Future.wait<void>(
        targetServers.map((server) async {
          final result = await _dohClient.probeServer(server);
          probeResults[server.id] = result;
          probeResults.refresh();
        }),
      );
      _dnsCache.clear();
    } finally {
      isTestingDoh.value = false;
    }
  }

  /// Tests actual HTTPS reachability of E-Hentai core hosts using the currently
  /// active connection mode, always preserving full OS TLS certificate checks.
  Future<void> runSiteConnectivityCheck({
    Duration timeout = const Duration(seconds: 8),
  }) async {
    if (isTestingSites.value) {
      return;
    }
    isTestingSites.value = true;
    for (final host in SniBypassDefaults.diagnosticHosts) {
      siteResults[host] = SiteCheckResult(
        host: host,
        status: ProbeStatus.testing,
      );
    }
    siteResults.refresh();

    try {
      if (mode.isBypassEnabled && !isProxyRunning) {
        await applyNetworkConfig();
      }
      await Future.wait<void>(
        SniBypassDefaults.diagnosticHosts.map((host) async {
          final result = await _probeSiteHost(host, timeout: timeout);
          siteResults[host] = result;
          siteResults.refresh();
        }),
      );
    } finally {
      isTestingSites.value = false;
    }
  }

  Future<SiteCheckResult> _probeSiteHost(
    String host, {
    required Duration timeout,
  }) async {
    final sw = Stopwatch()..start();
    final client = HttpClient()
      ..connectionTimeout = timeout
      ..badCertificateCallback = null;
    try {
      final targetUri = Uri.parse('https://$host/');
      if (mode.isBypassEnabled && activeLocalProxyDirective != null) {
        client.findProxy = (_) => activeLocalProxyDirective!;
      } else if (globalDioConfig.proxy != null &&
          globalDioConfig.proxy!.isNotEmpty) {
        client.findProxy = (_) => globalDioConfig.proxy!;
      }

      final req = await client.headUrl(targetUri).timeout(timeout);
      req.headers.set(HttpHeaders.userAgentHeader, 'Eros-FE/Diag');
      final resp = await req.close().timeout(timeout);
      sw.stop();

      final ok = resp.statusCode >= 200 && resp.statusCode < 500;
      return SiteCheckResult(
        host: host,
        status: ok ? ProbeStatus.ok : ProbeStatus.error,
        statusCode: resp.statusCode,
        latencyMs: sw.elapsedMilliseconds,
      );
    } on TimeoutException {
      return SiteCheckResult(
        host: host,
        status: ProbeStatus.timeout,
      );
    } catch (e) {
      final lower = '$e'.toLowerCase();
      final isTimeout = lower.contains('timed out') || lower.contains('timeout');
      return SiteCheckResult(
        host: host,
        status: isTimeout ? ProbeStatus.timeout : ProbeStatus.error,
        error: '$e',
      );
    } finally {
      client.close(force: true);
    }
  }

  /// Detects whether the user is currently behind an explicit manual proxy,
  /// active OS HTTP proxy, or TUN/Fake-IP environment (Surge Enhanced Mode /
  /// Clash TUN returning `198.18.0.0/15`).
  ///
  /// When [mode] is [SniBypassMode.standard] and [force] is false, this exits
  /// immediately without performing any OS DNS or proxy probes.
  Future<ProxyConflictInfo?> detectProxyConflict({bool force = false}) async {
    if (!force && !mode.isBypassEnabled) {
      proxyConflict.value = null;
      return null;
    }

    // 1. Check in-app manual proxy setting.
    if (Get.isRegistered<EhSettingService>()) {
      final ehSetting = Get.find<EhSettingService>();
      final type = ehSetting.proxyType;
      if ((type == ProxyType.http ||
              type == ProxyType.socks5 ||
              type == ProxyType.socks4) &&
          ehSetting.proxyHost.trim().isNotEmpty) {
        final info = ProxyConflictInfo(
          kind: ProxyConflictKind.manualProxy,
          detail: '${ehSetting.proxyHost}:${ehSetting.proxyPort}',
        );
        proxyConflict.value = info;
        return info;
      }

      // 2. Check OS system HTTP proxy if proxyType == system.
      if (type == ProxyType.system) {
        try {
          final sysProxy = await getProxy(proxyType: ProxyType.system);
          if (sysProxy != 'DIRECT' && sysProxy.trim().isNotEmpty) {
            final info = ProxyConflictInfo(
              kind: ProxyConflictKind.systemProxy,
              detail: sysProxy,
            );
            proxyConflict.value = info;
            return info;
          }
        } catch (_) {}
      }
    }

    // 3. Probe OS DNS for Fake-IP (198.18.0.0/15: Surge Enhanced / Clash TUN).
    try {
      final addrs = await _systemDnsLookup('e-hentai.org')
          .timeout(const Duration(seconds: 2));
      for (final addr in addrs) {
        if (addr.type == InternetAddressType.IPv4 &&
            isFakeIpAddress(addr.address)) {
          final info = ProxyConflictInfo(
            kind: ProxyConflictKind.fakeIpTun,
            detail: addr.address,
          );
          proxyConflict.value = info;
          return info;
        }
      }
    } catch (_) {}

    proxyConflict.value = null;
    return null;
  }
}
