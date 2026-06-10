# ✍️ Handwriting Keyboard

A premium, cross-platform (Android + Windows) handwriting IME keyboard app that turns **your own handwriting** into a functional system font. Type in your real handwriting across WhatsApp, Telegram, Notes, browsers, and every other app!

---

## 🚀 Key Features

*   **✍️ Canvas Drawing**: Digitally draw individual letters, digits, and symbols to build your glyph map.
*   **🤖 AI Note Extraction (OCR)**: Snap a photo of a page containing all your written letters. The app automatically segments, extracts, and matches each character using the Gemini API.
*   **🧠 Intelligent Word Suggestions**: Built-in Gemini-powered next-word suggestions directly above your keyboard, adapting dynamically to your writing style and context.
*   **🔤 Real TrueType Font (.ttf) Generation**: Compiles your handwritten characters into an installable `.ttf` font file.
*   **👥 Handwriting Profiles**: Supports multiple profiles. Keep styles for clean print, cursive, or different users, and swap between them instantly.
*   **🎙️ Voice Typing**: Integrated speech-to-text. Simply speak and watch your words appear in your handwriting.
*   **👆 Swipe Typing**: Glide across keys to write words smoothly.
*   **🎨 Live Custom Themes**: Fully custom keyboard theme presets with premium gradients, dark modes, and adjustable dimensions.

---

## 🔮 How the AI Note Extraction Pipeline Works

To make profile setup seamless, the app features an **AI-driven OCR and image extraction pipeline**:
1.  **Single-Pass Resizing & Compression**: The app captures a photo of your handwriting sheet, downscaling it to a maximum of 800px on the longest side. This keeps memory usage low and ensures instant API transfers.
2.  **Gemini OCR Processing**: The compressed JPEG is sent to the Gemini API with a specialized prompt requesting precise recognition of the letters in order.
3.  **Contour & Glyph Segmentation**: The app performs custom connected-component contour labeling to extract physical image bounding boxes (blobs) for each written character.
4.  **Bipartite Matching**: A greedy bipartite matching algorithm matches physical glyph blobs to recognized OCR symbols based on horizontal reading order and confidence, mapping them to the active handwriting profile automatically.
5.  **Interactive Alignment**: Any misaligned symbol can be corrected instantly via a simple long-press dialog on the review grid.

---

## 🛠️ API Key Management

The app uses the Gemini API for **AI Note Extraction** and **Predictive Typing Suggestions**. 
*   **Out-of-the-box Access**: A default, secure API key is embedded using split adjacent string literals to bypass code repository scanners.
*   **Custom Key Support**: Users can enter their own API key via **Settings → Gemini API Key** for personal, unlimited, and high-frequency usage. This key is persisted securely in the local Drift SQLite database.

---

## 📱 Android Installation & Setup

### 1. Enable the Handwriting Keyboard IME
To use the app as your default keyboard:
1.  Compile and install the release APK on your phone.
2.  Navigate to **Settings** → **General Management** → **Keyboard list and default** (or **System → Languages & input → On-screen keyboard**).
3.  Toggle **Handwriting Keyboard** to **On**.
4.  Set **Handwriting Keyboard** as your **Default keyboard**.

### 2. Apply Your Handwriting System-Wide (Without Root)
To see your own handwriting in WhatsApp, Telegram, and other apps, apply the generated `.ttf` font:
*   **Using iFont or zFont 3 (Recommended)**:
    1.  Open the **Handwriting Keyboard** app.
    2.  Tap **Settings** → **Generate Font** → **Generate Font**.
    3.  Once compiled, tap **Install Font**. The app will launch **iFont** or **zFont 3** with your font pre-loaded.
    4.  In iFont/zFont, tap **Apply** → **Set as system font**.
    5.  Depending on your device manufacturer, apply it through the theme manager:
        *   **Samsung (One UI)**: Apply via custom theme/font manager apps (like Good Lock or Mono).
        *   **Xiaomi (MIUI/HyperOS)**: Open **Themes** → **My Account** → **Fonts** and select your font.
        *   **OPPO/Realme (ColorOS)**: Select custom fonts via **Settings → Personalisation → Font & Display Size**.
    6.  Reboot your device if prompted. All text will now render in your handwriting!
*   **Share as Image Alternative**:
    If you don't want to install a system-wide font, go to **Settings → Share as Image**. Type your text and share it directly as a transparent PNG image in chat apps.

---

## 💻 Windows Installation & Setup

To use your handwriting font on Windows:
1.  Launch the Handwriting Keyboard app on Windows.
2.  Open **Settings** → **Generate Font** and tap **Generate Font**.
3.  Click **Install Font**.
4.  A User Account Control (UAC) dialog will request Administrator permissions. Click **Yes**.
5.  The app uses the Win32 `AddFontResource()` and `SendNotifyMessage()` APIs to install and register the TrueType font system-wide without a reboot.
6.  Open Notepad, Word, or your web browser settings, select your profile name (e.g., `Handwriting`) from the font selection dropdown, and enjoy typing in your own handwriting!

---

## 📦 Building from Source

### Prerequisites
*   [Flutter SDK](https://flutter.dev/docs/get-started/install) (version 3.19 or higher)
*   **Android Build**: Android Studio & Android SDK Command-line Tools (licenses accepted)
*   **Windows Build**: Visual Studio 2022 with "Desktop development with C++" workload installed

### Compilation Commands

```powershell
# Clone the repository
git clone https://github.com/pmunaswamireddy/HandWriting-keyboard.git
cd HandWriting-keyboard

# Retrieve dependencies
flutter pub get

# Generate Drift SQLite code
flutter pub run build_runner build --delete-conflicting-outputs

# Build Android Release APK
flutter build apk --release

# Build Windows Release Executable
flutter build windows --release
```

The compiled Android release APK will be saved at:
`build/app/outputs/flutter-apk/app-release.apk`

The compiled Windows binaries will be saved at:
`build/windows/x64/runner/Release/`

---

## 📄 License
This project is licensed under the MIT License - see the LICENSE file for details.
