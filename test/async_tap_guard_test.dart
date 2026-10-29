import 'dart:async';

import 'package:async_tap_guard/async_tap_guard.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

Widget _app(AsyncTapGuard guard) =>
    MaterialApp(home: Scaffold(body: Center(child: guard)));

Widget _buildButton(
  BuildContext context,
  AsyncTapState state,
  VoidCallback? onTap,
) {
  return ElevatedButton(
    onPressed: onTap,
    child: Text(switch (state.status) {
      AsyncTapStatus.idle => 'idle',
      AsyncTapStatus.busy => 'busy',
      AsyncTapStatus.failed => 'failed: ${state.error}',
    }),
  );
}

void main() {
  testWidgets('runs the action once while busy', (tester) async {
    final completer = Completer<void>();
    var runs = 0;
    await tester.pumpWidget(_app(AsyncTapGuard(
      onTap: () {
        runs++;
        return completer.future;
      },
      builder: _buildButton,
    )));

    await tester.tap(find.byType(ElevatedButton));
    await tester.pump();
    expect(find.text('busy'), findsOneWidget);

    await tester.tap(find.byType(ElevatedButton));
    await tester.tap(find.byType(ElevatedButton));
    await tester.pump();
    expect(runs, 1);

    completer.complete();
    await tester.pumpAndSettle();
    expect(find.text('idle'), findsOneWidget);

    await tester.tap(find.byType(ElevatedButton));
    await tester.pump();
    expect(runs, 2);
    await tester.pumpAndSettle();
  });

  testWidgets('passes a null callback while busy', (tester) async {
    final completer = Completer<void>();
    VoidCallback? latest;
    await tester.pumpWidget(_app(AsyncTapGuard(
      onTap: () => completer.future,
      builder: (context, state, onTap) {
        latest = onTap;
        return _buildButton(context, state, onTap);
      },
    )));
    expect(latest, isNotNull);

    await tester.tap(find.byType(ElevatedButton));
    await tester.pump();
    expect(latest, isNull);

    completer.complete();
    await tester.pumpAndSettle();
    expect(latest, isNotNull);
  });

  testWidgets('passes a null callback when onTap is null', (tester) async {
    await tester.pumpWidget(_app(const AsyncTapGuard(
      onTap: null,
      builder: _buildButton,
    )));
    final button = tester.widget<ElevatedButton>(find.byType(ElevatedButton));
    expect(button.onPressed, isNull);
  });

  testWidgets('exposes errors and calls onError', (tester) async {
    Object? reported;
    await tester.pumpWidget(_app(AsyncTapGuard(
      onTap: () async => throw StateError('boom'),
      onError: (error, _) => reported = error,
      builder: _buildButton,
    )));

    await tester.tap(find.byType(ElevatedButton));
    await tester.pumpAndSettle();
    expect(reported, isStateError);
    expect(find.text('failed: Bad state: boom'), findsOneWidget);

    // A failed action can be retried.
    await tester.tap(find.byType(ElevatedButton));
    await tester.pump();
    expect(find.text('busy'), findsOneWidget);
    await tester.pumpAndSettle();
  });

  testWidgets('reports errors to FlutterError without onError', (tester) async {
    await tester.pumpWidget(_app(AsyncTapGuard(
      onTap: () async => throw StateError('boom'),
      builder: _buildButton,
    )));

    await tester.tap(find.byType(ElevatedButton));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isStateError);
    expect(find.text('failed: Bad state: boom'), findsOneWidget);
  });

  testWidgets('keeps the busy state for minBusyDuration', (tester) async {
    await tester.pumpWidget(_app(AsyncTapGuard(
      onTap: () {},
      minBusyDuration: const Duration(milliseconds: 300),
      builder: _buildButton,
    )));

    await tester.tap(find.byType(ElevatedButton));
    await tester.pump(const Duration(milliseconds: 299));
    expect(find.text('busy'), findsOneWidget);
    await tester.pump(const Duration(milliseconds: 1));
    expect(find.text('idle'), findsOneWidget);
  });

  testWidgets('blocks taps during cooldown', (tester) async {
    var runs = 0;
    await tester.pumpWidget(_app(AsyncTapGuard(
      onTap: () => runs++,
      cooldown: const Duration(seconds: 1),
      builder: _buildButton,
    )));

    await tester.tap(find.byType(ElevatedButton));
    await tester.pump();
    await tester.tap(find.byType(ElevatedButton));
    await tester.pump(const Duration(milliseconds: 500));
    expect(runs, 1);

    await tester.pump(const Duration(milliseconds: 500));
    await tester.tap(find.byType(ElevatedButton));
    await tester.pump();
    expect(runs, 2);
    await tester.pumpAndSettle(const Duration(seconds: 1));
  });

  testWidgets('does not throw when disposed while busy', (tester) async {
    final completer = Completer<void>();
    await tester.pumpWidget(_app(AsyncTapGuard(
      onTap: () => completer.future,
      cooldown: const Duration(seconds: 1),
      builder: _buildButton,
    )));

    await tester.tap(find.byType(ElevatedButton));
    await tester.pump();
    await tester.pumpWidget(const SizedBox());

    completer.complete();
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
  });
}
