import 'dart:convert';

import 'package:cookie_jar/cookie_jar.dart';
import 'package:eros_fe/common/controller/user_controller.dart';
import 'package:eros_fe/common/service/auth_session_service.dart';
import 'package:eros_fe/component/exception/error.dart';
import 'package:eros_fe/index.dart';
import 'package:eros_fe/network/api.dart';
import 'package:eros_fe/network/request.dart';
import 'package:eros_fe/pages/login/view/login_cookie.dart';
import 'package:eros_fe/pages/setting/webview/cf_verify_in.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';

const TextStyle kTextStyle = TextStyle(
  fontSize: 16,
  textBaseline: TextBaseline.alphabetic,
  height: 1.25,
);

/// 登录视图阶段
enum LoginFlowPhase {
  /// 输入表单（首屏）
  form,

  /// 就地四步登录动画
  authenticating,

  /// 遇到 Cloudflare 人机挑战，等待点击「前往验证」
  cfRequired,

  /// 表站与里站均就绪
  success,

  /// 表站已登录，但未获里站 `igneous` 权限
  exDenied,
}

enum LoginStepState {
  waiting,
  running,
  done,
  warning,
}

class LoginController extends GetxController {
  final FocusNode nodePwd = FocusNode();
  final FocusNode nodeHash = FocusNode();
  final FocusNode nodeIgneous = FocusNode();

  final TextEditingController usernameController = TextEditingController();
  final TextEditingController passwdController = TextEditingController();

  // Cookie 登录控制器（使用真实字段名 ipb_member_id / ipb_pass_hash / igneous）
  final TextEditingController idController = TextEditingController();
  final TextEditingController hashController = TextEditingController();
  final TextEditingController igneousController = TextEditingController();

  final UserController userController = Get.find();
  AuthSessionService get authService => AuthSessionService.ensure();

  bool loadingLogin = false;
  bool obscurePasswd = true;
  bool clipboardHasCookieHint = false;

  LoginFlowPhase phase = LoginFlowPhase.form;
  String? inlineError;

  /// 四步状态：0 连接论坛, 1 验证账号, 2 获取里站权限, 3 同步资料与设置
  List<LoginStepState> stepStates = <LoginStepState>[
    LoginStepState.waiting,
    LoginStepState.waiting,
    LoginStepState.waiting,
    LoginStepState.waiting,
  ];
  List<String?> stepMetas = <String?>[null, null, null, null];

  AuthMethodKind lastAuthMethod = AuthMethodKind.password;
  bool lastVerifiedCf = false;
  bool _cancelled = false;

  /// 当前正在浏览器验证窗口中时置 true（用于 Desktop 提示验证窗口已打开）
  bool verifyWindowOpen = false;

  @override
  void onInit() {
    super.onInit();
    authService.probeExitRegion();
    checkClipboardForCookieHint();
  }

  @override
  void onClose() {
    usernameController.dispose();
    passwdController.dispose();
    idController.dispose();
    hashController.dispose();
    igneousController.dispose();
    nodePwd.dispose();
    nodeHash.dispose();
    nodeIgneous.dispose();
    super.onClose();
  }

  void _resetSteps() {
    stepStates = <LoginStepState>[
      LoginStepState.waiting,
      LoginStepState.waiting,
      LoginStepState.waiting,
      LoginStepState.waiting,
    ];
    stepMetas = <String?>[null, null, null, null];
  }

  void cancelActiveFlow() {
    _cancelled = true;
    loadingLogin = false;
    verifyWindowOpen = false;
    phase = LoginFlowPhase.form;
    _resetSteps();
    update();
  }

  void clearInlineError() {
    if (inlineError != null) {
      inlineError = null;
      update();
    }
  }

  void switchObscure() {
    obscurePasswd = !obscurePasswd;
    update();
  }

