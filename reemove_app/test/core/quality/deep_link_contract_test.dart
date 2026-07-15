import 'package:flutter_test/flutter_test.dart';
import 'package:reemove/app/router/deep_link_policy.dart';

void main() {
  test('accepts approved app and universal links', () {
    expect(DeepLinkPolicy.parseAllowed('https://reemove.app/p/abc'), isNotNull);
    expect(
      DeepLinkPolicy.parseAllowed('https://links.reemove.app/ch/weekly-5k'),
      isNotNull,
    );
    expect(
      DeepLinkPolicy.parseAllowed('https://www.reemove.app/u/athlete'),
      isNotNull,
    );
    expect(DeepLinkPolicy.parseAllowed('reemove://m/listing-1'), isNotNull);
    expect(
      DeepLinkPolicy.parseAllowed('https://reemove.app/discover/ai/coach'),
      isNotNull,
    );
    expect(
      DeepLinkPolicy.parseAllowed('https://reemove.app/home/activity'),
      isNotNull,
    );
  });

  test('rejects unsupported and malformed links', () {
    expect(DeepLinkPolicy.parseAllowed('javascript:alert(1)'), isNull);
    expect(DeepLinkPolicy.parseAllowed('https://example.com/p/abc'), isNull);
    expect(DeepLinkPolicy.parseAllowed('reemove://unknown/abc'), isNull);
    expect(DeepLinkPolicy.parseAllowed('https://reemove.app/'), isNull);
    expect(DeepLinkPolicy.parseAllowed('ftp://reemove.app/p/abc'), isNull);
  });
}
