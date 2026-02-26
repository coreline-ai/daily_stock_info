import 'dart:async';

class RetryPolicy {
  const RetryPolicy({this.maxAttempts = 3, this.baseDelayMs = 350});

  final int maxAttempts;
  final int baseDelayMs;

  Future<T> run<T>(
    Future<T> Function() task, {
    bool Function(Object error)? retryWhen,
  }) async {
    Object? lastError;
    StackTrace? lastStack;

    for (var i = 0; i < maxAttempts; i++) {
      try {
        return await task();
      } catch (error, stack) {
        lastError = error;
        lastStack = stack;
        final shouldRetry = retryWhen?.call(error) ?? true;
        if (!shouldRetry || i == maxAttempts - 1) {
          break;
        }
        await Future<void>.delayed(
          Duration(milliseconds: baseDelayMs * (i + 1)),
        );
      }
    }

    Error.throwWithStackTrace(lastError!, lastStack!);
  }
}
