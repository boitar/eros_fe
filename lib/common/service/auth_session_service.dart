import 'dart:convert';
import 'dart:math' as math;

import 'package:dio/dio.dart';
import 'package:eros_fe/common/controller/user_controller.dart';
import 'package:eros_fe/common/global.dart';
import 'package:eros_fe/network/app_dio/pdio.dart';
import 'package:eros_fe/utils/logger.dart';
import 'package:eros_fe/utils/storage.dart';
import 'package:flutter/widgets.dart';
import 'package:get/get.dart' hide Response;

/// 登录态 30 天监控的三档视觉状态
enum AuthCountdownStatus {
  /// 剩余天数充足（> 提前提醒阈值）
  valid,

  /// 临近到期（1..提前提醒阈值）
  expiring,

  /// 已达或超过监控周期（<= 0 天）
  expired,
}

/// 认证方式标识
enum AuthMethodKind {
  password,
  web,
  cookie,
  cfVerify,
}

/// 对端站点看到的当前出口地区与边缘节点（来自 `/cdn-cgi/trace`）
@immutable
class ExitTraceInfo {
  const ExitTraceInfo({
    required this.countryCode,
    required this.colo,
    required this.fetchedAtMs,
  });

  final String countryCode;
  final String colo;
  final int fetchedAtMs;

  static const Set<String> _asianCodes = <String>{
    'JP',
    'KR',
    'CN',
    'HK',
    'MO',
    'TW',
    'SG',
    'MY',
    'TH',
    'VN',
    'PH',
    'ID',
    'IN',
  };

  static const Map<String, String> _zhCountryNames = <String, String>{
    'JP': '日本',
    'KR': '韩国',
    'CN': '中国大陆',
    'HK': '中国香港',
    'MO': '中国澳门',
    'TW': '中国台湾',
    'SG': '新加坡',
    'US': '美国',
    'CA': '加拿大',
    'GB': '英国',
    'DE': '德国',
    'NL': '荷兰',
    'FR': '法国',
    'CH': '瑞士',
    'SE': '瑞典',
    'FI': '芬兰',
    'AU': '澳大利亚',
    'NZ': '新西兰',
    'RU': '俄罗斯',
    'IN': '印度',
  };

  static const Map<String, String> _zhColoCities = <String, String>{
    'NRT': '东京',
    'HND': '东京',
    'KIX': '大阪',
    'FUK': '福冈',
    'ICN': '首尔',
    'HKG': '香港',
    'TPE': '台北',
    'SIN': '新加坡',
    'LAX': '洛杉矶',
    'SJC': '圣何塞',
    'SEA': '西雅图',
    'ORD': '芝加哥',
    'EWR': '纽瓦克',
    'IAD': '阿什本',
    'DFW': '达拉斯',
    'FRA': '法兰克福',
    'AMS': '阿姆斯特丹',
    'LHR': '伦敦',
    'CDG': '巴黎',
    'ZRH': '苏黎世',
    'SYD': '悉尼',
  };

  bool get isAsianRegion => _asianCodes.contains(countryCode.toUpperCase());

  String displayLabel({required bool zh}) {
    final code = countryCode.toUpperCase();
    final coloCode = colo.toUpperCase();
    if (!zh) {
      return coloCode.isEmpty ? code : '$code · $coloCode';
    }
    final country = _zhCountryNames[code] ?? code;
    final city = _zhColoCities[coloCode];
    if (city != null && city != country) {
      return '$country · $city';
    }
    if (coloCode.isNotEmpty) {
      return '$country · $coloCode';
    }
    return country;
  }

  String compactWithColo({required bool zh}) {
    final base = displayLabel(zh: zh);
    final coloCode = colo.toUpperCase();
    if (coloCode.isEmpty || base.contains(coloCode)) {
      return base;
    }
    return '$base（$coloCode）';
  }

  static ExitTraceInfo? tryParse(String body, {int? nowMs}) {
    String? loc;
    String? colo;
    for (final rawLine in body.split('\n')) {
      final line = rawLine.trim();
      if (line.startsWith('loc=')) {
        loc = line.substring(4).trim().toUpperCase();
      } else if (line.startsWith('colo=')) {
        colo = line.substring(5).trim().toUpperCase();
      }
    }
    if (loc == null || loc.isEmpty) {
      return null;
    }
    return ExitTraceInfo(
      countryCode: loc,
      colo: colo ?? '',
      fetchedAtMs: nowMs ?? DateTime.now().millisecondsSinceEpoch,
    );
  }

