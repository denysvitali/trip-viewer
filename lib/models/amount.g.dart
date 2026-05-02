// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'amount.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

Amount _$AmountFromJson(Map<String, dynamic> json) => Amount(
      amount: (json['amount'] as num).toDouble(),
      currencyCode: json['currencyCode'] as String?,
    );

Map<String, dynamic> _$AmountToJson(Amount instance) => <String, dynamic>{
      'amount': instance.amount,
      'currencyCode': instance.currencyCode,
    };
