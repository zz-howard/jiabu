package io.github.zzhoward.jiabu

import android.content.ClipData
import android.content.ClipDescription
import android.content.ClipboardManager
import android.content.Context
import android.content.Intent
import android.net.Uri
import android.os.Build
import android.os.PersistableBundle
import android.view.WindowManager
import java.util.TimeZone
import io.flutter.embedding.android.FlutterFragmentActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterFragmentActivity() {
    private var pendingImageFiles: MethodChannel.Result? = null
    private var imageFileLimit = 9

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        // Chat attachment sheet, 文件 tab: image files from the system document
        // picker (Storage Access Framework, no storage permission). Returns
        // the raw bytes; Dart normalises them through the same JPEG pipeline.
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "jiabu/image_files")
            .setMethodCallHandler { call, result ->
                if (call.method != "pick") {
                    result.notImplemented()
                } else if (pendingImageFiles != null) {
                    result.error("image_selection_busy", null, null)
                } else {
                    imageFileLimit = call.argument<Int>("limit") ?: 9
                    pendingImageFiles = result
                    val intent = Intent(Intent.ACTION_OPEN_DOCUMENT)
                        .addCategory(Intent.CATEGORY_OPENABLE)
                        .setType("image/*")
                        .putExtra(Intent.EXTRA_ALLOW_MULTIPLE, true)
                    @Suppress("DEPRECATION")
                    startActivityForResult(intent, IMAGE_FILES_REQUEST)
                }
            }
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

    @Deprecated("Activity result API; kept for FlutterFragmentActivity parity")
    override fun onActivityResult(requestCode: Int, resultCode: Int, data: Intent?) {
        @Suppress("DEPRECATION")
        super.onActivityResult(requestCode, resultCode, data)
        if (requestCode != IMAGE_FILES_REQUEST) return
        val result = pendingImageFiles ?: return
        pendingImageFiles = null
        val uris = mutableListOf<Uri>()
        if (resultCode == RESULT_OK && data != null) {
            val clip = data.clipData
            if (clip != null) {
                for (i in 0 until clip.itemCount) uris.add(clip.getItemAt(i).uri)
            } else {
                data.data?.let { uris.add(it) }
            }
        }
        val limit = imageFileLimit
        Thread {
            try {
                val bytes = uris.take(limit).mapNotNull { uri ->
                    contentResolver.openInputStream(uri)?.use { it.readBytes() }
                }
                runOnUiThread { result.success(bytes) }
            } catch (error: Exception) {
                runOnUiThread { result.error("image_selection_failed", null, null) }
            }
        }.start()
    }

    private companion object {
        const val IMAGE_FILES_REQUEST = 7301
    }
}
