import 'dart:io';

import 'package:eros_fe/common/controller/history_controller.dart';
import 'package:eros_fe/common/controller/localfav_controller.dart';
import 'package:eros_fe/common/controller/mysql_controller.dart';
import 'package:eros_fe/common/controller/tag_controller.dart';
import 'package:eros_fe/common/controller/user_controller.dart';
import 'package:eros_fe/common/controller/webdav_controller.dart';
import 'package:eros_fe/common/service/ehsetting_service.dart';
import 'package:eros_fe/common/service/locale_service.dart';
import 'package:eros_fe/common/service/theme_service.dart';
import 'package:eros_fe/models/gallery_provider.dart';
import 'package:eros_fe/models/simple_tag.dart';
import 'package:eros_fe/pages/controller/fav_controller.dart';
import 'package:eros_fe/pages/controller/favorite_sel_controller.dart';
import 'package:eros_fe/pages/tab/controller/tabhome_controller.dart';
import 'package:eros_fe/pages/tab/view/list/waterfall_flow.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/scheduler.dart';
import 'package:get/get.dart';

/// P1-2 帧预算测量（瀑布流-大，合成数据，真实 macOS 引擎渲染）。
///
/// 运行：
///   flutter run --profile -d macos -t benchmark/frame_benchmark_main.dart
/// 结果行：grep BENCH_RESULT（测完自动 exit(0)）
///
/// 对比对象为两个代码版本在同一 harness 下的输出：
/// - keframe 占位版（165ff971^）：大卡先建占位再建真身（两帧/项）
/// - 真身直布局版（本分支）：首帧即真实比例（一帧/项）
void main() {
  WidgetsFlutterBinding.ensureInitialized();
  _registerFakeGraph();
  runApp(
    GetMaterialApp(
      home: CupertinoPageScaffold(
        child: SafeArea(child: _BenchPage()),
      ),
    ),
  );
}

class _BenchPage extends StatefulWidget {
  @override
  State<_BenchPage> createState() => _BenchPageState();
}

class _BenchPageState extends State<_BenchPage> {
  final ScrollController _controller = ScrollController();
  final List<FrameTiming> _timings = <FrameTiming>[];

  static const int _itemCount = 120;
  static const int _warmupScrolls = 4;
  static const int _maxMeasureScrolls = 40;
  static const double _scrollStep = 700;

  @override
  void initState() {
    super.initState();
    SchedulerBinding.instance.addTimingsCallback(_onTimings);
    WidgetsBinding.instance.addPostFrameCallback((_) => _run());
  }

  void _onTimings(List<FrameTiming> ts) => _timings.addAll(ts);

  Future<void> _run() async {
    try {
      await Future<void>.delayed(const Duration(milliseconds: 600));
      debugPrint('BENCH_STAGE scroll start');

      // 预热：剔除 JIT/着色器/首建噪声
      for (var i = 0; i < _warmupScrolls; i++) {
        await _scrollStepOnce();
      }
      final int warmupFrames = _timings.length;
      _timings.clear();
      debugPrint('BENCH_STAGE warmup done, discarded=$warmupFrames');

      // 测量段：持续滚动触发后续条目首帧构建
      int scrolls = 0;
      while (scrolls < _maxMeasureScrolls &&
          _controller.offset <
              _controller.position.maxScrollExtent - 200) {
        await _scrollStepOnce();
        scrolls++;
      }
      debugPrint('BENCH_STAGE measure done, scrolls=$scrolls');
      _report();
    } catch (e, s) {
      debugPrint('BENCH_ERROR $e\n$s');
      exit(1);
    } finally {
      exit(0);
    }
  }

  Future<void> _scrollStepOnce() async {
    final double target =
        (_controller.offset + _scrollStep)
            .clamp(0.0, _controller.position.maxScrollExtent);
    await _controller.animateTo(
      target,
      duration: const Duration(milliseconds: 260),
      curve: Curves.easeOut,
    );
    await Future<void>.delayed(const Duration(milliseconds: 40));
  }

