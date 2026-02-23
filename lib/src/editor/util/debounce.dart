import 'dart:async';

import 'package:flutter/material.dart';

class Debounce {
  static final Map<String, Timer> _timers = {};
  static final Map<String, VoidCallback> _callbacks = {};

  static void debounce(
    String key,
    Duration duration,
    VoidCallback callback,
  ) {
    if (duration == Duration.zero) {
      // Call immediately
      callback();
      cancel(key);
    } else {
      cancel(key);
      _callbacks[key] = callback;
      _timers[key] = Timer(
        duration,
        () {
          // Remove callback before executing to prevent double-execution
          // if flush() is called re-entrantly during the callback.
          final cb = _callbacks.remove(key);
          _timers.remove(key);
          cb?.call();
        },
      );
    }
  }

  /// Execute the pending callback immediately and cancel the timer.
  ///
  /// This prevents text loss on mobile when the debounce window hasn't
  /// elapsed but the text input service needs to re-attach (e.g. on
  /// selection change or focus loss).
  static void flush(String key) {
    final callback = _callbacks.remove(key);
    _timers[key]?.cancel();
    _timers.remove(key);
    callback?.call();
  }

  static void cancel(String key) {
    _timers[key]?.cancel();
    _timers.remove(key);
    _callbacks.remove(key);
  }

  static bool hasPending(String key) => _callbacks.containsKey(key);

  static void clear() {
    _timers.forEach((_, timer) => timer.cancel());
    _timers.clear();
    _callbacks.clear();
  }
}
