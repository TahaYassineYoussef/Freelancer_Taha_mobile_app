package com.freelance.freelancetahaapp

import android.net.Uri
import android.os.Build
import android.os.Bundle
import android.view.WindowManager
import androidx.browser.customtabs.CustomTabsIntent
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

/**
 * Hosts two things:
 *  - a channel to open URLs in a private Custom Tab (legacy Google web flow), and
 *  - the flags that let a full-screen-intent call notification appear over the
 *    lock screen and wake the display, like WhatsApp / Messenger.
 *
 * The lock-screen flags are harmless when the phone is already unlocked (opening
 * the app normally looks no different); they only take effect when the incoming
 * call's full-screen intent launches this activity while the screen is off or
 * locked.
 */
class MainActivity : FlutterActivity() {

    private val channelName = "taha/customtabs"

    override fun onCreate(savedInstanceState: Bundle?) {
        showOverLockScreen()
        super.onCreate(savedInstanceState)
    }

    private fun showOverLockScreen() {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O_MR1) {
            setShowWhenLocked(true)
            setTurnScreenOn(true)
        } else {
            @Suppress("DEPRECATION")
            window.addFlags(
                WindowManager.LayoutParams.FLAG_SHOW_WHEN_LOCKED or
                    WindowManager.LayoutParams.FLAG_TURN_SCREEN_ON or
                    WindowManager.LayoutParams.FLAG_KEEP_SCREEN_ON,
            )
        }
    }

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