  Map<String, dynamic> toJson() => <String, dynamic>{
        'countryCode': countryCode,
        'colo': colo,
        'fetchedAtMs': fetchedAtMs,
      };

  factory ExitTraceInfo.fromJson(Map<String, dynamic> json) => ExitTraceInfo(
        countryCode: (json['countryCode'] ?? '').toString(),
        colo: (json['colo'] ?? '').toString(),
        fetchedAtMs: int.tryParse('${json['fetchedAtMs'] ?? 0}') ?? 0,
      );
}

/// 单条认证历史记录
@immutable
class AuthHistoryEntry {
  const AuthHistoryEntry({
    required this.timestampMs,
    required this.method,
    required this.hasExAccess,
    required this.verifiedCf,
    this.exitSummary,
  });

  final int timestampMs;
  final AuthMethodKind method;
  final bool hasExAccess;
  final bool verifiedCf;
  final String? exitSummary;

  Map<String, dynamic> toJson() => <String, dynamic>{
        'timestampMs': timestampMs,
        'method': method.name,
        'hasExAccess': hasExAccess,
        'verifiedCf': verifiedCf,
        'exitSummary': exitSummary,
      };

  factory AuthHistoryEntry.fromJson(Map<String, dynamic> json) {
    final methodName = (json['method'] ?? 'password').toString();
    final kind = AuthMethodKind.values.firstWhere(
      (e) => e.name == methodName,
      orElse: () => AuthMethodKind.password,
    );
    return AuthHistoryEntry(
      timestampMs: int.tryParse('${json['timestampMs'] ?? 0}') ?? 0,
      method: kind,
      hasExAccess: json['hasExAccess'] == true,
      verifiedCf: json['verifiedCf'] == true,
      exitSummary: json['exitSummary']?.toString(),
    );
  }
}

/// 账号登录态 30 天监控快照
@immutable
class AuthSessionSnapshot {
  const AuthSessionSnapshot({
    this.memberId,
    this.lastAuthAtMs,
    this.ttlDays = defaultTtlDays,
    this.remindDaysBefore = defaultRemindDaysBefore,
    this.remindEnabled = true,
    this.lastDismissedAtMs,
    this.exFailedUntilMs,
    this.lastExit,
    this.history = const <AuthHistoryEntry>[],
  });

  static const int defaultTtlDays = 30;
  static const int defaultRemindDaysBefore = 3;
  static const Duration bannerCooldown = Duration(hours: 24);
  static const Duration exFailureCacheDuration = Duration(hours: 12);

  final String? memberId;
  final int? lastAuthAtMs;
  final int ttlDays;
  final int remindDaysBefore;
  final bool remindEnabled;
  final int? lastDismissedAtMs;
  final int? exFailedUntilMs;
  final ExitTraceInfo? lastExit;
  final List<AuthHistoryEntry> history;

  DateTime? get lastAuthAt => lastAuthAtMs == null
      ? null
      : DateTime.fromMillisecondsSinceEpoch(lastAuthAtMs!);

  DateTime? get expiresAt =>
      lastAuthAt?.add(Duration(days: math.max(1, ttlDays)));

  /// 剩余整天数（向上取整，保证刚认证完显示满 30 天，超期为 0）
  int remainingDaysAt(DateTime now) {
    final exp = expiresAt;
    if (exp == null) {
      return ttlDays;
    }
    final diffMs = exp.millisecondsSinceEpoch - now.millisecondsSinceEpoch;
    if (diffMs <= 0) {
      return 0;
    }
    const dayMs = 24 * 60 * 60 * 1000;
    return math.min(ttlDays, (diffMs / dayMs).ceil());
  }

  double progressAt(DateTime now) {
    if (ttlDays <= 0) {
      return 0;
    }
    final rem = remainingDaysAt(now);
    return (rem / ttlDays).clamp(0.0, 1.0);
  }

  AuthCountdownStatus statusAt(DateTime now) {
    final rem = remainingDaysAt(now);
    if (rem <= 0) {
      return AuthCountdownStatus.expired;
    }
    if (rem <= remindDaysBefore) {
      return AuthCountdownStatus.expiring;
    }
    return AuthCountdownStatus.valid;
  }