  /// 账号密码主登录流程（含出口探测、就地步骤链、CF 拦截识别与里站握手）
  Future<void> pressLogin({
    String? overrideUsername,
    bool closeOnComplete = false,
  }) async {
    if (loadingLogin) {
      return;
    }

    final username = (overrideUsername ?? usernameController.text).trim();
    final password = passwdController.text;
    final zh =
        Get.locale?.languageCode.toLowerCase().startsWith('zh') ?? true;

    if (username.isEmpty || password.isEmpty) {
      inlineError = zh ? '请输入用户名和密码' : 'Please enter username and password';
      update();
      return;
    }

    _cancelled = false;
    inlineError = null;
    loadingLogin = true;
    lastAuthMethod = AuthMethodKind.password;
    lastVerifiedCf = false;
    phase = LoginFlowPhase.authenticating;
    _resetSteps();
    stepStates[0] = LoginStepState.running;
    FocusManager.instance.primaryFocus?.unfocus();
    update();

    final sw = Stopwatch()..start();
    final exitInfo =
        authService.currentExit.value ?? await authService.probeExitRegion();
    if (_cancelled) {
      return;
    }
    sw.stop();
    stepStates[0] = LoginStepState.done;
    final coloTag = exitInfo?.colo ?? '';
    stepMetas[0] = coloTag.isNotEmpty
        ? '$coloTag · ${sw.elapsedMilliseconds} ms'
        : '${sw.elapsedMilliseconds} ms';
    stepStates[1] = LoginStepState.running;
    update();

    User? loggedInUser;
    try {
      loggedInUser = await userLogin(username, password);
    } catch (e, stack) {
      logger.e('userLogin error: $e\n$stack');
      if (_cancelled) {
        return;
      }
      if (isCfBlockedError(e)) {
        loadingLogin = false;
        stepStates[0] = LoginStepState.warning;
        stepMetas[0] = zh ? '等待验证' : 'Check required';
        stepStates[1] = LoginStepState.waiting;
        phase = LoginFlowPhase.cfRequired;
        update();
        return;
      }
      loadingLogin = false;
      phase = LoginFlowPhase.form;
      inlineError = (e is EhError && e.type == EhErrorType.login)
          ? (zh ? '用户名或密码不正确，请重试。' : 'Incorrect username or password.')
          : '$e';
      update();
      return;
    }

    if (_cancelled) {
      return;
    }
    if (loggedInUser == null || (loggedInUser.memberId?.isEmpty ?? true)) {
      loadingLogin = false;
      phase = LoginFlowPhase.form;
      inlineError =
          zh ? '登录未返回有效凭据，请重试或使用网页验证。' : 'Sign-in returned empty credentials.';
      update();
      return;
    }

    // 保存表站基础凭据
    userController.user(loggedInUser.copyWith(username: username.oN));
    stepStates[1] = LoginStepState.done;
    await _runExHandshakeAndProfileSync(
      memberId: loggedInUser.memberId!,
      method: AuthMethodKind.password,
      verifiedCf: false,
      zh: zh,
      closeOnComplete: closeOnComplete,
    );
  }

  /// 点击「前往验证」：打开应用内验证浏览器，通过后自动填表登录并握手里站
  Future<void> continueWithCfBrowser({
    String? overrideUsername,
    bool closeOnComplete = false,
  }) async {
    if (verifyWindowOpen) {
      return;
    }
    final username = (overrideUsername ?? usernameController.text).trim();
    final password = passwdController.text;
    final zh =
        Get.locale?.languageCode.toLowerCase().startsWith('zh') ?? true;

    verifyWindowOpen = true;
    update();
    final verification = await openCfVerification(
      username: username.isNotEmpty ? username : null,
      password: password.isNotEmpty ? password : null,
      interactiveWebLogin: username.isEmpty || password.isEmpty,
      acquireExSession: true,
    );
    verifyWindowOpen = false;

    if (_cancelled) {
      return;
    }
    if (verification == null) {
      update();
      return;
    }

    await applyCfVerification(verification);

    // 若浏览器内已经拿到完整登录 Cookie，直接进入后半段同步
    if (verification.hasLoginSession) {
      final memberId = verification.value('ipb_member_id')!.trim();
      final displayName =
          username.isNotEmpty ? username : '${memberId[0]}****';
      userController.user(
        userController.user.value.copyWith(username: displayName.oN),
      );
      loadingLogin = true;
      lastVerifiedCf = true;
      phase = LoginFlowPhase.authenticating;
      stepStates[0] = LoginStepState.done;
      stepMetas[0] = 'CF ✓';
      stepStates[1] = LoginStepState.done;
      update();

      await _runExHandshakeAndProfileSync(
        memberId: memberId,
        method: AuthMethodKind.password,
        verifiedCf: true,
        alreadyHasExFromBrowser: verification.hasValidIgneous,
        skipExNetworkBecauseBrowserTried: verification.exVisited,
        zh: zh,
        closeOnComplete: closeOnComplete,
      );
      return;
    }

    // 仅带回了 cf_clearance，重新发起一次表单提交
    if (verification.isComplete &&
        username.isNotEmpty &&
        password.isNotEmpty) {
      await pressLogin(
        overrideUsername: username,
        closeOnComplete: closeOnComplete,
      );
      return;
    }
    update();
  }

