import 'package:eros_fe/const/const.dart';

String formatSimpleSearch(String simpleSearch) {
  final separator = simpleSearch.indexOf(':');
  if (separator < 0 ||
      !EHConst.translateTagType.containsKey(
        simpleSearch.substring(0, separator).trim(),
      )) {
    return simpleSearch;
  }

  final namespace = simpleSearch.substring(0, separator).trim();
  var name = simpleSearch.substring(separator + 1).trim();
  while (name.length >= 2 && name.startsWith('"') && name.endsWith('"')) {
    name = name.substring(1, name.length - 1).trim();
  }
  if (namespace == 'uploader') {
    name = name.replaceAll('"', r'\"');
  }
  final end = namespace == 'uploader' || name.endsWith(r'$') ? '' : r'$';
  return '$namespace:"$name$end"';
}
