import 'package:eros_fe/adaptive/native_sheet.dart';
import 'package:eros_fe/common/service/controller_tag_service.dart';
import 'package:eros_fe/common/service/theme_service.dart';
import 'package:eros_fe/const/eh_palette.dart';
import 'package:eros_fe/generated/l10n.dart';
import 'package:eros_fe/pages/gallery/controller/rate_controller.dart';
import 'package:eros_fe/utils/logger.dart';
import 'package:eros_fe/utils/toast.dart';
import 'package:eros_fe/utils/vibrate.dart';
import 'package:eros_fe/widget/eh_buttons.dart';
import 'package:eros_fe/widget/eh_sheet.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter_rating_bar/flutter_rating_bar.dart';
import 'package:get/get.dart';

double _snap(double value) => ((value * 2).round() / 2).clamp(0.5, 5.0);

String? _summary(BuildContext context, RateController controller) {
  final provider = controller.pageController.gState.galleryProvider;
  final average = provider?.rating;
  final count = provider?.ratingCount?.trim() ?? '';
  if (average == null || average <= 0 || count.isEmpty) {
    return null;
  }
  return L10n.of(context).sp_rating_summary(average.toStringAsFixed(2), count);
}

Future<void> _submit(RateController controller, double rating) async {
  controller.rate = rating;
  try {
    await controller.rating();
  } catch (e, stack) {
    logger.e('rating error', error: e, stackTrace: stack);
    showToast('$e');
  }
}

/// Star rating with half steps; UIKit sheet with native glass, otherwise the
/// same layout drawn by Flutter.
Future<void> showRateDialog(BuildContext context) async {
  final RateController controller = Get.find(tag: pageCtrlTag);
  final chosen = await presentRateSheet(
    context,
    initial: controller.rate,
    summary: _summary(context, controller),
  );
  if (chosen != null) {
    await _submit(controller, chosen);
  }
}

/// Presents the rating sheet and returns the chosen rating, or null.
Future<double?> presentRateSheet(
  BuildContext context, {
  required double initial,
  String? summary,
}) async {
  final l10n = L10n.of(context);
  final start = _snap(initial);
  if (NativeSheet.available) {
    double? chosen;
    final session = await NativeSheet.present(
      kind: 'rate',
      config: {
        ...NativeSheet.style(context),
        'title': l10n.p_Rate,
        'submit': l10n.sp_rate_submit,
        'rating': start,
        'summary': summary ?? '',
      },
      onEvent: (_, name, value) {
        if (name == 'submit' && value is num) {
          chosen = value.toDouble();
        }
      },
    );
    if (session != null) {
      await session.closed;
      return chosen;
    }
  }
  if (!context.mounted) {
    return null;
  }
  return showEhSheet<double>(
    context: context,
    builder: (_) => _RateSheet(initial: start, summary: summary),
  );
}

class _RateSheet extends StatefulWidget {
  const _RateSheet({required this.initial, this.summary});

  final double initial;
  final String? summary;

  @override
  State<_RateSheet> createState() => _RateSheetState();
}

class _RateSheetState extends State<_RateSheet> {
  late double _rating = widget.initial;

  @override
  Widget build(BuildContext context) {
    final l10n = L10n.of(context);
    final palette = ehTheme.palette;
    final base = CupertinoTheme.of(context).textTheme.textStyle.copyWith(
      letterSpacing: 0,
      fontFeatures: const [FontFeature.tabularFigures()],
    );
    return SingleChildScrollView(
      child: Padding(
        padding: const EdgeInsets.only(bottom: 20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            EhSheetHeader(title: l10n.p_Rate),
            const SizedBox(height: 16),
            Semantics(
              label: l10n.p_Rate,
              value: '${_rating.toStringAsFixed(1)} / 5',
              child: RatingBar.builder(
                initialRating: widget.initial,
                minRating: 0.5,
                glow: false,
                allowHalfRating: true,
                itemCount: 5,
                itemSize: 40,
                itemPadding: const EdgeInsets.symmetric(horizontal: 4),
                unratedColor: palette.fillPressed.resolveFrom(context),
                itemBuilder: (_, _) => Icon(
                  CupertinoIcons.star_fill,
                  color: EhPalette.star.resolveFrom(context),
                ),
                onRatingUpdate: (value) {
                  // 每变动一档（含半星）一记 selection 轻点，跟手。
                  vibrateUtil.selection();
                  setState(() => _rating = value);
                },
              ),
            ),
            const SizedBox(height: 10),
            Text.rich(
              TextSpan(
                text: _rating.toStringAsFixed(1),
                style: base.copyWith(
                  fontSize: 44,
                  fontWeight: FontWeight.w600,
                  color: palette.text1.resolveFrom(context),
                ),
                children: [
                  TextSpan(
                    text: ' / 5',
                    style: base.copyWith(
                      fontSize: 17,
                      fontWeight: FontWeight.w500,
                      color: palette.text2.resolveFrom(context),
                    ),
                  ),
                ],
              ),
            ),
            if (widget.summary != null)
              Text(
                widget.summary!,
                style: base.copyWith(
                  fontSize: 13,
                  fontWeight: FontWeight.w500,
                  color: palette.text2.resolveFrom(context),
                ),
              ),
            const SizedBox(height: 22),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: EhButton(
                label: l10n.sp_rate_submit,
                style: EhButtonStyle.prominent,
                size: 52,
                expand: true,
                onPressed: _rating == widget.initial
                    ? null
                    : () => Navigator.of(context).pop(_rating),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