  DateTime? exFailureCooldownUntil(DateTime now) {
    final ms = exFailedUntilMs;
    if (ms == null || ms <= now.millisecondsSinceEpoch) {
      return null;
    }
    return DateTime.fromMillisecondsSinceEpoch(ms);
  }

  AuthSessionSnapshot copyWith({
    String? memberId,
    int? lastAuthAtMs,
    int? ttlDays,
    int? remindDaysBefore,
    bool? remindEnabled,
    int? lastDismissedAtMs,
    bool clearDismissed = false,
    int? exFailedUntilMs,
    bool clearExFailed = false,
    ExitTraceInfo? lastExit,
    List<AuthHistoryEntry>? history,
  }) {
    return AuthSessionSnapshot(
      memberId: memberId ?? this.memberId,
      lastAuthAtMs: lastAuthAtMs ?? this.lastAuthAtMs,
      ttlDays: ttlDays ?? this.ttlDays,
      remindDaysBefore: remindDaysBefore ?? this.remindDaysBefore,
      remindEnabled: remindEnabled ?? this.remindEnabled,
      lastDismissedAtMs:
          clearDismissed ? null : (lastDismissedAtMs ?? this.lastDismissedAtMs),
      exFailedUntilMs:
          clearExFailed ? null : (exFailedUntilMs ?? this.exFailedUntilMs),
      lastExit: lastExit ?? this.lastExit,
      history: history ?? this.history,
    );
  }

  Map<String, dynamic> toJson() => <String, dynamic>{
        'memberId': memberId,
        'lastAuthAtMs': lastAuthAtMs,
        'ttlDays': ttlDays,
        'remindDaysBefore': remindDaysBefore,
        'remindEnabled': remindEnabled,
        'lastDismissedAtMs': lastDismissedAtMs,
        'exFailedUntilMs': exFailedUntilMs,
        'lastExit': lastExit?.toJson(),
        'history': history.map((e) => e.toJson()).toList(),
      };

  factory AuthSessionSnapshot.fromJson(Map<String, dynamic> json) {
    final rawHistory = json['history'];
    final parsedHistory = rawHistory is List
        ? rawHistory
            .whereType<Map<dynamic, dynamic>>()
            .map((e) => AuthHistoryEntry.fromJson(Map<String, dynamic>.from(e)))
            .toList()
        : const <AuthHistoryEntry>[];
    final rawExit = json['lastExit'];
    return AuthSessionSnapshot(
      memberId: json['memberId']?.toString(),
      lastAuthAtMs: json['lastAuthAtMs'] == null
          ? null
          : int.tryParse('${json['lastAuthAtMs']}'),
      ttlDays: int.tryParse('${json['ttlDays'] ?? ''}') ?? defaultTtlDays,
      remindDaysBefore: int.tryParse('${json['remindDaysBefore'] ?? ''}') ??
          defaultRemindDaysBefore,
      remindEnabled: json['remindEnabled'] != false,
      lastDismissedAtMs: json['lastDismissedAtMs'] == null
          ? null
          : int.tryParse('${json['lastDismissedAtMs']}'),
      exFailedUntilMs: json['exFailedUntilMs'] == null
          ? null
          : int.tryParse('${json['exFailedUntilMs']}'),
      lastExit: rawExit is Map
          ? ExitTraceInfo.fromJson(Map<String, dynamic>.from(rawExit))
          : null,
      history: parsedHistory,
    );
  }
}

/// 统一管理登录态 30 天倒计时、出口节点探测与应用内顶部到期小弹窗
class AuthSessionService extends GetxService {
  AuthSessionService({
    Future<ExitTraceInfo?> Function()? traceProbe,
    DateTime Function()? clock,
  })  : _traceProbe = traceProbe,
        _clock = clock ?? DateTime.now;

  static const String storageKey = 'eh_auth_session_meta_v1';
  static const int maxHistoryCount = 10;

  static AuthSessionService ensure() {
    if (Get.isRegistered<AuthSessionService>()) {
      return Get.find<AuthSessionService>();
    }
    return Get.put<AuthSessionService>(AuthSessionService(), permanent: true);
  }

  final Future<ExitTraceInfo?> Function()? _traceProbe;
  final DateTime Function() _clock;

  final Rx<AuthSessionSnapshot> snapshot = const AuthSessionSnapshot().obs;
  final Rxn<ExitTraceInfo> currentExit = Rxn<ExitTraceInfo>();
  final RxBool probingExit = false.obs;

