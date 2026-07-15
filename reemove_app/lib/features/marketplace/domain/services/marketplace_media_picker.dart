abstract interface class MarketplaceMediaPicker {
  Future<List<String>> pickImages({int limit = 8});
}
