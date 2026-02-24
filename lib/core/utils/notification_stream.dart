// lib/utils/notification_stream.dart
import 'dart:async';

class NotificationStream {
  // A private constructor to prevent external instantiation.
  NotificationStream._privateConstructor();

  // The single, static instance of the class.
  static final NotificationStream instance =
      NotificationStream._privateConstructor();

  // The stream controller that will manage the stream of events.
  final StreamController<void> _controller = StreamController.broadcast();

  // A public getter for the stream, so UI components can listen to it.
  Stream<void> get stream => _controller.stream;

  // A method to send a new "refresh" event into the stream.
  void newNotification() {
    _controller.add(null);
  }

  // A method to close the stream controller when it's no longer needed.
  void dispose() {
    _controller.close();
  }
}
