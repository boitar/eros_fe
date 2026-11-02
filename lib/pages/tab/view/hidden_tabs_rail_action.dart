import 'package:eros_fe/generated/l10n.dart';
import 'package:eros_fe/pages/tab/controller/tabhome_controller.dart';
import 'package:eros_fe/widget/liquid_glass_popup.dart';
import 'package:eros_fe/widget/liquid_glass_rail.dart';
import 'package:flutter/cupertino.dart';
import 'package:get/get.dart';

LiquidGlassRailAction? hiddenTabsRailAction(BuildContext context) {
  final home = Get.find<TabHomeController>();
  final routes = home.hiddenTabRoutes;

  if (!(ModalRoute.of(context)?.isFirst ?? true)) {
    return LiquidGlassRailAction(
      icon: CupertinoIcons.chevron_back,
      label: L10n.of(context).back,
      onPressed: () => Navigator.of(context).maybePop(),
    );
  }
  if (routes.isEmpty) {
    return null;
  }

  final titles = tabPages.titlesOf(context);
  IconData iconFor(String route) =>
      tabPages.iconDatas[route]?.data ?? CupertinoIcons.circle;
  String titleFor(String route) => titles[route] ?? route;

  if (routes.length == 1) {
    final route = routes.single;
    return LiquidGlassRailAction(
      icon: iconFor(route),
      label: titleFor(route),
      onPressed: () => home.openHiddenTab(route),
    );
  }

  return LiquidGlassRailAction(
    icon: CupertinoIcons.ellipsis_circle,
    label: L10n.of(context).more_actions,
    onPressed: () => showCupertinoModalPopup<void>(
      context: context,
      builder: (sheetContext) => EhActionSheet(
        actions: [
          for (final route in routes)
            EhActionSheetAction(
              icon: iconFor(route),
              systemIcon:
                  tabPages.liquidGlassFallbackSymbols[route] ?? 'circle',
              onPressed: () {
                Navigator.of(sheetContext).pop();
                home.openHiddenTab(route);
              },
              child: Text(titleFor(route)),
            ),
        ],
        cancelButton: CupertinoActionSheetAction(
          onPressed: () => Navigator.of(sheetContext).pop(),
          child: Text(L10n.of(context).cancel),
        ),
      ),
    ),
  );
}
