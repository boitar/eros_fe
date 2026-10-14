import 'dart:convert';
import 'dart:io';

import 'package:eros_fe/common/global.dart';
import 'package:flutter/cupertino.dart';
import 'package:path/path.dart' as path;
import 'package:path_provider/path_provider.dart';

import 'download_recovery_scenarios.dart';

/// Isolated Simulator regression entry point; never reads user gallery data.
Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final documents = await getApplicationDocumentsDirectory();
  final reportRoot =
      Directory(path.join(documents.path, 'download-recovery-validation'));
  await reportRoot.create(recursive: true);
  final root = Directory(path.join(
      reportRoot.path, 'run-${DateTime.now().millisecondsSinceEpoch}'));
  await root.create(recursive: true);
  final db = Directory(path.join(root.path, 'db'));
  await db.create(recursive: true);
  Global.appDocPath = documents.path;
  Global.appSupportPath = db.path;
  final report = <String, dynamic>{
    'platform': Platform.operatingSystem,
    'dataRoot': root.path
  };
  try {
    await isarHelper.initIsar();
    report['passed'] = await runDownloadRecoveryScenarios(root, isarHelper);
    report['success'] = true;
  } on Object catch (error, stack) {
    report['success'] = false;
    report['error'] = '$error';
    report['stack'] = '$stack';
  }
  await File(path.join(reportRoot.path, 'result.json'))
      .writeAsString(const JsonEncoder.withIndent('  ').convert(report));
  runApp(CupertinoApp(
      home: CupertinoPageScaffold(
    navigationBar: const CupertinoNavigationBar(
        middle: Text('Download recovery regression')),
    child: SafeArea(
        child: Padding(
      padding: const EdgeInsets.all(20),
      child: SingleChildScrollView(
          child: Text(
        const JsonEncoder.withIndent('  ').convert(report),
      )),
    )),
  )));
}
