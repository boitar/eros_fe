import 'package:eros_fe/widget/appkit_interaction.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_smart_dialog/flutter_smart_dialog.dart';

/// Entry points for SmartDialog overlays that block interaction. The content
/// lease follows the actual overlay lifetime, including its exit animation.
/// Deliberately keep penetrating action toasts outside this API.
abstract final class AppModal {
  static Future<T?> showLoading<T>({
    required WidgetBuilder builder,
    SmartBackType? backType,
  }) => SmartDialog.showLoading<T>(
    builder: (context) => AppKitModalContent(child: builder(context)),
    backType: backType,
  );

  static Future<T?> showAttach<T>({
    required BuildContext targetContext,
    required WidgetBuilder builder,
    Positioned Function(Offset, Size)? highlightBuilder,
    String? tag,
    bool? keepSingle,
    VoidCallback? onDismiss,
  }) => SmartDialog.showAttach<T>(
    targetContext: targetContext,
    builder: (context) => AppKitModalContent(child: builder(context)),
    highlightBuilder: highlightBuilder,
    tag: tag,
    keepSingle: keepSingle,
    onDismiss: onDismiss,
  );
}
