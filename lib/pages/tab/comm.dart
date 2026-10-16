import 'package:flutter/cupertino.dart';

class EhTabController extends ChangeNotifier {
  EhTabController();

  bool _disposed = false;

  bool get hasScrollClients =>
      !_disposed && (hasScrollClientsCall?.call() ?? true);

  bool get canScrollToTop => scrollToTopCall != null && hasScrollClients;

  void scrollToTop() {
    if (canScrollToTop) {
      scrollToTopCall?.call();
    }
  }

  void scrollToTopRefresh() {
    if (hasScrollClients) {
      scrollToTopRefreshCall?.call();
    }
  }

  Future<void> scrollToTopAndRefresh() async {
    if (hasScrollClients) {
      await scrollToTopAndRefreshCall?.call();
    }
  }

  @override
  void dispose() {
    _disposed = true;
    super.dispose();
  }

  bool Function()? hasScrollClientsCall;

  // 目标state注册这个方法
  Function? scrollToTopCall;

  Function? scrollToTopRefreshCall;

  Future<void> Function()? scrollToTopAndRefreshCall;
}
