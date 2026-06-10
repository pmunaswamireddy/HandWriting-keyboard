package com.handwritingkeyboard.app

import android.inputmethodservice.InputMethodService
import android.view.View
import android.view.inputmethod.EditorInfo
import io.flutter.embedding.android.FlutterView
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.embedding.engine.FlutterEngineCache
import io.flutter.embedding.engine.dart.DartExecutor
import io.flutter.plugin.common.MethodChannel

/**
 * HandwritingIMEService — Android Input Method Service.
 *
 * This service hosts a Flutter engine that renders the handwriting keyboard UI.
 * It bridges Android's InputMethodService lifecycle with Flutter's rendering.
 *
 * FLOW:
 * 1. Android calls onCreateInputView() when the keyboard should appear
 * 2. We spin up a Flutter engine running our keyboard widget
 * 3. Flutter keyboard widget calls platform channel to type/delete
 * 4. We forward those calls to the InputConnection (the focused text field)
 */
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
        // Reuse cached engine if available (shared with main app)
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

        // Set up platform channel for text input communication
        methodChannel = MethodChannel(
            flutterEngine!!.dartExecutor.binaryMessenger,
            CHANNEL
        ).apply {
            setMethodCallHandler { call, result ->
                when (call.method) {
                    "typeText" -> {
                        val text = call.argument<String>("text") ?: ""
                        currentInputConnection?.commitText(text, 1)
                        result.success(null)
                    }
                    "backspace" -> {
                        currentInputConnection?.deleteSurroundingText(1, 0)
                        result.success(null)
                    }
                    "enter" -> {
                        val ic = currentInputConnection
                        val editorInfo = currentInputEditorInfo
                        if (editorInfo?.imeOptions?.and(EditorInfo.IME_FLAG_NO_ENTER_ACTION) == 0) {
                            ic?.performEditorAction(editorInfo?.imeOptions?.and(EditorInfo.IME_MASK_ACTION) ?: EditorInfo.IME_ACTION_NONE)
                        } else {
                            ic?.commitText("\n", 1)
                        }
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

    override fun onCreateInputView(): View {
        // Create Flutter view and return it as the keyboard view
        val engine = flutterEngine ?: return View(this)
        return FlutterView(this).also { flutterView ->
            flutterView.attachToFlutterEngine(engine)
            // Signal to Flutter that we're in IME mode
            methodChannel?.invokeMethod("setImeMode", mapOf("isIme" to true))
        }
    }

    override fun onStartInputView(info: EditorInfo?, restarting: Boolean) {
        super.onStartInputView(info, restarting)
        methodChannel?.invokeMethod("onStartInput", mapOf(
            "inputType" to (info?.inputType ?: 0),
            "imeOptions" to (info?.imeOptions ?: 0)
        ))
    }

    override fun onFinishInput() {
        super.onFinishInput()
        methodChannel?.invokeMethod("onFinishInput", null)
    }

    override fun onDestroy() {
        super.onDestroy()
        flutterEngine?.destroy()
    }
}