  void _report() {
    final builds =
        _timings.map((t) => t.buildDuration.inMicroseconds).toList()..sort();
    final rasters =
        _timings.map((t) => t.rasterDuration.inMicroseconds).toList()..sort();
    final totals = _timings
        .map((t) => (t.buildDuration + t.rasterDuration).inMicroseconds)
        .toList()
      ..sort();

    int pct(List<int> xs, double p) => xs.isEmpty
        ? 0
        : xs[((xs.length - 1) * p).round().clamp(0, xs.length - 1)];

    final int jankBuild = builds.where((us) => us > 16667).length;
    final int jankTotal = totals.where((us) => us > 16667).length;

    debugPrint('BENCH_RESULT '
        'frames=${_timings.length} '
        'build_p50_ms=${_ms(pct(builds, 0.50))} '
        'build_p90_ms=${_ms(pct(builds, 0.90))} '
        'build_max_ms=${_ms(builds.isEmpty ? 0 : builds.last)} '
        'raster_p50_ms=${_ms(pct(rasters, 0.50))} '
        'raster_p90_ms=${_ms(pct(rasters, 0.90))} '
        'raster_max_ms=${_ms(rasters.isEmpty ? 0 : rasters.last)} '
        'total_p50_ms=${_ms(pct(totals, 0.50))} '
        'total_p90_ms=${_ms(pct(totals, 0.90))} '
        'total_max_ms=${_ms(totals.isEmpty ? 0 : totals.last)} '
        'jank_build_gt16=$jankBuild '
        'jank_total_gt16=$jankTotal');
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return CustomScrollView(
      controller: _controller,
      slivers: [
        SliverPadding(
          padding: const EdgeInsets.all(8),
          sliver: EhWaterfallFlow(_buildProviders(_itemCount), 'bench',
              large: true),
        ),
      ],
    );
  }
}

String _ms(int microseconds) => (microseconds / 1000).toStringAsFixed(2);

List<GalleryProvider> _buildProviders(int n) => List.generate(n, (i) {
      return GalleryProvider(
        gid: 'bench$i',
        englishTitle: 'Benchmark gallery item $i with a longer title text',
        category: const ['Doujinshi', 'Manga', 'Artist CG'][i % 3],
        uploader: 'uploader$i',
        imgWidth: 200 + (i % 5) * 25,
        imgHeight: 280 + (i % 7) * 20,
        filecount: '${10 + i % 200}',
        rating: 2.0 + (i % 30) / 10,
        colorRating: 'ir',
        simpleTags: [
          SimpleTag(text: 'tag${i % 17}', color: 'ir'),
          SimpleTag(text: 'language:${i % 2 == 0 ? 'chinese' : 'english'}'),
          SimpleTag(text: 'female:${i % 11}'),
        ],
      );
    });

/// GalleryItemController 构造链所需的服务注册。
/// 与 test/tabview_controller_list_test.dart 同思路：涉及 Isar/网络/
/// 定时器的 onInit/onReady 一律以空实现子类替代。
void _registerFakeGraph() {
  Get.put<LocaleService>(LocaleService());
  Get.put<EhSettingService>(_FakeEhSettingService());
  Get.put<ThemeService>(ThemeService());
  Get.put<TagController>(_FakeTagController());
  Get.put<UserController>(_FakeUserController());
  Get.put<LocalFavController>(_FakeLocalFavController());
  Get.put<FavoriteSelectorController>(_FakeFavoriteSelectorController());
  Get.put<FavController>(_FakeFavController());
  Get.put<WebdavController>(_FakeWebdavController());
  Get.put<MysqlController>(_FakeMysqlController());
  Get.put<HistoryController>(_FakeHistoryController());
  Get.put<TabHomeController>(_FakeTabHomeController());
}

class _FakeEhSettingService extends EhSettingService {
  // 基类 onInit 会读取 Isar（tag 翻译版本号等），benchmark 环境不可用
  @override
  // ignore: must_call_super
  void onInit() {}
}

class _FakeTagController extends TagController {
  @override
  // ignore: must_call_super
  void onReady() {}
}

class _FakeUserController extends UserController {
  @override
  // ignore: must_call_super
  void onInit() {}
}

class _FakeLocalFavController extends LocalFavController {
  @override
  // ignore: must_call_super
  void onInit() {}
}

class _FakeFavoriteSelectorController extends FavoriteSelectorController {
  @override
  // ignore: must_call_super
  void onInit() {}
}

class _FakeFavController extends FavController {
  @override
  // ignore: must_call_super
  void onInit() {}
}

class _FakeWebdavController extends WebdavController {
  @override
  // ignore: must_call_super
  void onInit() {}
}

class _FakeMysqlController extends MysqlController {
  @override
  // ignore: must_call_super
  void onInit() {}
}

class _FakeHistoryController extends HistoryController {
  @override
  // ignore: must_call_super
  void onInit() {}
}

class _FakeTabHomeController extends TabHomeController {
  @override
  // ignore: must_call_super
  void onInit() {}
}
