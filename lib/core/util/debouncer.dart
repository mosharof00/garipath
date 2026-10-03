import 'dart:async';

/// Runs an action only after calls have stopped for [delay].
///
/// Ten long-presses in a row restart the timer ten times, so only the last
/// one does the work. Used to avoid one network request per gesture.
class Debouncer {
  Debouncer(this.delay);

  final Duration delay;
  Timer? _timer;

  bool get isPending => _timer?.isActive ?? false;

  /// Schedules [action], replacing any action that hasn't run yet.
  void run(void Function() action) {
    _timer?.cancel();
    _timer = Timer(delay, action);
  }

  void cancel() {
    _timer?.cancel();
    _timer = null;
  }
}
