package com.handwritingkeyboard.app

import android.content.Context
import android.graphics.*
import android.inputmethodservice.InputMethodService
import android.util.TypedValue
import android.view.MotionEvent
import android.view.View
import android.view.ViewGroup
import android.view.inputmethod.EditorInfo
import android.view.inputmethod.InputConnection

class HandwritingIMEService : InputMethodService() {

    private lateinit var keyboardView: HandwritingKeyboardView

    override fun onEvaluateFullscreenMode(): Boolean = false
    override fun onEvaluateInputViewShown(): Boolean = true

    override fun onCreateInputView(): View {
        keyboardView = HandwritingKeyboardView(this) { action -> handleKeyAction(action) }
        keyboardView.layoutParams = ViewGroup.LayoutParams(
            ViewGroup.LayoutParams.MATCH_PARENT,
            dp(280)
        )
        return keyboardView
    }

    override fun onStartInputView(info: EditorInfo?, restarting: Boolean) {
        super.onStartInputView(info, restarting)
        keyboardView.updateEditorInfo(info)
        keyboardView.setCapsLock(false)
    }

    private fun dp(v: Int) = TypedValue.applyDimension(
        TypedValue.COMPLEX_UNIT_DIP, v.toFloat(), resources.displayMetrics
    ).toInt()

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
            is KeyAction.OpenApp -> {
                val i = packageManager.getLaunchIntentForPackage(packageName)
                i?.addFlags(android.content.Intent.FLAG_ACTIVITY_NEW_TASK)
                i?.let { startActivity(it) }
            }
        }
    }

    sealed class KeyAction {
        data class TypeText(val text: String) : KeyAction()
        object Backspace : KeyAction()
        object Enter : KeyAction()
        object OpenApp : KeyAction()
    }
}

// ─────────────────────────────────────────────────────────────────────────────

data class KeyDef(
    val primary: String,
    val hint: String = "",       // small number/symbol hint top-right
    val type: KeyType = KeyType.NORMAL
)

enum class KeyType { NORMAL, ACTION, WIDE, SHIFT, BACKSPACE, ENTER, SPACE, TOOLBAR }

