package com.community.flutter.deeplink

import android.app.Activity
import android.content.Context
import android.content.Intent
import android.graphics.Bitmap
import android.graphics.Color
import android.graphics.pdf.PdfRenderer
import android.net.Uri
import android.os.Bundle
import android.util.Log
import android.webkit.MimeTypeMap
import java.io.File
import java.io.FileOutputStream

/**
 * A file (an image, or the first page of a PDF rendered to a PNG) shared to the app, copied into the
 * app's cache. One slot, process-wide: the latest share replaces an earlier unread one, and
 * [take] empties it, so a share is handed to Dart exactly once.
 */
object SharedFileSlot {
    private var pending: List<Map<String, Any?>>? = null

    /** One shared file (a SEND, or a failure). */
    @Synchronized
    fun put(share: Map<String, Any?>) {
        pending = listOf(share)
    }

    /** Every file of one share, in the sender's order (a SEND_MULTIPLE). */
    @Synchronized
    fun putAll(shares: List<Map<String, Any?>>) {
        pending = shares
    }

    /** The first file of the latest share, and the share is gone (`takeSharedFile`). */
    @Synchronized
    fun take(): Map<String, Any?>? {
        val p = pending
        pending = null
        return p?.firstOrNull()
    }

    /** Every file of the latest share, and the share is gone (`takeSharedFiles`). */
    @Synchronized
    fun takeAll(): List<Map<String, Any?>>? {
        val p = pending
        pending = null
        return p
    }
}

/**
 * "Share to <app>": the target of ACTION_SEND (image/<any>, application/pdf) and ACTION_SEND_MULTIPLE
 * (image/<any>; only the first item is used). The host app declares this activity with those
 * intent-filters in its own manifest (the plugin's manifest does not, so only the apps that want
 * file shares receive them). The shared content is copied to the cache on a worker thread while the
 * sender's URI grant is valid, kept in [SharedFileSlot] (read by `takeSharedFile`), and then the
 * app's launcher activity is brought forward: a running instance resumes, otherwise the app starts.
 */
class ShareFileReceiverActivity : Activity() {
    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        val intent = intent
        val uris = streamsOf(intent)
        val type = intent?.type
        Thread({
            if (uris.isEmpty()) {
                SharedFileSlot.put(errorOf("No shared file found"))
            } else {
                // Each file gets its own name: the cache folder is cleared once, before the first copy.
                clearShares(this)
                SharedFileSlot.putAll(uris.take(MAX_FILES).mapIndexed { i, u -> copyShared(this, u, if (uris.size == 1) type else null, clear = false, index = i) })
            }
            runOnUiThread {
                launchApp()
                finish()
            }
        }, "share-file-copy").start()
    }

    private fun launchApp() {
        try {
            val launch = packageManager.getLaunchIntentForPackage(packageName) ?: return
            // The running instance comes forward (a resume Dart listens for) instead of a new one.
            launch.addFlags(
                Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_REORDER_TO_FRONT or Intent.FLAG_ACTIVITY_SINGLE_TOP,
            )
            startActivity(launch)
        } catch (e: Exception) {
            Log.e(TAG, "launchApp failed", e)
        }
    }

    companion object {
        private const val TAG = "ShareFileReceiver"
        private const val DIR = "community_flutter_deeplink_shares"

        /** Longest side of a rendered PDF page, in pixels. */
        private const val PDF_MAX_SIDE = 3000

        /** Most files one SEND_MULTIPLE hands over (the rest are dropped). */
        const val MAX_FILES = 100

        /** Every EXTRA_STREAM of a SEND (one) or a SEND_MULTIPLE (all, in order). */
        @Suppress("DEPRECATION")
        fun streamsOf(intent: Intent?): List<Uri> = when (intent?.action) {
            Intent.ACTION_SEND -> listOfNotNull(intent.getParcelableExtra(Intent.EXTRA_STREAM))
            Intent.ACTION_SEND_MULTIPLE -> intent.getParcelableArrayListExtra<Uri>(Intent.EXTRA_STREAM)?.filterNotNull() ?: emptyList()
            else -> emptyList()
        }

        fun clearShares(context: Context) {
            File(context.cacheDir, DIR).listFiles()?.forEach { it.delete() }
        }

        /** EXTRA_STREAM of a SEND, or the first one of a SEND_MULTIPLE. */
        @Suppress("DEPRECATION")
        fun streamOf(intent: Intent?): Uri? = when (intent?.action) {
            Intent.ACTION_SEND -> intent.getParcelableExtra(Intent.EXTRA_STREAM)
            Intent.ACTION_SEND_MULTIPLE -> intent.getParcelableArrayListExtra<Uri>(Intent.EXTRA_STREAM)?.firstOrNull()
            else -> null
        }

        fun errorOf(message: String): Map<String, Any?> = mapOf("path" to null, "mimeType" to null, "error" to message)

        /** {path, mimeType, error}: the copied image or the rendered first PDF page, or why not. */
        fun copyShared(context: Context, uri: Uri, type: String?, clear: Boolean = true, index: Int = 0): Map<String, Any?> {
            return try {
                val dir = File(context.cacheDir, DIR)
                // Only the latest share is kept.
                if (clear) dir.listFiles()?.forEach { it.delete() }
                dir.mkdirs()
                val mime = type ?: context.contentResolver.getType(uri)
                if (mime == "application/pdf") {
                    val out = File(dir, "share_${System.currentTimeMillis()}_$index.png")
                    if (!renderFirstPdfPage(context, uri, out)) return errorOf("Unable to read shared PDF")
                    mapOf("path" to out.absolutePath, "mimeType" to "image/png", "error" to null)
                } else {
                    val ext = mime?.let { MimeTypeMap.getSingleton().getExtensionFromMimeType(it) }
                    val out = File(dir, "share_${System.currentTimeMillis()}_$index" + (if (ext.isNullOrEmpty()) "" else ".$ext"))
                    val input = context.contentResolver.openInputStream(uri) ?: return errorOf("Unable to read shared file")
                    input.use { i -> FileOutputStream(out).use { o -> i.copyTo(o) } }
                    mapOf("path" to out.absolutePath, "mimeType" to mime, "error" to null)
                }
            } catch (e: Exception) {
                // A revoked grant (SecurityException), a malformed URI, an unreadable file.
                Log.e(TAG, "copyShared failed", e)
                errorOf("Could not read the shared file: ${e.message}")
            }
        }

        private fun renderFirstPdfPage(context: Context, uri: Uri, out: File): Boolean {
            val pfd = context.contentResolver.openFileDescriptor(uri, "r") ?: return false
            pfd.use {
                PdfRenderer(it).use { renderer ->
                    if (renderer.pageCount == 0) return false
                    renderer.openPage(0).use { page ->
                        val scale = minOf(2f, PDF_MAX_SIDE.toFloat() / maxOf(page.width, page.height).coerceAtLeast(1))
                        val w = (page.width * scale).toInt().coerceAtLeast(1)
                        val h = (page.height * scale).toInt().coerceAtLeast(1)
                        val bitmap = Bitmap.createBitmap(w, h, Bitmap.Config.ARGB_8888)
                        // A PDF page is transparent where nothing is drawn; the decoder wants paper white.
                        bitmap.eraseColor(Color.WHITE)
                        page.render(bitmap, null, null, PdfRenderer.Page.RENDER_MODE_FOR_DISPLAY)
                        FileOutputStream(out).use { o -> bitmap.compress(Bitmap.CompressFormat.PNG, 100, o) }
                        bitmap.recycle()
                    }
                }
            }
            return true
        }
    }
}
