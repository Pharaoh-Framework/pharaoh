part of '../router.dart';

enum RouteDefinitionType { route, group, middleware }

class RouteMapping {
  final List<HTTPMethod> methods;
  final String _path;

  @visibleForTesting
  String get stringVal => '${methods.map((e) => e.name).toList()}: $_path';

  String get path => _path;

  const RouteMapping(this.methods, this._path);

  RouteMapping prefix(String prefix) {
    final newPath = prefix == BASE_PATH
        ? _path
        : _path == BASE_PATH
            ? prefix
            : '$prefix$_path';
    return RouteMapping(methods, newPath);
  }
}

typedef OpenApiRoute = ({
  List<String> tags,
  Type? returnType,
  HTTPMethod method,
  String route,
  List<ControllerMethodParam> args,
});

abstract class RouteDefinition {
  late RouteMapping route;
  final RouteDefinitionType type;

  String? group;

  RouteDefinition(this.type);

  void commit(Spanner spanner);

  List<OpenApiRoute> get openAPIRoutes;

  RouteDefinition _prefix(String prefix) => this..route = route.prefix(prefix);
}

class UseAliasedMiddleware {
  final String alias;

  UseAliasedMiddleware(this.alias);

  Iterable<Middleware> get mdw =>
      ApplicationFactory.resolveMiddlewareForGroup(alias);

  RouteGroupDefinition group(
    String name,
    List<RouteDefinition> routes, {
    String? prefix,
  }) {
    return RouteGroupDefinition._(name, prefix: prefix, definitions: routes)
      ..middleware(mdw);
  }

  RouteGroupDefinition routes(List<RouteDefinition> routes) {
    return RouteGroupDefinition._(
      alias,
      prefix: BASE_PATH,
      definitions: routes,
    )..middleware(mdw);
  }
}

class _MiddlewareDefinition extends RouteDefinition {
  final Middleware mdw;

  _MiddlewareDefinition(this.mdw, RouteMapping route)
      : super(RouteDefinitionType.middleware) {
    this.route = route;
  }

  @override
  void commit(Spanner spanner) => spanner.addMiddleware(route.path, mdw);

  @override
  List<OpenApiRoute> get openAPIRoutes => const [];
}

typedef ControllerMethodDefinition = (Type controller, Symbol symbol);

class ControllerMethod {
  final Type? returnType;
  final ControllerMethodDefinition method;
  final Iterable<ControllerMethodParam> params;

  String get methodName => symbolToString(method.$2);

  Type get controller => method.$1;

  ControllerMethod(
    this.method, {
    this.params = const [],
    this.returnType,
  });
}

class ControllerMethodParam {
  final String name;
  final Type type;
  final bool optional;
  final dynamic defaultValue;
  final RequestAnnotation? meta;

  final BaseDTO? dto;

  const ControllerMethodParam(
    this.name,
    this.type, {
    this.meta,
    this.optional = false,
    this.defaultValue,
    this.dto,
  });
}

class ControllerRouteMethodDefinition extends RouteDefinition {
  final ControllerMethod method;

  ControllerRouteMethodDefinition(
    ControllerMethodDefinition defn,
    RouteMapping mapping,
  )   : method = parseControllerMethod(defn),
        super(RouteDefinitionType.route) {
    route = mapping;
  }

  @override
  void commit(Spanner spanner) {
    final handler = ApplicationFactory.buildControllerMethod(method);
    for (final routeMethod in route.methods) {
      spanner.addRoute(routeMethod, route.path, useRequestHandler(handler));
    }
  }

  @override
  List<OpenApiRoute> get openAPIRoutes => route.methods
      .map((e) => (
            route: route.path,
            method: e,
            args: method.params.toList(),
            returnType: method.returnType,
            tags: <String>[if (group != null) group!]
          ))
      .toList();
}

class RouteGroupDefinition extends RouteDefinition {
  final String name;
  final List<RouteDefinition> defns = [];

  List<String> get paths => defns.map((e) => e.route.stringVal).toList();

  RouteGroupDefinition._(
    this.name, {
    String? prefix,
    Iterable<RouteDefinition> definitions = const [],
  }) : super(RouteDefinitionType.group) {
    final r = (prefix ?? name).toLowerCase();
    final routePath = r.startsWith(BASE_PATH) ? r : '/$r';
    route = RouteMapping([HTTPMethod.ALL], routePath);
    if (definitions.isEmpty) {
      throw StateError('Route definitions not provided for group');
    }
    _unwrapRoutes(definitions);
  }

  void _unwrapRoutes(Iterable<RouteDefinition> routes) {
    for (final subRoute in routes) {
      if (subRoute is! RouteGroupDefinition) {
        defns.add(subRoute._prefix(route.path)..group = name);
        continue;
      }

      for (var e in subRoute.defns) {
        defns.add(e._prefix(route.path)..group = subRoute.name);
      }
    }
  }

  void middleware(Iterable<Middleware> func) {
    if (func.isEmpty) return;
    final mdwDefn =
        _MiddlewareDefinition(func.reduce((val, e) => val.chain(e)), route);
    defns.insert(0, mdwDefn);
  }

  @override
  void commit(Spanner spanner) {
    for (final mdw in defns) {
      mdw.commit(spanner);
    }
  }

  @override
  List<OpenApiRoute> get openAPIRoutes => defns.fold(
        [],
        (preV, c) => preV..addAll(c.openAPIRoutes),
      );
}

typedef RequestHandlerWithApp = Function(
  Application app,
  Request req,
  Response res,
);

class FunctionalRouteDefinition extends RouteDefinition {
  final HTTPMethod method;
  final String path;

  final Middleware? _middleware;
  final Middleware? _requestHandler;

  FunctionalRouteDefinition.route(
      this.method, this.path, RequestHandler handler)
      : _middleware = null,
        _requestHandler = useRequestHandler(handler),
        super(RouteDefinitionType.route) {
    route = RouteMapping([method], path);
  }

  FunctionalRouteDefinition.middleware(this.path, Middleware handler)
      : _requestHandler = null,
        _middleware = handler,
        method = HTTPMethod.ALL,
        super(RouteDefinitionType.middleware) {
    route = RouteMapping([method], path);
  }

  @override
  void commit(Spanner spanner) {
    if (_middleware != null) {
      spanner.addMiddleware<Middleware>(path, _middleware!);
    } else if (_requestHandler != null) {
      spanner.addRoute<Middleware>(method, path, _requestHandler!);
    }
  }

  @override
  List<OpenApiRoute> get openAPIRoutes => [
        (
          args: [],
          returnType: Response,
          method: method,
          route: route.path,
          tags: <String>[if (group != null) group!]
        )
      ];
}