class HandwritingKeyboardView(
    context: Context,
    private val onKey: (HandwritingIMEService.KeyAction) -> Unit
) : View(context) {

    // ── Colours ───────────────────────────────────────────────────────────────
    private val C_BG        = Color.parseColor("#0F0F0F")
    private val C_KEY       = Color.parseColor("#2B2B2B")
    private val C_KEY_ACT   = Color.parseColor("#3C3C3E")   // action keys
    private val C_KEY_ENTER = Color.parseColor("#5B5BD6")   // enter key accent
    private val C_KEY_SHAD  = Color.parseColor("#111111")   // bottom shadow
    private val C_TEXT      = Color.WHITE
    private val C_HINT      = Color.parseColor("#888888")
    private val C_PRESSED   = Color.parseColor("#55FFFFFF")
    private val C_TOOLBAR   = Color.parseColor("#1A1A1A")

    // ── Layout ────────────────────────────────────────────────────────────────
    private val QWERTY = listOf("q","w","e","r","t","y","u","i","o","p")
    private val HINTS0 = listOf("1","2","3","4","5","6","7","8","9","0")
    private val ASDFG  = listOf("a","s","d","f","g","h","j","k","l")
    private val HINTS1 = listOf("@","#","₹","-","_","&","=","(",")","")

    // Row definitions
    // Row 0: toolbar  Row 1: QWERTY  Row 2: ASDF  Row 3: ZXCV  Row 4: bottom
    private val rowDefs: List<List<KeyDef>> = listOf(
        // ── Toolbar row ──
        listOf(
            KeyDef(">|",  type = KeyType.TOOLBAR),
            KeyDef("MIC", type = KeyType.TOOLBAR),
            KeyDef("CBP", type = KeyType.TOOLBAR),
            KeyDef("SET", type = KeyType.TOOLBAR),
        ),
        // ── QWERTY ──
        QWERTY.mapIndexed { i, c -> KeyDef(c, HINTS0[i]) },
        // ── ASDF ──
        ASDFG.mapIndexed { i, c -> KeyDef(c, if (i < HINTS1.size) HINTS1[i] else "") },
        // ── Shift row ──
        listOf(
            KeyDef("⇧",  type = KeyType.SHIFT),
            KeyDef("z"), KeyDef("x"), KeyDef("c"), KeyDef("v"),
            KeyDef("b"), KeyDef("n"), KeyDef("m"),
            KeyDef("⌫",  type = KeyType.BACKSPACE),
        ),
        // ── Bottom row ──
        listOf(
            KeyDef("?123", type = KeyType.ACTION),
            KeyDef(","),
            KeyDef("🌐",   type = KeyType.ACTION),
            KeyDef("😊",   type = KeyType.ACTION),
            KeyDef("SPACE",type = KeyType.SPACE),
            KeyDef("."),
            KeyDef("↵",    type = KeyType.ENTER),
        ),
    )

    data class DrawnKey(val rect: RectF, val def: KeyDef, var pressed: Boolean = false)

    private val drawnKeys = mutableListOf<DrawnKey>()
    private var capsLock  = false
    private var enterLabel = "↵"

    fun setCapsLock(on: Boolean) { capsLock = on; invalidate() }

    fun updateEditorInfo(info: EditorInfo?) {
        enterLabel = when (info?.imeOptions?.and(EditorInfo.IME_MASK_ACTION)) {
            EditorInfo.IME_ACTION_SEARCH -> "🔍"
            EditorInfo.IME_ACTION_SEND   -> "Send"
            EditorInfo.IME_ACTION_GO     -> "Go"
            EditorInfo.IME_ACTION_DONE   -> "Done"
            EditorInfo.IME_ACTION_NEXT   -> "Next"
            else                         -> "↵"
        }
        invalidate()
    }

    // ── Paints ────────────────────────────────────────────────────────────────
    private val bgP     = Paint(Paint.ANTI_ALIAS_FLAG)
    private val keyP    = Paint(Paint.ANTI_ALIAS_FLAG)
    private val shadP   = Paint(Paint.ANTI_ALIAS_FLAG).apply { color = C_KEY_SHAD }
    private val pressP  = Paint(Paint.ANTI_ALIAS_FLAG).apply { color = C_PRESSED }
    private val textP   = Paint(Paint.ANTI_ALIAS_FLAG).apply {
        color = C_TEXT
        typeface = Typeface.create("sans-serif", Typeface.NORMAL)
        textAlign = Paint.Align.CENTER
    }
    private val hintP   = Paint(Paint.ANTI_ALIAS_FLAG).apply {
        color = C_HINT
        typeface = Typeface.create("sans-serif", Typeface.NORMAL)
        textAlign = Paint.Align.RIGHT
    }

    // ── Build key rects ───────────────────────────────────────────────────────
    override fun onSizeChanged(w: Int, h: Int, oldW: Int, oldH: Int) {
        super.onSizeChanged(w, h, oldW, oldH)
        buildLayout(w, h)
    }

    private fun buildLayout(W: Int, H: Int) {
        drawnKeys.clear()
        val padX  = W * 0.008f
        val padT  = H * 0.010f

        // Row heights: toolbar 14%, keys 86% split into 4 rows
        val tbH   = H * 0.140f
        val keyH  = (H * 0.860f - padT * 5) / 4f
        val gapV  = padT

        val rowTops = listOf(
            padT,                                       // toolbar
            padT + tbH + gapV,                          // QWERTY
            padT + tbH + gapV + (keyH + gapV),          // ASDF
            padT + tbH + gapV + (keyH + gapV) * 2,      // shift+ZXC
            padT + tbH + gapV + (keyH + gapV) * 3,      // bottom
        )

        rowDefs.forEachIndexed { rowIdx, keys ->
            val top    = rowTops[rowIdx]
            val bottom = top + if (rowIdx == 0) tbH else keyH

            when (rowIdx) {
                0 -> buildToolbar(keys, padX, top, bottom, W)
                1 -> buildEvenRow(keys, padX, top, bottom, W, true)
                2 -> buildAsdfRow(keys, padX, top, bottom, W)
                3 -> buildShiftRow(keys, padX, top, bottom, W)
                4 -> buildBottomRow(keys, padX, top, bottom, W)
            }
        }
    }

    private fun buildToolbar(keys: List<KeyDef>, pad: Float, top: Float, bot: Float, W: Int) {
        val btnW = W * 0.09f
        val positions = listOf(pad, pad + btnW + pad, W - (btnW + pad) * 2, W - (btnW + pad))
        keys.forEachIndexed { i, k ->
            val l = positions[i]
            drawnKeys.add(DrawnKey(RectF(l, top + pad, l + btnW, bot - pad), k))
        }
    }

    private fun buildEvenRow(keys: List<KeyDef>, pad: Float, top: Float, bot: Float, W: Int, hints: Boolean) {
        val n    = keys.size
        val keyW = (W - pad * (n + 1)) / n
        keys.forEachIndexed { i, k ->
            val l = pad + i * (keyW + pad)
            drawnKeys.add(DrawnKey(RectF(l, top, l + keyW, bot), k))
        }
    }

    private fun buildAsdfRow(keys: List<KeyDef>, pad: Float, top: Float, bot: Float, W: Int) {
        // Centred row — 9 keys
        val n    = keys.size
        val keyW = (W - pad * (n + 1)) / (n + 0.5f)  // slightly smaller
        val totalW = keyW * n + pad * (n - 1)
        val startX = (W - totalW) / 2f
        keys.forEachIndexed { i, k ->
            val l = startX + i * (keyW + pad)
            drawnKeys.add(DrawnKey(RectF(l, top, l + keyW, bot), k))
        }
    }

    private fun buildShiftRow(keys: List<KeyDef>, pad: Float, top: Float, bot: Float, W: Int) {
        // shift(1.4×) | 7 letters | backspace(1.4×)
        val n       = keys.size
        val wideW   = (W - pad * (n + 1)) / (n + 0.8f) * 1.4f
        val letterW = (W - pad * (n + 1) - wideW * 2) / (n - 2)
        var x = pad
        keys.forEachIndexed { i, k ->
            val kw = if (i == 0 || i == n - 1) wideW else letterW
            drawnKeys.add(DrawnKey(RectF(x, top, x + kw, bot), k))
            x += kw + pad
        }
    }

    private fun buildBottomRow(keys: List<KeyDef>, pad: Float, top: Float, bot: Float, W: Int) {
        // ?123(1×)  ,(0.6×)  🌐(0.6×)  😊(0.6×)  SPACE(3×)  .(0.6×)  ↵(1×)
        val unit = (W.toFloat() - pad * (keys.size + 1)) / 7.4f
        val widths = listOf(unit, unit * 0.6f, unit * 0.6f, unit * 0.6f, unit * 3f, unit * 0.6f, unit)
        var x = pad
        keys.forEachIndexed { i, k ->
            val kw = widths[i]
            drawnKeys.add(DrawnKey(RectF(x, top, x + kw, bot), k))
            x += kw + pad
        }
    }

    // ── Draw ──────────────────────────────────────────────────────────────────
    override fun onDraw(canvas: Canvas) {
        // Background
        bgP.color = C_BG
        canvas.drawRect(0f, 0f, width.toFloat(), height.toFloat(), bgP)

        // Toolbar background
        drawnKeys.firstOrNull { it.def.type == KeyType.TOOLBAR }?.let { first ->
            bgP.color = C_TOOLBAR
            canvas.drawRect(0f, 0f, width.toFloat(), first.rect.bottom + first.rect.height() * 0.3f, bgP)
        }

        val keyH = drawnKeys.filter { it.def.type != KeyType.TOOLBAR }
            .map { it.rect.height() }.firstOrNull() ?: 48f

        val mainFontSz = keyH * 0.42f
        val hintFontSz = keyH * 0.26f
        val subFontSz  = keyH * 0.30f
        val CORNER     = keyH * 0.16f
        val SHADOW     = keyH * 0.06f

        drawnKeys.forEach { dk ->
            val r   = dk.def
            val rect = dk.rect
            val isToolbar = r.type == KeyType.TOOLBAR

            // Key background colour
            keyP.color = when {
                isToolbar                 -> Color.TRANSPARENT
                r.type == KeyType.SPACE   -> C_KEY_ACT
                r.type == KeyType.ACTION  -> C_KEY_ACT
                r.type == KeyType.SHIFT   -> C_KEY_ACT
                r.type == KeyType.BACKSPACE -> C_KEY_ACT
                r.type == KeyType.ENTER   -> C_KEY_ENTER
                else                      -> C_KEY
            }

            if (!isToolbar) {
                // Shadow (bottom edge illusion)
                val shadRect = RectF(rect.left, rect.top + SHADOW, rect.right, rect.bottom + SHADOW)
                canvas.drawRoundRect(shadRect, CORNER, CORNER, shadP)
                // Key face
                canvas.drawRoundRect(rect, CORNER, CORNER, keyP)
            }

            // Pressed overlay
            if (dk.pressed && !isToolbar) {
                canvas.drawRoundRect(rect, CORNER, CORNER, pressP)
            }

            val cx = rect.centerX()
            val cy = rect.centerY()

            when {
                isToolbar -> drawToolbarIcon(canvas, r.primary, cx, cy, keyH * 0.5f)

                r.type == KeyType.SPACE -> {
                    textP.textSize = subFontSz
                    textP.color = C_HINT
                    val ty = cy - (textP.descent() + textP.ascent()) / 2
                    canvas.drawText("English", cx, ty, textP)
                    textP.color = C_TEXT
                }

                r.primary == "⇧" || r.primary == "⇪" -> {
                    textP.textSize = mainFontSz * 1.1f
                    textP.color = C_TEXT
                    val label = if (capsLock) "⇪" else "⇧"
                    canvas.drawText(label, cx, cy - (textP.descent() + textP.ascent()) / 2, textP)
                }

                r.primary == "⌫" -> {
                    textP.textSize = mainFontSz * 1.1f
                    textP.color = C_TEXT
                    canvas.drawText("⌫", cx, cy - (textP.descent() + textP.ascent()) / 2, textP)
                }

                r.primary == "↵" -> {
                    textP.textSize = if (enterLabel.length > 1) mainFontSz * 0.72f else mainFontSz * 1.1f
                    textP.color = C_TEXT
                    canvas.drawText(enterLabel, cx, cy - (textP.descent() + textP.ascent()) / 2, textP)
                }

                else -> {
                    val display = if (capsLock && r.primary.length == 1 && r.primary[0].isLetter())
                        r.primary.uppercase() else r.primary

                    // Primary label
                    textP.textSize = mainFontSz
                    textP.color = C_TEXT
                    val ty = cy - (textP.descent() + textP.ascent()) / 2
                    canvas.drawText(display, cx, ty, textP)

                    // Number/symbol hint (top-right corner)
                    if (r.hint.isNotEmpty()) {
                        hintP.textSize = hintFontSz
                        canvas.drawText(r.hint, rect.right - rect.width() * 0.08f,
                            rect.top + hintFontSz * 1.1f, hintP)
                    }
                }
            }

            textP.color = C_TEXT // reset
        }
    }

    private fun drawToolbarIcon(canvas: Canvas, id: String, cx: Float, cy: Float, size: Float) {
        textP.textSize = size * 0.75f
        textP.color = C_HINT
        val label = when (id) {
            ">|"  -> "⌨"
            "MIC" -> "🎤"
            "CBP" -> "📋"
            "SET" -> "⚙"
            else  -> id
        }
        canvas.drawText(label, cx, cy - (textP.descent() + textP.ascent()) / 2, textP)
        textP.color = C_TEXT
    }

    // ── Touch ─────────────────────────────────────────────────────────────────
    override fun onTouchEvent(event: MotionEvent): Boolean {
        val x = event.x; val y = event.y
        when (event.actionMasked) {
            MotionEvent.ACTION_DOWN, MotionEvent.ACTION_MOVE -> {
                drawnKeys.forEach { it.pressed = it.rect.contains(x, y) }
                invalidate()
            }
            MotionEvent.ACTION_UP -> {
                val hit = drawnKeys.firstOrNull { it.rect.contains(x, y) }
                drawnKeys.forEach { it.pressed = false }
                invalidate()
                hit?.let { fire(it.def) }
            }
            MotionEvent.ACTION_CANCEL -> {
                drawnKeys.forEach { it.pressed = false }
                invalidate()
            }
        }
        return true
    }

    private fun fire(k: KeyDef) {
        when (k.type) {
            KeyType.BACKSPACE -> onKey(HandwritingIMEService.KeyAction.Backspace)
            KeyType.ENTER     -> onKey(HandwritingIMEService.KeyAction.Enter)
            KeyType.SHIFT     -> { capsLock = !capsLock; invalidate() }
            KeyType.SPACE     -> onKey(HandwritingIMEService.KeyAction.TypeText(" "))
            KeyType.TOOLBAR   -> {
                if (k.primary == ">|") onKey(HandwritingIMEService.KeyAction.OpenApp)
            }
            else -> when (k.primary) {
                "⌫"   -> onKey(HandwritingIMEService.KeyAction.Backspace)
                "↵"   -> onKey(HandwritingIMEService.KeyAction.Enter)
                "⇧","⇪" -> { capsLock = !capsLock; invalidate() }
                "🌐"  -> onKey(HandwritingIMEService.KeyAction.TypeText(" "))
                "😊","?123" -> { /* future */ }
                else  -> {
                    val ch = if (capsLock && k.primary.length == 1 && k.primary[0].isLetter())
                        k.primary.uppercase() else k.primary.lowercase()
                    onKey(HandwritingIMEService.KeyAction.TypeText(ch))
                    if (capsLock && k.primary.length == 1 && k.primary[0].isLetter()) {
                        capsLock = false; invalidate()
                    }
                }
            }
        }
    }
}
