import 'package:eros_fe/widget/refresh.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('RefreshHapticScheduler 下拉刷新渐进 tick 状态机', () {
    test('每跨过 12px 触发一次，进度严格递增，首个 tick 在 12px', () {
      final progressList = <double>[];
      final scheduler = RefreshHapticScheduler(onTick: progressList.add);

      for (double pulled = 0.0; pulled <= 100.0; pulled += 4.0) {
        scheduler.update(RefreshIndicatorMode.drag, pulled, 100.0);
      }

      // tick 落点：12, 24, 36, 48, 60, 72, 84, 96 → 共 8 次
      expect(progressList.length, 8);
      expect(progressList.first, closeTo(12 / 100, 1e-9));
      expect(progressList.last, closeTo(96 / 100, 1e-9));
      for (var i = 1; i < progressList.length; i++) {
        expect(progressList[i], greaterThan(progressList[i - 1]));
      }
    });

    test('峰值 24px 以内的抖动不重置、不重复震', () {
      final progressList = <double>[];
      final scheduler = RefreshHapticScheduler(onTick: progressList.add);

      scheduler.update(RefreshIndicatorMode.drag, 50.0, 100.0);
      expect(progressList.length, 1);

      // 峰值 50 以内的回撤与再推进（未跌破 50-24=26）→ 不重置
      scheduler.update(RefreshIndicatorMode.drag, 45.0, 100.0);
      scheduler.update(RefreshIndicatorMode.drag, 55.0, 100.0);
      // tickIndex 4 == 既有最高档 → 不重复震
      expect(progressList.length, 1);
    });

    test('松手回弹（拉距大幅回落）整个过程不触发 tick', () {
      final progressList = <double>[];
      final scheduler = RefreshHapticScheduler(onTick: progressList.add);

      // 拉到 90
      for (double pulled = 0.0; pulled <= 90.0; pulled += 6.0) {
        scheduler.update(RefreshIndicatorMode.drag, pulled, 100.0);
      }
      final countAfterPull = progressList.length;
      expect(countAfterPull, 7);

      // 松手回弹动画：extent 从 90 递减到 0（期间 builder 仍会收到调用）
      for (double pulled = 84.0; pulled >= 0.0; pulled -= 6.0) {
        scheduler.update(RefreshIndicatorMode.drag, pulled, 100.0);
      }
      expect(progressList.length, countAfterPull);
    });

    test('大幅回撤（较峰值 > 24px）后的回升视为新一轮，重新从轻渐进', () {
      final progressList = <double>[];
      final scheduler = RefreshHapticScheduler(onTick: progressList.add);

      scheduler.update(RefreshIndicatorMode.drag, 60.0, 100.0);
      expect(progressList.length, 1);

      // 单帧拉到 20：较峰值 60 回撤 40px → 标记本轮放弃
      scheduler.update(RefreshIndicatorMode.drag, 20.0, 100.0);
      // 回升第一帧：重置并重新渐进
      scheduler.update(RefreshIndicatorMode.drag, 24.0, 100.0);
      expect(progressList.length, 2);
      expect(progressList.last, closeTo(24 / 100, 1e-9));
    });

    test('armed / refresh / done 模式不 tick（armed 震由系统 mediumImpact 承担）', () {
      final progressList = <double>[];
      final scheduler = RefreshHapticScheduler(onTick: progressList.add);

      scheduler.update(RefreshIndicatorMode.armed, 110.0, 100.0);
      scheduler.update(RefreshIndicatorMode.refresh, 105.0, 100.0);
      scheduler.update(RefreshIndicatorMode.done, 100.0, 100.0);
      expect(progressList, isEmpty);
    });

    test('刷新结束后再次下拉：重新从轻开始', () {
      final progressList = <double>[];
      final scheduler = RefreshHapticScheduler(onTick: progressList.add);

      for (double pulled = 0.0; pulled <= 90.0; pulled += 6.0) {
        scheduler.update(RefreshIndicatorMode.drag, pulled, 100.0);
      }
      final firstRoundCount = progressList.length;

      // 刷新完成，回弹归零（回撤过程 builder 收到 done/drag 调用）
      scheduler.update(RefreshIndicatorMode.done, 60.0, 100.0);
      for (double pulled = 30.0; pulled >= 0.0; pulled -= 10.0) {
        scheduler.update(RefreshIndicatorMode.drag, pulled, 100.0);
      }

      // 再次下拉
      scheduler.update(RefreshIndicatorMode.drag, 12.0, 100.0);
      scheduler.update(RefreshIndicatorMode.drag, 25.0, 100.0);

      // 新一轮：12px 与 24px 两个 tick 又从轻开始
      expect(progressList.length, firstRoundCount + 2);
      expect(progressList[firstRoundCount], closeTo(12 / 100, 1e-9));
      expect(progressList.last, closeTo(25 / 100, 1e-9));
    });

    test('回归：拉到 30px 未触发就松手，下次下拉第一记 tick 应回到 12px 档', () {
      final progressList = <double>[];
      final scheduler = RefreshHapticScheduler(onTick: progressList.add);

      // 第一轮：拉到 30px（tick 在 12、24）
      for (double pulled = 0.0; pulled <= 30.0; pulled += 3.0) {
        scheduler.update(RefreshIndicatorMode.drag, pulled, 100.0);
      }
      expect(progressList.length, 2);
      expect(progressList[0], closeTo(0.12, 1e-9));
      expect(progressList[1], closeTo(0.24, 1e-9));

      // 松手回弹：平滑逐帧回落（单帧跌幅 < 24px，旧实现在此永远不重置）
      for (double pulled = 27.0; pulled >= 3.0; pulled -= 3.0) {
        scheduler.update(RefreshIndicatorMode.drag, pulled, 100.0);
      }
      expect(progressList.length, 2);

      // 再次下拉：第一记 tick 必须落回 12px 档（旧实现会沉默到 36px+）
      scheduler.update(RefreshIndicatorMode.drag, 6.0, 100.0);
      scheduler.update(RefreshIndicatorMode.drag, 14.0, 100.0);
      scheduler.update(RefreshIndicatorMode.drag, 26.0, 100.0);
      expect(progressList.length, 4);
      expect(progressList[2], closeTo(0.14, 1e-9));
      expect(progressList[3], closeTo(0.26, 1e-9));
    });

    test('回归：拉到 90px 松手后，下次下拉同样从 12px 档恢复', () {
      final progressList = <double>[];
      final scheduler = RefreshHapticScheduler(onTick: progressList.add);

      for (double pulled = 0.0; pulled <= 90.0; pulled += 6.0) {
        scheduler.update(RefreshIndicatorMode.drag, pulled, 100.0);
      }
      expect(progressList.length, 7);

      for (double pulled = 84.0; pulled >= 0.0; pulled -= 12.0) {
        scheduler.update(RefreshIndicatorMode.drag, pulled, 100.0);
      }

      scheduler.update(RefreshIndicatorMode.drag, 6.0, 100.0);
      scheduler.update(RefreshIndicatorMode.drag, 14.0, 100.0);
      scheduler.update(RefreshIndicatorMode.drag, 26.0, 100.0);
      // 旧实现：沉默到 96px；新实现：14px（12px 档）即恢复
      expect(progressList.length, 9);
      expect(progressList[7], closeTo(0.14, 1e-9));
    });

    test('回弹中途在峰值 24px 内重新抓住：视为同一轮，不重复震', () {
      final progressList = <double>[];
      final scheduler = RefreshHapticScheduler(onTick: progressList.add);

      for (double pulled = 0.0; pulled <= 30.0; pulled += 3.0) {
        scheduler.update(RefreshIndicatorMode.drag, pulled, 100.0);
      }
      expect(progressList.length, 2);

      // 回弹到 21（未跌破 30-24=6）被手指接住
      scheduler.update(RefreshIndicatorMode.drag, 27.0, 100.0);
      scheduler.update(RefreshIndicatorMode.drag, 24.0, 100.0);
      scheduler.update(RefreshIndicatorMode.drag, 21.0, 100.0);
      // 重新拉深：26px 处 tickIndex 2 == 既有最高档 → 不重复
      scheduler.update(RefreshIndicatorMode.drag, 26.0, 100.0);
      expect(progressList.length, 2);
      // 越过旧档位才继续
      scheduler.update(RefreshIndicatorMode.drag, 38.0, 100.0);
      expect(progressList.length, 3);
      expect(progressList.last, closeTo(0.38, 1e-9));
    });

    test('onNewSession：首轮下拉与每次大幅回撤后的新轮回合各触发一次', () {
      var sessionCount = 0;
      final progressList = <double>[];
      final scheduler = RefreshHapticScheduler(
        onTick: progressList.add,
        onNewSession: () => sessionCount++,
      );

      // 首轮下拉：起步帧触发一次
      for (double pulled = 0.0; pulled <= 40.0; pulled += 4.0) {
        scheduler.update(RefreshIndicatorMode.drag, pulled, 100.0);
      }
      expect(sessionCount, 1);
      expect(progressList.length, 3); // 12/24/36

      // 回弹到 0
      for (double pulled = 36.0; pulled >= 0.0; pulled -= 4.0) {
        scheduler.update(RefreshIndicatorMode.drag, pulled, 100.0);
      }
      expect(sessionCount, 1);

      // 新一轮下拉：回升第一帧再触发一次
      scheduler.update(RefreshIndicatorMode.drag, 8.0, 100.0);
      scheduler.update(RefreshIndicatorMode.drag, 16.0, 100.0);
      scheduler.update(RefreshIndicatorMode.drag, 24.0, 100.0);
      expect(sessionCount, 2);
      // 新一轮从 12px 档恢复
      expect(progressList.length, 5); // 12/24/36 + 16(≈12px 档) + 24
      expect(progressList[3], closeTo(0.16, 1e-9));
      expect(progressList.last, closeTo(0.24, 1e-9));
    });
  });
}
