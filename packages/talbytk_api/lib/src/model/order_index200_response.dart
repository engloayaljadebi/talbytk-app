//
// AUTO-GENERATED FILE, DO NOT MODIFY!
//

// ignore_for_file: unused_element
import 'package:talbytk_api/src/model/product_index200_response_links.dart';
import 'package:talbytk_api/src/model/order_index200_response_any_of1.dart';
import 'package:built_collection/built_collection.dart';
import 'package:talbytk_api/src/model/order_index200_response_any_of.dart';
import 'package:talbytk_api/src/model/order_resource.dart';
import 'package:talbytk_api/src/model/product_index200_response_meta.dart';
import 'package:built_value/built_value.dart';
import 'package:built_value/serializer.dart';
import 'package:one_of/any_of.dart';

part 'order_index200_response.g.dart';

/// OrderIndex200Response
///
/// Properties:
/// * [data] 
/// * [links] 
/// * [meta] 
@BuiltValue()
abstract class OrderIndex200Response implements Built<OrderIndex200Response, OrderIndex200ResponseBuilder> {
  /// Any Of [OrderIndex200ResponseAnyOf], [OrderIndex200ResponseAnyOf1]
  AnyOf get anyOf;

  OrderIndex200Response._();

  factory OrderIndex200Response([void updates(OrderIndex200ResponseBuilder b)]) = _$OrderIndex200Response;

  @BuiltValueHook(initializeBuilder: true)
  static void _defaults(OrderIndex200ResponseBuilder b) => b;

  @BuiltValueSerializer(custom: true)
  static Serializer<OrderIndex200Response> get serializer => _$OrderIndex200ResponseSerializer();
}

class _$OrderIndex200ResponseSerializer implements PrimitiveSerializer<OrderIndex200Response> {
  @override
  final Iterable<Type> types = const [OrderIndex200Response, _$OrderIndex200Response];

  @override
  final String wireName = r'OrderIndex200Response';

  Iterable<Object?> _serializeProperties(
    Serializers serializers,
    OrderIndex200Response object, {
    FullType specifiedType = FullType.unspecified,
  }) sync* {
  }

  @override
  Object serialize(
    Serializers serializers,
    OrderIndex200Response object, {
    FullType specifiedType = FullType.unspecified,
  }) {
    final anyOf = object.anyOf;
    return serializers.serialize(anyOf, specifiedType: FullType(AnyOf, anyOf.valueTypes.map((type) => FullType(type)).toList()))!;
  }

  @override
  OrderIndex200Response deserialize(
    Serializers serializers,
    Object serialized, {
    FullType specifiedType = FullType.unspecified,
  }) {
    final result = OrderIndex200ResponseBuilder();
    Object? anyOfDataSrc;
    final targetType = const FullType(AnyOf, [FullType(OrderIndex200ResponseAnyOf), FullType(OrderIndex200ResponseAnyOf1), ]);
    anyOfDataSrc = serialized;
    result.anyOf = serializers.deserialize(anyOfDataSrc, specifiedType: targetType) as AnyOf;
    return result.build();
  }
}

