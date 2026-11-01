import 'package:flutter/foundation.dart';
import 'package:quiver/core.dart';

import 'index.dart';

@immutable
class ItemConfig {

  const ItemConfig({
    required this.type,
    this.enableCustomWidth,
    this.customWidth,
    this.cardSize,
  });

  final String type;
  final bool? enableCustomWidth;
  final int? customWidth;
  final int? cardSize;

  factory ItemConfig.fromJson(Map<String,dynamic> json) => ItemConfig(
    type: json['type'].toString(),
    enableCustomWidth: json['enableCustomWidth'] != null ? bool.tryParse('${json['enableCustomWidth']}', caseSensitive: false) ?? false : null,
    customWidth: json['customWidth'] != null ? int.tryParse('${json['customWidth']}') ?? 0 : null,
    cardSize: json['cardSize'] != null ? int.tryParse('${json['cardSize']}') ?? 2 : null
  );
  
  Map<String, dynamic> toJson() => {
    'type': type,
    'enableCustomWidth': enableCustomWidth,
    'customWidth': customWidth,
    'cardSize': cardSize
  };

  ItemConfig clone() => ItemConfig(
    type: type,
    enableCustomWidth: enableCustomWidth,
    customWidth: customWidth,
    cardSize: cardSize
  );


  ItemConfig copyWith({
    String? type,
    Optional<bool?>? enableCustomWidth,
    Optional<int?>? customWidth,
    Optional<int?>? cardSize
  }) => ItemConfig(
    type: type ?? this.type,
    enableCustomWidth: checkOptional(enableCustomWidth, () => this.enableCustomWidth),
    customWidth: checkOptional(customWidth, () => this.customWidth),
    cardSize: checkOptional(cardSize, () => this.cardSize),
  );

  @override
  bool operator ==(Object other) => identical(this, other)
    || other is ItemConfig && type == other.type && enableCustomWidth == other.enableCustomWidth && customWidth == other.customWidth && cardSize == other.cardSize;

  @override
  int get hashCode => type.hashCode ^ enableCustomWidth.hashCode ^ customWidth.hashCode ^ cardSize.hashCode;
}
