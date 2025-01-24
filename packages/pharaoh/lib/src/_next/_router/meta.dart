part of '../router.dart';

sealed class RequestAnnotation<T> {
  final String? name;

  const RequestAnnotation([this.name]);

  T process(Request request, ControllerMethodParam methodParam);
}

enum ValidationErrorLocation { param, query, body, header }

class RequestValidationError extends Error {
  final String message;
  final Map? errors;
  final ValidationErrorLocation location;

  RequestValidationError.param(this.message)
      : location = ValidationErrorLocation.param,
        errors = null;

  RequestValidationError.header(this.message)
      : location = ValidationErrorLocation.header,
        errors = null;

  RequestValidationError.query(this.message)
      : location = ValidationErrorLocation.query,
        errors = null;

  RequestValidationError.body(this.message)
      : location = ValidationErrorLocation.body,
        errors = null;

  RequestValidationError.errors(this.location, this.errors) : message = '';

  Map<String, dynamic> get errorBody => {
        'location': location.name,
        if (errors != null)
          'errors': errors!.entries.map((e) => '${e.key}: ${e.value}').toList(),
        if (message.isNotEmpty) 'errors': [message],
      };

  @override
  String toString() => errorBody.toString();
}

/// Use this to annotate a parameter in a controller method
/// which will be resolved to the request body.
///
/// Example: create(@Body() user) {}
class Body extends RequestAnnotation {
  const Body();

  @override
  process(Request request, ControllerMethodParam methodParam) {
    final body = request.body;
    if (body == null) {
      if (methodParam.optional) return null;
      throw RequestValidationError.body(
          EzValidator.globalLocale.required('body'));
    }

    final dtoInstance = methodParam.dto;
    if (dtoInstance != null) return dtoInstance..validate(request);

    final type = methodParam.type;
    if (type != dynamic && body.runtimeType != type) {
      throw RequestValidationError.body(
          EzValidator.globalLocale.isTypeOf('${methodParam.type}', 'body'));
    }

    return body;
  }
}

/// Use this to annotate a parameter in a controller method
/// which will be resolved to a parameter in the request path.
///
/// `/users/<userId>/details` Example: getUser(@Param() String userId) {}
class Param extends RequestAnnotation {
  const Param([super.name]);

  @override
  process(Request request, ControllerMethodParam methodParam) {
    final paramName = name ?? methodParam.name;
    final value = request.params[paramName] ?? methodParam.defaultValue;
    final parsedValue = _parseValue(value, methodParam.type);
    if (parsedValue == null) {
      throw RequestValidationError.param(
          EzValidator.globalLocale.isTypeOf('${methodParam.type}', paramName));
    }
    return parsedValue;
  }
}

/// Use this to annotate a parameter in a controller method
/// which will be resolved to a parameter in the request query params.
///
/// `/users?name=Chima` Example: searchUsers(@Query() String name) {}
class Query extends RequestAnnotation {
  const Query([super.name]);

  @override
  process(Request request, ControllerMethodParam methodParam) {
    final paramName = name ?? methodParam.name;
    final value = request.query[paramName] ?? methodParam.defaultValue;
    if (!methodParam.optional && value == null) {
      throw RequestValidationError.query(
          EzValidator.globalLocale.required(paramName));
    }

    final parsedValue = _parseValue(value, methodParam.type);
    if (parsedValue == null) {
      throw RequestValidationError.query(
          EzValidator.globalLocale.isTypeOf('${methodParam.type}', paramName));
    }
    return parsedValue;
  }
}

class Header extends RequestAnnotation {
  const Header([super.name]);

  @override
  process(Request request, ControllerMethodParam methodParam) {
    final paramName = name ?? methodParam.name;
    final value = request.headers[paramName] ?? methodParam.defaultValue;
    if (!methodParam.optional && value == null) {
      throw RequestValidationError.header(
          EzValidator.globalLocale.required(paramName));
    }

    final parsedValue = _parseValue(value, methodParam.type);
    if (parsedValue == null) {
      throw RequestValidationError.header(
          EzValidator.globalLocale.isTypeOf('${methodParam.type}', paramName));
    }
    return parsedValue;
  }
}

_parseValue(dynamic value, Type type) {
  if (value.runtimeType == type) return value;
  value = value.toString();
  return switch (type) {
    const (int) => int.tryParse(value),
    const (double) => double.tryParse(value),
    const (bool) => value == 'true',
    const (List) || const (Map) => jsonDecode(value),
    _ => value,
  };
}

const param = Param();
const query = Query();
const body = Body();
const header = Header();
