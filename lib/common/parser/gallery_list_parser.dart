import 'package:collection/collection.dart';
import 'package:eros_fe/component/exception/error.dart';
import 'package:eros_fe/index.dart';
import 'package:html/dom.dart' as dom;
import 'package:html/parser.dart' show parse;
import 'package:intl/intl.dart';

/// 收藏标记解析结果。
class FavoriteMarker {
  const FavoriteMarker({
    required this.title,
    required this.favcat,
    required this.rawStyle,
  });

  final String title;
  final String favcat;
  final String rawStyle;

  bool get isFavorited => title.isNotEmpty;
}

/// 从列表行中解析收藏标题和收藏夹颜色。
///
/// ExHentai 的列表 HTML 在不同视图和版本中会改变收藏标记的层级，
/// 因此这里按 title/style 属性查找，而不是依赖固定的 nth-child。
FavoriteMarker parseFavoriteMarker(dom.Element element) {
  // Use the same posted-date node as master, with its stable ID preferred
  // over the legacy compact layout. Category names are user-defined: neither
  // the tooltip text nor a colored tag elsewhere in the row identifies it.
  final candidates = <dom.Element>[
    if (RegExp(r'^posted_\d+$').hasMatch(element.id)) element,
    ...element
        .querySelectorAll('[id]')
        .where((node) => RegExp(r'^posted_\d+$').hasMatch(node.id)),
    ..._legacyPostedElements(element),
  ];
  FavoriteMarker? unknownMarker;
  for (final candidate in candidates.toSet()) {
    final style = _attributeValue(candidate, 'style') ?? '';
    final borderColor = _borderColorFromStyle(style);
    final isPosted = RegExp(r'^posted_\d+$').hasMatch(candidate.id);
    if (borderColor == null && !(isPosted && _hasBackgroundColor(style))) {
      continue;
    }
    var favcat = _favoriteCategoryFromStyle(style);
    if (favcat.isEmpty && isPosted) {
      favcat = _favoriteCategoryFromBackgroundStyle(style);
    }
    final title = _attributeValue(candidate, 'title')?.trim() ?? '';
    final marker = FavoriteMarker(
      title: title.isNotEmpty
          ? title
          : (favcat.isEmpty ? '' : 'Favorites $favcat'),
      favcat: favcat,
      rawStyle: style,
    );
    if (favcat.isNotEmpty) {
      return marker;
    }
    unknownMarker ??= marker;
  }
  return unknownMarker ??
      const FavoriteMarker(title: '', favcat: '', rawStyle: '');
}

// The html package's nth-child selector counts text nodes. Locate the
// metadata block by its direct rating child instead of a numeric position.
Iterable<dom.Element> _legacyPostedElements(dom.Element row) sync* {
  for (final block in row.querySelectorAll('td.gl2c > div')) {
    if (block.children.any((child) => child.classes.contains('ir'))) {
      final posted = block.children.firstOrNull;
      if (posted != null && !posted.classes.contains('ir')) {
        yield posted;
      }
    }
  }
}

String? _attributeValue(dom.Element element, String name) {
  for (final entry in element.attributes.entries) {
    if (entry.key.toString().toLowerCase() == name.toLowerCase()) {
      return entry.value;
    }
  }
  return null;
}

String? _borderColorFromStyle(String style) {
  final match = RegExp(
    r'(?:^|;)\s*border-color\s*:\s*([^;]+)',
    caseSensitive: false,
  ).firstMatch(style);
  return match?.group(1)?.trim();
}

String _favoriteCategoryFromStyle(String style) =>
    _favoriteCategoryFromCssColor(_borderColorFromStyle(style) ?? '');

String _favoriteCategoryFromBackgroundStyle(String style) {
  final match =
      RegExp(r'(?:^|;)\s*background-color\s*:\s*([^;]+)', caseSensitive: false)
          .firstMatch(style);
  return _favoriteCategoryFromCssColor(match?.group(1) ?? '');
}

