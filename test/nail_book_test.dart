import 'package:comeback_app/screens/customer/nail_book_screen.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('nail book paging', () {
    test('an empty book still has one page', () {
      expect(NailBookPage.sheetsFor(0), 1);
      expect(NailBookPage.sheetsFor(-1), 1);
    });

    test('every look lands on exactly one page', () {
      // The real guard. A page holds `perPage` looks and the book shows
      // `sheetsFor(n)` pages, so the pages must have room for every look and
      // never for a whole empty page beyond them. Off by one in either
      // direction and a look silently vanishes off the end, or the customer
      // swipes into a blank sheet.
      for (int n = 1; n <= 50; n++) {
        final capacity = NailBookPage.sheetsFor(n) * NailBookPage.perPage;
        expect(capacity, greaterThanOrEqualTo(n),
            reason: '$n looks do not all fit');
        expect(capacity - n, lessThan(NailBookPage.perPage),
            reason: '$n looks leave a whole page empty');
      }
    });
  });
}
