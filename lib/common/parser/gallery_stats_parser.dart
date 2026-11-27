import 'dart:math' as math;

import 'package:eros_fe/const/const.dart';
import 'package:eros_fe/models/gallery_stats.dart';
import 'package:html/dom.dart';
import 'package:html/parser.dart' show parse;

final RegExp _digitsOnlyPattern = RegExp(r'^\d+$');
final RegExp _hexTokenPattern = RegExp(r'^[0-9a-fA-F]+$');
final RegExp _totalVisitsFallbackPattern = RegExp(
  r'Total Visits\s*:\s*([\d,]+)',
  caseSensitive: false,
);
final RegExp _compactNumberPattern = RegExp(
  r'^([\d,]+(?:\.\d+)?)\s*([KMB])?$',
  caseSensitive: false,
);

/// Builds a canonical E-Hentai `stats.php` URL after strictly validating
/// [gid] (digits) and [token] (hex). Returns empty string if invalid.
String buildGalleryStatsUrl(String? gid, String? token) {
  final cleanGid = gid?.trim() ?? '';
  final cleanToken = token?.trim() ?? '';
  if (!_digitsOnlyPattern.hasMatch(cleanGid) ||
      !_hexTokenPattern.hasMatch(cleanToken)) {
    return '';
  }
  return '${EHConst.EH_BASE_URL}/stats.php?gid=$cleanGid&t=$cleanToken';
}

/// Parses E-Hentai's `stats.php` HTML into a [GalleryStats] model.
///
/// Throws [GalleryStatsException] when the page asks for login or indicates
/// the gallery's statistics are unavailable.
GalleryStats parseGalleryStats(String html) {
  final trimmed = html.trim();
  if (trimmed.isEmpty) {
    throw const GalleryStatsException(
      GalleryStatsErrorKind.unavailable,
      'Empty stats response',
    );
  }

  final lower = trimmed.toLowerCase();
  if (isGalleryStatsLoginHtml(lower)) {
    throw const GalleryStatsException(
      GalleryStatsErrorKind.loginRequired,
      'E-Hentai login required',
    );
  }

  final document = parse(trimmed);
  final stuffbox = document.querySelector('.stuffbox');
  final graphsContainer = document.querySelector('#graphs');

  if (stuffbox == null && graphsContainer == null) {
    if (isGalleryStatsLoginHtml(document.body?.text.toLowerCase() ?? '')) {
      throw const GalleryStatsException(
        GalleryStatsErrorKind.loginRequired,
        'E-Hentai login required',
      );
    }
    throw const GalleryStatsException(
      GalleryStatsErrorKind.unavailable,
      'Stats page structure unavailable',
    );
  }

  final totalVisits = _parseTotalVisits(stuffbox);
  final rankings = _parseRankings(stuffbox);

  final graphDivs =
      graphsContainer?.children
          .where((child) => child.localName == 'div')
          .toList(growable: false) ??
      const <Element>[];

  final assignedGraphs = _assignGraphDivs(graphDivs);
  final dailyStats = _parseGraphSeries(
    assignedGraphs[GalleryStatsGranularity.daily],
  );
  final monthlyStats = _parseGraphSeries(
    assignedGraphs[GalleryStatsGranularity.monthly],
  );
  final yearlyStats = _parseGraphSeries(
    assignedGraphs[GalleryStatsGranularity.yearly],
  );

  if (totalVisits == null &&
      rankings.isEmpty &&
      dailyStats.isEmpty &&
      monthlyStats.isEmpty &&
      yearlyStats.isEmpty) {
    throw const GalleryStatsException(
      GalleryStatsErrorKind.unavailable,
      'No statistics found on page',
    );
  }

  return GalleryStats(
    totalVisits: totalVisits,
    allTimeRanking: rankings[GalleryStatsPeriod.allTime]?.ranking,
    allTimeScore: rankings[GalleryStatsPeriod.allTime]?.score,
    yearRanking: rankings[GalleryStatsPeriod.year]?.ranking,
    yearScore: rankings[GalleryStatsPeriod.year]?.score,
    monthRanking: rankings[GalleryStatsPeriod.month]?.ranking,
    monthScore: rankings[GalleryStatsPeriod.month]?.score,
    dayRanking: rankings[GalleryStatsPeriod.day]?.ranking,
    dayScore: rankings[GalleryStatsPeriod.day]?.score,
    yearlyStats: yearlyStats,
    monthlyStats: monthlyStats,
    dailyStats: dailyStats,
  );
}