String _favoriteCategoryFromCssColor(String value) {
  final color = value
      .replaceFirst(RegExp(r'\s*!important\s*$', caseSensitive: false), '')
      .trim()
      .toLowerCase();
  String? rgb;
  final hex = RegExp(r'^#([0-9a-f]{3}|[0-9a-f]{6})$').firstMatch(color);
  if (hex != null) {
    var digits = hex.group(1)!;
    if (digits.length == 3) digits = digits.split('').map((c) => '$c$c').join();
    rgb = [0, 2, 4]
        .map((i) => int.parse(digits.substring(i, i + 2), radix: 16))
        .join(',');
  } else {
    final match = RegExp(
      r'^rgba?\(\s*(\d{1,3})\s*,\s*(\d{1,3})\s*,\s*(\d{1,3})(?:\s*,\s*(\d*\.?\d+))?\s*\)$',
    ).firstMatch(color);
    if (match == null) return '';
    final channels = [1, 2, 3].map((i) => int.parse(match.group(i)!)).toList();
    final alpha = double.tryParse(match.group(4) ?? '1');
    if (channels.any((c) => c > 255) ||
        alpha == null ||
        alpha <= 0 ||
        alpha > 1) return '';
    rgb = channels.join(',');
  }
  // Exact site palette variants, never nearest-color guesses. The legacy
  // border palette also occurs as rgb()/rgba() or expanded hex in new markup.
  for (final entry in EHConst.favCat.entries) {
    final digits = entry.key.substring(1);
    final canonical =
        digits.split('').map((c) => int.parse('$c$c', radix: 16)).join(',');
    if (rgb == canonical) return entry.value;
  }
  const backgroundPalette = <String, String>{
    '0,0,0': '0',
    '240,0,0': '1',
    '240,160,0': '2',
    '208,208,0': '3',
    '0,128,0': '4',
    '144,240,64': '5',
    '64,176,240': '6',
    '0,0,240': '7',
    '80,0,128': '8',
    '232,0,232': '9',
  };
  return backgroundPalette[rgb] ?? '';
}

bool _hasBackgroundColor(String style) => RegExp(
      r'(?:^|;)\s*background-color\s*:',
      caseSensitive: false,
    ).hasMatch(style);

/// 检查返回结果是否是 compact 视图
bool isGalleryListDmL(String response) {
  final dom.Document document = parse(response);

  final dom.Element? searchnavElm = document.querySelector('.searchnav');

  late List<dom.Element>? optionElms;
  if (searchnavElm == null) {
    optionElms = document.querySelectorAll('#dms > div > select > option');
  } else {
    optionElms = searchnavElm
        .querySelector('#ulast')
        ?.parent
        ?.nextElementSibling
        ?.querySelectorAll('option');
    logger.t('searchnav optionElms length ${optionElms?.length}');
  }

  for (final dom.Element elm in optionElms ?? []) {
    final Map<dynamic, String> attributes = elm.attributes;
    if (attributes.keys.contains('selected')) {
      return attributes['value'] == 'l';
    } else {
      continue;
    }
  }

  return true;
}

///  收藏夹 检查返回结果的排序方式
bool? isFavoriteOrder(String response) {
  final dom.Document document = parse(response);

  final dom.Element? orderElm =
      document.querySelector('.searchnav')?.children.firstOrNull;

  if (orderElm != null) {
    logger.t('ooo ${orderElm.text}');
    final options = orderElm.querySelectorAll('option');
    return (options
                .where((e) => e.attributes['selected'] == 'selected')
                .firstOrNull
                ?.text ??
            '')
        .contains('Favorited');
  } else {
    final List<dom.Element> domList =
        document.querySelectorAll('body > div.ido > div');

    if (domList.length > 2) {
      final dom.Element? orderElm = domList[2].querySelector('div > span');
      logger.t('${orderElm?.text}');
      return orderElm?.text.trim() == 'Favorited';
    }

    return null;
  }
}

GalleryList parseGalleryListOfFav(String response) {
  return parseGalleryList(response, isFavorite: true);
}

