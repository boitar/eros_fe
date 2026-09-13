import 'package:eros_fe/const/theme_colors.dart';
import 'package:flutter/widgets.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';

/// The visibility and color must always come from the same category value.
class FavoriteIcon extends StatelessWidget {
  const FavoriteIcon({super.key, required this.category, this.size = 12});
  final String category;
  final double size;

  @override
  Widget build(BuildContext context) {
    final color = ThemeColors.favColor[category];
    if (color == null) return const SizedBox.shrink();
    return FaIcon(FontAwesomeIcons.solidHeart, color: color, size: size);
  }
}
