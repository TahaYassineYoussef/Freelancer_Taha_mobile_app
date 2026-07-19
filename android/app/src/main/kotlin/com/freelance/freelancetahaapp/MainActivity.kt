package com.freelance.freelancetahaapp

import android.net.Uri
import androidx.browser.customtabs.CustomTabsIntent
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

/**
 * Hosts a channel that opens a URL in an *ephemeral* Custom Tab — a private
 * browsing session whose cookies and history are discarded when it closes.
 *
 * Google rejects OAuth inside embedded WebViews ("disallowed_useragent"), so
 * sign-in has to happen in a real browser; ephemeral mode keeps it from
 * inheriting, or leaving behind, a Chrome session.
 */
class MainActivity : FlutterActivity() {

    private val channelName = "taha/customtabs"

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, channelName)
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    "openPrivate" -> {
                        val url = call.argument<String>("url")
                        if (url.isNullOrBlank()) {
                            result.error("no_url", "A url argument is required.", null)
                        } else {
                            try {
                                result.success(open(url))
                            } catch (e: Throwable) {
                                result.error("open_failed", e.message, null)
                            }
                        }
                    }
                    else -> result.notImplemented()
                }
            }
    }

    /**
     * @return true when the tab opened as a private/ephemeral session, false
     *         when it fell back to a normal Custom Tab.
     */
    private fun open(url: String): Boolean {
        val builder = CustomTabsIntent.Builder().setShowTitle(true)

        // Needs AndroidX Browser 1.9+ and a browser that supports it (Chrome
        // 130+). Anywhere else this throws and we fall back to a normal tab.
        val ephemeral = try {
            builder.setEphemeralBrowsingEnabled(true)
            true
        } catch (_: Throwable) {
            false
        }

        builder.build().launchUrl(this, Uri.parse(url))
        return ephemeral
    }
}
