# Handwriting Keyboard Proguard Rules

# ── Critical: Keep IME Service (must survive release minification) ──
-keep class com.handwritingkeyboard.app.HandwritingIMEService { *; }
-keep public class * extends android.inputmethodservice.InputMethodService
-keepclassmembers class * extends android.inputmethodservice.InputMethodService { *; }

# ── Keep MainActivity and Flutter embedding ──
-keep class com.handwritingkeyboard.app.MainActivity { *; }
-keep class io.flutter.** { *; }
-keep class io.flutter.embedding.** { *; }
-dontwarn io.flutter.embedding.**

# ── Keep plugin classes ──
-keep class com.handwritingkeyboard.app.FontInstallerPlugin { *; }

# Ignore warnings for optional ML Kit language packages that are not bundled
-dontwarn com.google.mlkit.vision.text.chinese.**
-dontwarn com.google.mlkit.vision.text.devanagari.**
-dontwarn com.google.mlkit.vision.text.japanese.**
-dontwarn com.google.mlkit.vision.text.korean.**
-dontwarn com.google.mlkit.vision.text.**
-dontwarn com.google.mlkit.**
-dontwarn com.google.android.gms.**
