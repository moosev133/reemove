class Money {
  const Money({required this.amountMinor, required this.currency})
    : assert(amountMinor >= 0);

  final int amountMinor;
  final String currency;

  double get amountMajor => amountMinor / 100;
}
