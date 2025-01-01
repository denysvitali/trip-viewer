import 'package:json_annotation/json_annotation.dart';

part 'amount.g.dart';

@JsonSerializable()
class Amount {
  final double value;
  final String currencyCode;

  Amount({required this.value, required this.currencyCode});

  factory Amount.fromJson(Map<String, dynamic> json) => _$AmountFromJson(json);

  Map<String, dynamic> toJson() => _$AmountToJson(this);
}
