import 'dart:async';

import 'package:flutter/foundation.dart';

class IsolateRunner {
  Future<R> run<T, R>(FutureOr<R> Function(T message) task, T message) {
    return compute(task, message);
  }
}
