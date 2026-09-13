import 'package:eros_fe/models/base/eh_models.dart';
import 'package:html/parser.dart' show parse;

FavAdd parserAddFavPage(String? response) {
  final document = parse(response);
  final root = document.querySelector('#galpop');
  if (root == null) throw const FormatException('Invalid favorite popup');
  final categories = <Favcat>[];
  String? selected;
  final inputs = root.querySelectorAll('input[name="favcat"]');
  for (final input in inputs) {
    final id = input.attributes['value'] ?? '';
    if (!RegExp(r'^[0-9]$').hasMatch(id)) continue;
    final row = input.parent?.parent;
    final title = row != null && row.children.length >= 3
        ? row.children[2].text.trim()
        : '';
    categories.add(Favcat(favId: id, favTitle: title));
    if (input.attributes.containsKey('checked')) {
      if (selected != null)
        throw const FormatException('Multiple favorites selected');
      selected = id;
    }
  }
  if (categories.length != 10 ||
      categories.map((category) => category.favId).toSet().length != 10) {
    throw const FormatException('Incomplete favorite categories');
  }
  return FavAdd(
    favcats: categories,
    usedNoteSlots: '1',
    maxNoteSlots: '100',
    favNote: root.querySelector('textarea')?.text.trim(),
    selectFavcat: selected,
  );
}
