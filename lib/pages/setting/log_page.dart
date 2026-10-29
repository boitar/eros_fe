import 'package:eros_fe/common/controller/log_controller.dart';
import 'package:eros_fe/common/service/layout_service.dart';
import 'package:eros_fe/component/setting/setting_scaffold.dart';
import 'package:eros_fe/index.dart';
import 'package:eros_fe/pages/setting/log_view_page.dart';
import 'package:flutter/cupertino.dart';
import 'package:get/get.dart';
import 'package:path/path.dart' as path;

class LogPage extends GetView<LogService> {
  const LogPage({super.key});

  @override
  Widget build(BuildContext context) {
    return SettingScaffold(
      title: 'Log',
      actions: [
        NativeNavigationAction(
          id: 'log.clear',
          title: L10n.of(context).clear_filter,
          symbol: 'trash',
          onPressed: controller.removeAll,
        ),
      ],
      trailing: CupertinoButton(
        padding: const EdgeInsets.all(0),
        minSize: 40,
        onPressed: controller.removeAll,
        child: const Icon(
          CupertinoIcons.trash,
          size: 24,
        ),
      ),
      child: CustomScrollView(
        slivers: [
          SliverSafeArea(
            bottom: false,
            sliver: CupertinoSliverRefreshControl(
                onRefresh: controller.refreshFiles),
          ),
          const SliverSafeArea(
            top: false,
            sliver: LogListView(),
          ),
        ],
      ),
    );
  }
}

class LogListView extends GetView<LogService> {
  const LogListView({super.key});

  @override
  Widget build(BuildContext context) {
    return Obx(() {
      if (controller.isLoading) {
        return const SliverFillRemaining(child: CupertinoActivityIndicator());
      }

      final logfiles = controller.logFiles;
      return SliverCupertinoListSection.insetGrouped(
        key: ValueKey(logfiles.length),
        itemCount: logfiles.length,
        itemBuilder: (context, index) {
          final _file = logfiles[index];
          final fileName = path.basename(_file.path);
          return EhCupertinoListTile(
            title: Text(fileName),
            trailing: const CupertinoListTileChevron(),
            onTap: () {
              Get.to(
                () => LogViewPage(
                  title: fileName,
                  index: index,
                ),
                id: detailNavigatorId,
                transition: isLayoutLarge ? Transition.rightToLeft : null,
              );
            },
          );
        },
      );
    });
  }
}
