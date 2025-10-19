import 'package:flutter/widgets.dart';
import 'package:go_router/go_router.dart';

import '../../../get_instance/src/bindings_interface.dart';
import '../../../get_state_manager/src/simple/get_state.dart';
import 'get_route.dart';
import 'page_settings.dart';
import 'route_middleware.dart';

class GoRouteAdapter {
  GoRouteAdapter(this.route, {this.parent});

  final GetPage<dynamic> route;
  final GetPage<dynamic>? parent;

  GoRoute toRoute() {
    return GoRoute(
      path: _resolvePath(route, parent: parent),
      name: route.name,
      redirect: (context, state) async {
        final runner = MiddlewareRunner(route.middlewares);
        final result = runner.runRedirect(state.uri.toString());
        return result?.name;
      },
      pageBuilder: (context, state) => buildPage(state),
      routes: route.children
          .map((child) => GoRouteAdapter(child, parent: route).toRoute())
          .toList(growable: false),
    );
  }

  Page<void> buildPage(GoRouterState state) {
    final runner = MiddlewareRunner(route.middlewares);
    final effectiveRoute = runner.runOnPageCalled(route) ?? route;

    final params = <String, String>{
      ...state.pathParameters,
      ...state.uri.queryParameters,
    };

    final pageSettings = PageSettings(state.uri, state.extra);
    pageSettings.params.addAll(params);

    final processedBindings = (runner.runOnBindingsStart(
              effectiveRoute.bindings,
            ) ??
            effectiveRoute.bindings)
        .cast<BindingsInterface>();
    final processedBinds = (runner.runOnBindingsStart(
              effectiveRoute.binds,
            ) ??
            effectiveRoute.binds)
        .cast<Bind>();

    final builder = runner.runOnPageBuildStart(effectiveRoute.page) ?? effectiveRoute.page;
    final widget = runner.runOnPageBuilt(builder());

    return (effectiveRoute.copyWith(
      key: state.pageKey,
      parameters: params,
      arguments: pageSettings,
      bindings: processedBindings,
      binds: processedBinds,
      page: () => widget,
    )) as Page<void>;
  }

  static Page<void> buildNotFoundPage(GoRouterState state) {
    return CustomTransitionPage<void>(
      key: state.pageKey,
      child: const SizedBox.shrink(),
      transitionsBuilder: (context, animation, secondaryAnimation, child) {
        return child;
      },
    );
  }

  String _resolvePath(GetPage page, {GetPage? parent}) {
    final name = page.name;
    if (name == '/') return '/';

    final normalized = name.startsWith('/') ? name.substring(1) : name;
    if (parent == null || parent.name == '/') {
      return normalized;
    }

    final parentName = parent.name.startsWith('/') ? parent.name.substring(1) : parent.name;
    if (normalized.startsWith(parentName)) {
      final relative = normalized.substring(parentName.length);
      if (relative.isEmpty) {
        return '';
      }
      return relative.startsWith('/') ? relative.substring(1) : relative;
    }

    return normalized;
  }
}
