// Simulator-only entrypoint: exercises production cache, download, menu and
// PhotoKit code using synthetic files and a loopback server, never an account.
import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:eros_fe/common/global.dart';
import 'package:eros_fe/common/service/ehsetting_service.dart';
import 'package:eros_fe/common/service/theme_service.dart';
import 'package:eros_fe/generated/l10n.dart';
import 'package:eros_fe/network/api.dart';
import 'package:eros_fe/pages/image_view/view/view_widget.dart';
import 'package:eros_fe/utils/gallery_image_export.dart';
import 'package:extended_image/extended_image.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_smart_dialog/flutter_smart_dialog.dart';
import 'package:get/get.dart';
import 'package:oktoast/oktoast.dart';
import 'package:path_provider/path_provider.dart';

import 'gallery_save_fixture.dart';

class ProbeSettings extends GetxService implements EhSettingService {
  @override
  bool get liquidGlass => false;
  @override
  bool get nativeHttpClientAdapter => false;
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class ProbeTheme extends GetxService implements ThemeService {
  @override
  CupertinoThemeData get themeData => const CupertinoThemeData();
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

late Directory docs;
late GalleryImageSource source;
late File gif;
final results = <String, Object?>{};
int networkRequests = 0;
Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  Global.tempPath = (await getTemporaryDirectory()).path;
  docs = await getApplicationDocumentsDirectory();
  Get.put<EhSettingService>(ProbeSettings());
  Get.put<ThemeService>(ProbeTheme());
  final cache = Directory('${Global.tempPath}/$cacheImageFolderName');
  await cache.create(recursive: true);
  await File('${cache.path}/gallery-probe-current')
      .writeAsBytes(saveCurrentPng);
  gif = await File('${docs.path}/animation.gif').writeAsBytes(saveAnimatedGif);
  final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
  server.listen((request) async {
    networkRequests++;
    if (request.uri.path == '/html') {
      request.response.headers.contentType = ContentType.html;
      request.response.write('<html>Login required</html>');
    } else if (request.uri.path == '/error') {
      request.response.statusCode = 503;
      request.response.write('Unavailable');
    } else {
      request.response.headers.contentType = ContentType('image', 'jpeg');
      request.response.contentLength = saveOriginalJpeg.length;
      request.response.add(saveOriginalJpeg);
    }
    await request.response.close();
  });
  source = GalleryImageSource(
      gid: 'probe',
      ser: 1,
      url: 'http://127.0.0.1:${server.port}/current-must-not-download',
      cacheKey: 'gallery-probe-current',
      originalUrl: 'http://127.0.0.1:${server.port}/original',
      originalCacheKey: 'gallery-probe-original',
      filename: 'fixture');
  runApp(GetCupertinoApp(
    locale: const Locale('zh', 'CN'),
    localizationsDelegates: const [
      L10n.delegate,
      GlobalCupertinoLocalizations.delegate,
      GlobalMaterialLocalizations.delegate,
      GlobalWidgetsLocalizations.delegate
    ],
    supportedLocales: L10n.delegate.supportedLocales,
    navigatorObservers: [FlutterSmartDialog.observer],
    builder: FlutterSmartDialog.init(
        builder: (context, child) => OKToast(child: child!)),
    home: const ProbePage(),
  ));
}

class ProbePage extends StatefulWidget {
  const ProbePage({super.key});
  @override
  State<ProbePage> createState() => _ProbePageState();
}

class _ProbePageState extends State<ProbePage> {
  String status = 'Running';
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => runProbe());
  }

  Future<void> runProbe() async {
    for (final entry in <String, Future<void> Function()>{
      'current-cache': () => Api.saveGalleryImageToPhoto(source),
      'original-download': () =>
          Api.saveGalleryImageToPhoto(source, original: true),
      'original-repeat': () =>
          Api.saveGalleryImageToPhoto(source, original: true),
      'animated-local': () => Api.saveLocalImageToPhoto(gif.path, gid: 'probe'),
      'html': () => Api.saveGalleryImageToPhoto(GalleryImageSource(
          url: source.originalUrl!.replaceFirst('/original', '/html'))),
      'http-error': () => Api.saveGalleryImageToPhoto(GalleryImageSource(
          url: source.originalUrl!.replaceFirst('/original', '/error'))),
    }.entries) {
      try {
        await entry.value();
        results[entry.key] = 'success';
      } on ImageExportException catch (error) {
        results[entry.key] = error.failure.name;
        results['${entry.key}-detail'] = error.cause?.toString();
      } catch (error) {
        results[entry.key] = error.toString();
      }
      results['${entry.key}-network-count'] = networkRequests;
      await File('${docs.path}/gallery-save-result.json')
          .writeAsString(jsonEncode(results));
    }
    if (mounted) {
      setState(() => status = 'Completed: $networkRequests network requests');
    }
  }

  @override
  Widget build(BuildContext context) => CupertinoPageScaffold(
        navigationBar:
            const CupertinoNavigationBar(middle: Text('Gallery save probe')),
        child: SafeArea(
            child: Center(
                child: Column(mainAxisSize: MainAxisSize.min, children: [
          Text(status),
          GestureDetector(
              onLongPress: () => showImageSheet(context, () {},
                  gid: source.gid,
                  ser: source.ser,
                  imageUrl: source.url,
                  origImageUrl: source.originalUrl,
                  cacheKey: source.cacheKey,
                  originalCacheKey: source.originalCacheKey,
                  filename: source.filename),
              child: Image(
                  image: ExtendedNetworkImageProvider(source.url!,
                      cache: true, cacheKey: source.cacheKey),
                  width: 200,
                  height: 200)),
          CupertinoButton(
              child: const Text('Toolbar save'),
              onPressed: () => showSaveActionSheet(context,
                  gid: source.gid,
                  ser: source.ser,
                  imageUrl: source.url,
                  origImageUrl: source.originalUrl,
                  cacheKey: source.cacheKey,
                  originalCacheKey: source.originalCacheKey,
                  filename: source.filename)),
        ]))),
      );
}
