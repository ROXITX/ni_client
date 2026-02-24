import 'dart:async';
import 'package:flutter/foundation.dart';

/// A simple singleton that notifies listeners every minute.
/// Used to keep UI elements that depend on current time (like session status) fresh.
class MinuteUpdater extends ChangeNotifier {
  static final MinuteUpdater _instance = MinuteUpdater._internal();
  factory MinuteUpdater() => _instance;

  Timer? _timer;

  MinuteUpdater._internal() {
    _startTimer();
  }

  void _startTimer() {
    _timer = Timer.periodic(const Duration(seconds: 30), (timer) {
      if (kDebugMode) {
        // Optional debug print to verify it's ticking
        // print('⏰ MinuteUpdater tick');
      }
      notifyListeners();
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }
}
