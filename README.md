# async_tap_guard

[![pub package](https://img.shields.io/pub/v/async_tap_guard.svg)](https://pub.dev/packages/async_tap_guard)
[![CI](https://github.com/abdullahtariq72/async_tap_guard/actions/workflows/ci.yml/badge.svg)](https://github.com/abdullahtariq72/async_tap_guard/actions/workflows/ci.yml)
[![License: MIT](https://img.shields.io/badge/license-MIT-blue.svg)](LICENSE)

Stop double taps from submitting the same order, payment or request twice.

`AsyncTapGuard` wraps **any** button or gesture widget. While its async action
runs, further taps are ignored and the button is disabled. Your builder gets a
busy or failed state so you can show a spinner or a retry label however you
like. No custom button to restyle, and no copied boilerplate in every screen.

<p>
  <img src="https://raw.githubusercontent.com/abdullahtariq72/async_tap_guard/main/doc/idle.png" width="280" alt="Example app, idle">
  <img src="https://raw.githubusercontent.com/abdullahtariq72/async_tap_guard/main/doc/busy.png" width="280" alt="Example app, busy after a double tap">
</p>

```dart
AsyncTapGuard(
  onTap: () => api.placeOrder(cart),
  builder: (context, state, onTap) => FilledButton(
    onPressed: onTap, // null while busy, so the button is disabled
    child: state.isBusy
        ? const CircularProgressIndicator()
        : const Text('Place order'),
  ),
)
```

## Features

- Works with `FilledButton`, `IconButton`, `InkWell`, `GestureDetector`,
  Cupertino buttons or your own widgets
- Busy, idle and failed states, with the error and stack trace
- `minBusyDuration` so a spinner doesn't flicker on fast actions
- `cooldown` to block taps for a while after an action finishes
- Errors go to `onError`, or to `FlutterError.reportError` so they are never
  silently swallowed
- Safe when the widget is disposed while the action is running
- `AsyncGuard`, a plain Dart class for the same protection in controllers,
  blocs or services
- No dependencies besides Flutter

## Installation

```bash
flutter pub add async_tap_guard
```

## Usage

### Showing errors and retrying

```dart
AsyncTapGuard(
  onTap: uploadPhoto,
  minBusyDuration: const Duration(milliseconds: 400),
  onError: (error, stackTrace) => showErrorSnackBar(error),
  builder: (context, state, onTap) => OutlinedButton(
    onPressed: onTap,
    child: Text(switch (state.status) {
      AsyncTapStatus.idle => 'Upload',
      AsyncTapStatus.busy => 'Uploading...',
      AsyncTapStatus.failed => 'Failed, tap to retry',
    }),
  ),
)
```

### Cooldown

```dart
AsyncTapGuard(
  onTap: sendVerificationCode,
  cooldown: const Duration(seconds: 30),
  builder: (context, state, onTap) => TextButton(
    onPressed: onTap,
    child: const Text('Resend code'),
  ),
)
```

### Without widgets

```dart
class CheckoutController {
  final _guard = AsyncGuard();

  /// Returns false if a checkout was already in progress.
  Future<bool> checkout() => _guard.run(() => api.checkout());
}
```

## API

| `AsyncTapGuard` parameter | Description |
|---|---|
| `onTap` | The async action. `null` disables the child. |
| `builder` | `(context, state, onTap)`. Pass `onTap` to your widget. |
| `onError` | Called when `onTap` throws. |
| `minBusyDuration` | Shortest time the busy state is shown. Defaults to zero. |
| `cooldown` | How long taps stay blocked after the action. Defaults to zero. |

See the [example app](example/lib/main.dart) for a runnable demo.

## Contributing

Issues and pull requests are welcome. Please run `flutter analyze` and
`flutter test` before opening a pull request.

## License

MIT
