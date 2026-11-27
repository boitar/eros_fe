import 'package:flutter/foundation.dart';

/// Ranking period reported on E-Hentai's `stats.php`.
enum GalleryStatsPeriod {
  allTime,
  year,
  month,
  day,
}

/// Time bucket granularity for historical visit/hit series.
enum GalleryStatsGranularity {
  yearly,
  monthly,
  daily,
}

/// Series metric displayed in the historical trend chart.
enum GalleryStatsMetric {
  visits,
  hits,
}

/// Structured failure reason when fetching or parsing `stats.php`.
enum GalleryStatsErrorKind {
  loginRequired,
  unavailable,
  network,
}

@immutable
class GalleryStatsException implements Exception {
  const GalleryStatsException(this.kind, [this.message]);

  final GalleryStatsErrorKind kind;
  final String? message;

  @override
  String toString() =>
      'GalleryStatsException(kind: $kind${message != null ? ', message: $message' : ''})';
}

@immutable
class GalleryRankingEntry {
  const GalleryRankingEntry({
    required this.period,
    this.ranking,
    this.score,
  });

  final GalleryStatsPeriod period;
  final int? ranking;
  final int? score;

  bool get isRanked => ranking != null && ranking! > 0;
}

@immutable
class GalleryVisitStat {
  const GalleryVisitStat({
    required this.period,
    required this.visits,
    required this.hits,
  });

  /// Raw label from `stats.php`, e.g. `2025`, `June`, `14th`.
  final String period;

  /// Approximate visit count (expanded from `K`/`M`/`B` suffixes if present).
  final double visits;

  /// Approximate hit count (expanded from `K`/`M`/`B` suffixes if present).
  final double hits;

  double valueFor(GalleryStatsMetric metric) =>
      metric == GalleryStatsMetric.visits ? visits : hits;
}

@immutable
class GalleryStats {
  const GalleryStats({
    this.totalVisits,
    this.allTimeRanking,
    this.allTimeScore,
    this.yearRanking,
    this.yearScore,
    this.monthRanking,
    this.monthScore,
    this.dayRanking,
    this.dayScore,
    this.yearlyStats = const <GalleryVisitStat>[],
    this.monthlyStats = const <GalleryVisitStat>[],
    this.dailyStats = const <GalleryVisitStat>[],
  });

  /// Total visit count reported on `stats.php`, or `null` if absent from the
  /// response. An explicit `0` indicates the site reported zero visits.
  final int? totalVisits;

  final int? allTimeRanking;
  final int? allTimeScore;
  final int? yearRanking;
  final int? yearScore;
  final int? monthRanking;
  final int? monthScore;
  final int? dayRanking;
  final int? dayScore;

  final List<GalleryVisitStat> yearlyStats;
  final List<GalleryVisitStat> monthlyStats;
  final List<GalleryVisitStat> dailyStats;

  List<GalleryRankingEntry> get rankings => <GalleryRankingEntry>[
    GalleryRankingEntry(
      period: GalleryStatsPeriod.allTime,
      ranking: allTimeRanking,
      score: allTimeScore,
    ),
    GalleryRankingEntry(
      period: GalleryStatsPeriod.year,
      ranking: yearRanking,
      score: yearScore,
    ),
    GalleryRankingEntry(
      period: GalleryStatsPeriod.month,
      ranking: monthRanking,
      score: monthScore,
    ),
    GalleryRankingEntry(
      period: GalleryStatsPeriod.day,
      ranking: dayRanking,
      score: dayScore,
    ),
  ];

  bool get hasTotalVisits => totalVisits != null && totalVisits! >= 0;

  bool get hasAnyRanking => rankings.any((entry) => entry.isRanked);

  bool get hasAnyChartData =>
      yearlyStats.isNotEmpty ||
      monthlyStats.isNotEmpty ||
      dailyStats.isNotEmpty;

  bool get isEmpty => !hasTotalVisits && !hasAnyRanking && !hasAnyChartData;

  List<GalleryVisitStat> seriesFor(GalleryStatsGranularity granularity) {
    switch (granularity) {
      case GalleryStatsGranularity.yearly:
        return yearlyStats;
      case GalleryStatsGranularity.monthly:
        return monthlyStats;
      case GalleryStatsGranularity.daily:
        return dailyStats;
    }
  }

  GalleryStatsGranularity get defaultGranularity {
    if (monthlyStats.isNotEmpty) {
      return GalleryStatsGranularity.monthly;
    }
    if (dailyStats.isNotEmpty) {
      return GalleryStatsGranularity.daily;
    }
    return GalleryStatsGranularity.yearly;
  }

  /// Favorite-to-visit ratio in `[0, 1]` when both figures are valid.
  double? favoriteRate(int? favoriteCount) {
    final visits = totalVisits;
    if (favoriteCount == null ||
        favoriteCount < 0 ||
        visits == null ||
        visits <= 0) {
      return null;
    }
    final rate = favoriteCount / visits;
    if (!rate.isFinite) {
      return null;
    }
    return rate.clamp(0.0, 1.0);
  }

  /// Historical average visits per day derived from E-Hentai's UTC `postTime`
  /// (`YYYY-MM-DD HH:mm` or `YYYY-MM-DD`). Returns null if under 24 hours old
  /// or when [postTime] cannot be parsed.
  double? averageDailyVisits(String? postTime, {DateTime? nowUtc}) {
    final visits = totalVisits;
    if (visits == null || visits <= 0 || postTime == null) {
      return null;
    }
    final postedUtc = parseEhPostTimeUtc(postTime);
    if (postedUtc == null) {
      return null;
    }
    final reference = (nowUtc ?? DateTime.now().toUtc()).toUtc();
    final elapsedHours = reference.difference(postedUtc).inHours;
    if (elapsedHours < 24) {
      return null;
    }
    final elapsedDays = elapsedHours / 24.0;
    return visits / elapsedDays;
  }
}

final RegExp _ehPostTimePattern = RegExp(
  r'^(\d{4})-(\d{2})-(\d{2})(?:[ T](\d{2}):(\d{2})(?::(\d{2}))?)?',
);

/// Parses E-Hentai's `postTime` string (UTC) into a UTC [DateTime].
DateTime? parseEhPostTimeUtc(String raw) {
  final match = _ehPostTimePattern.firstMatch(raw.trim());
  if (match == null) {
    return null;
  }
  final year = int.tryParse(match.group(1)!);
  final month = int.tryParse(match.group(2)!);
  final day = int.tryParse(match.group(3)!);
  final hour = int.tryParse(match.group(4) ?? '0') ?? 0;
  final minute = int.tryParse(match.group(5) ?? '0') ?? 0;
  final second = int.tryParse(match.group(6) ?? '0') ?? 0;
  if (year == null || month == null || day == null) {
    return null;
  }
  if (month < 1 || month > 12 || day < 1 || day > 31) {
    return null;
  }
  return DateTime.utc(year, month, day, hour, minute, second);
}
