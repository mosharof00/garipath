import 'dart:async';

/// A simple "please stop" flag that can be passed into async work.
///
/// Controllers use this instead of dio's CancelToken, so they don't depend
/// on the HTTP library. The repository turns it into a CancelToken.
class CancelSignal {
  final _cancelled = Completer<void>();

  bool get isCancelled => _cancelled.isCompleted;

  /// Completes when [cancel] is called.
  Future<void> get whenCancelled => _cancelled.future;

  /// Safe to call more than once.
  void cancel() {
    if (!_cancelled.isCompleted) _cancelled.complete();
  }
}