  /// 第 3 步（里站握手）+ 第 4 步（资料与站点设置同步）+ 记录 30 天监控元数据
  Future<void> _runExHandshakeAndProfileSync({
    required String memberId,
    required AuthMethodKind method,
    required bool verifiedCf,
    required bool zh,
    bool alreadyHasExFromBrowser = false,
    bool skipExNetworkBecauseBrowserTried = false,
    bool closeOnComplete = false,
  }) async {
    stepStates[2] = LoginStepState.running;
    update();

    bool hasEx = alreadyHasExFromBrowser || _currentUserHasValidIgneous();
    if (!hasEx && !skipExNetworkBecauseBrowserTried) {
      try {
        await clearExHentaiCookies();
        await getExIgneous();
        await _syncIgneousFromCookieJar();
        hasEx = _currentUserHasValidIgneous();
      } catch (e) {
        logger.w('EX handshake failed during login: $e');
        hasEx = _currentUserHasValidIgneous();
      }
    }

    stepStates[2] = hasEx ? LoginStepState.done : LoginStepState.warning;
    stepMetas[2] = hasEx ? 'igneous ✓' : (zh ? '未下发' : 'omitted');
    stepStates[3] = LoginStepState.running;
    update();

    try {
      Api.selEhProfile();
    } catch (e) {
      logger.w('selEhProfile ignored error: $e');
    }

    try {
      await asyncGetUserInfo(memberId: memberId, interactive: false);
    } catch (e) {
      logger.w('asyncGetUserInfo non-blocking error: $e');
    }

    stepStates[3] = LoginStepState.done;
    loadingLogin = false;
    lastAuthMethod = method;
    lastVerifiedCf = verifiedCf;

    // 清除密码框内存明文
    passwdController.clear();

    authService.recordAuthSuccess(
      memberId: memberId,
      method: method,
      hasExAccess: hasEx,
      verifiedCf: verifiedCf,
      zh: zh,
    );

    if (closeOnComplete && hasEx) {
      Get.back(result: true);
      return;
    }

    phase = hasEx ? LoginFlowPhase.success : LoginFlowPhase.exDenied;
    update();
  }

  bool _currentUserHasValidIgneous() {
    final ig = userController.user.value.igneous?.trim();
    return ig != null && ig.isNotEmpty && ig != 'mystery';
  }

  Future<void> _syncIgneousFromCookieJar() async {
    try {
      final PersistCookieJar jar = await Api.cookieJar;
      final exCookies =
          await jar.loadForRequest(Uri.parse(EHConst.EX_BASE_URL));
      final rawIg = _getCookiesValue(exCookies, 'igneous')?.trim();
      if (rawIg != null && rawIg.isNotEmpty && rawIg != 'mystery') {
        userController.user(
          userController.user.value.copyWith(igneous: rawIg.oN),
        );
      }
    } catch (e) {
      logger.d('_syncIgneousFromCookieJar error: $e');
    }
  }

  /// 在「表站已登录 · 里站未获权限」卡片上点击「换节点后重试里站」
  Future<void> retryExAccessOnly() async {
    if (loadingLogin) {
      return;
    }
    loadingLogin = true;
    update();

    await authService.probeExitRegion();
    bool hasEx = false;
    try {
      await clearExHentaiCookies();
      await getExIgneous();
      await _syncIgneousFromCookieJar();
      hasEx = _currentUserHasValidIgneous();
    } catch (e) {
      if (isCfBlockedError(e)) {
        final verification = await openCfVerification(acquireExSession: true);
        if (verification != null) {
          await applyCfVerification(verification);
          hasEx = verification.hasValidIgneous || _currentUserHasValidIgneous();
        }
      }
    }

    loadingLogin = false;
    authService.recordExRetryResult(hasExAccess: hasEx);
    if (hasEx) {
      phase = LoginFlowPhase.success;
    }
    update();
  }

  /// 完成登录页闭环返回上一页
  void finishAndClose() {
    Get.back(result: true);
  }

