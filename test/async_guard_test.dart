import 'dart:async';

import 'package:async_tap_guard/async_tap_guard.dart';
import 'package:fake_async/fake_async.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('ignores calls while an action is running', () async {
    final guard = AsyncGuard();
    final completer = Completer<void>();
    var runs = 0;

    final first = guard.run(() {
      runs++;
      return completer.future;
    });
    expect(guard.isLocked, isTrue);
    expect(await guard.run(() => runs++), isFalse);

    completer.complete();
    expect(await first, isTrue);
    expect(runs, 1);
    expect(guard.isLocked, isFalse);
  });

  test('rethrows errors and unlocks', () async {
    final guard = AsyncGuard();
    await expectLater(
        guard.run(() => throw StateError('boom')), throwsStateError);
    expect(guard.isLocked, isFalse);
    expect(await guard.run(() {}), isTrue);
  });

  test('stays locked during cooldown', () {
    fakeAsync((async) {
      final guard = AsyncGuard(cooldown: const Duration(seconds: 1));
      guard.run(() {});
      async.flushMicrotasks();
      expect(guard.isLocked, isTrue);

      async.elapse(const Duration(milliseconds: 999));
      expect(guard.isLocked, isTrue);
      async.elapse(const Duration(milliseconds: 1));
      expect(guard.isLocked, isFalse);
    });
  });
}