/// Returns `true` when [rawHtml] is an E-Hentai login bounce/form response.
bool isGalleryStatsLoginHtml(String rawHtml) {
  final lowerHtml = rawHtml.toLowerCase();
  return lowerHtml.contains('this page requires you to log on') ||
      lowerHtml.contains('name="ipb_login_form"') ||
      lowerHtml.contains("name='ipb_login_form'") ||
      lowerHtml.contains('<title>e-hentai.org login</title>');
}

int? _parseTotalVisits(Element? stuffbox) {
  if (stuffbox == null) {
    return null;
  }
  final paragraphs = stuffbox.querySelectorAll('p');
  for (final paragraph in paragraphs) {
    final text = paragraph.text;
    if (!text.toLowerCase().contains('total visits')) {
      continue;
    }
    for (final strong in paragraph.querySelectorAll('strong')) {
      final parsed = _parseIntToken(strong.text);
      if (parsed != null && parsed >= 0) {
        return parsed;
      }
    }
    final match = _totalVisitsFallbackPattern.firstMatch(text);
    if (match != null) {
      final parsed = _parseIntToken(match.group(1)!);
      if (parsed != null && parsed >= 0) {
        return parsed;
      }
    }
  }
  final match = _totalVisitsFallbackPattern.firstMatch(stuffbox.text);
  if (match != null) {
    final parsed = _parseIntToken(match.group(1)!);
    if (parsed != null && parsed >= 0) {
      return parsed;
    }
  }
  return null;
}

Map<GalleryStatsPeriod, ({int? ranking, int? score})> _parseRankings(
  Element? stuffbox,
) {
  final result = <GalleryStatsPeriod, ({int? ranking, int? score})>{};
  final tbody = stuffbox?.querySelector('table > tbody') ??
      stuffbox?.querySelector('table');
  if (tbody == null) {
    return result;
  }

  final rows = tbody.querySelectorAll('tr');
  if (rows.isEmpty) {
    return result;
  }

  final labeledRowIndices = <int>{};
  final usedRowIndices = <int>{};

  // Pass 1: semantic matching by row period text (resilient to spacer rows).
  for (var i = 0; i < rows.length; i++) {
    final row = rows[i];
    final period = _matchRankingPeriod(row.text);
    if (period == null) {
      continue;
    }
    labeledRowIndices.add(i);
    final cells = row.querySelectorAll('td');
    if (cells.length < 2) {
      continue;
    }
    final parsed = _extractRankAndScoreFromCells(cells);
    if (parsed != null) {
      result[period] = parsed;
      usedRowIndices.add(i);
    }
  }

  // Pass 2: positional fallback matching E-Hentai's canonical table indices
  // (tr 2/4/6/8 -> td 4 = rank, td 5 = score), strictly skipping rows that
  // were already matched or carry another known period label.
  const positionalMap = <int, GalleryStatsPeriod>{
    1: GalleryStatsPeriod.allTime,
    3: GalleryStatsPeriod.year,
    5: GalleryStatsPeriod.month,
    7: GalleryStatsPeriod.day,
  };
  for (final entry in positionalMap.entries) {
    if (result.containsKey(entry.value) ||
        entry.key >= rows.length ||
        usedRowIndices.contains(entry.key) ||
        labeledRowIndices.contains(entry.key)) {
      continue;
    }
    final cells = rows[entry.key].querySelectorAll('td');
    if (cells.length >= 5) {
      final rank = _parseRankToken(cells[3].text);
      final score = _parseIntToken(cells[4].text);
      if (rank != null || score != null) {
        result[entry.value] = (ranking: rank, score: score);
        usedRowIndices.add(entry.key);
      }
    }
  }

  return result;
}