  /// Cookie 登录（支持 ipb_member_id + ipb_pass_hash + 可选 igneous）
  Future<void> pressLoginCookie() async {
    if (loadingLogin) {
      return;
    }

    final memberId = idController.text.trim();
    final passHash = hashController.text.trim();
    final igneousInput = igneousController.text.trim();
    final zh =
        Get.locale?.languageCode.toLowerCase().startsWith('zh') ?? true;

    if (memberId.isEmpty || passHash.isEmpty) {
      showToast(
        zh
            ? '请填写 ipb_member_id 与 ipb_pass_hash'
            : 'ipb_member_id or ipb_pass_hash is empty',
      );
      return;
    }

    loadingLogin = true;
    FocusManager.instance.primaryFocus?.unfocus();
    update();

    final cleanIgneous =
        (igneousInput.isNotEmpty && igneousInput != 'mystery')
            ? igneousInput
            : null;

    final List<Cookie> cookies = <Cookie>[
      Cookie('ipb_member_id', memberId),
      Cookie('ipb_pass_hash', passHash),
      if (cleanIgneous != null) Cookie('igneous', cleanIgneous),
    ];

    final jar = await Api.cookieJar;
    await jar.saveFromResponse(Uri.parse(EHConst.EH_BASE_URL), cookies);
    await jar.saveFromResponse(
        Uri.parse('https://forums.e-hentai.org/'), cookies);
    if (cleanIgneous != null) {
      await jar.saveFromResponse(Uri.parse(EHConst.EX_BASE_URL), cookies);
    }

    final user = userController.user.value.copyWith(
      username: '${memberId.substring(0, 1)}****'.oN,
      memberId: memberId.oN,
      passHash: passHash.oN,
      igneous: cleanIgneous?.oN,
    );

    userController.user(user);

    bool hasEx = cleanIgneous != null;
    if (!hasEx) {
      try {
        await clearExHentaiCookies();
        await getExIgneous();
        await _syncIgneousFromCookieJar();
        hasEx = _currentUserHasValidIgneous();
      } catch (_) {}
    }

    try {
      await asyncGetUserInfo(memberId: memberId, interactive: true);
    } catch (e) {
      logger.w('cookie login asyncGetUserInfo warning: $e');
    }

    loadingLogin = false;
    authService.recordAuthSuccess(
      memberId: memberId,
      method: AuthMethodKind.cookie,
      hasExAccess: hasEx,
      zh: zh,
    );
    update();

    Api.selEhProfile();
    Get.back(result: true);
  }

  /// 应用内网页登录（移动端与桌面端均可用）
  Future<void> handOnWeblogin({bool closeParentOnSuccess = true}) async {
    if (verifyWindowOpen || loadingLogin) {
      return;
    }
    final zh =
        Get.locale?.languageCode.toLowerCase().startsWith('zh') ?? true;
    _cancelled = false;
    inlineError = null;
    verifyWindowOpen = true;
    update();

    final verification = await openCfVerification(
      interactiveWebLogin: true,
      acquireExSession: true,
    );
    verifyWindowOpen = false;

    if (_cancelled) {
      return;
    }
    if (verification == null || !verification.hasLoginSession) {
      update();
      return;
    }

    await applyCfVerification(verification);
    final memberId = verification.value('ipb_member_id')!.trim();
    final currentName = userController.user.value.username;
    if (currentName == null || currentName.isEmpty) {
      userController.user(
        userController.user.value.copyWith(
          username: '${memberId.substring(0, 1)}****'.oN,
        ),
      );
    }

    loadingLogin = true;
    lastAuthMethod = AuthMethodKind.web;
    lastVerifiedCf = verification.isComplete;
    phase = LoginFlowPhase.authenticating;
    _resetSteps();
    stepStates[0] = LoginStepState.done;
    stepMetas[0] = verification.isComplete ? 'CF ✓' : null;
    stepStates[1] = LoginStepState.done;
    update();

    await _runExHandshakeAndProfileSync(
      memberId: memberId,
      method: AuthMethodKind.web,
      verifiedCf: verification.isComplete,
      alreadyHasExFromBrowser: verification.hasValidIgneous,
      skipExNetworkBecauseBrowserTried: verification.exVisited,
      zh: zh,
      closeOnComplete: !closeParentOnSuccess,
    );
  }

