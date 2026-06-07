/// Lightweight OpenAPI schema node used for client-side response validation.
class OpenApiSchema {
  const OpenApiSchema({
    this.type,
    this.required = const [],
    this.properties = const {},
    this.items,
    this.additionalProperties = true,
    this.minItems,
    this.format,
  });

  final OpenApiSchemaType? type;
  final List<String> required;
  final Map<String, OpenApiSchema> properties;
  final OpenApiSchema? items;
  final bool additionalProperties;
  final int? minItems;
  final String? format;

  static const object = OpenApiSchema(type: OpenApiSchemaType.object);
  static const string = OpenApiSchema(type: OpenApiSchemaType.string);
  static const integer = OpenApiSchema(type: OpenApiSchemaType.integer);
  static const array = OpenApiSchema(type: OpenApiSchemaType.array);

  OpenApiSchema arrayOf(OpenApiSchema itemSchema, {int? minItems}) {
    return OpenApiSchema(
      type: OpenApiSchemaType.array,
      items: itemSchema,
      minItems: minItems,
    );
  }

  OpenApiSchema withRequired(List<String> keys) {
    return OpenApiSchema(
      type: type,
      required: keys,
      properties: properties,
      items: items,
      additionalProperties: additionalProperties,
      minItems: minItems,
      format: format,
    );
  }

  OpenApiSchema withProperties(Map<String, OpenApiSchema> props) {
    return OpenApiSchema(
      type: type ?? OpenApiSchemaType.object,
      required: required,
      properties: props,
      items: items,
      additionalProperties: additionalProperties,
      minItems: minItems,
      format: format,
    );
  }
}

enum OpenApiSchemaType {
  object,
  array,
  string,
  number,
  integer,
  boolean,
}
