//
// AUTO-GENERATED FILE, DO NOT MODIFY!
//

// ignore_for_file: unused_element
import 'package:built_collection/built_collection.dart';
import 'package:talbytk_api/src/model/order_resource.dart';
import 'package:built_value/built_value.dart';
import 'package:built_value/serializer.dart';

part 'order_index200_response_any_of.g.dart';

/// OrderIndex200ResponseAnyOf
///
/// Properties:
/// * [data] 
@BuiltValue()
abstract class OrderIndex200ResponseAnyOf implements Built<OrderIndex200ResponseAnyOf, OrderIndex200ResponseAnyOfBuilder> {
  @BuiltValueField(wireName: r'data')
  BuiltList<OrderResource> get data;

  OrderIndex200ResponseAnyOf._();

  factory OrderIndex200ResponseAnyOf([void updates(OrderIndex200ResponseAnyOfBuilder b)]) = _$OrderIndex200ResponseAnyOf;

  @BuiltValueHook(initializeBuilder: true)
  static void _defaults(OrderIndex200ResponseAnyOfBuilder b) => b;

  @BuiltValueSerializer(custom: true)
  static Serializer<OrderIndex200ResponseAnyOf> get serializer => _$OrderIndex200ResponseAnyOfSerializer();
}

class _$OrderIndex200ResponseAnyOfSerializer implements PrimitiveSerializer<OrderIndex200ResponseAnyOf> {
  @override
  final Iterable<Type> types = const [OrderIndex200ResponseAnyOf, _$OrderIndex200ResponseAnyOf];

  @override
  final String wireName = r'OrderIndex200ResponseAnyOf';

  Iterable<Object?> _serializeProperties(
    Serializers serializers,
    OrderIndex200ResponseAnyOf object, {
    FullType specifiedType = FullType.unspecified,
  }) sync* {
    yield r'data';
    yield serializers.serialize(
      object.data,
      specifiedType: const FullType(BuiltList, [FullType(OrderResource)]),
    );
  }

  @override
  Object serialize(
    Serializers serializers,
    OrderIndex200ResponseAnyOf object, {
    FullType specifiedType = FullType.unspecified,
  }) {
    return _serializeProperties(serializers, object, specifiedType: specifiedType).toList();
  }

  void _deserializeProperties(
    Serializers serializers,
    Object serialized, {
    FullType specifiedType = FullType.unspecified,
    required List<Object?> serializedList,
    required OrderIndex200ResponseAnyOfBuilder result,
    required List<Object?> unhandled,
  }) {
    for (var i = 0; i < serializedList.length; i += 2) {
      final key = serializedList[i] as String;
      final value = serializedList[i + 1];
      switch (key) {
        case r'data':
          final valueDes = serializers.deserialize(
            value,
            specifiedType: const FullType(BuiltList, [FullType(OrderResource)]),
          ) as BuiltList<OrderResource>;
          result.data.replace(valueDes);
          break;
        default:
          unhandled.add(key);
          unhandled.add(value);
          break;
      }
    }
  }

  @override
  OrderIndex200ResponseAnyOf deserialize(
    Serializers serializers,
    Object serialized, {
    FullType specifiedType = FullType.unspecified,
  }) {
    final result = OrderIndex200ResponseAnyOfBuilder();
    final serializedList = (serialized as Iterable<Object?>).toList();
    final unhandled = <Object?>[];
    _deserializeProperties(
      serializers,
      serialized,
      specifiedType: specifiedType,
      serializedList: serializedList,
      unhandled: unhandled,
      result: result,
    );
    return result.build();
  }
}