/// 列表数据处理
GalleryList parseGalleryList(
  String response, {
  bool isFavorite = false,
}) {
  final dom.Document document = parse(response);

  if ((document.body?.children.isEmpty ?? false) &&
      response.contains('banned')) {
    throw EhError(type: EhErrorType.banned, error: response);
  }

  const String _listSelector = 'tbody > tr';
  const String _pageSelector = 'table.ptt > tbody > tr > td';
  const String _favoritesSelector = 'body > div.ido > div.nosel > div';

  final List<Favcat> favcatList = <Favcat>[];
  if (isFavorite) {
    /// 收藏夹列表
    final List<dom.Element> favorites =
        document.querySelectorAll(_favoritesSelector);
    int _favId = 0;
    for (final dom.Element elm in favorites) {
      final List<dom.Element> divs = elm.querySelectorAll('div');
      if (divs.isNotEmpty && divs.length >= 3) {
        final Favcat favcat = Favcat(
            favId: '$_favId',
            favTitle: divs[2].text,
            totNum: int.parse(divs[0].text));
        favcatList.add(favcat);
        _favId += 1;
      }
    }
  }

// 最大页数
  int _maxPage = 0;
  List<dom.Element> _pages = document.querySelectorAll(_pageSelector);
  if (_pages.length > 2) {
    final dom.Element _maxPageElem = _pages[_pages.length - 2];
    _maxPage = int.parse(_maxPageElem.text.trim());
  }

  // 下一页页码
  final dom.Element? _curPageElem =
      _pages.firstWhereOrNull((e) => e.attributes['class'] == 'ptds');
  final _curPage = _curPageElem?.text.trim() ?? '';
  final _nextPage =
      (int.tryParse(_curPageElem?.nextElementSibling?.text.trim() ?? '') ?? 0) -
          1;
  final _prevPage =
      (int.tryParse(_curPageElem?.previousElementSibling?.text.trim() ?? '') ??
              0) -
          1;

  logger.t('$_curPage , _nextPage:$_nextPage , _prevPage:$_prevPage');

  const searchnavSelector = '.searchnav';
  final searchnavElm = document.querySelector(searchnavSelector);

  // prev
  final prevElm = searchnavElm?.querySelector('#uprev');
  final prevHref = prevElm?.attributes['href'];
  final _prev = prevHref?.split('=').last;

  // next
  final nextElm = searchnavElm?.querySelector('#unext');
  final nextHref = nextElm?.attributes['href'];
  final _next = nextHref?.split('=').last;

  logger.t('parse next:$_next, prev:$_prev');

// 画廊列表
  List<dom.Element> gallerys = document.querySelectorAll(_listSelector);

  final List<GalleryProvider> _gallaryProviders = [];
  for (final dom.Element tr in gallerys) {
    final String? category =
        tr.querySelector('td.gl1c.glcat > div')?.text.trim();

    // 表头或者广告
    if (category == null || category.isEmpty) {
      continue;
    }

    final String title =
        tr.querySelector('td.gl3c.glname > a > div.glink')?.text.trim() ?? '';

    final String url =
        tr.querySelector('td.gl3c.glname > a')?.attributes['href'] ?? '';
    final String _path = Uri.parse(url).path;
// logger.d('url $url   path $_path');

    final RegExp urlRex = RegExp(r'/g/(\d+)/(\w+)/$');
    final RegExpMatch? urlRult = urlRex.firstMatch(url);

    final String gid = urlRult?.group(1) ?? '';
    final String token = urlRult?.group(2) ?? '';

// tags
    final List<dom.Element> tags = tr.querySelectorAll('div.gt');

// tag
    final List<SimpleTag> simpleTags = <SimpleTag>[];
    final RegExp colorRex = RegExp(r'#(\w{6})');
    for (final dom.Element tag in tags) {
      final String tagText = tag.text.trim();

      final String? style = tag.attributes['style'];
      String color = '';
      String backgroundColor = '';
      if (style != null) {
        final Iterable<RegExpMatch> matches = colorRex.allMatches(style);
        color = matches.elementAt(0)[0] ?? '';
        backgroundColor = matches.elementAt(3)[0] ?? '';
      }
      simpleTags.add(SimpleTag(
          text: tagText,
          translat: tagText,
          color: color,
          backgrondColor: backgroundColor));
    }

    // favNote
    final favNoteElm = tr.querySelector('div.glfnote');
    final regFavnote = RegExp(r'Note:\s(.+)');
    final matchFavnote = regFavnote.firstMatch(favNoteElm?.text ?? '');
    final favNote = matchFavnote?.group(1);
    // if (favNote != null) print('favNote:$favNote');

    /// 判断获取语言标识
    String _translated = '';
    try {
      if (simpleTags.isNotEmpty) {
        final SimpleTag? _langTag = simpleTags.firstWhere(
            (SimpleTag element) => EHConst.iso936.keys.contains(element.text),
            orElse: () => const SimpleTag(
                  text: '',
                  translat: '',
                  color: '',
                  backgrondColor: '',
                ));

        _translated = EHUtils.getLanguage(_langTag?.text ?? '');
      }
    } catch (e, stack) {
      // logger.e('$e\n$stack');
    }

// 封面图片
    final dom.Element? img = tr.querySelector('td.gl2c > div > div > img');
    final String? imgDataSrc = img?.attributes['data-src'];
    final String? imgSrc = img?.attributes['src'];
    final String imgUrl = imgDataSrc ?? imgSrc ?? '';

// 图片宽高
    final String imageStyle = img?.attributes['style'] ?? '';
    final RegExpMatch? match =
        RegExp(r'height:(\d+)px;width:(\d+)px').firstMatch(imageStyle);
    final int imageHeight = int.parse(match?[1] ?? '0');
    final int imageWidth = int.parse(match?[2] ?? '0');

// 评分星级计算
    final ratingElement = tr.querySelector('td.gl2c .ir')!;
    final String ratPx = ratingElement.attributes['style']!;
    final RegExp pxA = RegExp(r'-?(\d+)px\s+-?(\d+)px');
    final RegExpMatch px = pxA.firstMatch(ratPx)!;

    final double ratingFB = (80.0 - double.parse(px.group(1)!)) / 16.0 -
        (px.group(2) == '21' ? 0.5 : 0.0);

// logger.i('ratingFB $ratingFB');

    // 发布时间
    bool expunged = false;
    final elmPostTime = tr.querySelector('[id=posted_$gid]') ??
        _legacyPostedElements(tr).firstOrNull;
    if (elmPostTime?.children.isNotEmpty ?? false) {
      // logger.d('${elmPostTime?.outerHtml}');
      expunged = true;
    }
    final String postTime = elmPostTime?.text.trim() ?? '';
    final DateTime time =
        DateFormat('yyyy-MM-dd HH:mm').parseUtc(postTime).toLocal();
    final String postTimeLocal = DateFormat('yyyy-MM-dd HH:mm').format(time);

// 收藏标志
    final favoriteMarker = parseFavoriteMarker(tr);
    final String favTitle = favoriteMarker.title;

// 评分颜色
    final String _colorRating = ratingElement.attributes['class'] ?? 'ir';

// 评分标志
    final String ir = _colorRating;
    final bool isRatinged = ir.contains(RegExp(r'ir ir[a-z]'));

// 收藏夹
    final String favcat = favoriteMarker.favcat;

    String _uplader = '';
    String _filecount = '';
    if (!isFavorite) {
      final dom.Element? elmGl4c = tr.querySelector('td.gl4c.glhide');
      if (elmGl4c != null) {
// 上传者
        _uplader = elmGl4c.children[0].text;

// 文件数量
        _filecount =
            RegExp(r'\d+').firstMatch(elmGl4c.children[1].text)!.group(0) ?? '';
      }
    } else {
      final dom.Element elmGl2c = tr.children[1];
      _filecount = RegExp(r'\d+')
          .firstMatch(
              elmGl2c.children[1].children[1].children[1].children[1].text)!
          .group(0)!;
    }

    void _addIiem() {
      _gallaryProviders.add(GalleryProvider(
        gid: gid,
        token: token,
        englishTitle: title,
        imgUrl: imgUrl,
        imgHeight: imageHeight,
        imgWidth: imageWidth,
        url: _path,
        category: category,
        simpleTags: simpleTags,
        postTime: postTimeLocal,
        ratingFallBack: ratingFB,
        colorRating: _colorRating,
        isRatinged: isRatinged,
        favTitle: favTitle,
        favcat: favcat,
        uploader: _uplader,
        filecount: _filecount,
        translated: _translated,
        favNote: favNote,
        expunged: expunged,
      ));
    }

    _addIiem();

// safeMode检查
//     if (Platform.isIOS && (ehSettingService.isSafeMode.value)) {
//       if (category.trim() == 'Non-H') {
//         _addIiem();
//       }
//     } else {
//       _addIiem();
//     }
  }

  // return Tuple2(_gallaryProviders, _maxPage);
  return GalleryList(
    gallerys: _gallaryProviders,
    favList: favcatList,
    nextGid: _next,
    prevGid: _prev,
    nextPage: _nextPage,
    prevPage: _prevPage,
    maxPage: _maxPage,
  );
}
