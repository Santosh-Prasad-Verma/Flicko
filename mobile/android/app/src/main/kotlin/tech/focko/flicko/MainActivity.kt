package tech.focko.flicko

import android.app.Activity
import android.content.Intent
import com.ryanheise.audioservice.AudioServiceActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : AudioServiceActivity() {

    private val CHANNEL = "tech.focko.flicko/screen_capture"

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL)
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    "startService" -> {
                        try {
                            ScreenCaptureService.start(this)
                            result.success(true)
                        } catch (e: Exception) {
                            result.error("FGS_ERROR", e.message, null)
                        }
                    }
                    "stopService" -> {
                        try {
                            ScreenCaptureService.stop(this)
                            result.success(true)
                        } catch (e: Exception) {
                            result.error("FGS_ERROR", e.message, null)
                        }
                    }
                    else -> result.notImplemented()
                }
            }
    }

    override fun onActivityResult(requestCode: Int, resultCode: Int, data: Intent?) {
        // Start the foreground service BEFORE super.onActivityResult so that
        // MediaProjection is guaranteed to have an active mediaProjection FGS
        // when flutter_webrtc processes the intent result inside super.onActivityResult.
        if (requestCode == 1 && resultCode == Activity.RESULT_OK) {
            ScreenCaptureService.start(this)
        }
        super.onActivityResult(requestCode, resultCode, data)
    }
}
