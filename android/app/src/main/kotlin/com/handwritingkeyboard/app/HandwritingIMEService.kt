package com.handwritingkeyboard.app

import android.content.Context
import android.graphics.Canvas
import android.graphics.Color
import android.graphics.Paint
import android.graphics.RectF
import android.graphics.Typeface
import android.inputmethodservice.InputMethodService
import android.os.Handler
import android.os.Looper
import android.view.MotionEvent
import android.view.View
import android.view.inputmethod.EditorInfo
import android.view.inputmethod.InputConnection

/**
 * HandwritingIMEService — Native Android Input Method Service.
 *
 * Draws a fully native keyboard UI so that Android recognises it as a valid IME.
 * The keyboard renders using Canvas (no Flutter dependency in the service itself).
 * Users can open the main app to configure/train their handwriting glyphs.
 *
 * Layout rows:
 *  Row 0: q w e r t y u i o p
 *  Row 1: a s d f g h j k l
 *  Row 2: ⇧ z x c v b n m ⌫
 *  Row 3: 123  [SPACE]  ✍  ↵
 */
class HandwritingIMEService : InputMethodService() {

    private lateinit var keyboardView: HandwritingKeyboardView

    override fun onCreateInputView(): View {
        keyboardView = HandwritingKeyboardView(this) { action ->
            handleKeyAction(action)
        }
        return keyboardView
    }

    override fun onStartInputView(info: EditorInfo?, restarting: Boolean) {
        super.onStartInputView(info, restarting)
        keyboardView.setCapsLock(false)
    }

    private fun handleKeyAction(action: KeyAction) {
        val ic: InputConnection = currentInputConnection ?: return
        when (action) {
            is KeyAction.TypeText -> ic.commitText(action.text, 1)
            is KeyAction.Backspace -> ic.deleteSurroundingText(1, 0)
            is KeyAction.Enter -> {
                val opts = currentInputEditorInfo?.imeOptions ?: EditorInfo.IME_ACTION_NONE
                val masked = opts and EditorInfo.IME_MASK_ACTION
                if (masked != EditorInfo.IME_ACTION_NONE && masked != EditorInfo.IME_ACTION_UNSPECIFIED) {
                    ic.performEditorAction(masked)
                } else {
                    ic.commitText("\n", 1)
                }
            }
            is KeyAction.SwitchMode -> {
                // Launch main app so user can draw/configure glyphs
                val intent = packageManager.getLaunchIntentForPackage(packageName)
                intent?.addFlags(android.content.Intent.FLAG_ACTIVITY_NEW_TASK)
                intent?.let { startActivity(it) }
            }
        }
    }

    sealed class KeyAction {
        data class TypeText(val text: String) : KeyAction()
        object Backspace : KeyAction()
        object Enter : KeyAction()
        object SwitchMode : KeyAction()
    }
}

/**
 * HandwritingKeyboardView — fully canvas-drawn QWERTY keyboard.
 */
