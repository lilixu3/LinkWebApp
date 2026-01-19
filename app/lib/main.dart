import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'src/app.dart';
import 'src/core/app_logger.dart';
import 'src/core/app_state.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  FlutterError.onError = (details) {
    FlutterError.presentError(details);
    log.e('FlutterError', error: details.exception, stackTrace: details.stack);
  };

  runZonedGuarded(() async {
    final state = await AppState.load();

    runApp(
      ChangeNotifierProvider.value(
        value: state,
        child: const LinkWebApp(),
      ),
    );
  }, (error, stack) {
    log.e('Uncaught zone error', error: error, stackTrace: stack);
    if (kDebugMode) {
      // ignore: avoid_print
      print(error);
    }
  });
}
