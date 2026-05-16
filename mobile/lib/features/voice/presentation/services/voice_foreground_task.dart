import 'package:flutter_foreground_task/flutter_foreground_task.dart';

@pragma('vm:entry-point')
void startCallback() {
  FlutterForegroundTask.setTaskHandler(VoiceForegroundTaskHandler());
}

class VoiceForegroundTaskHandler extends TaskHandler {
  @override
  Future<void> onStart(DateTime timestamp, TaskStarter starter) async {
    // Initialization if needed
  }

  @override
  void onRepeatEvent(DateTime timestamp) {
    // We can update the notification here if we have dynamic data
    // For voice, we usually just want the service to stay alive.
  }

  @override
  Future<void> onDestroy(DateTime timestamp, bool isTimeout) async {
    // Cleanup
  }
}