  /// [interactive] 为 false 时失败只抛出，不弹提示也不引导验证
  Future<void> asyncGetUserInfo({
    String? memberId,
    bool interactive = true,
  }) async {
    memberId ??= userController.user.value.memberId;
    if (memberId == null || memberId.isEmpty) {
      return;
    }
    logger.d('异步获取昵称和头像');
    User? info;
    try {
      info = await getUserInfo(memberId);
    } catch (e) {
      if (!interactive) {
        rethrow;
      }
      if (!isCfBlockedError(e)) {
        showToast('$e');
        rethrow;
      }
      if (!await promptCfVerification()) {
        showToast(L10n.current.cf_verify_required);
        rethrow;
      }
      try {
        info = await getUserInfo(memberId);
      } catch (retryError) {
        showToast(isCfBlockedError(retryError)
            ? L10n.current.cf_verify_still_blocked
            : '$retryError');
        rethrow;
      }
    }

    userController.user(userController.user.value.copyWith(
      nickName: info?.nickName?.oN,
      avatarUrl: info?.avatarUrl?.oN,
    ));
    userController.update();
  }

  /// 检测剪贴板中是否含有可识别的 Cookie 字段，用于 Cookie 页顶部一键填入提示
  Future<void> checkClipboardForCookieHint() async {
    try {
      final clipText =
          (await Clipboard.getData(Clipboard.kTextPlain))?.text ?? '';
      if (clipText.isEmpty) {
        clipboardHasCookieHint = false;
        return;
      }
      final parsed = parseCookieFromText(clipText);
      clipboardHasCookieHint = (parsed['ipb_member_id']?.isNotEmpty ?? false) &&
          (parsed['ipb_pass_hash']?.isNotEmpty ?? false);
      update();
    } catch (_) {
      clipboardHasCookieHint = false;
    }
  }

  static Map<String, String> parseCookieFromText(String rawText) {
    final result = <String, String>{};
    final text = rawText.trim();
    if (text.isEmpty) {
      return result;
    }

    if (text.contains('{')) {
      try {
        final decoded = jsonDecode(text);
        if (decoded is List) {
          for (final item in decoded) {
            if (item is Map) {
              final name = item['name']?.toString() ?? '';
              final val = item['value']?.toString() ?? '';
              if (name.isNotEmpty && val.isNotEmpty) {
                result[name] = val;
              }
            }
          }
          return result;
        }
      } catch (_) {}
    }

    // 先匹配明确的 key=value 对
    final kvReg = RegExp(
      r'(ipb_member_id|ipb_pass_hash|igneous)\s*[=:]\s*([^\s;&,]+)',
      caseSensitive: false,
    );
    for (final m in kvReg.allMatches(text)) {
      final k = m.group(1)!.toLowerCase();
      final v = m.group(2)!.trim();
      result[k] = v;
    }
    if (result.containsKey('ipb_member_id') &&
        result.containsKey('ipb_pass_hash')) {
      return result;
    }

    // 兜底：按空白/分隔符切分识别数字 ID 与 32 位十六进制 hash
    final matchMemberId = RegExp(r'^\d{3,10}$');
    final matchPassHash = RegExp(r'^[\da-fA-F]{32}$');
    final matchIgneous = RegExp(r'^[\da-fA-F]{16,40}$');
    for (final token in text.split(RegExp(r'[\s:;&=,]+'))) {
      if (!result.containsKey('ipb_member_id') &&
          matchMemberId.hasMatch(token)) {
        result['ipb_member_id'] = token;
      } else if (!result.containsKey('ipb_pass_hash') &&
          matchPassHash.hasMatch(token)) {
        result['ipb_pass_hash'] = token.toLowerCase();
      } else if (!result.containsKey('igneous') &&
          token.length != 32 &&
          matchIgneous.hasMatch(token)) {
        result['igneous'] = token.toLowerCase();
      }
    }
    return result;
  }

  Future<void> readCookieFromClipboard() async {
    final String clipText =
        (await Clipboard.getData(Clipboard.kTextPlain))?.text ?? '';
    final parsed = parseCookieFromText(clipText);
    if (parsed['ipb_member_id'] != null) {
      idController.text = parsed['ipb_member_id']!;
    }
    if (parsed['ipb_pass_hash'] != null) {
      hashController.text = parsed['ipb_pass_hash']!;
    }
    if (parsed['igneous'] != null && parsed['igneous'] != 'mystery') {
      igneousController.text = parsed['igneous']!;
    }
    update();
  }

  String? _getCookiesValue(List<Cookie> cookies, String name) {
    return cookies.firstWhereOrNull((e) => e.name == name)?.value;
  }

  Future<void> hanOnCookieLogin() async {
    await checkClipboardForCookieHint();
    final result = await Get.to<bool>(() => const LoginCookie());
    if (result == true) {
      Api.selEhProfile();
      Get.back(result: true);
    }
  }
}
