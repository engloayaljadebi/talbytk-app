// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'order_index200_response_any_of.dart';

// **************************************************************************
// BuiltValueGenerator
// **************************************************************************

class _$OrderIndex200ResponseAnyOf extends OrderIndex200ResponseAnyOf {
  @override
  final BuiltList<OrderResource> data;

  factory _$OrderIndex200ResponseAnyOf(
          [void Function(OrderIndex200ResponseAnyOfBuilder)? updates]) =>
      (OrderIndex200ResponseAnyOfBuilder()..update(updates))._build();

  _$OrderIndex200ResponseAnyOf._({required this.data}) : super._();
  @override
  OrderIndex200ResponseAnyOf rebuild(
          void Function(OrderIndex200ResponseAnyOfBuilder) updates) =>
      (toBuilder()..update(updates)).build();

  @override
  OrderIndex200ResponseAnyOfBuilder toBuilder() =>
      OrderIndex200ResponseAnyOfBuilder()..replace(this);

  @override
  bool operator ==(Object other) {
    if (identical(other, this)) return true;
    return other is OrderIndex200ResponseAnyOf && data == other.data;
  }

  @override
  int get hashCode {
    var _$hash = 0;
    _$hash = $jc(_$hash, data.hashCode);
    _$hash = $jf(_$hash);
    return _$hash;
  }

  @override
  String toString() {
    return (newBuiltValueToStringHelper(r'OrderIndex200ResponseAnyOf')
          ..add('data', data))
        .toString();
  }
}

class OrderIndex200ResponseAnyOfBuilder
    implements
        Builder<OrderIndex200ResponseAnyOf, OrderIndex200ResponseAnyOfBuilder> {
  _$OrderIndex200ResponseAnyOf? _$v;

  ListBuilder<OrderResource>? _data;
  ListBuilder<OrderResource> get data =>
      _$this._data ??= ListBuilder<OrderResource>();
  set data(ListBuilder<OrderResource>? data) => _$this._data = data;

  OrderIndex200ResponseAnyOfBuilder() {
    OrderIndex200ResponseAnyOf._defaults(this);
  }

  OrderIndex200ResponseAnyOfBuilder get _$this {
    final $v = _$v;
    if ($v != null) {
      _data = $v.data.toBuilder();
      _$v = null;
    }
    return this;
  }

  @override
  void replace(OrderIndex200ResponseAnyOf other) {
    _$v = other as _$OrderIndex200ResponseAnyOf;
  }

  @override
  void update(void Function(OrderIndex200ResponseAnyOfBuilder)? updates) {
    if (updates != null) updates(this);
  }

  @override
  OrderIndex200ResponseAnyOf build() => _build();

  _$OrderIndex200ResponseAnyOf _build() {
    _$OrderIndex200ResponseAnyOf _$result;
    try {
      _$result = _$v ??
          _$OrderIndex200ResponseAnyOf._(
            data: data.build(),
          );
    } catch (_) {
      late String _$failedField;
      try {
        _$failedField = 'data';
        data.build();
      } catch (e) {
        throw BuiltValueNestedFieldError(
            r'OrderIndex200ResponseAnyOf', _$failedField, e.toString());
      }
      rethrow;
    }
    replace(_$result);
    return _$result;
  }
}

// ignore_for_file: deprecated_member_use_from_same_package,type=lint
