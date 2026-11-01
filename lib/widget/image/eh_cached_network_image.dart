import 'package:blurhash_ffi/blurhash_ffi.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:eros_fe/common/controller/image_block_controller.dart';
import 'package:eros_fe/index.dart';
import 'package:eros_fe/network/app_dio/dio_file_service.dart';
import 'package:eros_fe/widget/image/rect_image_provider.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter_cache_manager/flutter_cache_manager.dart';
import 'package:get/get.dart';
import 'package:http/http.dart' as http;
import 'package:http/retry.dart' as retry;
import 'package:octo_image/octo_image.dart';

/// Images already drawn somewhere, by address. A page that opens on the
/// same picture, like a gallery's detail opened from its list card, can show
/// it in its first frame while its own copy is still decoding.
abstract final class ShownImages {
  static const int _capacity = 48;
  static final Map<String, ImageProvider> _providers = <String, ImageProvider>{};

  static void remember(String url, ImageProvider provider) {
    _providers.remove(url);
    _providers[url] = provider;
    if (_providers.length > _capacity) {
      _providers.remove(_providers.keys.first);
    }
  }

  static ImageProvider? of(String url) => _providers[url];
}

/// [url] as it is already drawn elsewhere, or nothing.
class ShownImage extends StatelessWidget {
  const ShownImage(
    this.url, {
    super.key,
    this.fit = BoxFit.cover,
    this.alignment = Alignment.center,
  });

  final String url;
  final BoxFit fit;
  final Alignment alignment;

  @override
  Widget build(BuildContext context) {
    final provider = ShownImages.of(url.handleUrl);
    if (provider == null) {
      return const SizedBox.expand();
    }
    return Image(
      image: provider,
      fit: fit,
      alignment: alignment,
      width: double.infinity,
      height: double.infinity,
      gaplessPlayback: true,
    );
  }
}

class EhCachedNetworkImage extends StatelessWidget {
  EhCachedNetworkImage({
    super.key,
    required this.imageUrl,
    this.height,
    this.width,
    this.fit,
    this.placeholder,
    this.errorWidget,
    this.progressIndicatorBuilder,
    this.httpHeaders,
    this.onLoadCompleted,
    this.checkPHashHide = false,
    this.checkQRCodeHide = false,
    this.onHideFlagChanged,
    this.ser,
    this.blurHash = false,
    this.sourceRect,
    this.alignment = Alignment.center,
    this.decodeWidth,
    this.fadeInDuration,
    this.placeholderWhileDecoding = false,
  });

  final String imageUrl;
  final double? height;
  final double? width;
  final BoxFit? fit;
  final Map<String, String>? httpHeaders;

  final PlaceholderWidgetBuilder? placeholder;
  final LoadingErrorWidgetBuilder? errorWidget;
  final ProgressIndicatorBuilder? progressIndicatorBuilder;
  final VoidCallback? onLoadCompleted;
  final bool checkPHashHide;
  final bool checkQRCodeHide;
  final ValueChanged<bool>? onHideFlagChanged;

  final bool blurHash;

  final int? ser;

  final Rect? sourceRect;

  final Alignment alignment;

  /// Decode at this width in physical pixels instead of the source size,
  /// so a card-sized cover does not keep a full-size bitmap in memory.
  /// Ignored with [sourceRect], whose crop is in source pixels.
  final int? decodeWidth;

  /// Placeholder-to-image fade; the package default (500ms) when null.
  final Duration? fadeInDuration;

  /// Keeps [placeholder] up until the image has decoded, not only until its
  /// file is found. Otherwise nothing is drawn in between, for a frame or
  /// more, and the image pops in.
  ///
  /// The placeholder is taken to be a [ShownImage] of the same address.
  /// When that picture is already drawn somewhere, the image goes in under
  /// it at once and only the placeholder fades: fading both ways would let
  /// the background show through halfway, a dip that reads as a flicker.
  final bool placeholderWhileDecoding;

  final ImageBlockController imageHideController = Get.find();

  bool get _holdsPlaceholder => placeholderWhileDecoding && placeholder != null;

  /// The fade of the image under the placeholder.
  Duration? get _imageFadeIn =>
      _holdsPlaceholder && ShownImages.of(imageUrl.handleUrl) != null
          ? Duration.zero
          : fadeInDuration;

