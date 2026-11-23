import 'package:flutter/foundation.dart';
import 'package:quiver/core.dart';

import 'index.dart';

@immutable
class EhLayout {

  const EhLayout({
    this.sideProportion,
    this.settingSideProportion,
  });

  final double? sideProportion;
  final double? settingSideProportion;

  factory EhLayout.fromJson(Map<String,dynamic> json) => EhLayout(
    sideProportion: json['sideProportion'] != null ? double.tryParse('${json['sideProportion']}') ?? 0.0 : null,
    settingSideProportion: json['settingSideProportion'] != null ? double.tryParse('${json['settingSideProportion']}') : null,
  );
  
  Map<String, dynamic> toJson() => {
    'sideProportion': sideProportion,
    'settingSideProportion': settingSideProportion,
  };

  EhLayout clone() => EhLayout(
    sideProportion: sideProportion,
    settingSideProportion: settingSideProportion,
  );


  EhLayout copyWith({
    Optional<double?>? sideProportion,
    Optional<double?>? settingSideProportion,
  }) => EhLayout(
    sideProportion: checkOptional(sideProportion, () => this.sideProportion),
    settingSideProportion: checkOptional(settingSideProportion, () => this.settingSideProportion),
  );

  @override
  bool operator ==(Object other) => identical(this, other)
    || other is EhLayout && sideProportion == other.sideProportion && settingSideProportion == other.settingSideProportion;

  @override
  int get hashCode => hash2(sideProportion.hashCode, settingSideProportion.hashCode);
}
