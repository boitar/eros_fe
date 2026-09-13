import 'dart:async';
import 'package:eros_fe/common/controller/favorite_state_store.dart';
import 'package:eros_fe/models/gallery_provider.dart';
import 'package:eros_fe/pages/item/controller/galleryitem_controller.dart';
import 'package:eros_fe/pages/item/favorite_icon.dart';
import 'package:eros_fe/const/theme_colors.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:get/get.dart';

void main() {
  late FavoriteStateStore store;
  setUp(() {
    store = FavoriteStateStore()..setAccount('test-account');
  });

  test('old response cannot cancel a confirmed favorite or change its color',
      () {
    final stamp = store.version;
    store.commit('42', '7', 'blue');
    store.acceptRead(
        const GalleryProvider(gid: '42', favcat: ''), stamp, store.epoch,
        authoritative: true);
    store.acceptRead(
        const GalleryProvider(gid: '42', favcat: '1'), stamp, store.epoch);
    expect(store['42']!.category, '7');
    final fresh = store.version;
    store.acceptRead(
        const GalleryProvider(gid: '42', favcat: ''), fresh, store.epoch,
        authoritative: true);
    expect(store['42']!.category, '');
  });

  test('unknown detail and missing toplist badge preserve confirmed state', () {
    store.commit('42', '8', 'purple');
    store.acceptRead(
        const GalleryProvider(gid: '42'), store.version, store.epoch,
        authoritative: true);
    store.acceptRead(const GalleryProvider(gid: '42', favcat: ''),
        store.version, store.epoch);
    expect(store['42']!.category, '8');
  });

  test('old immutable detail/cache snapshots overlay the latest mutation', () {
    const original = GalleryProvider(
        gid: '42', favcat: '', englishTitle: 'kept', filecount: '37');
    store.commit('42', '9', 'pink');
    final updated = store.overlay(original);
    expect(updated.favcat, '9');
    expect(updated.englishTitle, 'kept');
    expect(updated.filecount, '37');
    expect(original.favcat, '');
    store.commit('42', '', '');
    expect(store.overlay(updated).favcat, '');
  });

  test('account switch rejects outstanding responses', () {
    final epoch = store.epoch;
    final stamp = store.version;
    store.commit('42', '3', 'yellow');
    store.setAccount('another-account');
    store.acceptRead(
        const GalleryProvider(gid: '42', favcat: '3'), stamp, epoch);
    expect(store['42'], isNull);
  });

  test(
      'same gallery cannot submit twice, and failed operations release the lock',
      () async {
    final release = Completer<void>();
    final first = store.mutate('42', () => release.future);
    expect(store.isBusy('42'), isTrue);
    await expectLater(store.mutate('42', () async {}), throwsStateError);
    release.complete();
    await first;
    await expectLater(
        store.mutate('42', () async {
          throw StateError('failure');
        }),
        throwsStateError);
    expect(store.isBusy('42'), isFalse);
  });

  testWidgets(
      'all colors survive card recreation; cancellation removes the heart',
      (tester) async {
    favoriteStates.setAccount('widget-account');
    const initial = GalleryProvider(gid: '42', favcat: '', favTitle: '');
    var controller = GalleryItemController(galleryProvider: initial)..onInit();
    Widget card() => Directionality(
        textDirection: TextDirection.ltr,
        child: Obx(() => FavoriteIcon(category: controller.favCat)));
    await tester.pumpWidget(card());
    expect(find.byType(FaIcon), findsNothing);
    for (var category = 0; category < 10; category++) {
      favoriteStates.commit('42', '$category', 'custom $category');
      await tester.pump();
      expect(tester.widget<FaIcon>(find.byType(FaIcon)).color,
          ThemeColors.favColor['$category']);
      expect(controller.galleryProvider.favcat, '$category');
      // Re-entering/rebuilding with the original pre-favorite provider.
      controller = GalleryItemController(galleryProvider: initial)..onInit();
      await tester.pumpWidget(card());
      expect(tester.widget<FaIcon>(find.byType(FaIcon)).color,
          ThemeColors.favColor['$category']);
    }
    favoriteStates.commit('42', '', '');
    await tester.pump();
    expect(find.byType(FaIcon), findsNothing);
    favoriteStates.commit('42', '1', 'red');
    await tester.pump();
    favoriteStates.setAccount('signed-out');
    await tester.pump();
    expect(find.byType(FaIcon), findsNothing);
  });
}