GalleryStatsPeriod? _matchRankingPeriod(String rawRowText) {
  final lower = rawRowText.toLowerCase();
  if (lower.contains('all-time') || lower.contains('all time')) {
    return GalleryStatsPeriod.allTime;
  }
  if (lower.contains('past year') || lower.contains('yearly')) {
    return GalleryStatsPeriod.year;
  }
  if (lower.contains('past month') || lower.contains('monthly')) {
    return GalleryStatsPeriod.month;
  }
  if (lower.contains('yesterday') || lower.contains('past day')) {
    return GalleryStatsPeriod.day;
  }
  return null;
}

({int? ranking, int? score})? _extractRankAndScoreFromCells(
  List<Element> cells,
) {
  // E-Hentai's canonical 5-column ranking row:
  // [0]=label ("All-Time"), [1]="Ranking:", [2]=spacer/unused or "#rank",
  // [3]=rank, [4]=score.
  if (cells.length >= 5) {
    final rank = _parseRankToken(cells[3].text);
    final score = _parseIntToken(cells[4].text);
    if (rank != null || score != null) {
      return (ranking: rank, score: score);
    }
  }

  // Generic fallback: look for rank cell (prefixed with `#` or plain integer)
  // followed by score cell.
  int? rank;
  int? score;
  for (var i = 1; i < cells.length; i++) {
    final text = cells[i].text.trim();
    if (text.isEmpty) {
      continue;
    }
    final lower = text.toLowerCase();
    if (lower.contains('unranked')) {
      return (ranking: null, score: null);
    }
    final maybeRank = _parseRankToken(text);
    if (rank == null && maybeRank != null) {
      rank = maybeRank;
      continue;
    }
    final maybeScore = _parseIntToken(text);
    if (rank != null && score == null && maybeScore != null) {
      score = maybeScore;
      break;
    }
  }
  if (rank == null && score == null) {
    return null;
  }
  return (ranking: rank, score: score);
}

Map<GalleryStatsGranularity, Element> _assignGraphDivs(
  List<Element> graphDivs,
) {
  final assigned = <GalleryStatsGranularity, Element>{};
  final labeledIndices = <int>{};
  final usedIndices = <int>{};

  // Pass 1: semantic assignment by section heading.
  for (var i = 0; i < graphDivs.length; i++) {
    final granularity = _matchGraphGranularity(graphDivs[i]);
    if (granularity == null) {
      continue;
    }
    labeledIndices.add(i);
    if (!assigned.containsKey(granularity)) {
      assigned[granularity] = graphDivs[i];
      usedIndices.add(i);
    }
  }

  // Pass 2: positional fallback matching E-Hentai's canonical `#graphs > div`
  // order (0=daily, 1=monthly, 2=yearly), strictly skipping divs that were
  // already assigned or carry a known granularity heading.
  const positionalOrder = <(int, GalleryStatsGranularity)>[
    (0, GalleryStatsGranularity.daily),
    (1, GalleryStatsGranularity.monthly),
    (2, GalleryStatsGranularity.yearly),
  ];
  for (final (index, granularity) in positionalOrder) {
    if (assigned.containsKey(granularity) ||
        index >= graphDivs.length ||
        usedIndices.contains(index) ||
        labeledIndices.contains(index)) {
      continue;
    }
    assigned[granularity] = graphDivs[index];
    usedIndices.add(index);
  }

  return assigned;
}

