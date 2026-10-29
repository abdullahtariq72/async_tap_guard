import 'dart:async';

import 'package:flutter/widgets.dart';

/// The phase of an [AsyncTapGuard]'s action.
enum AsyncTapStatus {
  /// No action is running.
  idle,

  /// The action is running.
  busy,

  /// The last action threw an error. The next tap starts a new action.
  failed,
}

/// The state passed to an [AsyncTapGuard] builder.
@immutable
class AsyncTapState {
  /// Creates a state. Usually only [AsyncTapGuard] creates these.
  const AsyncTapState({
    this.status = AsyncTapStatus.idle,
    this.error,
    this.stackTrace,
  });

  /// The current phase.
  final AsyncTapStatus status;

  /// The error thrown by the last action, if [status] is
  /// [AsyncTapStatus.failed].
  final Object? error;

  /// The stack trace for [error].
  final StackTrace? stackTrace;

  /// Whether the action is running.
  bool get isBusy => status == AsyncTapStatus.busy;

  /// Whether the last action failed.
  bool get hasError => status == AsyncTapStatus.failed;

  @override
  bool operator ==(Object other) =>
      other is AsyncTapState &&
      other.status == status &&
      other.error == error &&
      other.stackTrace == stackTrace;

  @override
  int get hashCode => Object.hash(status, error, stackTrace);

  @override
  String toString() => 'AsyncTapState($status${hasError ? ', $error' : ''})';
}

/// Builds the guarded widget.
///
/// [onTap] is `null` while the action is running, during the cooldown, or
/// when [AsyncTapGuard.onTap] is `null`, so passing it straight to a button's
/// `onPressed` disables the button at the right times.
typedef AsyncTapWidgetBuilder = Widget Function(
  BuildContext context,
  AsyncTapState state,
  VoidCallback? onTap,
);

/// Wraps any widget with an async callback so that it cannot be triggered
/// again while the callback is still running.
///
/// The [builder] receives the current [AsyncTapState] and a guarded `onTap`
/// to hand to the child, so it works with any button or gesture widget:
///
/// ```dart
/// AsyncTapGuard(
///   onTap: () => api.placeOrder(),
///   builder: (context, state, onTap) => FilledButton(
///     onPressed: onTap,
///     child: state.isBusy
///         ? const SizedBox.square(
///             dimension: 16,
///             child: CircularProgressIndicator(strokeWidth: 2),
///           )
///         : const Text('Place order'),
///   ),
/// )
/// ```
class AsyncTapGuard extends StatefulWidget {
  /// Creates an [AsyncTapGuard].
  const AsyncTapGuard({
    super.key,
    required this.onTap,
    required this.builder,
    this.onError,
    this.minBusyDuration = Duration.zero,
    this.cooldown = Duration.zero,
  });

  /// The action to run. If `null`, the builder receives a `null` callback.
  final FutureOr<void> Function()? onTap;

  /// Builds the child from the current state and guarded callback.
  final AsyncTapWidgetBuilder builder;

  /// Called when [onTap] throws.
  ///
  /// If `null`, errors are reported through [FlutterError.reportError] so
  /// they are not silently swallowed. Either way the builder receives an
  /// [AsyncTapStatus.failed] state.
  final void Function(Object error, StackTrace stackTrace)? onError;

  /// The shortest time the busy state is shown.
  ///
  /// Use this to avoid a loading indicator flickering for actions that
  /// usually finish almost instantly.
  final Duration minBusyDuration;

  /// How long taps stay blocked after the action completes.
  final Duration cooldown;

  @override
  State<AsyncTapGuard> createState() => _AsyncTapGuardState();
}

class _AsyncTapGuardState extends State<AsyncTapGuard> {
  AsyncTapState _state = const AsyncTapState();
  bool _locked = false;
  Timer? _cooldownTimer;

  @override
  void dispose() {
    _cooldownTimer?.cancel();
    super.dispose();
  }

  Future<void> _handleTap() async {
    final action = widget.onTap;
    if (action == null || _locked) return;
    _locked = true;
    setState(() => _state = const AsyncTapState(status: AsyncTapStatus.busy));

    final minBusy = Future<void>.delayed(widget.minBusyDuration);
    AsyncTapState result = const AsyncTapState();
    try {
      await action();
    } catch (error, stackTrace) {
      result = AsyncTapState(
        status: AsyncTapStatus.failed,
        error: error,
        stackTrace: stackTrace,
      );
      _reportError(error, stackTrace);
    }
    await minBusy;
    if (!mounted) return;

    if (widget.cooldown > Duration.zero) {
      _cooldownTimer = Timer(widget.cooldown, () {
        if (mounted) setState(() => _locked = false);
      });
    } else {
      _locked = false;
    }
    setState(() => _state = result);
  }

  void _reportError(Object error, StackTrace stackTrace) {
    final onError = widget.onError;
    if (onError != null) {
      onError(error, stackTrace);
    } else {
      FlutterError.reportError(FlutterErrorDetails(
        exception: error,
        stack: stackTrace,
        library: 'async_tap_guard',
        context: ErrorDescription('while running an AsyncTapGuard action'),
      ));
    }
  }

  @override
  Widget build(BuildContext context) {
    final enabled = widget.onTap != null && !_locked;
    return widget.builder(context, _state, enabled ? _handleTap : null);
  }
}
