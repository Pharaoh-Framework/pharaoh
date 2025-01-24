part of '../validation.dart';

const _instanceInvoke = r.InstanceInvokeCapability('^[^_]');

class DtoReflector extends r.Reflectable {
  const DtoReflector()
      : super(
            r.typeCapability,
            r.metadataCapability,
            r.newInstanceCapability,
            r.declarationsCapability,
            r.reflectedTypeCapability,
            _instanceInvoke,
            r.subtypeQuantifyCapability);
}

@protected
const dtoReflector = DtoReflector();

abstract interface class _BaseDTOImpl {
  late Map<String, dynamic> data;

  void validate(Request request) {
    data = const {};
    final (result, errors) = schema.validateSync(request.body ?? {});
    if (errors.isNotEmpty) {
      throw RequestValidationError.errors(ValidationErrorLocation.body, errors);
    }
    data = Map<String, dynamic>.from(result);
  }

  r.ClassMirror? _classMirrorCache;
  Iterable<({String name, Type type, ClassPropertyValidator meta})>
      get properties {
    _classMirrorCache ??=
        dtoReflector.reflectType(runtimeType) as r.ClassMirror;
    return _classMirrorCache!.getters.where((e) => e.isAbstract).map((prop) {
      final returnType = prop.reflectedReturnType;
      final meta =
          prop.metadata.whereType<ClassPropertyValidator>().firstOrNull ??
              ezRequired(returnType);

      if (meta.propertyType != returnType) {
        throw ArgumentError(
            'Type Mismatch between ${meta.runtimeType}(${meta.propertyType}) & $runtimeType class property ${prop.simpleName}->($returnType)');
      }

      return (
        name: (meta.name ?? prop.simpleName),
        meta: meta,
        type: returnType,
      );
    });
  }

  EzSchema? _schemaCache;
  EzSchema get schema {
    if (_schemaCache != null) return _schemaCache!;

    final entriesToMap = properties.fold<Map<String, EzValidator<dynamic>>>(
      {},
      (prev, curr) => prev..[curr.name] = curr.meta.validator,
    );

    return _schemaCache = EzSchema.shape(entriesToMap);
  }
}

@dtoReflector
abstract class BaseDTO extends _BaseDTOImpl {
  @override
  noSuchMethod(Invocation invocation) {
    final property = symbolToString(invocation.memberName);
    return data[property];
  }
}
