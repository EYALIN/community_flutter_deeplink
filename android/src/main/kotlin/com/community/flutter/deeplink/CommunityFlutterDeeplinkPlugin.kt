package com.community.flutter.deeplink

import android.app.Activity
import android.content.ActivityNotFoundException
import android.content.Context
import android.content.Intent
import android.net.Uri
import io.flutter.embedding.engine.plugins.FlutterPlugin
import io.flutter.embedding.engine.plugins.activity.ActivityAware
import io.flutter.embedding.engine.plugins.activity.ActivityPluginBinding
import io.flutter.plugin.common.EventChannel
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import io.flutter.plugin.common.PluginRegistry

/**
 * Deep links: the intent's VIEW link, launching and probing other apps, and
 * text shared to the app (ACTION_SEND text/<any>) at launch or while it runs.
 */
class CommunityFlutterDeeplinkPlugin : FlutterPlugin, MethodChannel.MethodCallHandler, EventChannel.StreamHandler,
    ActivityAware, PluginRegistry.NewIntentListener {
    private lateinit var appContext: Context
    private lateinit var channel: MethodChannel
    private lateinit var events: EventChannel
    private var sink: EventChannel.EventSink? = null
    private var binding: ActivityPluginBinding? = null
    private var lastDeepLinkUrl: String? = null
    private lateinit var shares: EventChannel
    private var shareSink: EventChannel.EventSink? = null

    /** A share that arrived while nothing listened to the shares channel (the launch share). */
    private var pendingShare: Map<String, Any?>? = null

    override fun onAttachedToEngine(binding: FlutterPlugin.FlutterPluginBinding) {
        appContext = binding.applicationContext
        channel = MethodChannel(binding.binaryMessenger, "community_flutter_deeplink")
        channel.setMethodCallHandler(this)
        events = EventChannel(binding.binaryMessenger, "community_flutter_deeplink/links")
        events.setStreamHandler(this)
        shares = EventChannel(binding.binaryMessenger, "community_flutter_deeplink/shares")
        shares.setStreamHandler(object : EventChannel.StreamHandler {
            override fun onListen(arguments: Any?, events: EventChannel.EventSink?) {
                shareSink = events
                val pending = pendingShare ?: return
                pendingShare = null
                events?.success(pending)
            }

            override fun onCancel(arguments: Any?) {
                shareSink = null
            }
        })
    }

    override fun onDetachedFromEngine(binding: FlutterPlugin.FlutterPluginBinding) {
        channel.setMethodCallHandler(null)
        events.setStreamHandler(null)
        shares.setStreamHandler(null)
        sink = null
        shareSink = null
    }

    override fun onAttachedToActivity(binding: ActivityPluginBinding) {
        this.binding = binding
        binding.addOnNewIntentListener(this)
        // The launch intent: kept for getLastDeepLink, not emitted (nobody listens yet).
        handleIntent(binding.activity.intent, emit = false)
        shareFrom(binding.activity.intent)?.let { deliverShare(it) }
    }

    override fun onDetachedFromActivityForConfigChanges() = onDetachedFromActivity()

    override fun onReattachedToActivityForConfigChanges(binding: ActivityPluginBinding) = onAttachedToActivity(binding)

    override fun onDetachedFromActivity() {
        binding?.removeOnNewIntentListener(this)
        binding = null
    }

    override fun onNewIntent(intent: Intent): Boolean {
        shareFrom(intent)?.let { deliverShare(it) }
        return handleIntent(intent, emit = true)
    }

    /** To the listener, or kept for the first one (only the latest share is kept). */
    private fun deliverShare(share: Map<String, Any?>) {
        val s = shareSink
        if (s != null) s.success(share) else pendingShare = share
    }

    /**
     * {text, subject} of an ACTION_SEND with a text MIME type and a non-empty EXTRA_TEXT, or of an
     * ACTION_PROCESS_TEXT (the selected text; only an app that declares that intent-filter receives one); null
     * otherwise.
     * The intent is consumed (its action changed) so an activity re-create does not deliver it again.
     */
    private fun shareFrom(intent: Intent?): Map<String, Any?>? {
        if (intent == null) return null
        // A selection's "<app>" action (ACTION_PROCESS_TEXT, text/plain): the selected text, as a share.
        if (Intent.ACTION_PROCESS_TEXT == intent.action) {
            val selected = intent.getCharSequenceExtra(Intent.EXTRA_PROCESS_TEXT)
            if (selected.isNullOrEmpty()) return null
            intent.setAction(SHARE_CONSUMED)
            return mapOf("text" to selected.toString(), "subject" to null)
        }
        if (Intent.ACTION_SEND != intent.action) return null
        val type = intent.type
        if (type == null || !type.startsWith("text/")) return null
        val text = intent.getCharSequenceExtra(Intent.EXTRA_TEXT)
        if (text.isNullOrEmpty()) return null
        intent.setAction(SHARE_CONSUMED)
        return mapOf("text" to text.toString(), "subject" to intent.getStringExtra(Intent.EXTRA_SUBJECT))
    }

    private fun handleIntent(intent: Intent?, emit: Boolean): Boolean {
        if (intent == null || Intent.ACTION_VIEW != intent.action) return false
        val url = intent.data?.toString() ?: return false
        lastDeepLinkUrl = url
        if (emit) sink?.success(url)
        return false // let other plugins see the intent too
    }

    override fun onListen(arguments: Any?, events: EventChannel.EventSink?) {
        sink = events
    }

    override fun onCancel(arguments: Any?) {
        sink = null
    }

    override fun onMethodCall(call: MethodCall, result: MethodChannel.Result) {
        when (call.method) {
            "getLastDeepLink" -> result.success(lastDeepLinkUrl)
            // A file shared to ShareFileReceiverActivity: {path, mimeType, error} once, then null.
            "takeSharedFile" -> result.success(SharedFileSlot.take())
            // Every file of the latest share ([{path, mimeType, error}, ...]) once, then null.
            "takeSharedFiles" -> result.success(SharedFileSlot.takeAll())
            "launchApp" -> {
                val url = call.argument<String>("url")
                if (url.isNullOrEmpty()) {
                    result.error("INVALID_ARGUMENT", "url is required", null)
                    return
                }
                val intent = Intent(Intent.ACTION_VIEW, Uri.parse(url)).addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
                try {
                    appContext.startActivity(intent)
                    result.success(true)
                } catch (e: ActivityNotFoundException) {
                    result.success(false) // no app handles the link
                } catch (e: Exception) {
                    result.error("LAUNCH_FAILED", e.message, null)
                }
            }
            "isAppInstalled" -> {
                val url = call.argument<String>("url")
                if (url.isNullOrEmpty()) {
                    result.success(false)
                    return
                }
                val intent = Intent(Intent.ACTION_VIEW, Uri.parse(url))
                result.success(intent.resolveActivity(appContext.packageManager) != null)
            }
            else -> result.notImplemented()
        }
    }

    private companion object {
        const val SHARE_CONSUMED = "community_flutter_deeplink.SHARE_CONSUMED"
    }
}
