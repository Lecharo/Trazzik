/// Web/non-IO stub: local filesystem `.env` reading is unavailable in the browser.
/// Use `--dart-define-from-file=.env` when running on Web.
Future<String?> readLocalEnvFileIfPresent([String path = '.env']) async => null;
