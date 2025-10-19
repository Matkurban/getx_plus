import 'package:web/web.dart' as web;

class _HistoryController {
  _HistoryController();

  bool _blockBack = false;
  bool _initialized = false;

  void _ensureListener() {
    if (_initialized) {
      return;
    }
    _initialized = true;
    web.window.onPopState.listen((event) {
      if (!_blockBack) {
        return;
      }
      final current = web.window.location.href;
      web.window.history.pushState(null, '', current);
    });
  }

  void update(
    String location, {
    required bool replace,
    required bool blockBack,
  }) {
    _ensureListener();
    _blockBack = blockBack;

    final resolved = _resolveHref(location);
    if (replace) {
      web.window.history.replaceState(null, '', resolved);
    } else {
      web.window.history.pushState(null, '', resolved);
    }
  }

  String _resolveHref(String location) {
    return Uri.base.resolve(location).toString();
  }
}

final _HistoryController _controller = _HistoryController();

void syncBrowserHistory(
  String location, {
  required bool replace,
  required bool blockBack,
}) {
  _controller.update(location, replace: replace, blockBack: blockBack);
}