GalleryStatsGranularity? _matchGraphGranularity(Element div) {
  final headerText =
      (div.querySelector('p, h2, h3, th, strong')?.text ?? div.text)
          .toLowerCase();
  if (headerText.contains('daily')) {
    return GalleryStatsGranularity.daily;
  }
  if (headerText.contains('monthly')) {
    return GalleryStatsGranularity.monthly;
  }
  if (headerText.contains('yearly')) {
    return GalleryStatsGranularity.yearly;
  }
  return null;
}

List<GalleryVisitStat> _parseGraphSeries(Element? graphDiv) {
  if (graphDiv == null) {
    return const <GalleryVisitStat>[];
  }
  final tbody =
      graphDiv.querySelector('table > tbody') ??
      graphDiv.querySelector('table');
  if (tbody == null) {
    return const <GalleryVisitStat>[];
  }

  final rows = tbody.querySelectorAll('tr');
  List<String> periods = const <String>[];
  final valueRows = <List<double>>[];

  for (final row in rows) {
    final keyCells = row.querySelectorAll('.stdk');
    if (periods.isEmpty && keyCells.isNotEmpty) {
      periods = keyCells.map((e) => e.text.trim()).toList(growable: false);
      continue;
    }
    final valCells = row.querySelectorAll('.stdv');
    if (valCells.isNotEmpty) {
      valueRows.add(
        valCells.map((e) => parseCompactStatNumber(e.text)).toList(growable: false),
      );
    }
  }

  if (periods.isEmpty || valueRows.isEmpty) {
    return const <GalleryVisitStat>[];
  }

  final visitsRow = valueRows[0];
  final hitsRow = valueRows.length > 1 ? valueRows[1] : const <double>[];
  final count = math.min(periods.length, visitsRow.length);

  final stats = <GalleryVisitStat>[];
  for (var i = 0; i < count; i++) {
    final period = periods[i];
    if (period.isEmpty) {
      continue;
    }
    final visits = visitsRow[i];
    final hits = i < hitsRow.length ? hitsRow[i] : 0.0;
    stats.add(GalleryVisitStat(period: period, visits: visits, hits: hits));
  }

  final firstActive = stats.indexWhere(
    (stat) => stat.visits > 0 || stat.hits > 0,
  );
  if (firstActive == -1) {
    return const <GalleryVisitStat>[];
  }
  return List<GalleryVisitStat>.unmodifiable(stats.sublist(firstActive));
}

int? _parseIntToken(String raw) {
  final cleaned = raw.trim().replaceAll(',', '');
  if (cleaned.isEmpty) {
    return null;
  }
  return int.tryParse(cleaned);
}

int? _parseRankToken(String raw) {
  final cleaned = raw.trim().replaceFirst('#', '').replaceAll(',', '');
  if (cleaned.isEmpty) {
    return null;
  }
  final parsed = int.tryParse(cleaned);
  if (parsed == null || parsed <= 0) {
    return null;
  }
  return parsed;
}

/// Parses E-Hentai `stats.php` cell values such as `5731`, `5,731`, `570K`,
/// `16.2M`, `1.1B`, or `-`.
double parseCompactStatNumber(String raw) {
  final cleaned = raw.trim();
  if (cleaned.isEmpty || cleaned == '-' || cleaned == '—') {
    return 0;
  }
  final match = _compactNumberPattern.firstMatch(cleaned);
  if (match == null) {
    return 0;
  }
  final base = double.tryParse(match.group(1)!.replaceAll(',', ''));
  if (base == null || !base.isFinite || base < 0) {
    return 0;
  }
  final double scaled;
  switch (match.group(2)?.toUpperCase()) {
    case 'K':
      scaled = base * 1000;
    case 'M':
      scaled = base * 1000 * 1000;
    case 'B':
      scaled = base * 1000 * 1000 * 1000;
    default:
      scaled = base;
  }
  if (!scaled.isFinite || scaled < 0) {
    return 0;
  }
  return scaled;
}
