import 'package:eros_fe/utils/vibrate.dart';
import 'package:flutter/cupertino.dart';

const double kDefaultRefreshTriggerPullDistance = 100.0;

/// 相邻两次下拉 tick 之间的拉距（逻辑像素）。拉弓式渐进：每跨过这个间隔震一次，
/// 强度随拉距增加，越过触发线的 armed 震交给系统 CupertinoSliverRefreshControl。
const double kRefreshHapticTickSpacing = 12.0;

/// 下拉刷新渐进 tick 的状态机。
///
/// 输入是 [CupertinoSliverRefreshControl.builder] 每帧给出的刷新状态与拉距，
/// 输出是 tick 回调。原则（跟手不傻震）：
/// - 距离驱动：每跨过 [tickSpacing] 才可能震一次，回撤静默；
/// - 只在拖动中（drag 模式）渐进，armed 震由系统 mediumImpact 承担，不叠加；
/// - 大幅回撤（较本轮峰值回退超过 [_resetRetreatDistance]）后的回升视为
///   新一轮，从轻开始重新渐进。
class RefreshHapticScheduler {
  RefreshHapticScheduler({
    this.tickSpacing = kRefreshHapticTickSpacing,
    this.onTick,
    this.onNewSession,
  });

  final double tickSpacing;
  final void Function(double progress)? onTick;

  /// 检测到新一轮下拉（大幅回撤后的首次回升）时触发一次。用于在下拉的
  /// 慢速起步段预热 Core Haptics 引擎，让第一记 tick 不承担冷启动延迟。
  final void Function()? onNewSession;

  /// 从 0 起（而非 -1）：0 档对应 0~12px，不触发，首个 tick 落在 12px。
  int _maxTickIndex = 0;

  /// 本轮交互（含回弹）见过的最大拉距。
  double _sessionMax = 0;
  double _lastPulledExtent = 0;

  /// 初始即为 true：首轮下拉同样按"新会话"预热引擎。
  bool _pendingReset = true;

  /// 较本轮峰值回撤超过该值视为本轮已放弃；小幅抖动不重置。
  static const double _resetRetreatDistance = 24.0;

  @visibleForTesting
  void reset() {
    _sessionMax = 0;
    _lastPulledExtent = 0;
    _maxTickIndex = 0;
    _pendingReset = true;
  }

  void update(
    RefreshIndicatorMode mode,
    double pulledExtent,
    double triggerDistance,
  ) {
    if (pulledExtent > _sessionMax) {
      _sessionMax = pulledExtent;
    } else if (pulledExtent < _sessionMax - _resetRetreatDistance) {
      // 平滑回弹每帧只回落几个像素，"本轮已放弃"只能通过较峰值的大幅
      // 回退来识别：松手回弹、刷新完成回弹都会走到这里。
      _pendingReset = true;
    }

    if (_pendingReset && pulledExtent > _lastPulledExtent) {
      // 回撤后拉距重新回升 = 新一轮下拉，从轻开始。
      _pendingReset = false;
      _sessionMax = pulledExtent;
      _maxTickIndex = 0;
      onNewSession?.call();
    }

    // 松手后的回弹动画里拉距持续回落，绝不能触发 tick；只有比上一帧
    // 更深（或持平）才允许计为"拉深"。
    final bool pullingDeeper = pulledExtent >= _lastPulledExtent - 0.5;

    if (mode == RefreshIndicatorMode.drag &&
        pullingDeeper &&
        triggerDistance > 0) {
      final int tickIndex = (pulledExtent / tickSpacing).floor();
      if (tickIndex > _maxTickIndex) {
        _maxTickIndex = tickIndex;
        onTick?.call(pulledExtent / triggerDistance);
      }
    }

    _lastPulledExtent = pulledExtent;
  }
}

class EhCupertinoSliverRefreshControl extends StatefulWidget {
  const EhCupertinoSliverRefreshControl({super.key, this.onRefresh});

  final RefreshCallback? onRefresh;

  @override
  State<EhCupertinoSliverRefreshControl> createState() =>
      _EhCupertinoSliverRefreshControlState();
}

class _EhCupertinoSliverRefreshControlState
    extends State<EhCupertinoSliverRefreshControl> {
  final RefreshHapticScheduler _hapticScheduler = RefreshHapticScheduler(
    onTick: (progress) => vibrateUtil.pullTick(progress),
    // 新一轮下拉的起步段（拉距几像素、手指最慢）先预热引擎。
    onNewSession: () => vibrateUtil.prepareHaptics(),
  );

  /// onRefresh 完成后给结果反馈：成功 success、失败 error。
  /// 异常 rethrow 保持 CupertinoSliverRefreshControl 原有的复位语义。
  Future<void> _handleRefresh() async {
    try {
      await widget.onRefresh?.call();
      await vibrateUtil.success();
    } catch (e) {
      await vibrateUtil.error();
      rethrow;
    }
  }

  Widget _hapticIndicator(
    BuildContext context,
    RefreshIndicatorMode mode,
    double pulledExtent,
    double refreshTriggerPullDistance,
    double refreshIndicatorExtent,
  ) {
    _hapticScheduler.update(mode, pulledExtent, refreshTriggerPullDistance);
    return CupertinoSliverRefreshControl.buildRefreshIndicator(
      context,
      mode,
      pulledExtent,
      refreshTriggerPullDistance,
      refreshIndicatorExtent,
    );
  }

  @override
  Widget build(BuildContext context) {
    return CupertinoSliverRefreshControl(
      onRefresh: widget.onRefresh == null ? null : _handleRefresh,
      refreshTriggerPullDistance: kDefaultRefreshTriggerPullDistance,
      // refreshIndicatorExtent: 100,
      builder: _hapticIndicator,
    );
  }
}
