// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'order_index200_response_any_of1.dart';

// **************************************************************************
// BuiltValueGenerator
// **************************************************************************

class _$OrderIndex200ResponseAnyOf1 extends OrderIndex200ResponseAnyOf1 {
  @override
  final BuiltList<OrderResource> data;
  @override
  final ProductIndex200ResponseLinks links;
  @override
  final ProductIndex200ResponseMeta meta;

  factory _$OrderIndex200ResponseAnyOf1(
          [void Function(OrderIndex200ResponseAnyOf1Builder)? updates]) =>
      (OrderIndex200ResponseAnyOf1Builder()..update(updates))._build();

  _$OrderIndex200ResponseAnyOf1._(
      {required this.data, required this.links, required this.meta})
      : super._();
  @override
  OrderIndex200ResponseAnyOf1 rebuild(
          void Function(OrderIndex200ResponseAnyOf1Builder) updates) =>
      (toBuilder()..update(updates)).build();

  @override
  OrderIndex200ResponseAnyOf1Builder toBuilder() =>
      OrderIndex200ResponseAnyOf1Builder()..replace(this);

  @override
  bool operator ==(Object other) {
    if (identical(other, this)) return true;
    return other is OrderIndex200ResponseAnyOf1 &&
        data == other.data &&
        links == other.links &&
        meta == other.meta;
  }

  @override
  int get hashCode {
    var _$hash = 0;
    _$hash = $jc(_$hash, data.hashCode);
    _$hash = $jc(_$hash, links.hashCode);
    _$hash = $jc(_$hash, meta.hashCode);
    _$hash = $jf(_$hash);
    return _$hash;
  }

  @override
  String toString() {
    return (newBuiltValueToStringHelper(r'OrderIndex200ResponseAnyOf1')
          ..add('data', data)
          ..add('links', links)
          ..add('meta', meta))
        .toString();
  }
}

class OrderIndex200ResponseAnyOf1Builder
    implements
        Builder<OrderIndex200ResponseAnyOf1,
            OrderIndex200ResponseAnyOf1Builder> {
  _$OrderIndex200ResponseAnyOf1? _$v;

  ListBuilder<OrderResource>? _data;
  ListBuilder<OrderResource> get data =>
      _$this._data ??= ListBuilder<OrderResource>();
  set data(ListBuilder<OrderResource>? data) => _$this._data = data;

  ProductIndex200ResponseLinksBuilder? _links;
  ProductIndex200ResponseLinksBuilder get links =>
      _$this._links ??= ProductIndex200ResponseLinksBuilder();
  set links(ProductIndex200ResponseLinksBuilder? links) =>
      _$this._links = links;

  ProductIndex200ResponseMetaBuilder? _meta;
  ProductIndex200ResponseMetaBuilder get meta =>
      _$this._meta ??= ProductIndex200ResponseMetaBuilder();
  set meta(ProductIndex200ResponseMetaBuilder? meta) => _$this._meta = meta;

  OrderIndex200ResponseAnyOf1Builder() {
    OrderIndex200ResponseAnyOf1._defaults(this);
  }

  OrderIndex200ResponseAnyOf1Builder get _$this {
    final $v = _$v;
    if ($v != null) {
      _data = $v.data.toBuilder();
      _links = $v.links.toBuilder();
      _meta = $v.meta.toBuilder();
      _$v = null;
    }
    return this;
  }

  @override
  void replace(OrderIndex200ResponseAnyOf1 other) {
    _$v = other as _$OrderIndex200ResponseAnyOf1;
  }

  @override
  void update(void Function(OrderIndex200ResponseAnyOf1Builder)? updates) {
    if (updates != null) updates(this);
  }

  @override
  OrderIndex200ResponseAnyOf1 build() => _build();

  _$OrderIndex200ResponseAnyOf1 _build() {
    _$OrderIndex200ResponseAnyOf1 _$result;
    try {
      _$result = _$v ??
          _$OrderIndex200ResponseAnyOf1._(
            data: data.build(),
            links: links.build(),
            meta: meta.build(),
          );
    } catch (_) {
      late String _$failedField;
      try {
        _$failedField = 'data';
        data.build();
        _$failedField = 'links';
        links.build();
        _$failedField = 'meta';
        meta.build();
      } catch (e) {
        throw BuiltValueNestedFieldError(
            r'OrderIndex200ResponseAnyOf1', _$failedField, e.toString());
      }
      rethrow;
    }
    replace(_$result);
    return _$result;
  }
}

// ignore_for_file: deprecated_member_use_from_same_package,type=lint
