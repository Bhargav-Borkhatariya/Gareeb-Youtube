# gareeb-youtube

Personal-use Android app. **Do not publish** it to Play Store, GitHub Releases, or anywhere public.

It is a **YouTube website WebView** (like Brave on youtube.com): Home, Shorts, Search, and the real player (1080p/4K). Ad hosts are blocked. “Open in app” / Play Store jumps are cancelled.

This **violates YouTube’s Terms of Service**. Sideload the APK on your own phone (and friends’ phones) only.

Sign in with Google **on the YouTube site** inside the app for subscriptions and comments.

## How to run

Flutter is not required system-wide if you already have it. This machine can use:

```bash
export PATH="$HOME/development/flutter/bin:$PATH"
export JAVA_HOME="/usr/lib/jvm/java-17-openjdk-amd64"
export ANDROID_HOME="$HOME/Android/Sdk"
export PATH="$PATH:$JAVA_HOME/bin:$ANDROID_HOME/platform-tools"

cd "/home/sanskar/Documents/R&D/gareeb-youtube"
flutter pub get
flutter run
```

Or build an APK and sideload:

```bash
flutter build apk
adb install -r build/app/outputs/flutter-apk/app-release.apk
```

Debug signing is enough. No store listing.

## iOS Build

Building for iOS requires Apple's toolchain (Xcode / macOS). Since local Linux environments cannot compile native iOS apps directly, two paths are supported:

### Option 1: GitHub Actions (Automated Cloud Build - Free & Recommended)
A workflow has been configured in `.github/workflows/build-ios.yml`.
1. Push your changes to GitHub.
2. Go to the repository's **Actions** tab on GitHub.
3. Select **Build iOS IPA** and click **Run workflow** (or simply push to `main`).
4. Download the compiled `GareebYouTube.ipa` from the workflow summary artifacts.
5. Sideload onto iPhone/iPad using [Sideloadly](https://sideloadly.io/), [AltStore](https://altstore.io/), or TrollStore.

### Option 2: Build Locally on macOS
If you have access to a Mac:
```bash
flutter pub get
flutter build ios --release --no-codesign
```
Or open `ios/Runner.xcworkspace` in Xcode to run on a physical iPhone or Simulator with your free personal Apple ID signing.

## When playback breaks (it will)

Nothing unofficial works forever. YouTube changes servers. ReVanced stopping after about a minute is that war.

**If this app 403s, won’t start, or dies mid-video:**

1. Watch in **NewPipe** or **Brave** right now.
2. Later, bump `youtube_explode_dart` in `pubspec.yaml` and rebuild.
3. Do **not** add custom YouTube bypass / PO-token / SABR exploits.

Keep NewPipe and/or Brave installed as the spare tire.
