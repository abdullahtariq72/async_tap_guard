import 'dart:async';

/// Runs at most one async action at a time.
///
/// Calls to [run] made while a previous action is still running are ignored,
/// which makes it a simple way to prevent duplicate submissions from repeated
/// taps, key presses or events. It has no Flutter dependency, so it can also be
/// used in controllers, blocs or services.
///
/// ```dart
/// final guard = AsyncGuard();
///
/// Future<void> submit() => guard.run(() => api.placeOrder());
/// ```
class AsyncGuard {
  /// Creates a guard.
  ///
  /// [cooldown] keeps the guard locked for a while after an action completes,
  /// which is useful for actions that should not be repeated immediately.
  AsyncGuard({this.cooldown = Duration.zero});

  /// How long the guard stays locked after an action completes.
  final Duration cooldown;

  bool _locked = false;

  /// Whether an action is running or the cooldown has not yet elapsed.
  bool get isLocked => _locked;

  /// Runs [action] unless the guard is locked.
  ///
  /// Returns `true` if [action] ran and completed successfully, and `false`
  /// if the call was ignored because the guard was locked. Errors thrown by
  /// [action] are rethrown to the caller; the guard is unlocked either way.
  Future<bool> run(FutureOr<void> Function() action) async {
    if (_locked) return false;
    _locked = true;
    try {
      await action();
      return true;
    } finally {
      if (cooldown > Duration.zero) {
        Timer(cooldown, () => _locked = false);
      } else {
        _locked = false;
      }
    }
  }
}
