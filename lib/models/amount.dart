import 'package:intl/intl.dart';
import 'package:json_annotation/json_annotation.dart';

part 'amount.g.dart';

@JsonSerializable()
class Amount {
  final double amount;
  final String? currencyCode;

  Amount({required this.amount, this.currencyCode});

  factory Amount.fromJson(Map<String, dynamic> json) => Amount(
        amount: (json['amount'] as num?)?.toDouble() ?? 0,
        currencyCode: json['currencyCode'] as String?,
      );

  Map<String, dynamic> toJson() => _$AmountToJson(this);

  // Format the amount with currency symbol/code
  String format() {
    try {
      final format = NumberFormat.currency(
        locale:
            'en_US', // Use a locale that supports the currency or handle mapping
        symbol: currencyCode ?? '', // Use currency code as symbol if available
        decimalDigits: 2,
      );
      // Handle potential negative amounts if necessary
      return format.format(amount);
    } catch (e) {
      // Fallback for unknown currency codes or formatting errors
      return '${amount.toStringAsFixed(2)} ${currencyCode ?? ''}'.trim();
    }
  }
}
