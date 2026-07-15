import '../../domain/value_objects/money.dart';
import '../firestore_parser.dart';

class MoneyDto {
  const MoneyDto({required this.amountMinor, required this.currency});

  factory MoneyDto.fromMap(FirestoreMap data) => MoneyDto(
    amountMinor: FirestoreParser.integer(data, 'amountMinor'),
    currency: FirestoreParser.string(data, 'currency'),
  );

  factory MoneyDto.fromDomain(Money value) =>
      MoneyDto(amountMinor: value.amountMinor, currency: value.currency);

  final int amountMinor;
  final String currency;

  Money toDomain() => Money(amountMinor: amountMinor, currency: currency);

  FirestoreMap toMap() => <String, Object?>{
    'amountMinor': amountMinor,
    'currency': currency,
  };
}
