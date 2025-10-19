import 'web_history_helper_stub.dart' if (dart.library.html) 'web_history_helper_web.dart' as impl;

void syncBrowserHistory(
  String location, {
  required bool replace,
  required bool blockBack,
}) {
  impl.syncBrowserHistory(location, replace: replace, blockBack: blockBack);
}
