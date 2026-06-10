package com.handwritingkeyboard.app

import android.content.Intent
import android.net.Uri
import androidx.core.content.FileProvider
import io.flutter.embedding.engine.plugins.FlutterPlugin
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import java.io.File

/**
 * Android platform channel handler for font installation.
 * Tries Samsung/Xiaomi native font APIs first, then falls back to iFont deep-link.
 */
class FontInstallerPlugin : FlutterPlugin, MethodChannel.MethodCallHandler {

    companion object {
        const val CHANNEL = "com.handwritingkeyboard/font_installer"
        const val IFONT_PACKAGE = "com.kapp.ifont"
        const val ZFONT_PACKAGE = "com.htcleung.wling.zfont3"
    }

    private lateinit var channel: MethodChannel
    private lateinit var context: android.content.Context

    override fun onAttachedToEngine(binding: FlutterPlugin.FlutterPluginBinding) {
        context = binding.applicationContext
        channel = MethodChannel(binding.binaryMessenger, CHANNEL)
        channel.setMethodCallHandler(this)
    }

    override fun onDetachedFromEngine(binding: FlutterPlugin.FlutterPluginBinding) {
        channel.setMethodCallHandler(null)
    }

    override fun onMethodCall(call: MethodCall, result: MethodChannel.Result) {
        when (call.method) {
            "installFontAndroid" -> {
                val fontPath = call.argument<String>("fontPath") ?: run {
                    result.error("MISSING_ARG", "fontPath required", null)
                    return
                }
                installFontAndroid(fontPath, result)
            }
            "openiFontWithFont" -> {
                val fontPath = call.argument<String>("fontPath") ?: run {
                    result.error("MISSING_ARG", "fontPath required", null)
                    return
                }
                openFontManager(fontPath, result)
            }
            else -> result.notImplemented()
        }
    }

    private fun installFontAndroid(fontPath: String, result: MethodChannel.Result) {
        // Android 12+ has per-app font override via Configuration
        // For system-wide: we need iFont/zFont
        // First try to open font manager
        val fontFile = File(fontPath)
        if (!fontFile.exists()) {
            result.error("FILE_NOT_FOUND", "Font file not found: $fontPath", null)
            return
        }

        // Check if iFont or zFont is installed
        val packageManager = context.packageManager
        val hasIFont = isPackageInstalled(IFONT_PACKAGE, packageManager)
        val hasZFont = isPackageInstalled(ZFONT_PACKAGE, packageManager)

        if (hasIFont || hasZFont) {
            openFontManager(fontPath, result)
        } else {
            // Neither installed — prompt user to install iFont
            result.error(
                "FONT_MANAGER_NOT_FOUND",
                "Please install iFont or zFont 3 from Play Store to apply system fonts.",
                mapOf(
                    "iFontPlayUrl" to "https://play.google.com/store/apps/details?id=$IFONT_PACKAGE",
                    "zFontPlayUrl" to "https://play.google.com/store/apps/details?id=$ZFONT_PACKAGE"
                )
            )
        }
    }

    private fun openFontManager(fontPath: String, result: MethodChannel.Result) {
        try {
            val fontFile = File(fontPath)
            val uri = FileProvider.getUriForFile(
                context,
                "${context.packageName}.fileprovider",
                fontFile
            )

            val intent = Intent(Intent.ACTION_VIEW).apply {
                setDataAndType(uri, "font/ttf")
                addFlags(Intent.FLAG_GRANT_READ_URI_PERMISSION)
                addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
            }

            context.startActivity(intent)
            result.success(mapOf("success" to true, "openedFontManager" to true))
        } catch (e: Exception) {
            result.error("OPEN_FAILED", e.message, null)
        }
    }

    private fun isPackageInstalled(packageName: String, pm: android.content.pm.PackageManager): Boolean {
        return try {
            pm.getPackageInfo(packageName, 0)
            true
        } catch (_: android.content.pm.PackageManager.NameNotFoundException) {
            false
        }
    }
}
