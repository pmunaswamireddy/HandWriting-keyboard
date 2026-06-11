package com.handwritingkeyboard.app

import android.inputmethodservice.InputMethodService
import android.util.TypedValue
import android.view.View
import android.view.ViewGroup
import android.view.inputmethod.EditorInfo
import io.flutter.embedding.android.FlutterView
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.embedding.engine.FlutterEngineCache
import io.flutter.embedding.engine.dart.DartExecutor
import io.flutter.plugin.common.MethodChannel

class HandwritingIMEService : InputMethodService() {

    companion object {
        const val ENGINE_ID = "handwriting_keyboard_ime_engine"
        const val CHANNEL = "com.handwritingkeyboard/ime"
    }

    private var flutterEngine: FlutterEngine? = null
    private var methodChannel: MethodChannel? = null

    override fun onCreate() {
        super.onCreate()
        initFlutterEngine()
    }

    private fun initFlutterEngine() {
        val cached = FlutterEngineCache.getInstance().get(ENGINE_ID)
        if (cached != null) {
            flutterEngine = cached
        } else {
            flutterEngine = FlutterEngine(this).also { engine ->
                engine.dartExecutor.executeDartEntrypoint(
                    DartExecutor.DartEntrypoint.createDefault()
                )
                FlutterEngineCache.getInstance().put(ENGINE_ID, engine)
            }
        }

        methodChannel = MethodChannel(
            flutterEngine!!.dartExecutor.binaryMessenger,
            CHANNEL
        ).apply {
            setMethodCallHandler { call, result ->
                when (call.method) {
                    "typeText" -> {
                        val text = call.argument<String>("text") ?: ""
                        currentInputConnection?.commitText(text, 1)
                        sendCurrentTextToDart()
                        result.success(null)
                    }
                    "backspace" -> {
                        currentInputConnection?.deleteSurroundingText(1, 0)
                        sendCurrentTextToDart()
                        result.success(null)
                    }
                    "typeSuggestion" -> {
                        val text = call.argument<String>("text") ?: ""
                        val deleteLength = call.argument<Int>("deleteLength") ?: 0
                        val ic = currentInputConnection
                        if (ic != null) {
                            if (deleteLength > 0) {
                                ic.deleteSurroundingText(deleteLength, 0)
                            }
                            ic.commitText(text, 1)
                        }
                        sendCurrentTextToDart()
                        result.success(null)
                    }
                    "enter" -> {
                        val ic = currentInputConnection
                        val editorInfo = currentInputEditorInfo
                        val opts = editorInfo?.imeOptions ?: EditorInfo.IME_ACTION_NONE
                        val masked = opts and EditorInfo.IME_MASK_ACTION
                        if (masked != EditorInfo.IME_ACTION_NONE && masked != EditorInfo.IME_ACTION_UNSPECIFIED) {
                            ic?.performEditorAction(masked)
                        } else {
                            ic?.commitText("\n", 1)
                        }
                        sendCurrentTextToDart()
                        result.success(null)
                    }
                    "hideKeyboard" -> {
                        requestHideSelf(0)
                        result.success(null)
                    }
                    else -> result.notImplemented()
                }
            }
        }
    }

    private fun sendCurrentTextToDart() {
        val ic = currentInputConnection ?: return
        val textBefore = ic.getTextBeforeCursor(1024, 0)?.toString() ?: ""
        methodChannel?.invokeMethod("updateCurrentText", mapOf("text" to textBefore))
    }

    override fun onEvaluateFullscreenMode(): Boolean = false
    override fun onEvaluateInputViewShown(): Boolean = true

    override fun onUpdateSelection(
        oldSelStart: Int, oldSelEnd: Int,
        newSelStart: Int, newSelEnd: Int,
        candidatesStart: Int, candidatesEnd: Int
    ) {
        super.onUpdateSelection(oldSelStart, oldSelEnd, newSelStart, newSelEnd, candidatesStart, candidatesEnd)
        sendCurrentTextToDart()
    }

    override fun onCreateInputView(): View {
        val engine = flutterEngine ?: return View(this)
        val flutterView = FlutterView(this)
        flutterView.attachToFlutterEngine(engine)
        flutterView.layoutParams = ViewGroup.LayoutParams(
            ViewGroup.LayoutParams.MATCH_PARENT,
            dp(300)
        )
        methodChannel?.invokeMethod("setImeMode", mapOf("isIme" to true))
        android.os.Handler(android.os.Looper.getMainLooper()).postDelayed({
            sendCurrentTextToDart()
        }, 150)
        return flutterView
    }

    override fun onStartInputView(info: EditorInfo?, restarting: Boolean) {
        super.onStartInputView(info, restarting)
        methodChannel?.invokeMethod("setImeMode", mapOf("isIme" to true))
        android.os.Handler(android.os.Looper.getMainLooper()).postDelayed({
            sendCurrentTextToDart()
        }, 100)
    }

    private fun dp(v: Int) = TypedValue.applyDimension(
        TypedValue.COMPLEX_UNIT_DIP, v.toFloat(), resources.displayMetrics
    ).toInt()
}
