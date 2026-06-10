package com.handwritingkeyboard.app

import android.content.ComponentName
import android.content.Intent
import android.os.Bundle
import android.provider.Settings
import android.view.inputmethod.InputMethodManager
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {

    companion object {
        private const val IME_CHANNEL = "com.handwritingkeyboard/ime_setup"
        private const val IME_ID = "com.handwritingkeyboard.app/.HandwritingIMEService"
    }

    private lateinit var imeChannel: MethodChannel

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        imeChannel = MethodChannel(flutterEngine.dartExecutor.binaryMessenger, IME_CHANNEL)
        imeChannel.setMethodCallHandler { call, result ->
            when (call.method) {
                "isImeEnabled" -> result.success(isImeEnabled())
                "isImeDefault" -> result.success(isImeDefault())
                "openImeSettings" -> {
                    openImeSettings()
                    result.success(null)
                }
                "openDefaultImeChooser" -> {
                    openDefaultImeChooser()
                    result.success(null)
                }
                else -> result.notImplemented()
            }
        }
    }

    /** Returns true if our IME is in the enabled IMEs list */
    private fun isImeEnabled(): Boolean {
        val enabledImIds = Settings.Secure.getString(
            contentResolver, Settings.Secure.ENABLED_INPUT_METHODS
        ) ?: return false
        return enabledImIds.split(":").any { it.trim() == IME_ID }
    }

    /** Returns true if our IME is currently set as the default */
    private fun isImeDefault(): Boolean {
        val defaultIme = Settings.Secure.getString(
            contentResolver, Settings.Secure.DEFAULT_INPUT_METHOD
        ) ?: return false
        return defaultIme.trim() == IME_ID
    }

    /** Opens Settings → Language & input → Virtual keyboard list */
    private fun openImeSettings() {
        startActivity(Intent(Settings.ACTION_INPUT_METHOD_SETTINGS).apply {
            addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
        })
    }

    /** Shows the system "Choose keyboard" picker dialog */
    private fun openDefaultImeChooser() {
        val imm = getSystemService(INPUT_METHOD_SERVICE) as InputMethodManager
        imm.showInputMethodPicker()
    }
}
