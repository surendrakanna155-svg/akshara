import 'openapi_schema.dart';

/// Validates JSON payloads against lightweight OpenAPI schema definitions.
class OpenApiResponseValidator {
  const OpenApiResponseValidator();

  /// Returns validation error messages; empty list means valid.
  List<String> validate(Object? value, OpenApiSchema schema, {String path = r'$'}) {
    final errors = <String>[];

    if (value == null) {
      if (schema.type != null) {
        errors.add('$path: expected ${schema.type!.name}, got null');
      }
      return errors;
    }

    switch (schema.type) {
      case OpenApiSchemaType.object:
        errors.addAll(_validateObject(value, schema, path));
      case OpenApiSchemaType.array:
        errors.addAll(_validateArray(value, schema, path));
      case OpenApiSchemaType.string:
        if (value is! String) {
          errors.add('$path: expected string, got ${value.runtimeType}');
        } else if (schema.format == 'date-time' &&
            DateTime.tryParse(value) == null) {
          errors.add('$path: invalid date-time string');
        }
      case OpenApiSchemaType.integer:
        if (value is! int) {
          errors.add('$path: expected integer, got ${value.runtimeType}');
        }
      case OpenApiSchemaType.number:
        if (value is! num) {
          errors.add('$path: expected number, got ${value.runtimeType}');
        }
      case OpenApiSchemaType.boolean:
        if (value is! bool) {
          errors.add('$path: expected boolean, got ${value.runtimeType}');
        }
      case null:
        break;
    }

    return errors;
  }

  List<String> _validateObject(
    Object value,
    OpenApiSchema schema,
    String path,
  ) {
    final errors = <String>[];
    if (value is! Map) {
      return ['$path: expected object, got ${value.runtimeType}'];
    }

    final map = {
      for (final entry in value.entries)
        if (entry.key is String) entry.key as String: entry.value,
    };

    for (final key in schema.required) {
      if (!map.containsKey(key)) {
        errors.add('$path: missing required property "$key"');
      }
    }

    for (final entry in schema.properties.entries) {
      if (!map.containsKey(entry.key)) continue;
      errors.addAll(
        validate(map[entry.key], entry.value, path: '$path.${entry.key}'),
      );
    }

    if (!schema.additionalProperties) {
      for (final key in map.keys) {
        if (!schema.properties.containsKey(key) && !schema.required.contains(key)) {
          errors.add('$path: unexpected property "$key"');
        }
      }
    }

    return errors;
  }

  List<String> _validateArray(
    Object value,
    OpenApiSchema schema,
    String path,
  ) {
    final errors = <String>[];
    if (value is! List) {
      return ['$path: expected array, got ${value.runtimeType}'];
    }

    if (schema.minItems != null && value.length < schema.minItems!) {
      errors.add('$path: expected at least ${schema.minItems} items');
    }

    final itemSchema = schema.items;
    if (itemSchema == null) return errors;

    for (var i = 0; i < value.length; i++) {
      errors.addAll(
        validate(value[i], itemSchema, path: '$path[$i]'),
      );
    }

    return errors;
  }
}
