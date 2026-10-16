import 'package:eros_fe/generated/l10n.dart';
import 'package:eros_fe/utils/logger.dart';
import 'package:eros_fe/widget/liquid_glass_popup.dart';
import 'package:flutter/cupertino.dart';

Future<String?> showExportProgress(
  BuildContext context,
  Future<String?> Function() createFile, {
  VoidCallback? onCancel,
  void Function(Object error, StackTrace stack)? onError,
}) {
  var started = false;
  return showCupertinoDialog<String?>(
    context: context,
    builder: (dialogContext) {
      if (!started) {
        started = true;
        WidgetsBinding.instance.addPostFrameCallback((_) async {
          if (!dialogContext.mounted) {
            return;
          }
          String? result;
          Object? failure;
          StackTrace? failureStack;
          try {
            result = await createFile();
          } catch (error, stack) {
            failure = error;
            failureStack = stack;
            logger.e('Export file creation failed',
                error: error, stackTrace: stack);
          }
          // Cancellation can remove this route while file creation finishes.
          // Remove only the original dialog, never a later navigation route.
          if (dialogContext.mounted) {
            final route = ModalRoute.of(dialogContext)!;
            if (!route.isActive) {
              return;
            }
            final navigator = Navigator.of(dialogContext);
            if (route.isCurrent) {
              navigator.pop(result);
            } else {
              navigator.removeRoute(route, result);
            }
            if (failure != null) {
              onError?.call(failure, failureStack!);
            }
          }
        });
      }
      return EhAlertDialog(
        title: Text(L10n.of(dialogContext).processing),
        content: const Padding(
          padding: EdgeInsets.only(top: 10),
          child: CupertinoActivityIndicator(radius: 16),
        ),
        actions: [
          CupertinoDialogAction(
            onPressed: () {
              onCancel?.call();
              Navigator.of(dialogContext).pop();
            },
            child: Text(L10n.of(dialogContext).cancel,
                style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    color: CupertinoColors.destructiveRed)),
          ),
        ],
      );
    },
  );
}
