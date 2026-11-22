import 'dart:async';

/// Debounces expensive launcher-widget captures and guarantees a queued capture
/// is abandoned when the screen is no longer eligible to run it.
///
/// Eligibility is supplied by the caller as a snapshot ([canCapture]) and as a
/// lazy check at fire time ([stillCanCapture]). The lazy check is what stops a
/// capture that was queued while the dashboard was visible from running after
/// the user switched to another shell tab during the debounce window.
class HomeWidgetCaptureScheduler {
  HomeWidgetCaptureScheduler({this.debounce = const Duration(milliseconds: 1200)});

  final Duration debounce;
  Timer? _timer;

  bool get isScheduled => _timer?.isActive ?? false;

  /// Queues [capture] after [debounce] when [canCapture] is true.
  ///
  /// Re-scheduling cancels any pending capture, which mirrors the dashboard's
  /// build-time debounce: the timer only fires after data has settled.
  void schedule({
    required bool canCapture,
    required bool Function() stillCanCapture,
    required Future<void> Function() capture,
  }) {
    _timer?.cancel();
    _timer = null;
    if (!canCapture) return;
    _timer = Timer(debounce, () {
      _timer = null;
      if (!stillCanCapture()) return;
      capture();
    });
  }

  void cancel() {
    _timer?.cancel();
    _timer = null;
  }

  void dispose() => cancel();
}
