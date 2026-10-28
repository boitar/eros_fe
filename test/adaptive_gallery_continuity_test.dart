import 'package:eros_fe/adaptive/adaptive_environment.dart';
import 'package:eros_fe/adaptive/gallery_anchor.dart';
import 'package:eros_fe/common/controller/block_controller.dart';
import 'package:eros_fe/common/service/ehsetting_service.dart';
import 'package:eros_fe/common/service/layout_service.dart';
import 'package:eros_fe/common/service/theme_service.dart';
import 'package:eros_fe/const/const.dart';
import 'package:eros_fe/generated/l10n.dart';
import 'package:eros_fe/pages/item/gallery_item.dart';
import 'package:eros_fe/pages/tab/view/list/grid.dart';
import 'package:eros_fe/pages/tab/view/list/tab_base.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:logger/logger.dart';

import 'support/grid_tags_fixture.dart';

void main() {
  testWidgets('production list/tag grid keeps a gallery across 20 size cycles',
      (tester) async {
    Logger.level = Level.off;
    Get.testMode = true;
    final settings = Get.put<EhSettingService>(_Settings());
    settings.listMode.value = ListModeEnum.list;
    (settings as _Settings).tagLimit.value = 8;
    Get.put<ThemeService>(GridTagsFixtureTheme());
    Get.put<LayoutServices>(GridTagsFixtureLayout());
    Get.put<BlockController>(_Blocks());
    registerGridMasterDependencies();
    addTearDown(Get.reset);
    final galleries = gridTagsFixtureGalleries(count: 100);
    final scroll = ScrollController();
    final anchor = GalleryAnchorController();
    addTearDown(scroll.dispose);
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(390, 700);
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(GetCupertinoApp(
      locale: const Locale('zh', 'CN'),
      supportedLocales: L10n.delegate.supportedLocales,
      localizationsDelegates: const [
        L10n.delegate,
        GlobalCupertinoLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalMaterialLocalizations.delegate,
      ],
      home: Builder(builder: (context) {
        return AdaptiveEnvironmentScope(
          snapshot:
              AdaptiveEnvironmentSnapshot(size: MediaQuery.sizeOf(context)),
          child: CustomScrollView(
            controller: scroll,
            slivers: [
              const SliverToBoxAdapter(child: SizedBox(height: 90)),
              getGallerySliverList(galleries, 'anchor-production',
                  anchorController: anchor),
            ],
          ),
        );
      }),
    ));
    await tester.pumpAndSettle();
    scroll.jumpTo(1650);
    await tester.pumpAndSettle();
    final before = anchor.anchor!;
    expect(before.index, greaterThan(5));
    for (var cycle = 0; cycle < 20; cycle++) {
      for (final size in [
        const Size(700, 1100),
        const Size(390, 700),
      ]) {
        tester.view.physicalSize = size;
        await tester.pumpAndSettle();
        final after = anchor.anchor!;
        expect(after.id, before.id, reason: 'cycle=$cycle size=$size');
        expect(after.leading / after.extent,
            closeTo(before.leading / before.extent, 0.01));
        expect(settings.listMode.value, ListModeEnum.list);
        if (size.width >= 600) {
          expect(tester.widget<EhGridView>(find.byType(EhGridView)).mode,
              ListModeEnum.gridTags);
        } else {
          final card = find.byWidgetPredicate(
              (widget) =>
                  widget is GalleryItemWidget &&
                  widget.galleryProvider.gid == before.id,
              skipOffstage: false);
          expect(tester.getRect(card).bottom, greaterThan(0));
          expect(tester.getRect(card).top, lessThan(size.height));
        }
        expect(tester.takeException(), isNull);
      }
    }
    await tester.pumpWidget(const SizedBox.shrink());
  });
}

class _Settings extends GridTagsFixtureSettings {
  final _fixed = true.obs;
  final _blur = false.obs;
  @override
  bool get fixedHeightOfListItems => _fixed.value;
  @override
  bool get blurringOfCoverBackground => _blur.value;
}

class _Blocks extends BlockController {
  @override
  // No persisted account or blocking rules in this isolated host fixture.
  // ignore: must_call_super
  void onInit() {}
}
