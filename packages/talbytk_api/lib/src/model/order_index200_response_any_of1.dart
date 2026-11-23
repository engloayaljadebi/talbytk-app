//
// AUTO-GENERATED FILE, DO NOT MODIFY!
//

// ignore_for_file: unused_element
import 'package:talbytk_api/src/model/product_index200_response_links.dart';
import 'package:built_collection/built_collection.dart';
import 'package:talbytk_api/src/model/order_resource.dart';
import 'package:talbytk_api/src/model/product_index200_response_meta.dart';
import 'package:built_value/built_value.dart';
import 'package:built_value/serializer.dart';

part 'order_index200_response_any_of1.g.dart';

/// OrderIndex200ResponseAnyOf1
///
/// Properties:
/// * [data] 
/// * [links] 
/// * [meta] 
@BuiltValue()
abstract class OrderIndex200ResponseAnyOf1 implements Built<OrderIndex200ResponseAnyOf1, OrderIndex200ResponseAnyOf1Builder> {
  @BuiltValueField(wireName: r'data')
  BuiltList<OrderResource> get data;

  @BuiltValueField(wireName: r'links')
  ProductIndex200ResponseLinks get links;

  @BuiltValueField(wireName: r'meta')
  ProductIndex200ResponseMeta get meta;

  OrderIndex200ResponseAnyOf1._();

  factory OrderIndex200ResponseAnyOf1([void updates(OrderIndex200ResponseAnyOf1Builder b)]) = _$OrderIndex200ResponseAnyOf1;

  @BuiltValueHook(initializeBuilder: true)
  static void _defaults(OrderIndex200ResponseAnyOf1Builder b) => b;

  @BuiltValueSerializer(custom: true)
  static Serializer<OrderIndex200ResponseAnyOf1> get serializer => _$OrderIndex200ResponseAnyOf1Serializer();
}

class _$OrderIndex200ResponseAnyOf1Serializer implements PrimitiveSerializer<OrderIndex200ResponseAnyOf1> {
  @override
  final Iterable<Type> types = const [OrderIndex200ResponseAnyOf1, _$OrderIndex200ResponseAnyOf1];

  @override
  final String wireName = r'OrderIndex200ResponseAnyOf1';

  Iterable<Object?> _serializeProperties(
    Serializers serializers,
    OrderIndex200ResponseAnyOf1 object, {
    FullType specifiedType = FullType.unspecified,
  }) sync* {
    yield r'data';
    yield serializers.serialize(
      object.data,
      specifiedType: const FullType(BuiltList, [FullType(OrderResource)]),
    );
    yield r'links';
    yield serializers.serialize(
      object.links,
      specifiedType: const FullType(ProductIndex200ResponseLinks),
    );
    yield r'meta';
    yield serializers.serialize(
      object.meta,
      specifiedType: const FullType(ProductIndex200ResponseMeta),
    );
  }

  @override
  Object serialize(
    Serializers serializers,
    OrderIndex200ResponseAnyOf1 object, {
    FullType specifiedType = FullType.unspecified,
  }) {
    return _serializeProperties(serializers, object, specifiedType: specifiedType).toList();
  }

  void _deserializeProperties(
    Serializers serializers,
    Object serialized, {
    FullType specifiedType = FullType.unspecified,
    required List<Object?> serializedList,
    required OrderIndex200ResponseAnyOf1Builder result,
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
        case r'links':
          final valueDes = serializers.deserialize(
            value,
            specifiedType: const FullType(ProductIndex200ResponseLinks),
          ) as ProductIndex200ResponseLinks;
          result.links.replace(valueDes);
          break;
        case r'meta':
          final valueDes = serializers.deserialize(
            value,
            specifiedType: const FullType(ProductIndex200ResponseMeta),
          ) as ProductIndex200ResponseMeta;
          result.meta.replace(valueDes);
          break;
        default:
          unhandled.add(key);
          unhandled.add(value);
          break;
      }
    }
  }

  @override
  OrderIndex200ResponseAnyOf1 deserialize(
    Serializers serializers,
    Object serialized, {
    FullType specifiedType = FullType.unspecified,
  }) {
    final result = OrderIndex200ResponseAnyOf1Builder();
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

