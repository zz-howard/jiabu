package io.github.zzhoward.jiabu

import android.content.ClipData
import android.content.ClipDescription
import android.content.ClipboardManager
import android.content.Context
import android.os.Build
import android.os.PersistableBundle
import android.view.WindowManager
import java.util.TimeZone
import io.flutter.embedding.android.FlutterFragmentActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterFragmentActivity() {
    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "jiabu/window_privacy")
            .setMethodCallHandler { call, result ->
                if (call.method == "deviceTimezone") {
                    result.success(TimeZone.getDefault().id)
                } else if (call.method != "setSecure") {
                    result.notImplemented()
                } else {
                    if (call.argument<Boolean>("enabled") == true) {
                        window.addFlags(WindowManager.LayoutParams.FLAG_SECURE)
                    } else {
                        window.clearFlags(WindowManager.LayoutParams.FLAG_SECURE)
                    }
                    result.success(null)
                }
            }
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "jiabu/secure_clipboard")
            .setMethodCallHandler { call, result ->
                if (call.method != "copy") {
                    result.notImplemented()
                } else {
                    val text = call.argument<String>("text")
                    if (text == null || call.argument<Boolean>("sensitive") != true) {
                        result.error("invalid_sensitive_clip", null, null)
                    } else {
                        val clip = ClipData.newPlainText("", text)
                        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU) {
                            clip.description.extras = PersistableBundle().apply {
                                putBoolean(ClipDescription.EXTRA_IS_SENSITIVE, true)
                            }
                        }
                        (getSystemService(Context.CLIPBOARD_SERVICE) as ClipboardManager)
                            .setPrimaryClip(clip)
                        result.success(null)
                    }
                }
            }
    }
}
