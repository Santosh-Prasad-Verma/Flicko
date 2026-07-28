package tech.focko.flicko

import android.app.Activity
import android.content.Intent
import android.os.Handler
import android.os.Looper
import com.ryanheise.audioservice.AudioServiceActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : AudioServiceActivity() {

    private val CHANNEL = "tech.focko.flicko/screen_capture"
    private var pendingScreenCapture = false

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL)
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    "prepareCapture" -> {
                        pendingScreenCapture = true
                        result.success(true)
                    }
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
                            pendingScreenCapture = false
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
        // On Android 14+ (API 34+), when user approves screen share prompt:
        // 1. Immediately start ScreenCaptureService so the mediaProjection FGS starts
        // 2. Defer passing result back to flutter_webrtc slightly to allow FGS registration
        if (resultCode == Activity.RESULT_OK && (pendingScreenCapture || data?.getParcelableExtra<Intent>(Intent.EXTRA_INTENT) != null || requestCode == 1)) {
            pendingScreenCapture = false
            ScreenCaptureService.start(this)
            Handler(Looper.getMainLooper()).postDelayed({
                super.onActivityResult(requestCode, resultCode, data)
            }, 300)
            return
        }
        super.onActivityResult(requestCode, resultCode, data)
    }
}
