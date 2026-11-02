package io.github.zzhoward.jiabu

import android.app.PendingIntent
import android.content.BroadcastReceiver
import android.content.ClipData
import android.content.ClipDescription
import android.content.ClipboardManager
import android.content.Context
import android.content.Intent
import android.content.IntentFilter
import android.content.pm.PackageInstaller
import android.content.pm.PackageManager
import android.net.Uri
import android.os.Build
import android.os.PersistableBundle
import android.provider.OpenableColumns
import android.provider.Settings
import android.util.Base64
import android.view.WindowManager
import java.io.File
import java.io.FileOutputStream
import java.io.IOException
import java.util.TimeZone
import io.flutter.embedding.android.FlutterFragmentActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterFragmentActivity() {
    private var pendingImageFiles: MethodChannel.Result? = null
    private var imageFileLimit = 9
    private var pendingDocuments: MethodChannel.Result? = null
    private var documentImageSlots = 8
    private var documentFileSlots = 4
    private var documentMaxBytes = 10L * 1024 * 1024
    private var documentMaxImageBytes = 64L * 1024 * 1024
    private var pendingInstall: MethodChannel.Result? = null
    private var installGeneration = 0
    private var installReceiverRegistered = false
    private val installReceiver = object : BroadcastReceiver() {
        override fun onReceive(context: Context?, intent: Intent?) {
            if (intent?.action == INSTALL_ACTION) handleInstallStatus(intent)
        }
    }

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        val installFilter = IntentFilter(INSTALL_ACTION)
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU) {
            registerReceiver(installReceiver, installFilter, Context.RECEIVER_NOT_EXPORTED)
        } else {
            @Suppress("DEPRECATION")
            registerReceiver(installReceiver, installFilter)
        }
        installReceiverRegistered = true
        // System document picker (Storage Access Framework, no storage
        // permission). "pick": image files, raw bytes that Dart normalises
        // through the JPEG pipeline. "pickDocuments": the chat attachment
        // sheet's 文件 tab, images and PDFs in one selection; each document
        // is copied (bounded) into the app cache and returned as a path with
        // its kind, display name and size. Dart deletes the copies.
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "jiabu/image_files")
            .setMethodCallHandler { call, result ->
                if (call.method != "pick" && call.method != "pickDocuments") {
                    result.notImplemented()
                } else if (pendingImageFiles != null || pendingDocuments != null) {
                    result.error("image_selection_busy", null, null)
                } else if (call.method == "pickDocuments") {
                    documentImageSlots = call.argument<Int>("imageSlots") ?: 0
                    documentFileSlots = call.argument<Int>("fileSlots") ?: 0
                    documentMaxBytes = call.argument<Number>("maxBytes")?.toLong()
                        ?: (10L * 1024 * 1024)
                    documentMaxImageBytes = call.argument<Number>("maxImageBytes")?.toLong()
                        ?: (64L * 1024 * 1024)
                    pendingDocuments = result
                    val intent = Intent(Intent.ACTION_OPEN_DOCUMENT)
                        .addCategory(Intent.CATEGORY_OPENABLE)
                        .setType("*/*")
                        .putExtra(Intent.EXTRA_MIME_TYPES, arrayOf("image/*", "application/pdf"))
                        .putExtra(Intent.EXTRA_ALLOW_MULTIPLE, true)
                    @Suppress("DEPRECATION")
                    startActivityForResult(intent, DOCUMENTS_REQUEST)
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
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "jiabu/update_installer")
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    "verifySignature" -> {
                        val path = call.argument<String>("path")
                        result.success(path != null && signaturesMatch(path))
                    }
                    "canInstall" -> result.success(packageManager.canRequestPackageInstalls())
                    "openInstallSettings" -> {
                        startActivity(
                            Intent(
                                Settings.ACTION_MANAGE_UNKNOWN_APP_SOURCES,
                                Uri.parse("package:$packageName"),
                            ),
                        )
                        result.success(null)
                    }
                    "install" -> {
                        val path = call.argument<String>("path")
                        if (path == null) {
                            result.error("invalid_install_path", null, null)
                        } else {
                            pendingInstall?.success("cancelled")
                            pendingInstall = result
                            installGeneration += 1
                            installPackage(path, installGeneration)
                        }
                    }
                    else -> result.notImplemented()
                }
            }
    }

    override fun onDestroy() {
        if (installReceiverRegistered) {
            unregisterReceiver(installReceiver)
            installReceiverRegistered = false
        }
        super.onDestroy()
    }

    private fun signaturesMatch(path: String): Boolean {
        return try {
            @Suppress("DEPRECATION")
            val archive = packageManager.getPackageArchiveInfo(
                path,
                PackageManager.GET_SIGNING_CERTIFICATES,
            ) ?: return false
            @Suppress("DEPRECATION")
            val current = packageManager.getPackageInfo(
                packageName,
                PackageManager.GET_SIGNING_CERTIFICATES,
            )
            signatureSet(archive.signingInfo) == signatureSet(current.signingInfo) &&
                signatureSet(archive.signingInfo).isNotEmpty()
        } catch (error: Exception) {
            false
        }
    }

    private fun signatureSet(info: android.content.pm.SigningInfo?): Set<String> {
        if (info == null) return emptySet()
        val signatures = if (info.hasMultipleSigners()) {
            info.apkContentsSigners
        } else {
            info.signingCertificateHistory
        }
        return signatures.map {
            Base64.encodeToString(it.toByteArray(), Base64.NO_WRAP)
        }.toSet()
    }

    private fun installPackage(path: String, generation: Int) {
        Thread {
            var session: PackageInstaller.Session? = null
            try {
                val file = File(path)
                val params = PackageInstaller.SessionParams(
                    PackageInstaller.SessionParams.MODE_FULL_INSTALL,
                ).apply { setAppPackageName(packageName) }
                val sessionId = packageManager.packageInstaller.createSession(params)
                val opened = packageManager.packageInstaller.openSession(sessionId)
                session = opened
                file.inputStream().use { input ->
                    opened.openWrite("jiabu.apk", 0, file.length()).use { output ->
                        input.copyTo(output)
                        opened.fsync(output)
                    }
                }
                val callback = Intent(INSTALL_ACTION)
                    .setPackage(packageName)
                    .putExtra(INSTALL_GENERATION, generation)
                val pending = PendingIntent.getBroadcast(
                    this,
                    sessionId,
                    callback,
                    PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_MUTABLE,
                )
                opened.commit(pending.intentSender)
            } catch (error: Exception) {
                session?.abandon()
                runOnUiThread { finishInstall("failed", generation) }
            } finally {
                session?.close()
            }
        }.start()
    }

    private fun handleInstallStatus(intent: Intent) {
        val generation = intent.getIntExtra(INSTALL_GENERATION, -1)
        if (generation != installGeneration) return
        when (intent.getIntExtra(PackageInstaller.EXTRA_STATUS, PackageInstaller.STATUS_FAILURE)) {
            PackageInstaller.STATUS_PENDING_USER_ACTION -> {
                @Suppress("DEPRECATION")
                val confirmation = intent.getParcelableExtra(Intent.EXTRA_INTENT) as? Intent
                if (confirmation == null) {
                    finishInstall("failed", generation)
                } else {
                    startActivity(confirmation)
                }
            }
            PackageInstaller.STATUS_SUCCESS -> finishInstall("success", generation)
            PackageInstaller.STATUS_FAILURE_ABORTED -> finishInstall("cancelled", generation)
            else -> finishInstall("failed", generation)
        }
    }

    private fun finishInstall(status: String, generation: Int) {
        if (generation != installGeneration) return
        val result = pendingInstall ?: return
        pendingInstall = null
        result.success(status)
    }

    @Deprecated("Activity result API; kept for FlutterFragmentActivity parity")
    override fun onActivityResult(requestCode: Int, resultCode: Int, data: Intent?) {
        @Suppress("DEPRECATION")
        super.onActivityResult(requestCode, resultCode, data)
        if (requestCode == DOCUMENTS_REQUEST) {
            val documents = pendingDocuments ?: return
            pendingDocuments = null
            returnDocuments(documents, pickedUris(resultCode, data))
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

    private class Picked(val uri: Uri, val kind: String?, val name: String?, val size: Long)

    private class Rejected(val code: String) : Exception(code)

    // Two passes, all off the UI thread. First every document's kind and
    // reported size, rejecting an over-limit selection before reading any
    // content (only a 16-byte header is sniffed when the provider reports
    // no usable type). Then each document is streamed into the app cache
    // with a hard byte cap, so nothing large is held in memory. Any failure,
    // including OutOfMemoryError, ends in a clean channel error and no copies.
    private fun returnDocuments(result: MethodChannel.Result, uris: List<Uri>) {
        val imageSlots = documentImageSlots
        val fileSlots = documentFileSlots
        val maxPdfBytes = documentMaxBytes
        val maxImageBytes = documentMaxImageBytes
        val directory = File(cacheDir, "picked-documents")
        Thread {
            val copies = mutableListOf<File>()
            try {
                directory.mkdirs()
                // Copies left by an earlier, killed pick are never needed.
                directory.listFiles()?.forEach { it.delete() }
                val picked = uris.map { describe(it) }
                if (picked.any { it.kind == null }) throw Rejected("chat_file_not_pdf")
                if (picked.count { it.kind == "pdf" } > fileSlots) {
                    throw Rejected("chat_files_too_many")
                }
                if (picked.count { it.kind == "image" } > imageSlots) {
                    throw Rejected("chat_too_large")
                }
                for (document in picked) {
                    val image = document.kind == "image"
                    if (document.size > (if (image) maxImageBytes else maxPdfBytes)) {
                        throw Rejected(if (image) "image_too_large" else "chat_file_too_large")
                    }
                }
                val files = picked.map { document ->
                    val image = document.kind == "image"
                    val copy = File.createTempFile("document-", ".part", directory)
                    copies.add(copy)
                    val bytes = copyAtMost(
                        document.uri,
                        copy,
                        if (image) maxImageBytes else maxPdfBytes,
                    ) ?: throw Rejected(if (image) "image_too_large" else "chat_file_too_large")
                    mapOf(
                        "kind" to document.kind,
                        "name" to document.name,
                        "size" to bytes,
                        "path" to copy.absolutePath,
                    )
                }
                runOnUiThread { result.success(mapOf("documents" to files)) }
            } catch (rejected: Rejected) {
                copies.forEach { it.delete() }
                runOnUiThread { result.success(mapOf("rejected" to rejected.code)) }
            } catch (error: Throwable) {
                copies.forEach { it.delete() }
                runOnUiThread { result.error("file_selection_failed", null, null) }
            }
        }.start()
    }

    private fun describe(uri: Uri): Picked {
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
        val mime = contentResolver.getType(uri)
        val kind = when {
            mime == "application/pdf" -> "pdf"
            mime != null && mime.startsWith("image/") -> "image"
            else -> sniff(uri)
        }
        return Picked(uri, kind, name, size)
    }

    // Providers without a usable type (none, application/octet-stream):
    // decide by magic bytes. Kinds the image pipeline decodes, or a PDF.
    private fun sniff(uri: Uri): String? {
        val head = ByteArray(16)
        val read = contentResolver.openInputStream(uri)?.use { stream ->
            var total = 0
            while (total < head.size) {
                val count = stream.read(head, total, head.size - total)
                if (count < 0) break
                total += count
            }
            total
        } ?: 0
        fun at(offset: Int, vararg bytes: Int) =
            read >= offset + bytes.size &&
                bytes.indices.all { head[offset + it] == bytes[it].toByte() }
        fun text(offset: Int, value: String) = at(offset, *value.map { it.code }.toIntArray())
        return when {
            text(0, "%PDF-") -> "pdf"
            at(0, 0xFF, 0xD8, 0xFF) -> "image"
            at(0, 0x89, 0x50, 0x4E, 0x47) -> "image"
            text(0, "GIF8") -> "image"
            text(0, "RIFF") && text(8, "WEBP") -> "image"
            text(4, "ftyp") && listOf("heic", "heix", "hevc", "hevx", "mif1", "msf1")
                .any { text(8, it) } -> "image"
            else -> null
        }
    }

    // Streams at most maxBytes into target; null (and target deleted) when
    // the document is larger. Never holds the document in memory.
    private fun copyAtMost(uri: Uri, target: File, maxBytes: Long): Long? {
        val input = contentResolver.openInputStream(uri)
            ?: throw IOException("unreadable_document")
        val total = input.use { stream ->
            FileOutputStream(target).use { out ->
                val buffer = ByteArray(64 * 1024)
                var copied = 0L
                while (true) {
                    val read = stream.read(buffer)
                    if (read < 0) break
                    copied += read
                    if (copied > maxBytes) break
                    out.write(buffer, 0, read)
                }
                copied
            }
        }
        if (total > maxBytes) {
            target.delete()
            return null
        }
        return total
    }

    private companion object {
        const val IMAGE_FILES_REQUEST = 7301
        const val DOCUMENTS_REQUEST = 7302
        const val INSTALL_ACTION = "io.github.zzhoward.jiabu.INSTALL_STATUS"
        const val INSTALL_GENERATION = "jiabu.install_generation"
    }
}
