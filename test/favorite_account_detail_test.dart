import 'package:eros_fe/common/controller/cache_controller.dart';
import 'package:eros_fe/common/controller/favorite_state_store.dart';
import 'package:eros_fe/common/service/controller_tag_service.dart';
import 'package:eros_fe/common/service/ehsetting_service.dart';
import 'package:eros_fe/generated/l10n.dart';
import 'package:eros_fe/models/gallery_provider.dart';
import 'package:eros_fe/pages/controller/fav_controller.dart';
import 'package:eros_fe/pages/gallery/controller/gallery_fav_controller.dart';
import 'package:eros_fe/pages/gallery/controller/gallery_page_controller.dart';
import 'package:eros_fe/pages/gallery/controller/gallery_page_state.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';

class _Settings extends GetxService implements EhSettingService {
  @override
  dynamic noSuchMethod(Invocation invocation) =>
      throw StateError('Unexpected setting: ${invocation.memberName}');
}

class _Cache extends GetxController implements CacheController {
  @override
  dynamic noSuchMethod(Invocation invocation) =>
      throw StateError('Unexpected cache access: ${invocation.memberName}');
}

class _Page extends GetxController implements GalleryPageController {
  _Page(this.gState);
  @override
  final GalleryPageState gState;
  @override
  dynamic noSuchMethod(Invocation invocation) =>
      throw StateError('Unexpected page access: ${invocation.memberName}');
}

void main() {
  tearDown(Get.reset);
  Future<(GalleryPageState, GalleryFavController)> mount(
      WidgetTester tester) async {
    Get.testMode = true;
    favoriteStates.setAccount('detail-account-a');
    Get.put<EhSettingService>(_Settings());
    Get.put<CacheController>(_Cache());
    Get.put<FavController>(FavController());
    Get.put<ControllerTagService>(
        ControllerTagService()..pushPageCtrl(gid: '42'));
    await tester.pumpWidget(const GetCupertinoApp(
      locale: Locale('en'),
      localizationsDelegates: [L10n.delegate],
      home: CupertinoPageScaffold(child: Text('Neutral fixture')),
    ));
    await tester.pumpAndSettle();
    final state = GalleryPageState()
      ..galleryProvider = const GalleryProvider(
          gid: '42',
          favcat: '8',
          favTitle: 'Account A private folder',
          englishTitle: 'Public gallery metadata',
          filecount: '20');
    Get.put<GalleryPageController>(_Page(state), tag: '42');
    final controller = Get.put<GalleryFavController>(GalleryFavController());
    expect(controller.favcat, '8');
    return (state, controller);
  }

  testWidgets('an open detail snapshot cannot leak another account favorite',
      (tester) async {
    final (state, _) = await mount(tester);
    favoriteStates.setAccount('detail-account-b');
    expect(state.galleryProvider!.favcat, isEmpty);
    expect(state.galleryProvider!.favTitle, isEmpty);
    expect(state.galleryProvider!.englishTitle, 'Public gallery metadata');
    expect(state.galleryProvider!.filecount, '20');
  });

  testWidgets(
      'an already mounted detail control drops cached account favorite fields',
      (tester) async {
    final (_, controller) = await mount(tester);
    favoriteStates.setAccount('detail-account-b');
    expect(controller.favcat, isEmpty);
    expect(controller.favTitle, isEmpty);
  });

  testWidgets(
      'the current account confirmed state overlays an older open detail',
      (tester) async {
    final (state, controller) = await mount(tester);
    favoriteStates.setAccount('detail-account-b');
    favoriteStates.commit('42', '3', 'Account B folder');
    expect(state.galleryProvider!.favcat, '3');
    expect(controller.favcat, '3');
    expect(controller.favTitle, 'Account B folder');
  });

  testWidgets('a fresh detail assignment updates an existing favorite control',
      (tester) async {
    final (state, controller) = await mount(tester);
    favoriteStates.setAccount('detail-account-b');
    state.galleryProvider = const GalleryProvider(
        gid: '42', favcat: '2', favTitle: 'Fresh account B folder');
    expect(controller.favcat, '2');
    expect(controller.favTitle, 'Fresh account B folder');
  });

  testWidgets(
      'local favorites keep their label across a network account switch',
      (tester) async {
    final (state, controller) = await mount(tester);
    state.galleryProvider = const GalleryProvider(
        gid: '42', favcat: '', favTitle: '', localFav: true);
    favoriteStates.setAccount('detail-account-b');
    favoriteStates.commit('42', '', '');
    expect(controller.favcat, 'l');
    expect(controller.favTitle, L10n.current.local_favorite);
  });
}
