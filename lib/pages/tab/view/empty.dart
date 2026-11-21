import 'package:eros_fe/adaptive/browse_layout.dart';
import 'package:eros_fe/common/service/theme_service.dart';
import 'package:eros_fe/utils/logger.dart';
import 'package:eros_fe/widget/desktop_sidebar.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:get/get.dart';

class EmptyPage extends StatelessWidget {
  const EmptyPage({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    // Sharing one column, the list shows through while a page slides over it.
    final pane = context.dependOnInheritedWidgetOfExactType<BrowsePaneScope>();
    if (pane != null && !pane.split) {
      return const SizedBox.expand();
    }
    final desktop = DesktopSidebarScope.maybeOf(context)?.desktop == true;
    logger.t('isDarkMode ${ehTheme.isDarkMode}');
    return Obx(() {
      final palette = ehTheme.palette;
      final isZh = Localizations.localeOf(context).languageCode == 'zh';
      return AnnotatedRegion<SystemUiOverlayStyle>(
        value: ehTheme.isDarkMode
            ? SystemUiOverlayStyle.light.copyWith(
                statusBarColor: Colors.transparent,
                systemNavigationBarColor: Colors.transparent,
                systemNavigationBarDividerColor: Colors.transparent,
              )
            : SystemUiOverlayStyle.dark.copyWith(
                statusBarColor: Colors.transparent,
                systemNavigationBarColor: Colors.transparent,
                systemNavigationBarDividerColor: Colors.transparent,
              ),
        child: CupertinoPageScaffold(
          backgroundColor: desktop
              ? CupertinoTheme.of(context).scaffoldBackgroundColor
              : (!ehTheme.isDarkMode
                    ? CupertinoColors.secondarySystemBackground
                    : null),
          child: SafeArea(
            child: Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: desktop
                    ? Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Container(
                            width: 52,
                            height: 52,
                            alignment: Alignment.center,
                            decoration: BoxDecoration(
                              color: palette.fill.resolveFrom(context),
                              borderRadius: BorderRadius.circular(14),
                            ),
                            child: ExcludeSemantics(
                              child: FaIcon(
                                FontAwesomeIcons.layerGroup,
                                size: 22,
                                color: palette.text3.resolveFrom(context),
                              ),
                            ),
                          ),
                          const SizedBox(height: 14),
                          Text(
                            isZh
                                ? '选择画廊以查看详情'
                                : 'Select a gallery to view its details',
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w500,
                              color: palette.text2.resolveFrom(context),
                            ),
                          ),
                          const SizedBox(height: 6),
                          Text(
                            isZh
                                ? '点击中间列表中的条目即可在此预览'
                                : 'Click an item in the list to preview it here',
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              fontSize: 12,
                              color: palette.text3.resolveFrom(context),
                            ),
                          ),
                        ],
                      )
                    : Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const ExcludeSemantics(
                            child: FaIcon(
                              FontAwesomeIcons.layerGroup,
                              size: 100,
                              color: CupertinoColors.inactiveGray,
                            ),
                          ),
                          const SizedBox(height: 20),
                          Text(
                            isZh
                                ? '选择画廊以查看详情'
                                : 'Select a gallery to view its details',
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              color: CupertinoDynamicColor.resolve(
                                CupertinoColors.secondaryLabel,
                                context,
                              ),
                            ),
                          ),
                        ],
                      ),
              ),
            ),
          ),
        ),
      );
    });
  }
}
