class PaginationPage<T> {
  const PaginationPage({
    required this.items,
    required this.hasMore,
    this.cursorDocumentId,
  });

  final List<T> items;
  final bool hasMore;
  final String? cursorDocumentId;
}