  /// 单次前台会话已经弹出过顶部通知后不再重复打扰
  bool _shownInCurrentSession = false;

  DateTime get now => _clock();

  @override
  void onInit() {
    super.onInit();
    _loadFromStorage();
    _syncWithCurrentUser();
    if (Get.isRegistered<UserController>()) {
      ever(Get.find<UserController>().user, (_) => _syncWithCurrentUser());
    }
  }

  void _loadFromStorage() {
    try {
      final raw = storageUtil.getString(storageKey);
      if (raw != null && raw.isNotEmpty) {
        final decoded = jsonDecode(raw);
        if (decoded is Map) {
          final loaded =
              AuthSessionSnapshot.fromJson(Map<String, dynamic>.from(decoded));
          snapshot.value = loaded;
          if (loaded.lastExit != null) {
            currentExit.value = loaded.lastExit;
          }
        }
      }
    } catch (e) {
      logger.w('load auth session meta failed: $e');
    }
  }

  void _persist() {
    try {
      storageUtil.setString(storageKey, jsonEncode(snapshot.value.toJson()));
    } catch (e) {
      logger.w('persist auth session meta failed: $e');
    }
  }

  /// 对老版本已登录用户平滑初始化一个默认 30 天周期，切换账号时重置账号绑定
  void _syncWithCurrentUser() {
    if (!Get.isRegistered<UserController>()) {
      return;
    }
    final userCtrl = Get.find<UserController>();
    if (!userCtrl.isLogin) {
      _shownInCurrentSession = false;
      return;
    }
    final memberId = userCtrl.user.value.memberId;
    final cur = snapshot.value;
    if (cur.memberId != memberId || cur.lastAuthAtMs == null) {
      snapshot.value = AuthSessionSnapshot(
        memberId: memberId,
        lastAuthAtMs: now.millisecondsSinceEpoch,
        ttlDays: cur.ttlDays,
        remindDaysBefore: cur.remindDaysBefore,
        remindEnabled: cur.remindEnabled,
        history: cur.memberId == memberId ? cur.history : const <AuthHistoryEntry>[],
      );
      _persist();
    }
  }

  /// 记录一次成功的登录或重新认证，立即将倒计时重置为满周期
  void recordAuthSuccess({
    required String memberId,
    required AuthMethodKind method,
    required bool hasExAccess,
    bool verifiedCf = false,
    ExitTraceInfo? exitInfo,
    bool zh = true,
  }) {
    final ts = now.millisecondsSinceEpoch;
    final effectiveExit = exitInfo ?? currentExit.value ?? snapshot.value.lastExit;
    final entry = AuthHistoryEntry(
      timestampMs: ts,
      method: method,
      hasExAccess: hasExAccess,
      verifiedCf: verifiedCf,
      exitSummary: effectiveExit?.compactWithColo(zh: zh),
    );
    final prevHistory = snapshot.value.memberId == memberId
        ? snapshot.value.history
        : const <AuthHistoryEntry>[];
    final nextHistory = <AuthHistoryEntry>[
      entry,
      ...prevHistory,
    ].take(maxHistoryCount).toList();

    snapshot.value = snapshot.value.copyWith(
      memberId: memberId,
      lastAuthAtMs: ts,
      clearDismissed: true,
      exFailedUntilMs: hasExAccess
          ? null
          : ts + AuthSessionSnapshot.exFailureCacheDuration.inMilliseconds,
      clearExFailed: hasExAccess,
      lastExit: effectiveExit,
      history: nextHistory,
    );
    _shownInCurrentSession = false;
    _persist();
  }

  /// 记录里站单独重试结果
  void recordExRetryResult({required bool hasExAccess}) {
    final ts = now.millisecondsSinceEpoch;
    snapshot.value = snapshot.value.copyWith(
      exFailedUntilMs: hasExAccess
          ? null
          : ts + AuthSessionSnapshot.exFailureCacheDuration.inMilliseconds,
      clearExFailed: hasExAccess,
    );
    _persist();
  }

  void updateRemindEnabled(bool enabled) {
    snapshot.value = snapshot.value.copyWith(remindEnabled: enabled);
    _persist();
  }

  void updateRemindDaysBefore(int days) {
    snapshot.value =
        snapshot.value.copyWith(remindDaysBefore: days.clamp(1, 14));
    _persist();
  }

