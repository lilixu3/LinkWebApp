import 'package:logger/logger.dart';

final log = Logger(
  printer: PrettyPrinter(
    methodCount: 0,
    errorMethodCount: 5,
    lineLength: 100,
    colors: false,
    printEmojis: true,
    // `printTime` is deprecated in newer logger versions.
    dateTimeFormat: DateTimeFormat.onlyTimeAndSinceStart,
  ),
);
