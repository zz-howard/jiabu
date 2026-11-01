package io.github.zzhoward.jiabu

import android.content.ClipData
import android.content.ClipDescription
import android.content.ClipboardManager
import android.content.Context
import android.content.Intent
import android.net.Uri
import android.os.Build
import android.os.PersistableBundle
import android.provider.OpenableColumns
import android.view.WindowManager
import java.io.ByteArrayOutputStream
import java.io.IOException
import java.util.TimeZone
import io.flutter.embedding.android.FlutterFragmentActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterFragmentActivity() {
    private var pendingImageFiles: MethodChannel.Result? = null
    private var imageFileLimit = 9
    private var pendingPdfFiles: MethodChannel.Result? = null
    private var pdfFileLimit = 4
    private var pdfMaxBytes = 10L * 1024 * 1024

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        // System document picker (Storage Access Framework, no storage
        // permission). "pick": image files, raw bytes that Dart normalises
        // through the JPEG pipeline. "pickPdfs": the chat attachment sheet's
        // 文件 tab; per PDF its display name, size and raw bytes.
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "jiabu/image_files")
            .setMethodCallHandler { call, result ->
                if (call.method != "pick" && call.method != "pickPdfs") {
                    result.notImplemented()
                } else if (pendingImageFiles != null || pendingPdfFiles != null) {
                    result.error("image_selection_busy", null, null)
                } else if (call.method == "pickPdfs") {
                    pdfFileLimit = call.argument<Int>("limit") ?: 4
                    pdfMaxBytes = call.argument<Number>("maxBytes")?.toLong()
                        ?: (10L * 1024 * 1024)
                    pendingPdfFiles = result
                    val intent = Intent(Intent.ACTION_OPEN_DOCUMENT)
                        .addCategory(Intent.CATEGORY_OPENABLE)
                        .setType("application/pdf")
                        .putExtra(Intent.EXTRA_ALLOW_MULTIPLE, true)
                    @Suppress("DEPRECATION")
                    startActivityForResult(intent, PDF_FILES_REQUEST)
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
        if (requestCode == PDF_FILES_REQUEST) {
            val pdfs = pendingPdfFiles ?: return
            pendingPdfFiles = null
            returnPdfs(pdfs, pickedUris(resultCode, data))
            return
        }
        if (requestCode != IMAGE_FILES_REQUEST) return
        val result = pendingImageFiles ?: return
        pendingImageFiles = null
        val uris = pickedUris(resultCode, data)
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

    private fun pickedUris(resultCode: Int, data: Intent?): List<Uri> {
        val uris = mutableListOf<Uri>()
        if (resultCode == RESULT_OK && data != null) {
            val clip = data.clipData
            if (clip != null) {
                for (i in 0 until clip.itemCount) uris.add(clip.getItemAt(i).uri)
            } else {
                data.data?.let { uris.add(it) }
            }
        }
        return uris
    }

    // Every picked document reports its name and size so Dart can reject a
    // selection over the limit; bytes are read only for the first `limit`
    // documents and never beyond `maxBytes` (null bytes = too large).
    private fun returnPdfs(result: MethodChannel.Result, uris: List<Uri>) {
        val limit = pdfFileLimit
        val maxBytes = pdfMaxBytes
        Thread {
            try {
                val files = uris.mapIndexed { index, uri ->
                    var name: String? = null
                    var size = -1L
                    contentResolver.query(
                        uri,
                        arrayOf(OpenableColumns.DISPLAY_NAME, OpenableColumns.SIZE),
                        null,
                        null,
                        null,
                    )?.use { cursor ->
                        if (cursor.moveToFirst()) {
                            val nameColumn = cursor.getColumnIndex(OpenableColumns.DISPLAY_NAME)
                            val sizeColumn = cursor.getColumnIndex(OpenableColumns.SIZE)
                            if (nameColumn >= 0 && !cursor.isNull(nameColumn)) {
                                name = cursor.getString(nameColumn)
                            }
                            if (sizeColumn >= 0 && !cursor.isNull(sizeColumn)) {
                                size = cursor.getLong(sizeColumn)
                            }
                        }
                    }
                    val bytes = if (index < limit && size <= maxBytes) {
                        readAtMost(uri, maxBytes)
                    } else {
                        null
                    }
                    mapOf(
                        "name" to name,
                        "size" to (bytes?.size?.toLong() ?: size),
                        "bytes" to bytes,
                    )
                }
                runOnUiThread { result.success(files) }
            } catch (error: Exception) {
                runOnUiThread { result.error("file_selection_failed", null, null) }
            }
        }.start()
    }

    private fun readAtMost(uri: Uri, maxBytes: Long): ByteArray? {
        val input = contentResolver.openInputStream(uri)
            ?: throw IOException("unreadable_document")
        return input.use { stream ->
            val out = ByteArrayOutputStream()
            val buffer = ByteArray(64 * 1024)
            var total = 0L
            var tooLarge = false
            while (true) {
                val read = stream.read(buffer)
                if (read < 0) break
                total += read
                if (total > maxBytes) {
                    tooLarge = true
                    break
                }
                out.write(buffer, 0, read)
            }
            if (tooLarge) null else out.toByteArray()
        }
    }

    private companion object {
        const val IMAGE_FILES_REQUEST = 7301
        const val PDF_FILES_REQUEST = 7302
    }
}