class HandwritingKeyboardView(
    context: Context,
    private val onKey: (HandwritingIMEService.KeyAction) -> Unit
) : View(context) {

    // ── Colours (dark theme matching the Flutter app) ──
    private val bgColor     = Color.parseColor("#0D0D0D")
    private val keyColor    = Color.parseColor("#1E1E2E")
    private val keyColorAlt = Color.parseColor("#2A2A3E")
    private val keyColorAcc = Color.parseColor("#7C3AED")  // purple accent (space)
    private val keyColorBS  = Color.parseColor("#3A1A1A")
    private val keyText     = Color.WHITE
    private val keyHint     = Color.parseColor("#9CA3AF")
    private val pressedOver = Color.parseColor("#44FFFFFF")

    private val bgPaint     = Paint(Paint.ANTI_ALIAS_FLAG).apply { color = bgColor }
    private val keyPaint    = Paint(Paint.ANTI_ALIAS_FLAG)
    private val textPaint   = Paint(Paint.ANTI_ALIAS_FLAG).apply {
        color = keyText
        typeface = Typeface.create("sans-serif-medium", Typeface.NORMAL)
        textAlign = Paint.Align.CENTER
    }
    private val hintPaint   = Paint(Paint.ANTI_ALIAS_FLAG).apply {
        color = keyHint
        typeface = Typeface.create("sans-serif", Typeface.NORMAL)
        textAlign = Paint.Align.CENTER
    }

    // Key rows definition  [label, action-text or special command]
    private val rows = listOf(
        listOf("q","w","e","r","t","y","u","i","o","p"),
        listOf("a","s","d","f","g","h","j","k","l"),
        listOf("⇧","z","x","c","v","b","n","m","⌫"),
        listOf("?123","SPACE","✍","↵")
    )

    data class KeyRect(val rect: RectF, val label: String, var isPressed: Boolean = false)

    private val keyRects = mutableListOf<KeyRect>()
    private var capsLock = false
    private val handler = Handler(Looper.getMainLooper())

    fun setCapsLock(on: Boolean) { capsLock = on; invalidate() }

    override fun onSizeChanged(w: Int, h: Int, oldW: Int, oldH: Int) {
        super.onSizeChanged(w, h, oldW, oldH)
        buildKeyRects(w, h)
    }

    private fun buildKeyRects(w: Int, h: Int) {
        keyRects.clear()
        val padding = w * 0.01f
        val rowH    = h / 4f
        val cornerR = 8f

        rows.forEachIndexed { rowIdx, keys ->
            val keyW   = (w - padding * (keys.size + 1)) / keys.size
            val top    = rowIdx * rowH + padding
            val bottom = (rowIdx + 1) * rowH - padding

            keys.forEachIndexed { keyIdx, label ->
                val left  = padding + keyIdx * (keyW + padding)
                val right = left + keyW

                // Row 3: make SPACE wider
                val actualLeft: Float
                val actualRight: Float
                if (rowIdx == 3) {
                    val segW = w / 4f
                    actualLeft  = keyIdx * segW + padding
                    actualRight = (keyIdx + 1) * segW - padding
                } else {
                    actualLeft  = left
                    actualRight = right
                }

                keyRects.add(KeyRect(RectF(actualLeft, top, actualRight, bottom), label))
            }
        }
    }

    override fun onDraw(canvas: Canvas) {
        super.onDraw(canvas)
        canvas.drawRect(0f, 0f, width.toFloat(), height.toFloat(), bgPaint)

        val keyFontSize  = height * 0.1f
        val hintFontSize = height * 0.065f
        textPaint.textSize = keyFontSize
        hintPaint.textSize  = hintFontSize

        keyRects.forEach { kr ->
            val displayLabel = when {
                kr.label == "⇧" && capsLock -> "⇪"
                kr.label.length == 1 && kr.label[0].isLetter() && capsLock -> kr.label.uppercase()
                else -> kr.label
            }

            // Choose key background colour
            keyPaint.color = when (kr.label) {
                "SPACE" -> keyColorAcc
                "⌫"     -> keyColorBS
                "✍"     -> Color.parseColor("#1D4ED8")
                "↵"     -> Color.parseColor("#065F46")
                "?123"  -> keyColorAlt
                "⇧","⇪" -> if (capsLock) keyColorAcc else keyColorAlt
                else    -> keyColor
            }

            canvas.drawRoundRect(kr.rect, 10f, 10f, keyPaint)

            // Pressed overlay
            if (kr.isPressed) {
                val overlayPaint = Paint(Paint.ANTI_ALIAS_FLAG).apply { color = pressedOver }
                canvas.drawRoundRect(kr.rect, 10f, 10f, overlayPaint)
            }

            val cx = kr.rect.centerX()
            val cy = kr.rect.centerY() - (textPaint.descent() + textPaint.ascent()) / 2

            when (kr.label) {
                "SPACE" -> {
                    textPaint.textSize = hintFontSize
                    canvas.drawText("✍ Handwriting Keyboard", cx, cy, textPaint)
                    textPaint.textSize = keyFontSize
                }
                else -> canvas.drawText(displayLabel, cx, cy, textPaint)
            }
        }
    }

    override fun onTouchEvent(event: MotionEvent): Boolean {
        val x = event.x; val y = event.y
        when (event.action) {
            MotionEvent.ACTION_DOWN, MotionEvent.ACTION_MOVE -> {
                keyRects.forEach { it.isPressed = false }
                keyRects.firstOrNull { it.rect.contains(x, y) }?.isPressed = true
                invalidate()
            }
            MotionEvent.ACTION_UP -> {
                val hit = keyRects.firstOrNull { it.rect.contains(x, y) }
                keyRects.forEach { it.isPressed = false }
                invalidate()
                hit?.let { dispatchKey(it.label) }
            }
        }
        return true
    }

    private fun dispatchKey(label: String) {
        when (label) {
            "⌫"     -> onKey(HandwritingIMEService.KeyAction.Backspace)
            "↵"     -> onKey(HandwritingIMEService.KeyAction.Enter)
            "⇧","⇪" -> { capsLock = !capsLock; invalidate() }
            "SPACE" -> onKey(HandwritingIMEService.KeyAction.TypeText(" "))
            "✍"     -> onKey(HandwritingIMEService.KeyAction.SwitchMode)
            "?123"  -> { /* TODO: switch to number/symbol layout */ }
            else    -> {
                val text = if (capsLock) label.uppercase() else label.lowercase()
                onKey(HandwritingIMEService.KeyAction.TypeText(text))
                if (capsLock && label.length == 1 && label[0].isLetter()) {
                    capsLock = false; invalidate()
                }
            }
        }
    }
}
