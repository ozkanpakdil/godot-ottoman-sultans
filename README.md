# Chronicles of the House of Osman

An educational, minimalist narrative-adventure and interactive timeline covering 600+ years of Ottoman history (1299–1922), built with Godot 4.x. Navigate chronologically through the reigns of all 36 sultans across 5 chapters, view Wikipedia-sourced portraits, listen to period music, take end-of-chapter quizzes, and convert your study time into a leaderboard score.

## Requirements

- **Godot Engine 4.x** (4.3 or newer recommended) — download from [godotengine.org](https://godotengine.org/download). No other dependencies.

## Running the Game

### Option A: Godot Editor (recommended)

1. Open the Godot Project Manager.
2. Click **Import**, browse to this folder, and select `project.godot`.
3. Click **Import & Open**.
4. Press **F5** (or the Play button ▶ in the top-right) to run.

### Option B: Command Line

```bash
# From this folder:
godot --path .

# Or, without opening the project folder first:
godot --path /path/to/ottoman-sultans
```

If Godot is not on your `PATH`, use the full binary path, e.g. on macOS:

```bash
/Applications/Godot.app/Contents/MacOS/Godot --path .
```

### First run note

The game starts at the **Main Menu**. Choose **Continue the Journey** to start from your saved progress, or pick any chapter to jump straight to it. Progress, study time, quiz results, and your chosen language are saved automatically (encrypted) to the user data folder.

## Supported Languages

The game ships with full UI and content translations for:

- **English** (`en`)
- **Türkçe / Turkish** (`tr`)
- **中文 / Simplified Chinese** (`zh`)
- **Русский / Russian** (`ru`)
- **Español / Spanish** (`es`)

Use the language picker on the Main Menu to switch instantly. The default language is taken from your OS locale, falling back to English.

UI strings live in `assets/i18n/ui_translations.csv`. Historical content (sultan names, summaries, battle descriptions, chapter titles) is stored inline in `data/historical_db.json` under the `en/tr/zh/ru/es` keys.

## Running the Tests

A headless self-check validates the database, translations, portrait files, audio, quiz generation, scoring, and save/load:

```bash
godot --headless --path . res://test_runner.tscn
```

Expected output ends with `ALL TESTS PASSED`.

## Project Structure

```text
├── assets/
│   ├── audio/            # Period music tracks (Ottoman mehter/classical)
│   ├── fonts/            # Drop .ttf/.otf fonts here if you want custom typography
│   ├── i18n/             # UI translation CSV
│   ├── sultans/          # Sultan portraits downloaded from Wikipedia/Wikimedia Commons
│   └── UI/               # App icon and future UI art
├── core/
│   ├── Autoload/         # HistoricalData, GameManager, SaveManager, MusicPlayer
│   └── Systems/          # QuizSystem, TimeTracker
├── data/
│   └── historical_db.json  # All chapters, sultans, battles, spouses, video metadata (5 languages)
└── scenes/               # MainMenu, Timeline, Quiz, Leaderboard (.tscn + .gd)
```

## Customizing Content

### Historical text

Everything content-related lives in `data/historical_db.json` — no code changes needed:

- **Edit a summary or battle description** — change the text under any language key and restart the game.
- **Add a YouTube video** — set `"video_id"` (e.g. `"dQw4w9WgXcQ"`) on a sultan; a "▶ Watch" button appears and opens the system YouTube app/browser.
- **Add a sultan or battle** — follow the existing JSON structure; the timeline and quiz generator pick it up automatically.

### Portraits

Portraits are loaded from `assets/sultans/<slug>.jpg`. Each sultan's `"portrait"` field in the JSON points to the corresponding file. If you want to replace an image, drop a new `.jpg` with the same filename.

### Music

The bottom music bar scans `assets/audio/` for `.ogg`, `.mp3`, and `.wav` files and plays them in a loop. Add more tracks to the folder and they will appear automatically. Volume is currently controlled through the default **Music** bus in Godot.

### Fonts

The project now bundles **Noto Sans** (for Latin, Turkish, Russian, and Spanish) with **Noto Sans CJK SC** as a fallback (for Simplified Chinese). Both are set as the default project font in `assets/fonts/default_font.tres`.

To add custom fonts (e.g. Cinzel or Playfair Display), place the files in `assets/fonts/` and set them as theme overrides on the labels/buttons, or replace `default_font.tres`.

## Building Release Binaries

A shell script at `tools/build.sh` automates exporting to iOS, Android, macOS, Windows, and Linux. On first run it creates `export_presets.cfg` (and an Android debug keystore) if they do not exist.

### Prerequisites

1. **Godot 4.x Export Templates** are installed automatically by the build script if missing (downloaded from GitHub, extracted, and placed in the layout Godot expects). If you prefer, you can install them manually: **Editor → Manage Export Templates → Download and Install**.
2. **Android** (optional): configure the Android SDK in **Editor → Editor Settings → Export → Android**, or the export will fail. The script auto-generates a release keystore on first Android build, so `./tools/build.sh android` produces a signed release APK.
3. **iOS** (optional): requires macOS + Xcode. The preset exports the Xcode project only (`application/export_project_only=true`) so the build script can produce a project without a real Apple Team ID. Open the project in Xcode and set your own team/signing before building.

### Usage

```bash
# Make the script executable (only once)
chmod +x tools/build.sh

# Install export templates (run once, or skip if already installed)
./tools/build.sh --install-templates

# Build everything
./tools/build.sh all

# Build only mobile platforms
./tools/build.sh mobile        # ios + android

# Build only desktop platforms
./tools/build.sh desktop       # mac + windows + linux

# Build a single platform
./tools/build.sh mac
./tools/build.sh windows
./tools/build.sh linux
./tools/build.sh android
./tools/build.sh ios
```

### Output locations

| Platform | Output |
|----------|--------|
| macOS    | `build/macos/Chronicles of the House of Osman.app` |
| Windows  | `build/windows/Chronicles_of_the_House_of_Osman.exe` |
| Linux    | `build/linux/Chronicles_of_the_House_of_Osman.x86_64` |
| Android  | `build/android/Chronicles_of_the_House_of_Osman.apk` (release-signed with auto-generated keystore) |
| iOS      | `build/ios/Chronicles_of_the_House_of_Osman.xcodeproj` (open in Xcode) |

## Mobile Export

The project is preconfigured for mobile (portrait orientation, `gl_compatibility` renderer, `canvas_items` stretch). To export manually from the editor instead of using the script:

1. Install Godot's **Export Templates** (Editor → Manage Export Templates).
2. For Android: configure the Android SDK in Editor Settings, then **Project → Export → Add preset → Android**.
3. For iOS: **Project → Export → Add preset → iOS** (requires macOS and Xcode).

Game Center / Play Games leaderboard submission activates automatically when the corresponding Godot plugin singleton is present in the build; otherwise the game runs fully offline with a local progress screen.

## Troubleshooting Builds

### "No export template found at the expected path"

The build script downloads and installs the correct Godot export templates automatically (from the official GitHub release) and flattens the `templates/` subfolder that the `.tpz` archive creates into the layout Godot expects (`<version>/ios.zip`, `<version>/android_release.apk`, etc.).

If you want to install them manually:

1. Open the Godot editor.
2. **Editor → Manage Export Templates**.
3. Click **Download and Install** for the version shown in the error message.
4. Re-run `./tools/build.sh`.

The templates are installed to `~/Library/Application Support/Godot/export_templates/<version>/` on macOS, `%APPDATA%\Godot\export_templates\<version>\` on Windows, and `~/.local/share/godot/export_templates/<version>/` on Linux.

### "Metal renderer require iOS 14+"

The iOS export preset already sets the minimum iOS version to 14.0. If you see this error after generating `export_presets.cfg` with an older version of the script, open `export_presets.cfg` and change:

```ini
application/min_ios_version="14.0"
```

under the `[preset.1.options]` (iOS) section.

### "cannot connect to daemon at tcp:5037: Connection refused"

This is the Android Debug Bridge (`adb`) daemon. The build script now starts `adb` automatically before invoking Godot when `adb` is on your `PATH`, so this message should no longer appear. If you still see it, make sure the Android SDK is configured or remove the Android preset from `export_presets.cfg`.

### iOS build after export

Godot does **not** produce a ready `.ipa`. The iOS preset is set to **Export Project Only**, so the script writes the Xcode project directly to `build/ios/`. To finish:

1. Open `build/ios/Chronicles_of_the_House_of_Osman.xcodeproj` in Xcode.
2. Select your Apple Developer Team under **Signing & Capabilities** (the preset uses a placeholder Team ID).
3. Choose a target device/simulator and build (`Cmd+B`) or archive (`Product → Archive`) to make an `.ipa`.

## Credits & Licenses

- **Sultan portraits**: downloaded from Wikipedia/Wikimedia Commons. Most are public-domain paintings/miniatures. See `assets/sultans/CREDITS.txt` for source URLs.
- **Music**: downloaded from Wikimedia Commons. See `assets/audio/CREDITS.txt` for source URLs and per-file licenses.
- **Historical data**: compiled from the project's game-design document and standard reference works.
