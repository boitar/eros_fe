import 'package:flutter/foundation.dart';

const Set<String> _kAllowedEhHosts = <String>{
  'e-hentai.org',
  'exhentai.org',
};

final RegExp _kGalleryPathPattern = RegExp(
  r'^/g/(\d+)/([0-9a-fA-F]{10})(?:/.*)?$',
);

bool isAllowedEhHost(String host) =>
    _kAllowedEhHosts.contains(host.trim().toLowerCase());

/// Resolves an E-Hentai/ExHentai gallery link (absolute, protocol-relative,
/// `/g/...`, or `g/...`) against [baseUri] and validates scheme, host, and path.
Uri? resolveEhGalleryUri(String? rawUrl, {Uri? baseUri}) {
  final trimmed = rawUrl?.trim() ?? '';
  if (trimmed.isEmpty) {
    return null;
  }

  Uri? parsed;
  if (trimmed.startsWith('//')) {
    parsed = Uri.tryParse('https:$trimmed');
  } else {
    parsed = Uri.tryParse(trimmed);
  }
  if (parsed == null) {
    return null;
  }

  final fallbackBase =
      (baseUri != null &&
          (baseUri.scheme == 'https' || baseUri.scheme == 'http') &&
          isAllowedEhHost(baseUri.host))
      ? Uri(scheme: 'https', host: baseUri.host.toLowerCase())
      : null;

  Uri resolved;
  if (parsed.hasScheme) {
    final scheme = parsed.scheme.toLowerCase();
    if ((scheme != 'https' && scheme != 'http') ||
        !isAllowedEhHost(parsed.host)) {
      return null;
    }
    resolved = parsed;
  } else if (parsed.host.isNotEmpty) {
    if (!isAllowedEhHost(parsed.host)) {
      return null;
    }
    resolved = parsed.replace(scheme: 'https');
  } else {
    final normalizedPath = parsed.path.startsWith('/')
        ? parsed.path
        : '/${parsed.path}';
    if (!_kGalleryPathPattern.hasMatch(normalizedPath)) {
      return null;
    }
    if (fallbackBase != null) {
      resolved = fallbackBase.replace(path: normalizedPath);
    } else {
      resolved = Uri(path: normalizedPath);
    }
  }

  final match = _kGalleryPathPattern.firstMatch(resolved.path);
  if (match == null) {
    return null;
  }
  final gid = match.group(1)!;
  final token = match.group(2)!.toLowerCase();
  final canonicalPath = '/g/$gid/$token/';

  if (resolved.hasScheme && isAllowedEhHost(resolved.host)) {
    return Uri(
      scheme: resolved.scheme.toLowerCase(),
      host: resolved.host.toLowerCase(),
      path: canonicalPath,
    );
  }
  return Uri(path: canonicalPath);
}

/// Parses `(gid, token)` from a validated E-Hentai/ExHentai gallery URL or path.
(String, String)? parseGalleryGidToken(String? rawUrl, {Uri? baseUri}) {
  final resolved = resolveEhGalleryUri(rawUrl, baseUri: baseUri);
  if (resolved == null) {
    return null;
  }
  final match = _kGalleryPathPattern.firstMatch(resolved.path);
  if (match == null) {
    return null;
  }
  return (match.group(1)!, match.group(2)!.toLowerCase());
}

@immutable
class GalleryNewerVersion {
  const GalleryNewerVersion({
    required this.gid,
    required this.token,
    required this.url,
    required this.title,
    this.addedDate,
  });

  factory GalleryNewerVersion.fromJson(Map<String, dynamic> json) =>
      GalleryNewerVersion(
        gid: json['gid']?.toString() ?? '',
        token: json['token']?.toString() ?? '',
        url: json['url']?.toString() ?? '',
        title: json['title']?.toString() ?? '',
        addedDate: json['addedDate']?.toString(),
      );

  final String gid;
  final String token;
  final String url;
  final String title;
  final String? addedDate;

  int get gidInt => int.tryParse(gid) ?? 0;

  /// Date portion (`YYYY-MM-DD`) for compact subtitles.
  String get shortDate {
    final raw = addedDate?.trim() ?? '';
    if (raw.isEmpty) {
      return '';
    }
    return raw.split(' ').first;
  }

  /// Month-day portion (`MM-dd`) when [shortDate] is `YYYY-MM-DD`, else [shortDate].
  String get shortMonthDay {
    final date = shortDate;
    if (date.length >= 10 && date[4] == '-' && date[7] == '-') {
      return date.substring(5, 10);
    }
    return date;
  }

  Map<String, dynamic> toJson() => <String, dynamic>{
    'gid': gid,
    'token': token,
    'url': url,
    'title': title,
    if (addedDate != null) 'addedDate': addedDate,
  };

  GalleryNewerVersion clone() => GalleryNewerVersion(
    gid: gid,
    token: token,
    url: url,
    title: title,
    addedDate: addedDate,
  );

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is GalleryNewerVersion &&
          gid == other.gid &&
          token == other.token &&
          url == other.url &&
          title == other.title &&
          addedDate == other.addedDate;

  @override
  int get hashCode => Object.hash(gid, token, url, title, addedDate);
}
