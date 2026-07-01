package com.opendocs.manager.security

import android.os.Handler
import android.os.Looper
import androidx.biometric.BiometricManager
import androidx.biometric.BiometricManager.Authenticators.BIOMETRIC_STRONG
import androidx.biometric.BiometricManager.Authenticators.DEVICE_CREDENTIAL
import androidx.biometric.BiometricPrompt
import androidx.core.content.ContextCompat
import androidx.fragment.app.FragmentActivity
import io.flutter.embedding.android.FlutterFragmentActivity
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel

/**
 * Delegates PIN/biometric authentication to the Android BiometricPrompt API.
 * The activity must be a [FlutterFragmentActivity] (or a subclass) so
 * BiometricPrompt can attach its UI to the fragment back-stack.
 */
class BiometricHandler(
    private val activity: FragmentActivity,
) : MethodChannel.MethodCallHandler {

    private val mainHandler = Handler(Looper.getMainLooper())

    override fun onMethodCall(call: MethodCall, result: MethodChannel.Result) {
        when (call.method) {
            "canAuthenticate" -> result.success(canAuthenticate())
            "authenticate" -> {
                val title = call.argument<String>("title") ?: "Authenticate"
                val subtitle = call.argument<String>("subtitle") ?: ""
                authenticate(title, subtitle, result)
            }
            else -> result.notImplemented()
        }
    }

    private fun canAuthenticate(): Boolean {
        val bm = BiometricManager.from(activity)
        val status = bm.canAuthenticate(BIOMETRIC_STRONG or DEVICE_CREDENTIAL)
        return status == BiometricManager.BIOMETRIC_SUCCESS
    }

    private fun authenticate(title: String, subtitle: String, result: MethodChannel.Result) {
        val executor = ContextCompat.getMainExecutor(activity)
        val prompt = BiometricPrompt(
            activity,
            executor,
            object : BiometricPrompt.AuthenticationCallback() {
                override fun onAuthenticationSucceeded(r: BiometricPrompt.AuthenticationResult) {
                    result.success(true)
                }
                override fun onAuthenticationFailed() {
                    // Called for each failed attempt; don't resolve yet.
                }
                override fun onAuthenticationError(errorCode: Int, errString: CharSequence) {
                    result.success(false)
                }
            },
        )
        val info = BiometricPrompt.PromptInfo.Builder()
            .setTitle(title)
            .setSubtitle(subtitle)
            .setAllowedAuthenticators(BIOMETRIC_STRONG or DEVICE_CREDENTIAL)
            .build()
        mainHandler.post { prompt.authenticate(info) }
    }
}