  void updateTtlDays(int days) {
    snapshot.value = snapshot.value.copyWith(ttlDays: days.clamp(7, 180));
    _persist();
  }

  /// 是否应在进入应用时弹出页面顶部提醒横幅
  bool shouldShowStartupBanner({required bool isLoggedIn}) {
    if (!isLoggedIn || _shownInCurrentSession) {
      return false;
    }
    final snap = snapshot.value;
    if (!snap.remindEnabled || snap.lastAuthAtMs == null) {
      return false;
    }
    final current = now;
    final st = snap.statusAt(current);
    if (st == AuthCountdownStatus.valid) {
      return false;
    }
    final dismissedMs = snap.lastDismissedAtMs;
    if (dismissedMs != null) {
      final elapsed = current.millisecondsSinceEpoch - dismissedMs;
      if (elapsed < AuthSessionSnapshot.bannerCooldown.inMilliseconds) {
        return false;
      }
    }
    return true;
  }

  void markStartupBannerShown() {
    _shownInCurrentSession = true;
  }

  void dismissStartupBannerForCooldown() {
    _shownInCurrentSession = true;
    snapshot.value = snapshot.value.copyWith(
      lastDismissedAtMs: now.millisecondsSinceEpoch,
    );
    _persist();
  }

  @visibleForTesting
  void resetSessionBannerFlag() {
    _shownInCurrentSession = false;
  }

  /// 探测论坛看到的当前出口国家与 Cloudflare 边缘节点
  Future<ExitTraceInfo?> probeExitRegion() async {
    if (probingExit.value) {
      return currentExit.value;
    }
    probingExit.value = true;
    try {
      final ExitTraceInfo? info;
      if (_traceProbe != null) {
        info = await _traceProbe();
      } else {
        info = await _defaultProbe();
      }
      if (info != null) {
        currentExit.value = info;
      }
      return info;
    } catch (e) {
      logger.d('probeExitRegion ignored error: $e');
      return currentExit.value;
    } finally {
      probingExit.value = false;
    }
  }

  Future<ExitTraceInfo?> _defaultProbe() async {
    final DioHttpClient client = DioHttpClient(dioConfig: globalDioConfig);
    final DioHttpResponse response = await client.get(
      'https://forums.e-hentai.org/cdn-cgi/trace',
      options: Options(
        responseType: ResponseType.plain,
        sendTimeout: const Duration(seconds: 6),
        receiveTimeout: const Duration(seconds: 6),
        validateStatus: (status) => status != null && status < 500,
      ),
    );
    final data = response.data?.toString() ?? '';
    return ExitTraceInfo.tryParse(data, nowMs: now.millisecondsSinceEpoch);
  }
}

/// 登录与账号管理模块的中英文双语文案（零侵入自动跟随系统语言）
class AuthStrings {
  const AuthStrings._(this.zh);

  final bool zh;

  static AuthStrings of(BuildContext context) {
    Locale? locale;
    try {
      locale = Localizations.maybeLocaleOf(context);
    } catch (_) {
      locale = null;
    }
    final code = (locale ?? Get.locale)?.languageCode.toLowerCase() ?? 'zh';
    return AuthStrings._(code.startsWith('zh'));
  }

  String get welcomeBack => zh ? '欢迎回来' : 'Welcome back';
  String get loginSubtitle =>
      zh ? '登录后同步你的收藏、评分与阅读设置。' : 'Sign in to sync favorites, ratings, and settings.';
  String get usernameHint => zh ? '用户名' : 'Username';
  String get passwordHint => zh ? '密码' : 'Password';
  String get signIn => zh ? '登录' : 'Sign in';
  String get webSignIn => zh ? '网页登录' : 'Web Sign-in';
  String get cookieSignIn => zh ? 'Cookie 登录' : 'Cookie Sign-in';
  String get useCookieSignIn => zh ? '使用 Cookie 登录' : 'Sign in with Cookie';
  String get switchToCookie => zh ? '改用 Cookie 登录' : 'Use Cookie instead';
  String get cancel => zh ? '取消' : 'Cancel';
  String get probingExit => zh ? '检测出口…' : 'Checking region…';
  String get recheckExit => zh ? '重新检测' : 'Recheck';
  String asianExitNotice(String place) => zh
      ? '当前从$place出口。使用亚洲节点登录常常拿不到里站权限；建议先切到欧美节点再登录，登录后可随意切换。'
      : 'Current exit: $place. Signing in from Asian nodes often omits EX access (igneous). Consider switching to a US/EU node before signing in.';

