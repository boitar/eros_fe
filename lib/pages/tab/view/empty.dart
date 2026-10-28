import 'package:eros_fe/common/service/theme_service.dart';
import 'package:eros_fe/utils/logger.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:get/get.dart';

class EmptyPage extends StatelessWidget {
  const EmptyPage({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    logger.t('isDarkMode ${ehTheme.isDarkMode}');
    return Obx(() {
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
          backgroundColor: !ehTheme.isDarkMode
              ? CupertinoColors.secondarySystemBackground
              : null,
          child: SafeArea(
            child: Container(
              child: Center(
                child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: Column(
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
                        Localizations.localeOf(context).languageCode == 'zh'
                            ? '选择画廊以查看详情'
                            : 'Select a gallery to view its details',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          color: CupertinoDynamicColor.resolve(
                              CupertinoColors.secondaryLabel, context),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      );
    });
  }
}
