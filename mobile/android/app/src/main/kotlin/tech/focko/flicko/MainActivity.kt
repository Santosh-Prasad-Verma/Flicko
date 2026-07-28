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
}
