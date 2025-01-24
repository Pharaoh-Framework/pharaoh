part of '../core.dart';

class Injectable extends r.Reflectable {
  const Injectable()
      : super(
          r.invokingCapability,
          r.metadataCapability,
          r.newInstanceCapability,
          r.declarationsCapability,
          r.reflectedTypeCapability,
          r.typeRelationsCapability,
          const r.InstanceInvokeCapability('^[^_]'),
          r.subtypeQuantifyCapability,
        );
}

const unnamedConstructor = '';

const inject = Injectable();

List<X> filteredDeclarationsOf<X extends r.DeclarationMirror>(
    r.ClassMirror cm, predicate) {
  var result = <X>[];
  cm.declarations.forEach((k, v) {
    if (predicate(v)) result.add(v as X);
  });
  return result;
}

r.ClassMirror reflectType(Type type) {
  try {
    return inject.reflectType(type) as r.ClassMirror;
  } catch (e) {
    throw UnsupportedError(
        'Unable to reflect on $type. Re-run your build command');
  }
}

extension ClassMirrorExtensions on r.ClassMirror {
  List<r.VariableMirror> get variables {
    return filteredDeclarationsOf(this, (v) => v is r.VariableMirror);
  }

  List<r.MethodMirror> get getters {
    return filteredDeclarationsOf(
        this, (v) => v is r.MethodMirror && v.isGetter);
  }

  List<r.MethodMirror> get setters {
    return filteredDeclarationsOf(
        this, (v) => v is r.MethodMirror && v.isSetter);
  }

  List<r.MethodMirror> get methods {
    return filteredDeclarationsOf(
        this, (v) => v is r.MethodMirror && v.isRegularMethod);
  }
}

T createNewInstance<T extends Object>(Type classType) {
  final classMirror = reflectType(classType);
  final constructorMethod = classMirror.declarations.entries
      .firstWhereOrNull((e) => e.key == '$classType')
      ?.value as r.MethodMirror?;
  final constructorParameters = constructorMethod?.parameters ?? [];
  if (constructorParameters.isEmpty) {
    return classMirror.newInstance(unnamedConstructor, const []) as T;
  }

  final namedDeps = constructorParameters
      .where((e) => e.isNamed)
      .map((e) => (
            name: e.simpleName,
            instance: instanceFromRegistry(type: e.reflectedType)
          ))
      .fold<Map<Symbol, dynamic>>(
          {}, (prev, e) => prev..[Symbol(e.name)] = e.instance);

  final dependencies = constructorParameters
      .where((e) => !e.isNamed)
      .map((e) => instanceFromRegistry(type: e.reflectedType))
      .toList();

  return classMirror.newInstance(unnamedConstructor, dependencies, namedDeps)
      as T;
}

ControllerMethod parseControllerMethod(ControllerMethodDefinition defn) {
  final type = defn.$1;
  final method = defn.$2;

  final ctrlMirror = inject.reflectType(type) as r.ClassMirror;
  if (ctrlMirror.superclass?.reflectedType != HTTPController) {
    throw ArgumentError('$type must extend BaseController');
  }

  final methods = ctrlMirror.instanceMembers.values.whereType<r.MethodMirror>();
  final actualMethod =
      methods.firstWhereOrNull((e) => e.simpleName == symbolToString(method));
  if (actualMethod == null) {
    throw ArgumentError(
      '$type does not have method  #${symbolToString(method)}',
    );
  }

  final returnType = getActualType(actualMethod.reflectedReturnType);

  final parameters = actualMethod.parameters;
  if (parameters.isEmpty) return ControllerMethod(defn, returnType: returnType);

  if (parameters.any((e) => e.metadata.length > 1)) {
    throw ArgumentError(
        'Multiple annotations using on $type #${symbolToString(method)} parameter');
  }

  final params = parameters.map((e) {
    final meta = e.metadata.first;
    if (meta is! RequestAnnotation) {
      throw ArgumentError(
        'Invalid annotation $meta used on $type #${symbolToString(method)} parameter',
      );
    }

    final paramType = e.reflectedType;
    final maybeDto = _tryResolveDtoInstance(paramType);

    return ControllerMethodParam(
      e.simpleName,
      paramType,
      defaultValue: e.defaultValue,
      optional: e.isOptional,
      meta: meta,
      dto: maybeDto,
    );
  });

  return ControllerMethod(defn, params: params, returnType: returnType);
}

final _regex = RegExp(r"^(\w+)<(.+)>$");
Type? getActualType(Type type) {
  final match = _regex.firstMatch(type.toString());
  if (match != null) {
    return q.data[inject]!.types
        .firstWhereOrNull((type) => type.toString() == match.group(2));
  }
  return type;
}

BaseDTO? _tryResolveDtoInstance(Type type) {
  try {
    final mirror = dtoReflector.reflectType(type) as r.ClassMirror;
    return mirror.newInstance(unnamedConstructor, []) as BaseDTO;
  } on r.NoSuchCapabilityError catch (_) {
    return null;
  }
}

void ensureIsSubTypeOf<Parent extends Object>(Type objectType) {
  try {
    final type = reflectType(objectType);
    if (type.superclass!.reflectedType != Parent) throw Exception();
  } catch (e) {
    throw ArgumentError.value(objectType, 'Invalid Type provided',
        'Ensure your class extends `$Parent` class');
  }
}