  String get signingInTitle => zh ? '正在登录' : 'Signing in';
  String get stepConnectForum => zh ? '连接论坛' : 'Connect to forum';
  String get stepVerifyAccount => zh ? '验证账号' : 'Verify credentials';
  String get stepExAccess => zh ? '获取里站权限' : 'Acquire EX access';
  String get stepSyncProfile => zh ? '同步资料与设置' : 'Sync profile & settings';
  String get waitingVerification => zh ? '等待验证' : 'Verification needed';

  String get cfRequiredTitle => zh ? '需要安全验证' : 'Security check required';
  String get cfRequiredSubtitle =>
      zh ? '论坛开启了 Cloudflare 人机检查。' : 'The forum requested a Cloudflare human check.';
  String get cfContinueHint => zh
      ? '在应用内浏览器完成一次验证后，会自动带着刚才的账号继续登录，无需重新输入。'
      : 'Complete the check once in the in-app browser; your account will continue signing in automatically.';
  String get goVerify => zh ? '前往验证' : 'Verify now';
  String get showVerifyWindow => zh ? '显示验证窗口' : 'Show verification window';

  String get verifyBrowserTitle => zh ? '安全验证' : 'Security Check';
  String get trackStepVerify => zh ? '完成验证' : 'Complete check';
  String get trackStepAutoLogin => zh ? '自动登录' : 'Auto sign-in';
  String get trackStepReturn => zh ? '返回' : 'Return';
  String get dockHintVerify => zh
      ? '点一下页面中的验证框；通过后会自动提交账号并返回，无需手动点完成。'
      : 'Complete the checkbox above; sign-in and return happen automatically.';
  String get dockHintCfOnly => zh
      ? '完成人机验证后将自动保存验证凭据并返回。'
      : 'Once verified, clearance cookies are saved automatically.';
  String get troubleLink => zh ? '一直过不去？' : 'Stuck on verification?';
  String get clearWebDataAndReload => zh ? '清除站点数据并刷新' : 'Clear site data & reload';

  String welcomeUser(String name) => zh ? '欢迎，$name' : 'Welcome, $name';
  String get bothSitesReady =>
      zh ? '表站和里站都已就绪。' : 'Both E-Hentai and EX are ready.';
  String get ehOnlyTitle => zh ? '表站已登录' : 'Signed in to E-Hentai';
  String get ehOnlySubtitle =>
      zh ? '但没有拿到里站权限。' : 'EX access cookie was not granted.';
  String get exDeniedReason => zh
      ? '站点没有下发里站凭据（igneous = mystery）。最常见的原因是用亚洲节点登录，也可能是新账号尚未获得资格。重试时会先自动清除本机 12 小时失败记录。'
      : 'The server returned igneous=mystery. This usually happens on Asian exit IPs or new accounts without EX permission. Retrying clears the 12-hour failure cookie first.';
  String get retryExAfterSwitch => zh ? '换节点后重试里站' : 'Retry EX after switching node';
  String get useEhOnlyForNow => zh ? '先只用表站' : 'Continue with E-Hentai only';
  String get startBrowsing => zh ? '开始浏览' : 'Start browsing';

  String get accountPageTitle => zh ? '账号与登录态' : 'Account & Session';
  String get changeAvatar => zh ? '更换头像' : 'Change avatar';
  String get sessionValid => zh ? '登录态有效' : 'Session active';
  String get sessionExpiring => zh ? '即将到期' : 'Expiring soon';
  String get sessionExpired => zh ? '监控周期已满' : 'Renewal recommended';
  String get remainingDaysUnit => zh ? '剩余天' : 'days left';
  String remainingDaysSummary(int days) =>
      days > 0 ? (zh ? '登录态剩余 $days 天' : '$days days left') : (zh ? '建议重新认证' : 'Re-auth advised');
  String expiresOnText(String dateStr, int ttl) =>
      zh ? '$dateStr 到期 · $ttl 天周期' : 'Expires $dateStr · $ttl-day cycle';
  String lastAuthText(String timeStr) =>
      zh ? '上次认证：$timeStr' : 'Last auth: $timeStr';

