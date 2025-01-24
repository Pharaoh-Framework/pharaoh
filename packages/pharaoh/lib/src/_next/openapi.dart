import 'package:collection/collection.dart';
import 'package:pharaoh/pharaoh_next.dart';

class OpenApiGenerator {
  static Map<String, dynamic> generateOpenApi(
    List<OpenApiRoute> routes, {
    required String apiName,
    required List<String> serverUrls,
  }) {
    return {
      "openapi": "3.0.0",
      "info": {"title": apiName, "version": "1.0.0"},
      "servers": serverUrls.map((e) => {'url': e}).toList(),
      "paths": _generatePaths(routes),
      "components": {"schemas": _generateSchemas(routes)}
    };
  }

  static Map<String, dynamic> _generatePaths(List<OpenApiRoute> routes) {
    final paths = <String, Map<String, dynamic>>{};

    for (final route in routes) {
      final pathParams = route.args.where((e) => e.meta is Param).toList();
      final bodyParam = route.args.firstWhereOrNull((e) => e.meta is Body);
      final parameters = _generateParameters(route.args);
      final routeMethod = route.method.name.toLowerCase();

      var path = route.route;

      // Convert Express-style path params (:id) to OpenAPI style ({id})
      for (final param in pathParams) {
        path = path.replaceAll('<${param.name}>', '{${param.name}}');
      }

      paths[path] = paths[path] ?? {};
      paths[path]![routeMethod] = {
        "summary": "",
        if (parameters.isNotEmpty) "parameters": parameters,
        if (route.tags.isNotEmpty) "tags": route.tags,
        "responses": {
          "200": {
            "description": "Successful response",
            if (route.returnType != null && route.returnType != Response)
              "content": {
                "application/json": {
                  "schema": {
                    "\$ref": "#/components/schemas/${route.returnType}"
                  },
                },
              }
          }
        }
      };

      if (bodyParam != null) {
        paths[path]![routeMethod]["requestBody"] = {
          "required": !bodyParam.optional,
          "content": {
            "application/json": {"schema": _generateSchema(bodyParam)}
          }
        };
      }
    }

    return paths;
  }

  static List<Map<String, dynamic>> _generateParameters(
    List<ControllerMethodParam> args,
  ) {
    final parameters = <Map<String, dynamic>>[];

    for (final arg in args) {
      final parameterLocation = _getParameterLocation(arg.meta);
      if (parameterLocation == null) continue;

      final parameterSchema = _generateSchema(arg);

      // Add default value if available and not a path parameter
      if (arg.defaultValue != null && parameterLocation != "path") {
        parameterSchema["default"] = arg.defaultValue;
      }

      final param = {
        "name": arg.name,
        "in": parameterLocation,
        "required": parameterLocation == "path" ? true : !arg.optional,
        "schema": parameterSchema,
      };

      parameters.add(param);
    }

    return parameters;
  }

  static String? _getParameterLocation(RequestAnnotation? annotation) {
    return switch (annotation) {
      const Header() => "header",
      const Query() => "query",
      const Param() => "path",
      _ => null,
    };
  }

  static Map<String, dynamic> _generateSchema(ControllerMethodParam param) {
    if (param.dto != null) {
      return {
        "\$ref": "#/components/schemas/${param.dto.runtimeType.toString()}"
      };
    }

    return _typeToOpenApiType(param.type);
  }

  static Map<String, dynamic> _typeToOpenApiType(Type type) {
    switch (type) {
      case const (String):
        return {"type": "string"};
      case const (int):
        return {"type": "integer", "format": "int32"};
      case const (double):
        return {"type": "number", "format": "double"};
      case const (bool):
        return {"type": "boolean"};
      case const (DateTime):
        return {"type": "string", "format": "date-time"};
      default:
        final actualType = getActualType(type);
        if (actualType == null) return {"type": "object"};

        // final properties = <VariableMirror>[];

        // ClassMirror? clazz = reflectType(actualType);
        // while (clazz?.superclass != null) {
        //   properties.addAll(clazz!.variables);
        //   clazz = clazz.superclass;
        // }

        // print(properties);

        return {"type": "object"};
    }
  }

  static Map<String, dynamic> _generateSchemas(List<OpenApiRoute> routes) {
    final schemas = <String, dynamic>{};

    for (final route in routes) {
      final returnType = route.returnType;
      for (final arg in route.args) {
        final dto = arg.dto;
        if (dto == null) continue;

        schemas[dto.runtimeType.toString()] = {
          "type": "object",
          "properties": dto.properties.fold({},
              (preV, curr) => preV..[curr.name] = _typeToOpenApiType(curr.type))
        };
      }

      if (returnType == null || returnType == Response) continue;

      final properties = reflectType(returnType).variables;

      schemas[returnType.toString()] = {
        "type": "object",
        "properties": properties.fold(
            {},
            (preV, curr) => preV
              ..[curr.simpleName] = _typeToOpenApiType(curr.reflectedType))
      };
    }

    return schemas;
  }

  static String renderDocsPage(String openApiRoute) {
    return '''
<!DOCTYPE html>
<html lang="en">
  <head>
    <meta charset="utf-8" />
    <meta name="viewport" content="width=device-width, initial-scale=1" />
    <meta name="description" content="SwaggerUI" />
    <title>SwaggerUI</title>
    <link rel="stylesheet" href="https://unpkg.com/swagger-ui-dist@5.11.0/swagger-ui.css" />
  </head>
  <body>
  <div id="swagger-ui"></div>
  <script src="https://unpkg.com/swagger-ui-dist@5.11.0/swagger-ui-bundle.js" crossorigin></script>
  <script src="https://unpkg.com/swagger-ui-dist@5.11.0/swagger-ui-standalone-preset.js" crossorigin></script>
  <script>
    window.onload = () => {
      window.ui = SwaggerUIBundle({
        url: '$openApiRoute',
        dom_id: '#swagger-ui',
        presets: [
          SwaggerUIBundle.presets.apis,
          SwaggerUIStandalonePreset
        ],
        layout: "StandaloneLayout",
      });
    };
  </script>
  </body>
</html>
''';
  }
}
