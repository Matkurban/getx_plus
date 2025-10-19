import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:getx_plus/get.dart';
import 'package:go_router/go_router.dart';

import 'go_router_support.dart';
import 'web_history_helper.dart';

class GetDelegate extends RouterDelegate<RouteDecoder>
    with ChangeNotifier, PopNavigatorRouterDelegateMixin<RouteDecoder>, IGetNavigation {
  factory GetDelegate.createDelegate({
    GetPage<dynamic>? notFoundRoute,
    List<GetPage> pages = const [],
    List<NavigatorObserver>? navigatorObservers,
    TransitionDelegate<dynamic>? transitionDelegate,
    PopMode backButtonPopMode = PopMode.history,
    PreventDuplicateHandlingMode preventDuplicateHandlingMode =
        PreventDuplicateHandlingMode.reorderRoutes,
    GlobalKey<NavigatorState>? navigatorKey,
  }) {
    return GetDelegate(
      notFoundRoute: notFoundRoute,
      navigatorObservers: navigatorObservers,
      transitionDelegate: transitionDelegate,
      backButtonPopMode: backButtonPopMode,
      preventDuplicateHandlingMode: preventDuplicateHandlingMode,
      pages: pages,
      navigatorKey: navigatorKey,
    );
  }

  final List<RouteDecoder> _activePages = <RouteDecoder>[];
  final List<GetPage<dynamic>> _rootRoutes = <GetPage<dynamic>>[];
  final PopMode backButtonPopMode;
  final PreventDuplicateHandlingMode preventDuplicateHandlingMode;

  final GetPage notFoundRoute;

  GoRouter? _goRouter;
  bool _routerDirty = true;
  String? _initialLocation;
  bool _isUpdatingRouter = false;

  final List<NavigatorObserver>? navigatorObservers;
  final TransitionDelegate<dynamic>? transitionDelegate;

  final Iterable<GetPage> Function(RouteDecoder currentNavStack)? pickPagesForRootNavigator;

  List<RouteDecoder> get activePages => _activePages;

  final _routeTree = ParseRouteTree(routes: []);

  List<GetPage<dynamic>> get registeredRoutes => List.unmodifiable(_rootRoutes);

  void addPages(List<GetPage> getPages) {
    for (final page in getPages) {
      if (!_rootRoutes.contains(page)) {
        _rootRoutes.add(page);
      }
    }
    _routeTree.addRoutes(getPages);
    _markRouterDirty();
  }

  void clearRouteTree() {
    _rootRoutes.clear();
    _routeTree.routes.clear();
    _markRouterDirty();
  }

  void addPage(GetPage getPage) {
    if (!_rootRoutes.contains(getPage)) {
      _rootRoutes.add(getPage);
    }
    _routeTree.addRoute(getPage);
    _markRouterDirty();
  }

  void removePage(GetPage getPage) {
    _rootRoutes.remove(getPage);
    _routeTree.removeRoute(getPage);
    _markRouterDirty();
  }

  void _markRouterDirty() {
    _routerDirty = true;
    if (_goRouter != null) {
      notifyListeners();
    }
  }

  RouteDecoder matchRoute(String name, {PageSettings? arguments}) {
    return _routeTree.matchRoute(name, arguments: arguments);
  }

  GoRouter get goRouter => _ensureRouter();

  GoRouter _ensureRouter() {
    if (_goRouter == null || _routerDirty) {
      final previous = _goRouter;
      if (previous != null) {
        previous.routerDelegate.removeListener(_handleRouterChanged);
        previous.dispose();
      }
      _goRouter = _buildRouter();
      _routerDirty = false;
    }
    return _goRouter!;
  }

  GoRouter _buildRouter() {
    final routeBases =
        _rootRoutes.map((page) => GoRouteAdapter(page).toRoute()).toList(growable: false);

    if (routeBases.isEmpty) {
      routeBases.add(
        GoRoute(
          path: '/',
          pageBuilder: (context, state) => GoRouteAdapter(notFoundRoute).buildPage(state),
        ),
      );
    }

    final observers = <NavigatorObserver>[HeroController()];
    if (navigatorObservers != null) {
      observers.addAll(navigatorObservers!);
    }

    final initialLocation =
        _initialLocation ?? (_rootRoutes.isNotEmpty ? _rootRoutes.first.name : notFoundRoute.name);

    final router = GoRouter(
      navigatorKey: navigatorKey,
      initialLocation: initialLocation,
      routes: routeBases,
      observers: observers,
      errorPageBuilder: (context, state) => GoRouteAdapter.buildNotFoundPage(state),
      redirect: (context, state) => _handleRedirect(state),
    );

    router.routerDelegate.addListener(_handleRouterChanged);

    return router;
  }

  // GlobalKey<NavigatorState> get navigatorKey => Get.key;

  @override
  GlobalKey<NavigatorState> navigatorKey;

  final String? restorationScopeId;

  GetDelegate({
    GetPage? notFoundRoute,
    this.navigatorObservers,
    this.transitionDelegate,
    this.backButtonPopMode = PopMode.history,
    this.preventDuplicateHandlingMode = PreventDuplicateHandlingMode.reorderRoutes,
    this.pickPagesForRootNavigator,
    this.restorationScopeId,
    bool showHashOnUrl = false,
    GlobalKey<NavigatorState>? navigatorKey,
    required List<GetPage> pages,
  })  : navigatorKey = navigatorKey ?? GlobalKey<NavigatorState>(),
        notFoundRoute = notFoundRoute ??= GetPage(
          name: '/404',
          page: () => const Scaffold(
            body: Center(child: Text('Route not found')),
          ),
        ) {
    if (!showHashOnUrl && GetPlatform.isWeb) setUrlStrategy();
    addPages(pages);
    addPage(notFoundRoute);
    _initialLocation = pages.isNotEmpty ? pages.first.name : notFoundRoute.name;
    _ensureRouter();
    Get.log('GetDelegate is created !');
  }

  @override
  void dispose() {
    final router = _goRouter;
    if (router != null) {
      router.routerDelegate.removeListener(_handleRouterChanged);
      router.dispose();
    }
    super.dispose();
  }

  Future<RouteDecoder?> runMiddleware(RouteDecoder config) async {
    final middlewares = config.currentTreeBranch.last.middlewares;
    if (middlewares.isEmpty) {
      return config;
    }
    var iterator = config;
    for (var item in middlewares) {
      var redirectRes = await item.redirectDelegate(iterator);

      if (redirectRes == null) {
        config.route?.completer?.complete();
        return null;
      }
      if (config != redirectRes) {
        config.route?.completer?.complete();
        Get.log('Redirect to ${redirectRes.pageSettings?.name}');
      }

      iterator = redirectRes;
      // Stop the iteration over the middleware if we changed page
      // and that redirectRes is not the same as the current config.
      if (config != redirectRes) {
        break;
      }
    }
    // If the target is not the same as the source, we need
    // to run the middlewares for the new route.
    if (iterator != config) {
      return await runMiddleware(iterator);
    }
    return iterator;
  }

  Future<void> _unsafeHistoryAdd(RouteDecoder config) async {
    final res = await runMiddleware(config);
    if (res == null) return;
    _activePages.add(res);
  }

  PageSettings _resolvePageSettings(
    RouteDecoder decoder,
    PageSettings fallback,
  ) {
    final existing = decoder.pageSettings;
    if (existing != null) {
      return existing;
    }
    final route = decoder.route;
    if (route != null) {
      final args = route.arguments;
      if (args is PageSettings) {
        return args;
      }
      final uri = Uri.tryParse(route.name) ?? fallback.uri;
      return PageSettings(uri, args);
    }
    return fallback;
  }

  void _updateRouterLocation({RouteDecoder? target, bool replace = false}) {
    final router = _goRouter;
    if (router == null) {
      return;
    }
    final decoder = target ?? (_activePages.isNotEmpty ? _activePages.last : null);
    if (decoder == null) {
      final fallback = _buildPageSettings(notFoundRoute.name);
      _navigate(router, fallback, replace: replace);
      return;
    }

    final fallbackSettings =
        decoder.pageSettings ?? _buildPageSettings(decoder.route?.name ?? notFoundRoute.name);
    final settings = _resolvePageSettings(decoder, fallbackSettings);

    _navigate(router, settings, replace: replace);
  }

  String? _routerLocation(GoRouter router) {
    final information = router.routeInformationProvider.value;
    final uri = information.uri;
    final uriString = uri.toString();
    if (uriString.isNotEmpty) {
      return uriString;
    }
    if (uri.path.isNotEmpty || uri.hasQuery || uri.fragment.isNotEmpty) {
      return uriString;
    }
    return _initialLocation ?? notFoundRoute.name;
  }

  String? _currentLocationName() {
    if (_activePages.isNotEmpty) {
      final top = _activePages.last;
      final fallback =
          top.pageSettings ?? _buildPageSettings(top.route?.name ?? notFoundRoute.name);
      final settings = _resolvePageSettings(top, fallback);
      return settings.name;
    }
    return _initialLocation ?? notFoundRoute.name;
  }

  String? _handleRedirect(GoRouterState state) {
    final desired = _currentLocationName();
    if (desired == null) {
      return null;
    }
    final requested = state.uri.toString();
    if (requested == desired) {
      return null;
    }
    return desired;
  }

  void _handleRouterChanged() {
    if (_isUpdatingRouter) {
      return;
    }
    final router = _goRouter;
    if (router == null) {
      return;
    }
    final desired = _currentLocationName();
    if (desired == null) {
      return;
    }
    final current = _routerLocation(router);
    if (current == desired) {
      return;
    }

    PageSettings settings;
    if (_activePages.isNotEmpty) {
      final top = _activePages.last;
      final fallback =
          top.pageSettings ?? _buildPageSettings(top.route?.name ?? notFoundRoute.name);
      settings = _resolvePageSettings(top, fallback);
    } else {
      settings = _buildPageSettings(desired);
    }

    _isUpdatingRouter = true;
    try {
      router.replace(desired, extra: settings);
      syncBrowserHistory(
        desired,
        replace: true,
        blockBack: _activePages.length <= 1,
      );
    } finally {
      _isUpdatingRouter = false;
    }
  }

  void _navigate(
    GoRouter router,
    PageSettings settings, {
    required bool replace,
  }) {
    final current = _routerLocation(router);
    final shouldNavigate = current != settings.name;
    if (shouldNavigate) {
      _isUpdatingRouter = true;
      try {
        if (replace) {
          router.replace(settings.name, extra: settings);
        } else {
          router.go(settings.name, extra: settings);
        }
      } finally {
        _isUpdatingRouter = false;
      }
    }
    syncBrowserHistory(
      settings.name,
      replace: replace || !shouldNavigate,
      blockBack: _activePages.length <= 1,
    );
  }

  // Future<T?> _unsafeHistoryRemove<T>(RouteDecoder config, T result) async {
  //   var index = _activePages.indexOf(config);
  //   if (index >= 0) return _unsafeHistoryRemoveAt(index, result);
  //   return null;
  // }

  Future<T?> _unsafeHistoryRemoveAt<T>(int index, T result) async {
    if (index == _activePages.length - 1 && _activePages.length > 1) {
      //removing WILL update the current route
      final toCheck = _activePages[_activePages.length - 2];
      final resMiddleware = await runMiddleware(toCheck);
      if (resMiddleware == null) return null;
      _activePages[_activePages.length - 2] = resMiddleware;
    }

    final completer = _activePages.removeAt(index).route?.completer;
    if (completer?.isCompleted == false) completer!.complete(result);

    _updateRouterLocation(replace: true);

    return completer?.future as T?;
  }

  T arguments<T>() {
    return currentConfiguration?.pageSettings?.arguments as T;
  }

  Map<String, String> get parameters {
    return currentConfiguration?.pageSettings?.params ?? {};
  }

  PageSettings? get pageSettings {
    return currentConfiguration?.pageSettings;
  }

  Future<void> _pushHistory(RouteDecoder config) async {
    if (config.route!.preventDuplicates) {
      final originalEntryIndex = _activePages
          .indexWhere((element) => element.pageSettings?.name == config.pageSettings?.name);
      if (originalEntryIndex >= 0) {
        switch (preventDuplicateHandlingMode) {
          case PreventDuplicateHandlingMode.popUntilOriginalRoute:
            popModeUntil(config.pageSettings!.name, popMode: PopMode.page);
            break;
          case PreventDuplicateHandlingMode.reorderRoutes:
            await _unsafeHistoryRemoveAt(originalEntryIndex, null);
            await _unsafeHistoryAdd(config);
            break;
          case PreventDuplicateHandlingMode.doNothing:
          default:
            break;
        }
        return;
      }
    }
    await _unsafeHistoryAdd(config);
  }

  Future<T?> _popHistory<T>(T result) async {
    if (!_canPopHistory()) return null;
    return await _doPopHistory(result);
  }

  Future<T?> _doPopHistory<T>(T result) async {
    return _unsafeHistoryRemoveAt<T>(_activePages.length - 1, result);
  }

  Future<T?> _popPage<T>(T result) async {
    if (!_canPopPage()) return null;
    return await _doPopPage(result);
  }

  // returns the popped page
  Future<T?> _doPopPage<T>(T result) async {
    final currentBranch = currentConfiguration?.currentTreeBranch;
    if (currentBranch != null && currentBranch.length > 1) {
      //remove last part only
      final remaining = currentBranch.take(currentBranch.length - 1);
      final prevHistoryEntry =
          _activePages.length > 1 ? _activePages[_activePages.length - 2] : null;

      //check if current route is the same as the previous route
      if (prevHistoryEntry != null) {
        //if so, pop the entire _activePages entry
        final newLocation = remaining.last.name;
        final prevLocation = prevHistoryEntry.pageSettings?.name;
        if (newLocation == prevLocation) {
          //pop the entire _activePages entry
          return await _popHistory(result);
        }
      }

      //create a new route with the remaining tree branch
      final res = await _popHistory<T>(result);
      await _pushHistory(
        RouteDecoder(
          remaining.toList(),
          null,
          //TOOD: persist state??
        ),
      );
      return res;
    } else {
      //remove entire entry
      return await _popHistory(result);
    }
  }

  Future<T?> _pop<T>(PopMode mode, T result) async {
    switch (mode) {
      case PopMode.history:
        return await _popHistory<T>(result);
      case PopMode.page:
        return await _popPage<T>(result);
    }
  }

  Future<T?> popHistory<T>(T result) async {
    return await _popHistory<T>(result);
  }

  bool _canPopHistory() {
    return _activePages.length > 1;
  }

  Future<bool> canPopHistory() {
    return SynchronousFuture(_canPopHistory());
  }

  bool _canPopPage() {
    final currentTreeBranch = currentConfiguration?.currentTreeBranch;
    if (currentTreeBranch == null) return false;
    return currentTreeBranch.length > 1 ? true : _canPopHistory();
  }

  Future<bool> canPopPage() {
    return SynchronousFuture(_canPopPage());
  }

  bool _canPop(PopMode mode) {
    switch (mode) {
      case PopMode.history:
        return _canPopHistory();
      case PopMode.page:
        return _canPopPage();
    }
  }

  /// gets the visual pages from the current _activePages entry
  ///
  /// visual pages must have [GetPage.participatesInRootNavigator] set to true
  Iterable<GetPage> getVisualPages(RouteDecoder? currentHistory) {
    final res =
        currentHistory!.currentTreeBranch.where((r) => r.participatesInRootNavigator != null);
    if (res.isEmpty) {
      //default behavior, all routes participate in root navigator
      return _activePages.map((e) => e.route!);
    } else {
      //user specified at least one participatesInRootNavigator
      return res.where((element) => element.participatesInRootNavigator == true);
    }
  }

  @override
  Widget build(BuildContext context) {
    _ensureRouter();
    final currentHistory = currentConfiguration;
    final pages = currentHistory == null
        ? <GetPage>[]
        : pickPagesForRootNavigator?.call(currentHistory).toList() ??
            getVisualPages(currentHistory).toList();
    if (pages.isEmpty) {
      return ColoredBox(
        color: Theme.of(context).scaffoldBackgroundColor,
      );
    }
    return GetNavigator(
      key: navigatorKey,
      onPopPage: _onPopVisualRoute,
      pages: pages,
      observers: navigatorObservers,
      transitionDelegate: transitionDelegate ?? const DefaultTransitionDelegate<dynamic>(),
    );
  }

  @override
  Future<void> goToUnknownPage([bool clearPages = false]) async {
    if (clearPages) _activePages.clear();

    final pageSettings = _buildPageSettings(notFoundRoute.name);
    final routeDecoder = _getRouteDecoder(pageSettings);

    _push(routeDecoder!);
  }

  @protected
  void _popWithResult<T>([T? result]) {
    if (_activePages.isEmpty) {
      return;
    }
    final completer = _activePages.removeLast().route?.completer;
    if (completer?.isCompleted == false) completer!.complete(result);
    _updateRouterLocation(replace: true);
  }

  @override
  Future<T?> toNamed<T>(
    String page, {
    dynamic arguments,
    dynamic id,
    bool preventDuplicates = true,
    Map<String, String>? parameters,
  }) async {
    final args = _buildPageSettings(page, arguments);
    final route = _getRouteDecoder<T>(args);
    if (route != null) {
      return _push<T>(route);
    } else {
      goToUnknownPage();
    }
    return null;
  }

  @override
  Future<T?> to<T>(
    Widget Function() page, {
    bool? opaque,
    Transition? transition,
    Curve? curve,
    Duration? duration,
    String? id,
    String? routeName,
    bool fullscreenDialog = false,
    dynamic arguments,
    List<BindingsInterface> bindings = const [],
    bool preventDuplicates = true,
    bool? popGesture,
    bool showCupertinoParallax = true,
    double Function(BuildContext context)? gestureWidth,
    bool rebuildStack = true,
    PreventDuplicateHandlingMode preventDuplicateHandlingMode =
        PreventDuplicateHandlingMode.reorderRoutes,
  }) async {
    routeName ??= _cleanRouteName("/${page.runtimeType}");
    // if (preventDuplicateHandlingMode ==
    //PreventDuplicateHandlingMode.Recreate) {
    //   routeName = routeName + page.hashCode.toString();
    // }

    final getPage = GetPage<T>(
      name: routeName,
      opaque: opaque ?? true,
      page: page,
      gestureWidth: gestureWidth,
      showCupertinoParallax: showCupertinoParallax,
      popGesture: popGesture ?? Get.defaultPopGesture,
      transition: transition ?? Get.defaultTransition,
      curve: curve ?? Get.defaultTransitionCurve,
      fullscreenDialog: fullscreenDialog,
      bindings: bindings,
      transitionDuration: duration ?? Get.defaultTransitionDuration,
      preventDuplicateHandlingMode: preventDuplicateHandlingMode,
    );

    _routeTree.addRoute(getPage);
    final args = _buildPageSettings(routeName, arguments);
    final route = _getRouteDecoder<T>(args);
    final result = await _push<T>(
      route!,
      rebuildStack: rebuildStack,
    );
    _routeTree.removeRoute(getPage);
    return result;
  }

  @override
  Future<T?> off<T>(
    Widget Function() page, {
    bool? opaque,
    Transition? transition,
    Curve? curve,
    Duration? duration,
    String? id,
    String? routeName,
    bool fullscreenDialog = false,
    dynamic arguments,
    List<BindingsInterface> bindings = const [],
    bool preventDuplicates = true,
    bool? popGesture,
    bool showCupertinoParallax = true,
    double Function(BuildContext context)? gestureWidth,
  }) async {
    routeName ??= _cleanRouteName("/${page.runtimeType}");
    final route = GetPage<T>(
      name: routeName,
      opaque: opaque ?? true,
      page: page,
      gestureWidth: gestureWidth,
      showCupertinoParallax: showCupertinoParallax,
      popGesture: popGesture ?? Get.defaultPopGesture,
      transition: transition ?? Get.defaultTransition,
      curve: curve ?? Get.defaultTransitionCurve,
      fullscreenDialog: fullscreenDialog,
      bindings: bindings,
      transitionDuration: duration ?? Get.defaultTransitionDuration,
    );

    final args = _buildPageSettings(routeName, arguments);
    return _replace(args, route);
  }

  @override
  Future<T?>? offAll<T>(
    Widget Function() page, {
    bool Function(GetPage route)? predicate,
    bool opaque = true,
    bool? popGesture,
    String? id,
    String? routeName,
    dynamic arguments,
    List<BindingsInterface> bindings = const [],
    bool fullscreenDialog = false,
    Transition? transition,
    Curve? curve,
    Duration? duration,
    bool showCupertinoParallax = true,
    double Function(BuildContext context)? gestureWidth,
  }) async {
    routeName ??= _cleanRouteName("/${page.runtimeType}");
    final route = GetPage<T>(
      name: routeName,
      opaque: opaque,
      page: page,
      gestureWidth: gestureWidth,
      showCupertinoParallax: showCupertinoParallax,
      popGesture: popGesture ?? Get.defaultPopGesture,
      transition: transition ?? Get.defaultTransition,
      curve: curve ?? Get.defaultTransitionCurve,
      fullscreenDialog: fullscreenDialog,
      bindings: bindings,
      transitionDuration: duration ?? Get.defaultTransitionDuration,
    );

    final args = _buildPageSettings(routeName, arguments);

    final newPredicate = predicate ?? (route) => false;

    while (_activePages.length > 1 && !newPredicate(_activePages.last.route!)) {
      _popWithResult();
    }

    return _replace(args, route);
  }

  @override
  Future<T?>? offAllNamed<T>(
    String newRouteName, {
    // bool Function(GetPage route)? predicate,
    dynamic arguments,
    String? id,
    Map<String, String>? parameters,
  }) async {
    final args = _buildPageSettings(newRouteName, arguments);
    final route = _getRouteDecoder<T>(args);
    if (route == null) return null;

    while (_activePages.length > 1) {
      _popWithResult();
    }

    return _replaceNamed(route);
  }

  @override
  Future<T?>? offNamedUntil<T>(
    String page, {
    bool Function(GetPage route)? predicate,
    dynamic arguments,
    String? id,
    Map<String, String>? parameters,
  }) async {
    final args = _buildPageSettings(page, arguments);
    final route = _getRouteDecoder<T>(args);
    if (route == null) return null;

    final newPredicate = predicate ?? (route) => false;

    while (_activePages.length > 1 && !newPredicate(_activePages.last.route!)) {
      _popWithResult();
    }

    return _push(route);
  }

  @override
  Future<T?> offNamed<T>(
    String page, {
    dynamic arguments,
    String? id,
    Map<String, String>? parameters,
  }) async {
    final args = _buildPageSettings(page, arguments);
    final route = _getRouteDecoder<T>(args);
    if (route == null) return null;
    _popWithResult();
    return _push<T>(route);
  }

  @override
  Future<T?> toNamedAndOffUntil<T>(
    String page,
    bool Function(GetPage) predicate, [
    Object? data,
  ]) async {
    final arguments = _buildPageSettings(page, data);

    final route = _getRouteDecoder<T>(arguments);

    if (route == null) return null;

    while (_activePages.isNotEmpty && !predicate(_activePages.last.route!)) {
      _popWithResult();
    }

    return _push<T>(route);
  }

  @override
  Future<T?> offUntil<T>(
    Widget Function() page,
    bool Function(GetPage) predicate, [
    Object? arguments,
  ]) async {
    while (_activePages.isNotEmpty && !predicate(_activePages.last.route!)) {
      _popWithResult();
    }

    return to<T>(page, arguments: arguments);
  }

  @override
  void removeRoute<T>(String name) {
    _activePages.remove(RouteDecoder.fromRoute(name));
  }

  bool get canBack {
    return _activePages.length > 1;
  }

  void _checkIfCanBack() {
    assert(() {
      if (!canBack) {
        final last = _activePages.last;
        final name = last.route?.name;
        throw 'The page $name cannot be popped';
      }
      return true;
    }());
  }

  @override
  Future<R?> backAndtoNamed<T, R>(String page, {T? result, Object? arguments}) async {
    final args = _buildPageSettings(page, arguments);
    final route = _getRouteDecoder<R>(args);
    if (route == null) return null;
    _popWithResult<T>(result);
    return _push<R>(route);
  }

  /// Removes routes according to [PopMode]
  /// until it reaches the specific [fullRoute],
  /// DOES NOT remove the [fullRoute]
  @override
  Future<void> popModeUntil(
    String fullRoute, {
    PopMode popMode = PopMode.history,
  }) async {
    // remove history or page entries until you meet route
    var iterator = currentConfiguration;
    while (_canPop(popMode) && iterator != null) {
      //the next line causes wasm compile error if included in the while loop
      //https://github.com/flutter/flutter/issues/140110
      if (iterator.pageSettings?.name == fullRoute) {
        break;
      }
      await _pop(popMode, null);
      // replace iterator
      iterator = currentConfiguration;
    }
    notifyListeners();
  }

  @override
  void backUntil(bool Function(GetPage) predicate) {
    while (_activePages.length > 1 && !predicate(_activePages.last.route!)) {
      _popWithResult();
    }

    notifyListeners();
  }

  Future<T?> _replace<T>(PageSettings arguments, GetPage<T> page) async {
    final index = _activePages.length > 1 ? _activePages.length - 1 : 0;
    _routeTree.addRoute(page);

    final activePage = _getRouteDecoder(arguments);

    // final activePage = _configureRouterDecoder<T>(route!, arguments);

    _activePages[index] = activePage!;

    notifyListeners();
    _updateRouterLocation(target: activePage, replace: true);
    final result = await activePage.route?.completer?.future as Future<T?>?;
    _routeTree.removeRoute(page);

    return result;
  }

  Future<T?> _replaceNamed<T>(RouteDecoder activePage) async {
    final index = _activePages.length > 1 ? _activePages.length - 1 : 0;
    // final activePage = _configureRouterDecoder<T>(page, arguments);
    _activePages[index] = activePage;

    notifyListeners();
    _updateRouterLocation(target: activePage, replace: true);
    final result = await activePage.route?.completer?.future as Future<T?>?;
    return result;
  }

  /// Takes a route [name] String generated by [to], [off], [offAll]
  /// (and similar context navigation methods), cleans the extra chars and
  /// accommodates the format.
  /// TODO: check for a more "appealing" URL naming convention.
  /// `() => MyHomeScreenView` becomes `/my-home-screen-view`.
  String _cleanRouteName(String name) {
    name = name.replaceAll('() => ', '');

    /// uncomment for URL styling.
    // name = name.paramCase!;
    if (!name.startsWith('/')) {
      name = '/$name';
    }
    return Uri.tryParse(name)?.toString() ?? name;
  }

  PageSettings _buildPageSettings(String page, [Object? data]) {
    var uri = Uri.parse(page);
    return PageSettings(uri, data);
  }

  @protected
  RouteDecoder? _getRouteDecoder<T>(PageSettings arguments) {
    var page = arguments.uri.path;
    final parameters = arguments.params;
    if (parameters.isNotEmpty) {
      final uri = Uri(path: page, queryParameters: parameters);
      page = uri.toString();
    }

    final decoder = _routeTree.matchRoute(page, arguments: arguments);
    final route = decoder.route;
    if (route == null) return null;

    return _configureRouterDecoder<T>(decoder, arguments);
  }

  @protected
  RouteDecoder _configureRouterDecoder<T>(
    RouteDecoder decoder,
    PageSettings arguments, {
    bool attachCompleter = true,
  }) {
    final parameters = arguments.params.isEmpty ? arguments.query : arguments.params;
    arguments.params.addAll(arguments.query);
    if (decoder.parameters.isEmpty) {
      decoder.parameters.addAll(parameters);
    }

    decoder.route = decoder.route?.copyWith(
      completer: attachCompleter && _activePages.isNotEmpty ? Completer<T?>() : null,
      arguments: arguments,
      parameters: parameters,
      key: ValueKey(arguments.name),
    );

    return decoder;
  }

  Future<T?> _push<T>(RouteDecoder decoder, {bool rebuildStack = true}) async {
    var res = await runMiddleware(decoder);
    if (res == null) return null;
    // final res = mid ?? decoder;
    // if (res == null) res = decoder;

    final preventDuplicateHandlingMode =
        res.route?.preventDuplicateHandlingMode ?? PreventDuplicateHandlingMode.reorderRoutes;

    final onStackPage =
        _activePages.firstWhereOrNull((element) => element.route?.key == res.route?.key);

    /// There are no duplicate routes in the stack
    if (onStackPage == null) {
      _activePages.add(res);
    } else {
      /// There are duplicate routes, reorder
      switch (preventDuplicateHandlingMode) {
        case PreventDuplicateHandlingMode.doNothing:
          break;
        case PreventDuplicateHandlingMode.reorderRoutes:
          _activePages.remove(onStackPage);
          _activePages.add(res);
          break;
        case PreventDuplicateHandlingMode.popUntilOriginalRoute:
          while (_activePages.last == onStackPage) {
            _popWithResult();
          }
          break;
        case PreventDuplicateHandlingMode.recreate:
          _activePages.remove(onStackPage);
          _activePages.add(res);
      }
    }
    if (rebuildStack) {
      notifyListeners();
    }
    final router = goRouter;
    final pageSettings = res.pageSettings ??
        decoder.pageSettings ??
        _buildPageSettings(res.route?.name ?? decoder.pageSettings?.name ?? '/');
    final location = pageSettings.name;

    final future = router.push<T>(location, extra: pageSettings);
    syncBrowserHistory(
      location,
      replace: true,
      blockBack: _activePages.length <= 1,
    );
    final completer = res.route?.completer;
    if (completer != null && !completer.isCompleted) {
      future.then((value) {
        if (!completer.isCompleted) {
          completer.complete(value);
        }
      }, onError: (error, stackTrace) {
        if (!completer.isCompleted) {
          completer.completeError(error, stackTrace);
        }
      });
      return completer.future as Future<T?>?;
    }
    return future;
  }

  @override
  Future<void> setNewRoutePath(RouteDecoder configuration) async {
    final page = configuration.route;
    if (page == null) {
      goToUnknownPage();
      return;
    } else {
      _push(configuration);
    }
  }

  @override
  RouteDecoder? get currentConfiguration {
    if (_activePages.isEmpty) return null;
    final route = _activePages.last;
    return route;
  }

  Future<bool> handlePopupRoutes({
    Object? result,
  }) async {
    Route? currentRoute;
    navigatorKey.currentState!.popUntil((route) {
      currentRoute = route;
      return true;
    });
    if (currentRoute is PopupRoute) {
      return await navigatorKey.currentState!.maybePop(result);
    }
    return false;
  }

  @override
  Future<bool> popRoute({
    Object? result,
    PopMode? popMode,
  }) async {
    //Returning false will cause the entire app to be popped.
    final wasPopup = await handlePopupRoutes(result: result);
    if (wasPopup) return true;

    if (_canPop(popMode ?? backButtonPopMode)) {
      await _pop(popMode ?? backButtonPopMode, result);
      notifyListeners();
      return true;
    }
    if (GetPlatform.isWeb && _activePages.isNotEmpty) {
      _updateRouterLocation(target: _activePages.last, replace: true);
      return SynchronousFuture(true);
    }

    return super.popRoute();
  }

  @override
  void back<T>([T? result]) {
    _checkIfCanBack();
    _popWithResult<T>(result);
    notifyListeners();
  }

  bool _onPopVisualRoute(Route<dynamic> route, dynamic result) {
    final didPop = route.didPop(result);
    if (!didPop) {
      return false;
    }
    _popWithResult(result);
    // final settings = route.settings;
    // if (settings is GetPage) {
    //   final config = _activePages.cast<RouteDecoder?>().firstWhere(
    //         (element) => element?.route == settings,
    //         orElse: () => null,
    //       );
    //   if (config != null) {
    //     _removeHistoryEntry(config, result);
    //   }
    // }
    notifyListeners();
    //return !route.navigator!.userGestureInProgress;
    return true;
  }
}