  String get reauthenticate => zh ? '重新认证' : 'Re-authenticate';
  String get reauthenticateNow => zh ? '立即重新认证' : 'Re-authenticate now';
  String get reauthResetTtl => zh ? '认证并重置周期' : 'Authenticate & reset timer';
  String get reauthSheetSubtitle => zh
      ? '续期并重置倒计时，或免密直接过网页安全验证。'
      : 'Renew your session timer, or run a passwordless web security check.';
  String get webSecurityVerify => zh ? '网页安全验证' : 'Web Security Check';
  String get updateCookie => zh ? '更新 Cookie' : 'Update Cookie';

  String get sectionSiteStatus => zh ? '站点状态' : 'Site Status';
  String get surfaceSite => zh ? '表站 E-Hentai' : 'E-Hentai';
  String get innerSite => zh ? '里站 EX' : 'EX Inner Site';
  String get statusSignedIn => zh ? '已登录' : 'Signed in';
  String get statusGranted => zh ? '已获权限' : 'Granted';
  String get statusNotGranted => zh ? '未获权限' : 'Not granted';
  String get exitAtAuth => zh ? '认证时出口' : 'Auth exit node';

  String get sectionCredentials => zh ? '登录信息（点按可复制）' : 'Session Credentials (tap to copy)';
  String get viewAllCredentials => zh ? '查看全部凭据' : 'All credentials';
  String credentialCount(int count) => zh ? '共 $count 项' : '$count items';
  String get copiedToast => zh ? '已复制到剪贴板' : 'Copied to clipboard';

  String get sectionHistory => zh ? '最近认证记录' : 'Recent Auth History';
  String get sectionReminder => zh ? '到期提醒（应用内）' : 'Expiry Reminder (In-app)';
  String get inAppTopReminder => zh ? '进入应用时顶部提醒' : 'Top banner on app launch';
  String get remindAdvance => zh ? '提前提醒时间' : 'Remind in advance';
  String get monitorCycle => zh ? '监控周期' : 'Monitor cycle';
  String beforeDaysLabel(int d) => zh ? '到期前 $d 天' : '$d days before';
  String cycleDaysLabel(int d) => zh ? '$d 天' : '$d days';
  String get reminderFooter => zh
      ? '有效期从最近一次认证成功算起；仅在进入应用时于页面上方弹出轻提示，不请求系统通知权限。'
      : 'Counted from your last successful authentication. Shows an in-app top pill on launch without OS notifications.';

  String get signOut => zh ? '退出登录' : 'Sign Out';

  String bannerTitle(int days) => days > 0
      ? (zh ? '登录态将在 $days 天后到期' : 'Session expires in $days days')
      : (zh ? '登录态已满监控周期' : 'Session monitor cycle reached');
  String get bannerSubtitle => zh
      ? '重新认证一次，避免收藏与里站访问中断'
      : 'Re-authenticate to keep favorites and EX access active';

  String methodLabel(AuthMethodKind kind, {required bool verifiedCf}) {
    switch (kind) {
      case AuthMethodKind.password:
        if (zh) {
          return verifiedCf ? '账号密码 · 经过验证' : '账号密码登录';
        }
        return verifiedCf ? 'Password · Verified' : 'Password sign-in';
      case AuthMethodKind.web:
        return zh ? '应用内网页登录' : 'In-app Web sign-in';
      case AuthMethodKind.cookie:
        return zh ? 'Cookie 登录' : 'Cookie sign-in';
      case AuthMethodKind.cfVerify:
        return zh ? '网页安全验证续期' : 'Web security verification';
    }
  }

  static String maskSecret(String? value) {
    if (value == null || value.isEmpty) {
      return '—';
    }
    if (value.length <= 4) {
      return '${value[0]}•••';
    }
    return '${value.substring(0, math.min(3, value.length))}•••${value.substring(value.length - 2)}';
  }

  static String formatMonthDayTime(DateTime dt, {required bool zh}) {
    final m = dt.month.toString().padLeft(2, '0');
    final d = dt.day.toString().padLeft(2, '0');
    final hh = dt.hour.toString().padLeft(2, '0');
    final mm = dt.minute.toString().padLeft(2, '0');
    return zh ? '$m 月 $d 日 $hh:$mm' : '$m-$d $hh:$mm';
  }

  static String formatMonthDay(DateTime dt, {required bool zh}) {
    final m = dt.month;
    final d = dt.day;
    return zh ? '$m 月 $d 日' : '${dt.year}-${m.toString().padLeft(2, '0')}-${d.toString().padLeft(2, '0')}';
  }
}
