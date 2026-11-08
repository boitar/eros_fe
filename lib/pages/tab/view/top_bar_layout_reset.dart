import 'package:eros_fe/common/service/ehsetting_service.dart';
import 'package:flutter/widgets.dart';
import 'package:get/get.dart';

/// Starts a glass list page over after the top bar layout setting changes.
///
/// The new layout changes the header height. Offsets measured against the
/// old height leave the outer header and the inner list out of step, and
/// while the tab sits offstage the nested scroll view cannot tell which inner
/// list is the visible one. So the reset waits until the tab is shown again.
mixin TopBarLayoutReset<T extends StatefulWidget> on State<T> {
  Worker? _topBarLayoutWorker;
  bool _topBarResetPending = false;
  bool _topBarTabVisible = true;

  /// Returns the page to its initial anchor without animation. Pages also
  /// forget their remembered gallery so a layout change cannot restore it.
  void resetForTopBarLayout();

  @override
  void initState() {
    super.initState();
    _topBarLayoutWorker = ever(
      Get.find<EhSettingService>().liquidGlassTopBarLayoutRx,
      (_) {
        _topBarResetPending = true;
        _scheduleTopBarReset();
      },
    );
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // Offstage tabs run with tickers disabled; this also rebuilds the
    // dependency when the tab comes back.
    _topBarTabVisible = TickerMode.valuesOf(context).enabled;
    _scheduleTopBarReset();
  }

  @override
  void dispose() {
    _topBarLayoutWorker?.dispose();
    super.dispose();
  }

  void _scheduleTopBarReset() {
    if (!_topBarResetPending || !_topBarTabVisible) {
      return;
    }
    _topBarResetPending = false;
    // After the frame that lays the page out with the new header height.
    WidgetsBinding.instance
      ..addPostFrameCallback((_) {
        if (mounted) {
          resetForTopBarLayout();
        }
      })
      ..ensureVisualUpdate();
  }
}
