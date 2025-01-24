// ignore_for_file: avoid_function_literals_in_foreach_calls

part of '../core.dart';

class _PharaohNextImpl implements Application {
  late final AppConfig _appConfig;
  late final Spanner _spanner;

  ViewEngine? _viewEngine;

  _PharaohNextImpl(this._appConfig, this._spanner);

  @override
  T singleton<T extends Object>(T instance) => registerSingleton<T>(instance);

  @override
  T instanceOf<T extends Object>() => instanceFromRegistry<T>();

  @override
  void useRoutes(RoutesResolver routeResolver) {
    final routes = routeResolver.call();
    routes.forEach((route) => route.commit(_spanner));

    final openAPiRoutes = routes.fold(
        <OpenApiRoute>[], (preV, curr) => preV..addAll(curr.openAPIRoutes));

    final result = OpenApiGenerator.generateOpenApi(
      openAPiRoutes,
      apiName: _appConfig.name,
      serverUrls: [_appConfig.url],
    );

    final openApiFile = File('openapi.json');
    openApiFile.writeAsStringSync(JsonEncoder.withIndent(' ').convert(result));

    Route.route(HTTPMethod.GET, '/swagger', (req, res) {
      return res
          .header(HttpHeaders.contentTypeHeader, ContentType.html.value)
          .send(OpenApiGenerator.renderDocsPage('/swagger.json'));
    }).commit(_spanner);

    Route.route(HTTPMethod.GET, '/swagger.json', (_, res) {
      return res
          .header(HttpHeaders.contentTypeHeader, ContentType.json.value)
          .send(openApiFile.openRead());
    }).commit(_spanner);
  }

  @override
  void useViewEngine(ViewEngine viewEngine) => _viewEngine = viewEngine;

  @override
  AppConfig get config => _appConfig;

  @override
  String get name => config.name;

  @override
  String get url => config.url;

  @override
  int get port => config.port;

  Pharaoh _createPharaohInstance({OnErrorCallback? onException}) {
    final pharaoh = Pharaoh()..useSpanner(_spanner);
    Pharaoh.viewEngine = _viewEngine;

    if (onException != null) pharaoh.onError(onException);
    return pharaoh;
  }
}