  Future<bool> _future() async {
    // if (checkPHashHide && checkQRCodeHide) {
    //   return await imageHideController.checkPHashHide(
    //         imageUrl,
    //         sourceRect: sourceRect,
    //       ) ||
    //       await imageHideController.checkQRCodeHide(
    //         imageUrl,
    //         sourceRect: sourceRect,
    //       );
    // }
    // if (checkPHashHide) {
    //   return await imageHideController.checkPHashHide(imageUrl,
    //       sourceRect: sourceRect);
    // } else {
    //   return await imageHideController.checkQRCodeHide(imageUrl,
    //       sourceRect: sourceRect);
    // }
    bool result = false;
    if (checkPHashHide) {
      result = await imageHideController.checkPHashHide(imageUrl,
          sourceRect: sourceRect);
    }
    if (checkQRCodeHide) {
      result = await imageHideController.checkQRCodeHide(imageUrl,
          sourceRect: sourceRect);
    }
    return result;
  }

  ImageWidgetBuilder get imageWidgetBuilder => (context, imageProvider) {
        if (decodeWidth != null && sourceRect == null) {
          imageProvider = ResizeImage(imageProvider,
              width: decodeWidth, allowUpscaling: false);
        }

        if (blurHash) {
          imageProvider = BlurhashTheImage(imageProvider);
        }

        if (sourceRect != null) {
          logger.t('sourceRect $sourceRect');
          imageProvider = RectImageProvider(
            imageProvider,
            sourceRect!,
          );
        }

        final shown = imageProvider;
        final remembers =
            sourceRect == null && !checkPHashHide && !checkQRCodeHide;
        final holdsPlaceholder = _holdsPlaceholder;
        final octoImage = OctoImage(
          image: shown,
          width: width,
          height: height,
          fit: fit,
          alignment: alignment,
          // Called once the picture is drawn, so only decoded images are
          // offered to other pages.
          imageBuilder: remembers
              ? (context, child) {
                  ShownImages.remember(imageUrl.handleUrl, shown);
                  return child;
                }
              : null,
          placeholderBuilder: holdsPlaceholder
              ? (context) => placeholder!(context, imageUrl)
              : null,
          fadeInDuration: holdsPlaceholder ? _imageFadeIn : null,
          fadeOutDuration: holdsPlaceholder ? fadeInDuration : null,
        );
        if (checkPHashHide || checkQRCodeHide) {
          return FutureBuilder<bool>(
              future: _future(),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.done) {
                  if (snapshot.hasError) {
                    return octoImage;
                  }
                  final showHidePlaceWidget = snapshot.data ?? false;
                  onHideFlagChanged?.call(showHidePlaceWidget);
                  return showHidePlaceWidget
                      ? Center(
                          child: Icon(
                            CupertinoIcons.xmark_shield_fill,
                            size: 32,
                            color: CupertinoDynamicColor.resolve(
                                CupertinoColors.systemGrey3, context),
                          ),
                        )
                      : octoImage;
                } else {
                  return placeholder?.call(context, imageUrl) ??
                      Container(
                        alignment: Alignment.center,
                        child: const CupertinoActivityIndicator(),
                      );
                  // return octoImage;
                }
              });
        } else {
          return octoImage;
        }
      };

  @override
  Widget build(BuildContext context) {
    final imgHttpHeaders = {
      'Cookie': Global.profile.user.cookie,
      'Host': Uri.parse(imageUrl).host,
      'User-Agent': EHConst.CHROME_USER_AGENT,
      'Accept-Encoding': 'gzip, deflate, br'
    };
    if (httpHeaders != null) {
      imgHttpHeaders.addAll(httpHeaders!);
    }

    final image = CachedNetworkImage(
      cacheManager: imageCacheManager(ser: ser),
      imageBuilder: imageWidgetBuilder,
      httpHeaders: imgHttpHeaders,
      width: width,
      height: height,
      fit: fit,
      imageUrl: imageUrl.handleUrl,
      alignment: alignment,
      placeholder: placeholder,
      errorWidget: errorWidget,
      progressIndicatorBuilder: progressIndicatorBuilder,
      fadeInDuration: _imageFadeIn ?? const Duration(milliseconds: 500),
    );

    return image;
  }
}

final client = retry.RetryClient(
  http.Client(),
);

final imageCacheManagerOld = CacheManager(
  Config(
    'CachedNetworkImage',
    fileService: HttpFileService(
      httpClient: client,
    ),
    // fileService: DioFileService(),
  ),
);

CacheManager imageCacheManager({int? ser}) {
  return CacheManager(
    Config(
      'CachedNetworkImage',
      fileService: DioFileService(ser: ser),
    ),
  );
}

ImageProvider getEhImageProvider(String url, {int? ser}) {
  return CachedNetworkImageProvider(
    url,
    cacheManager: imageCacheManager(ser: ser),
    // cacheKey: buildImageCacheKey(url),
  );
}
