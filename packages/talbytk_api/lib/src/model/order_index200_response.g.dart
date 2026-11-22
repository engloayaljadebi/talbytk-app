// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'order_index200_response.dart';

// **************************************************************************
// BuiltValueGenerator
// **************************************************************************

class _$OrderIndex200Response extends OrderIndex200Response {
  @override
  final AnyOf anyOf;

  factory _$OrderIndex200Response(
          [void Function(OrderIndex200ResponseBuilder)? updates]) =>
      (OrderIndex200ResponseBuilder()..update(updates))._build();

  _$OrderIndex200Response._({required this.anyOf}) : super._();
  @override
  OrderIndex200Response rebuild(
          void Function(OrderIndex200ResponseBuilder) updates) =>
      (toBuilder()..update(updates)).build();

  @override
  OrderIndex200ResponseBuilder toBuilder() =>
      OrderIndex200ResponseBuilder()..replace(this);

  @override
  bool operator ==(Object other) {
    if (identical(other, this)) return true;
    return other is OrderIndex200Response && anyOf == other.anyOf;
  }

  @override
  int get hashCode {
    var _$hash = 0;
    _$hash = $jc(_$hash, anyOf.hashCode);
    _$hash = $jf(_$hash);
    return _$hash;
  }

  @override
  String toString() {
    return (newBuiltValueToStringHelper(r'OrderIndex200Response')
          ..add('anyOf', anyOf))
        .toString();
  }
}

class OrderIndex200ResponseBuilder
    implements Builder<OrderIndex200Response, OrderIndex200ResponseBuilder> {
  _$OrderIndex200Response? _$v;

  AnyOf? _anyOf;
  AnyOf? get anyOf => _$this._anyOf;
  set anyOf(AnyOf? anyOf) => _$this._anyOf = anyOf;

  OrderIndex200ResponseBuilder() {
    OrderIndex200Response._defaults(this);
  }

  OrderIndex200ResponseBuilder get _$this {
    final $v = _$v;
    if ($v != null) {
      _anyOf = $v.anyOf;
      _$v = null;
    }
    return this;
  }

  @override
  void replace(OrderIndex200Response other) {
    _$v = other as _$OrderIndex200Response;
  }

  @override
  void update(void Function(OrderIndex200ResponseBuilder)? updates) {
    if (updates != null) updates(this);
  }

  @override
  OrderIndex200Response build() => _build();

  _$OrderIndex200Response _build() {
    final _$result = _$v ??
        _$OrderIndex200Response._(
          anyOf: BuiltValueNullFieldError.checkNotNull(
              anyOf, r'OrderIndex200Response', 'anyOf'),
        );
    replace(_$result);
    return _$result;
  }
}

// ignore_for_file: deprecated_member_use_from_same_package,type=lint
