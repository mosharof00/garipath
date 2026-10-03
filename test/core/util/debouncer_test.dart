import 'package:fake_async/fake_async.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:garipath/core/util/debouncer.dart';

void main() {
  test('runs once, after calls stop, with the last action', () {
    fakeAsync((async) {
      final debouncer = Debouncer(const Duration(milliseconds: 500));
      final runs = <int>[];

      for (var i = 0; i < 10; i++) {
        debouncer.run(() => runs.add(i));
        async.elapse(const Duration(milliseconds: 30));
      }
      expect(runs, isEmpty);

      async.elapse(const Duration(milliseconds: 500));
      expect(runs, [9]);
    });
  });

  test('waits the full delay after the last call', () {
    fakeAsync((async) {
      final debouncer = Debouncer(const Duration(milliseconds: 500));
      var ran = false;

      debouncer.run(() => ran = true);
      async.elapse(const Duration(milliseconds: 499));
      expect(ran, isFalse);
      expect(debouncer.isPending, isTrue);

      async.elapse(const Duration(milliseconds: 1));
      expect(ran, isTrue);
      expect(debouncer.isPending, isFalse);
    });
  });

  test('cancel stops a pending action', () {
    fakeAsync((async) {
      final debouncer = Debouncer(const Duration(milliseconds: 500));
      var ran = false;

      debouncer.run(() => ran = true);
      debouncer.cancel();
      async.elapse(const Duration(seconds: 1));

      expect(ran, isFalse);
      expect(async.pendingTimers, isEmpty);
    });
  });
}
