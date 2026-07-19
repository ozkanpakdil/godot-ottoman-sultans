#!/usr/bin/env bash
set -euo pipefail

# Build script for Chronicles of the House of Osman.
# Exports the Godot project to iOS, Android, macOS, Windows and/or Linux.
#
# Usage:
#   ./tools/build.sh ios android mac windows linux
#   ./tools/build.sh all              # build every platform
#   ./tools/build.sh desktop          # build mac + windows + linux
#   ./tools/build.sh mobile           # build ios + android
#   ./tools/build.sh --install-templates
#                                     # download & install missing export templates
#
# Requirements:
#   - Godot 4.x on PATH or at /Applications/Godot.app (macOS)
#   - Export presets (this script creates basic ones if missing)
#   - Export templates (this script checks for them and can install them)
#   - Android: Android SDK + debug keystore (auto-generated if missing)
#   - iOS:     macOS + Xcode to compile the exported Xcode project
#   - Desktop: no extra tooling required

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"
BUILD_DIR="$PROJECT_DIR/build"
PRESETS_FILE="$PROJECT_DIR/export_presets.cfg"

mkdir -p "$BUILD_DIR"

# -----------------------------------------------------------------------------
# Locate Godot
# -----------------------------------------------------------------------------
find_godot() {
    if command -v godot &>/dev/null; then
        echo "godot"
        return
    fi
    local candidates=(
        "/Applications/Godot.app/Contents/MacOS/Godot"
        "$HOME/Applications/Godot.app/Contents/MacOS/Godot"
        "/Applications/Godot 4.app/Contents/MacOS/Godot"
        "$HOME/Applications/Godot 4.app/Contents/MacOS/Godot"
        "/usr/local/bin/godot"
        "/opt/homebrew/bin/godot"
    )
    for c in "${candidates[@]}"; do
        if [ -x "$c" ]; then
            echo "$c"
            return
        fi
    done
    echo "ERROR: Godot binary not found. Add it to PATH or install it." >&2
    exit 1
}

GODOT="$(find_godot)"
echo "Using Godot: $GODOT"

# -----------------------------------------------------------------------------
# Godot version & export templates
# -----------------------------------------------------------------------------
get_godot_version() {
    "$GODOT" --version | head -n1 | sed -E 's/\.official\..*//;s/\.custom\..*//'
}

get_templates_dir() {
    local os
    os="$(uname -s)"
    case "$os" in
        Darwin) echo "$HOME/Library/Application Support/Godot/export_templates" ;;
        Linux)  echo "$HOME/.local/share/godot/export_templates" ;;
        MINGW*|MSYS*|CYGWIN*) echo "$HOME/AppData/Roaming/Godot/export_templates" ;;
        *) echo "$HOME/.local/share/godot/export_templates" ;;
    esac
}

GODOT_VERSION="$(get_godot_version)"
TEMPLATES_DIR="$(get_templates_dir)"
VERSION_DIR="$TEMPLATES_DIR/$GODOT_VERSION"

print_template_help() {
    cat >&2 <<EOF

Godot export templates are missing.
Expected directory: $VERSION_DIR

The script will now download and install them automatically.
If you prefer to install manually, cancel (Ctrl+C) and use the Godot editor:
   Editor → Manage Export Templates → Download and Install
   (choose version $GODOT_VERSION)

EOF
}

check_templates() {
    # Godot expects platform zips directly under the version directory (e.g. .../4.7.1.stable/ios.zip).
    if [ ! -f "$VERSION_DIR/ios.zip" ] && [ ! -f "$VERSION_DIR/version.txt" ]; then
        print_template_help
        install_templates
    fi

    # Fix older/mis-extracted layouts where the files ended up in a `templates/` subfolder.
    if [ -d "$VERSION_DIR/templates" ]; then
        echo "Flattening template directory layout ..."
        mv "$VERSION_DIR/templates/"* "$VERSION_DIR/" || true
        rmdir "$VERSION_DIR/templates" 2>/dev/null || true
    fi
}

install_templates() {
    if [ -d "$VERSION_DIR" ] && [ -f "$VERSION_DIR/version.txt" ]; then
        echo "Export templates already installed at $VERSION_DIR"
        return
    fi

    local url_version
    if [[ "$GODOT_VERSION" == *".stable" ]]; then
        url_version="${GODOT_VERSION%.stable}-stable"
    elif [[ "$GODOT_VERSION" == *".dev" ]]; then
        url_version="${GODOT_VERSION%.dev}-dev1"
    elif [[ "$GODOT_VERSION" == *".beta" ]]; then
        url_version="${GODOT_VERSION%.beta}-beta1"
    elif [[ "$GODOT_VERSION" == *".rc" ]]; then
        url_version="${GODOT_VERSION%.rc}-rc1"
    else
        url_version="$GODOT_VERSION-stable"
    fi

    local tpz_url="https://github.com/godotengine/godot/releases/download/${url_version}/Godot_v${url_version}_export_templates.tpz"
    local tmp_file="/tmp/godot_export_templates_${url_version}.tpz"

    echo "Downloading export templates for Godot $GODOT_VERSION..."
    echo "URL: $tpz_url"

    if ! command -v curl &>/dev/null; then
        echo "ERROR: curl is required to download templates." >&2
        exit 1
    fi

    if ! curl -L -f --max-time 600 -o "$tmp_file" "$tpz_url"; then
        echo "ERROR: Failed to download templates from GitHub." >&2
        echo "Please install them manually: Editor → Manage Export Templates" >&2
        exit 1
    fi

    if [ ! -s "$tmp_file" ]; then
        echo "ERROR: Downloaded template file is empty." >&2
        exit 1
    fi

    echo "Installing templates to $VERSION_DIR ..."
    mkdir -p "$VERSION_DIR"
    unzip -q -o "$tmp_file" -d "$VERSION_DIR"

    # The .tpz contains a top-level `templates/` folder; Godot needs the platform files directly
    # under the version directory, so flatten the layout automatically.
    if [ -d "$VERSION_DIR/templates" ]; then
        mv "$VERSION_DIR/templates/"* "$VERSION_DIR/" || true
        rmdir "$VERSION_DIR/templates" 2>/dev/null || true
    fi

    rm -f "$tmp_file"
    echo "Export templates installed."
}

# -----------------------------------------------------------------------------
# Ensure export presets exist
# -----------------------------------------------------------------------------
generate_android_keystore() {
    local keystore_path="$1"
    local alias="$2"
    local dname="$3"
    if [ ! -f "$keystore_path" ]; then
        if ! command -v keytool &>/dev/null; then
            echo "WARNING: keytool not found; skipping keystore generation for $keystore_path" >&2
            return 1
        fi
        echo "Generating Android keystore: $keystore_path"
        keytool -genkey -v \
            -keystore "$keystore_path" \
            -alias "$alias" \
            -keyalg RSA -keysize 2048 -validity 10000 \
            -storepass android -keypass android \
            -dname "$dname" 2>/dev/null || true
    fi
}

generate_presets() {
    echo "No export_presets.cfg found. Creating a basic one..."
    local android_debug_keystore="$SCRIPT_DIR/debug.keystore"
    local android_release_keystore="$SCRIPT_DIR/release.keystore"
    generate_android_keystore "$android_debug_keystore" "androiddebugkey" "CN=Android Debug,O=Android,C=US"
    generate_android_keystore "$android_release_keystore" "androidreleasekey" "CN=Android Release,O=Android,C=US"

    cat > "$PRESETS_FILE" <<EOF
[preset.0]

name="Android"
platform="Android"
runnable=true
advanced_options=false
dedicated_server=false
custom_features=""
export_filter="all_resources"
include_filter=""
exclude_filter="build/*"
export_path="build/android/Chronicles_of_the_House_of_Osman.apk"
encryption_include_filters=""
encryption_exclude_filters=""
encrypt_pck=false
encrypt_directory=false
script_export_mode=2
script_encryption_key=""

[preset.0.options]

custom_template/debug=""
custom_template/release=""
gradle_build/use_gradle_build=false
gradle_build/export_format=0
gradle_build/min_sdk=""
gradle_build/target_sdk=""
architectures/armeabi-v7a=false
architectures/arm64-v8a=true
architectures/x86=false
architectures/x86_64=false
keystore/debug="$android_debug_keystore"
keystore/debug_user="androiddebugkey"
keystore/debug_password="android"
keystore/release="$android_release_keystore"
keystore/release_user="androidreleasekey"
keystore/release_password="android"
version/code=1
version/name="1.0"
package/unique_name="com.ottoman.timeline"
package/name="Chronicles of the House of Osman"
package/signature=""
package/app_category=8
package/retain_data_on_uninstall=false
package/exclude_from_recents=false
package/show_in_android_tv=false
package/show_in_app_library=false
launcher_icons/main_192x192=""
launcher_icons/adaptive_foreground_432x432=""
launcher_icons/adaptive_background_432x432=""
graphics/opengl_debug=false
xr_features/xr_mode=0
screen/immersive_navigation=true
screen/maximize=false
screen/keep_screen_on=true
screen/orientation=0
screen/support_small=true
screen/support_normal=true
screen/support_large=true
screen/support_xlarge=true
user_data_backup/allow=false
debug_logging/logcat=false
command_line/extra_args=""
apk_expansion/enable=false
apk_expansion/SALT=""
apk_expansion/public_key=""
permissions/custom_permissions=PoolStringArray(  )
permissions/access_checkin_properties=false
permissions/access_coarse_location=false
permissions/access_fine_location=false
permissions/access_location_extra_commands=false
permissions/access_mock_location=false
permissions/access_network_state=false
permissions/access_surface_flinger=false
permissions/access_wifi_state=false
permissions/account_manager=false
permissions/add_voicemail=false
permissions/authenticate_accounts=false
permissions/battery_stats=false
permissions/bind_accessibility_service=false
permissions/bind_appwidget=false
permissions/bind_device_admin=false
permissions/bind_input_method=false
permissions/bind_nfc_service=false
permissions/bind_notification_listener_service=false
permissions/bind_print_service=false
permissions/bind_remoteviews=false
permissions/bind_text_service=false
permissions/bind_vpn_service=false
permissions/bind_wallpaper=false
permissions/bluetooth=false
permissions/bluetooth_admin=false
permissions/bluetooth_privileged=false
permissions/brick=false
permissions/broadcast_package_removed=false
permissions/broadcast_sms=false
permissions/broadcast_sticky=false
permissions/broadcast_wap_push=false
permissions/call_phone=false
permissions/call_privileged=false
permissions/camera=false
permissions/capture_audio_output=false
permissions/capture_secure_video_output=false
permissions/capture_video_output=false
permissions/change_component_enabled_state=false
permissions/change_configuration=false
permissions/change_network_state=false
permissions/change_wifi_multicast_state=false
permissions/change_wifi_state=false
permissions/clear_app_cache=false
permissions/clear_app_user_data=false
permissions/control_location_updates=false
permissions/delete_cache_files=false
permissions/delete_packages=false
permissions/device_power=false
permissions/diagnostic=false
permissions/disable_keyguard=false
permissions/dump=false
permissions/expand_status_bar=false
permissions/factory_test=false
permissions/flashlight=false
permissions/force_back=false
permissions/get_accounts=false
permissions/get_package_size=false
permissions/get_tasks=false
permissions/get_top_activity_info=false
permissions/global_search=false
permissions/hardware_test=false
permissions/inject_events=false
permissions/install_location_provider=false
permissions/install_packages=false
permissions/install_shortcut=false
permissions/internal_system_window=false
permissions/internet=false
permissions/kill_background_processes=false
permissions/location_hardware=false
permissions/manage_accounts=false
permissions/manage_app_tokens=false
permissions/manage_documents=false
permissions/manage_external_storage=false
permissions/master_clear=false
permissions/media_content_control=false
permissions/modify_audio_settings=false
permissions/modify_phone_state=false
permissions/mount_format_filesystems=false
permissions/mount_unmount_filesystems=false
permissions/nfc=false
permissions/persistent_activity=false
permissions/post_notifications=false
permissions/process_outgoing_calls=false
permissions/read_calendar=false
permissions/read_call_log=false
permissions/read_contacts=false
permissions/read_external_storage=false
permissions/read_frame_buffer=false
permissions/read_history_bookmarks=false
permissions/read_input_state=false
permissions/read_logs=false
permissions/read_phone_state=false
permissions/read_profile=false
permissions/read_sms=false
permissions/read_sync_settings=false
permissions/read_sync_stats=false
permissions/read_voicemail=false
permissions/reboot=false
permissions/receive_boot_completed=false
permissions/receive_mms=false
permissions/receive_sms=false
permissions/receive_wap_push=false
permissions/record_audio=false
permissions/reorder_tasks=false
permissions/restart_packages=false
permissions/send_respond_via_message=false
permissions/send_sms=false
permissions/set_activity_watcher=false
permissions/set_alarm=false
permissions/set_always_finish=false
permissions/set_animation_scale=false
permissions/set_debug_app=false
permissions/set_orientation=false
permissions/set_pointer_speed=false
permissions/set_preferred_applications=false
permissions/set_process_limit=false
permissions/set_time=false
permissions/set_time_zone=false
permissions/set_wallpaper=false
permissions/set_wallpaper_hints=false
permissions/signal_persistent_processes=false
permissions/status_bar=false
permissions/subscribed_feeds_read=false
permissions/subscribed_feeds_write=false
permissions/system_alert_window=false
permissions/transmit_ir=false
permissions/uninstall_shortcut=false
permissions/update_device_stats=false
permissions/use_credentials=false
permissions/use_sip=false
permissions/vibrate=false
permissions/wake_lock=false
permissions/write_apn_settings=false
permissions/write_calendar=false
permissions/write_call_log=false
permissions/write_contacts=false
permissions/write_external_storage=false
permissions/write_gservices=false
permissions/write_history_bookmarks=false
permissions/write_profile=false
permissions/write_secure_settings=false
permissions/write_settings=false
permissions/write_sms=false
permissions/write_sync_settings=false
permissions/write_voicemail=false

[preset.1]

name="iOS"
platform="iOS"
runnable=true
advanced_options=false
dedicated_server=false
custom_features=""
export_filter="all_resources"
include_filter=""
exclude_filter="build/*"
export_path="build/ios/Chronicles_of_the_House_of_Osman.zip"
encryption_include_filters=""
encryption_exclude_filters=""
encrypt_pck=false
encrypt_directory=false
script_export_mode=2
script_encryption_key=""

[preset.1.options]

custom_template/debug=""
custom_template/release=""
architectures/arm64=true
architectures/x86_64=false
application/app_store_team_id="0000000000"
application/provisioning_profile_uuid_debug=""
application/provisioning_profile_uuid_release=""
application/export_method_debug=1
application/export_method_release=0
application/targeted_device_family=2
application/min_ios_version="14.0"
application/bundle_identifier="com.ottoman.timeline"
application/icons/iphone_120x120=""
application/icons/iphone_180x180=""
application/icons/ipad_76x76=""
application/icons/ipad_152x152=""
application/icons/app_store_1024x1024=""
application/icons/spotlight_40x40=""
application/icons/spotlight_80x80=""
application/storyboard/use_launch_screen_storyboard=true
application/storyboard/image_scale_mode=0
application/storyboard/custom_image@2x=""
application/storyboard/custom_image@3x=""
application/storyboard/use_custom_bg_color=false
application/storyboard/custom_bg_color=Color(0, 0, 0, 1)
application/icon_interpolation=4
application/launch_screens_interpolation=4
application/export_project_only=true
plugins=PoolStringArray(  )

[preset.2]

name="macOS"
platform="macOS"
runnable=true
advanced_options=false
dedicated_server=false
custom_features=""
export_filter="all_resources"
include_filter=""
exclude_filter="build/*"
export_path="build/macos/Chronicles_of_the_House_of_Osman.zip"
encryption_include_filters=""
encryption_exclude_filters=""
encrypt_pck=false
encrypt_directory=false
script_export_mode=2
script_encryption_key=""

[preset.2.options]

custom_template/debug=""
custom_template/release=""
debug/export_console_script=1
application/icon="res://assets/UI/icon.svg"
application/icon_interpolation=4
application/bundle_identifier="com.ottoman.timeline"
application/signature=""
application/app_category="Games"
application/short_version="1.0"
application/version="1.0"
application/copyright=""
application/copyright_localized={}
display/high_res=true
codesign/codesign=0
codesign/identity=""
codesign/certificate_file=""
codesign/certificate_password=""
codesign/entitlements/custom_file=""
codesign/entitlements/allow_jit_code=false
codesign/entitlements/allow_unsigned_executable_memory=false
codesign/entitlements/allow_dyld_environment_variables=false
codesign/entitlements/disable_library_validation=false
codesign/entitlements/audio_input=false
codesign/entitlements/camera=false
codesign/entitlements/location=false
codesign/entitlements/address_book=false
codesign/entitlements/calendar=false
codesign/entitlements/photos_library=false
codesign/entitlements/apple_events=false
codesign/entitlements/debugging=false
codesign/entitlements/app_sandbox/enabled=false
codesign/entitlements/app_sandbox/network_server=false
codesign/entitlements/app_sandbox/network_client=false
codesign/entitlements/app_sandbox/device_usb=false
codesign/entitlements/app_sandbox/device_bluetooth=false
notarization/notarization=0
texture_format/s3tc=true
texture_format/etc=false
texture_format/etc2=false

[preset.3]

name="Windows"
platform="Windows Desktop"
runnable=true
advanced_options=false
dedicated_server=false
custom_features=""
export_filter="all_resources"
include_filter=""
exclude_filter="build/*"
export_path="build/windows/Chronicles_of_the_House_of_Osman.exe"
encryption_include_filters=""
encryption_exclude_filters=""
encrypt_pck=false
encrypt_directory=false
script_export_mode=2
script_encryption_key=""

[preset.3.options]

custom_template/debug=""
custom_template/release=""
debug/export_console_wrapper=1
binary_format/architecture="x86_64"
texture_format/bptc=true
texture_format/s3tc=true
texture_format/etc=false
texture_format/etc2=false
codesign/enable=false
codesign/identity_type=0
codesign/identity=""
codesign/password=""
codesign/timestamp=true
codesign/timestamp_server_url=""
codesign/digest_algorithm=1
codesign/description=""
codesign/custom_options=PoolStringArray(  )
application/modify_resources=false
application/icon="res://assets/UI/icon.svg"
application/console_wrapper_icon="res://assets/UI/icon.svg"
application/icon_interpolation=4
application/file_version=""
application/product_version=""
application/company_name=""
application/product_name="Chronicles of the House of Osman"
application/file_description=""
application/copyright=""
application/trademarks=""

[preset.4]

name="Linux"
platform="Linux"
runnable=true
advanced_options=false
dedicated_server=false
custom_features=""
export_filter="all_resources"
include_filter=""
exclude_filter="build/*"
export_path="build/linux/Chronicles_of_the_House_of_Osman.x86_64"
encryption_include_filters=""
encryption_exclude_filters=""
encrypt_pck=false
encrypt_directory=false
script_export_mode=2
script_encryption_key=""

[preset.4.options]

custom_template/debug=""
custom_template/release=""
debug/export_console_wrapper=1
binary_format/architecture="x86_64"
texture_format/bptc=true
texture_format/s3tc=true
texture_format/etc=false
texture_format/etc2=false
EOF

    echo "Created $PRESETS_FILE"
    echo "NOTE: Review mobile settings (Android SDK, iOS signing) in the Godot editor before shipping."
}

fix_ios_preset() {
    if [ -f "$PRESETS_FILE" ]; then
        if grep -q 'application/min_ios_version="12.0"' "$PRESETS_FILE"; then
            echo "Fixing iOS minimum version to 14.0 (required by Metal renderer)..."
            sed -i.bak 's/application\/min_ios_version="12.0"/application\/min_ios_version="14.0"/' "$PRESETS_FILE"
            rm -f "$PRESETS_FILE.bak"
        fi
    fi
}

ensure_android_keystores() {
    local android_debug_keystore="$SCRIPT_DIR/debug.keystore"
    local android_release_keystore="$SCRIPT_DIR/release.keystore"
    generate_android_keystore "$android_debug_keystore" "androiddebugkey" "CN=Android Debug,O=Android,C=US"
    generate_android_keystore "$android_release_keystore" "androidreleasekey" "CN=Android Release,O=Android,C=US"

    if [ -f "$PRESETS_FILE" ]; then
        # Always rewrite keystore paths so the preset matches the keys generated
        # on this machine/CI runner, regardless of any absolute paths committed in git.
        if [ -f "$android_debug_keystore" ]; then
            sed -i.bak "s#^keystore/debug=\".*\"#keystore/debug=\"$android_debug_keystore\"#" "$PRESETS_FILE"
            sed -i.bak 's/^keystore\/debug_user=".*"/keystore\/debug_user="androiddebugkey"/' "$PRESETS_FILE"
            sed -i.bak 's/^keystore\/debug_password=".*"/keystore\/debug_password="android"/' "$PRESETS_FILE"
        fi
        if [ -f "$android_release_keystore" ]; then
            sed -i.bak "s#^keystore/release=\".*\"#keystore/release=\"$android_release_keystore\"#" "$PRESETS_FILE"
            sed -i.bak 's/^keystore\/release_user=".*"/keystore\/release_user="androidreleasekey"/' "$PRESETS_FILE"
            sed -i.bak 's/^keystore\/release_password=".*"/keystore\/release_password="android"/' "$PRESETS_FILE"
        fi
        rm -f "$PRESETS_FILE.bak"
    fi
}

if [ ! -f "$PRESETS_FILE" ]; then
    generate_presets
fi
fix_ios_preset
ensure_android_keystores

# -----------------------------------------------------------------------------
# Export helpers
# -----------------------------------------------------------------------------
export_platform() {
    local preset="$1"
    local out_path="$2"
    local mode="${3:-release}"
    local out_dir
    out_dir="$(dirname "$out_path")"
    # Wipe the previous output so Godot does not try to pack old build artifacts
    # (e.g. a previous iOS Xcode project) into the new export.
    rm -rf "$out_dir"
    mkdir -p "$out_dir"
    # Keep the Android Debug Bridge daemon warm so Godot doesn't print a
    # harmless "cannot connect to daemon" warning during unrelated exports.
    if command -v adb &>/dev/null; then
        adb start-server >/dev/null 2>&1 || true
    fi

    echo ""
    echo "==> Exporting $preset ($mode) ..."
    if [ "$mode" == "debug" ]; then
        "$GODOT" --headless --path "$PROJECT_DIR" --export-debug "$preset" "$out_path"
    else
        "$GODOT" --headless --path "$PROJECT_DIR" --export-release "$preset" "$out_path"
    fi
}

build_ios() {
    # With application/export_project_only=true Godot writes the Xcode project directly
    # to the export_path directory, not a zip.
    export_platform "iOS" "build/ios/Chronicles_of_the_House_of_Osman"
    echo "iOS Xcode project ready at: $BUILD_DIR/ios/Chronicles_of_the_House_of_Osman.xcodeproj"
    echo "Open it in Xcode, set your real Team ID / bundle identifier / signing, and build/archive."
}

build_android() {
    export_platform "Android" "build/android/Chronicles_of_the_House_of_Osman.apk"
    echo "Android release APK ready at: $BUILD_DIR/android/Chronicles_of_the_House_of_Osman.apk"
}

build_mac() {
    export_platform "macOS" "build/macos/Chronicles_of_the_House_of_Osman.zip"
    echo "Unzipping macOS app..."
    rm -rf "$BUILD_DIR/macos/Chronicles of the House of Osman.app"
    unzip -q -o "$BUILD_DIR/macos/Chronicles_of_the_House_of_Osman.zip" -d "$BUILD_DIR/macos"
    echo "macOS app ready at: $BUILD_DIR/macos/"
}

build_windows() {
    export_platform "Windows" "build/windows/Chronicles_of_the_House_of_Osman.exe"
    echo "Windows executable ready at: $BUILD_DIR/windows/Chronicles_of_the_House_of_Osman.exe"
}

build_linux() {
    export_platform "Linux" "build/linux/Chronicles_of_the_House_of_Osman.x86_64"
    chmod +x "$BUILD_DIR/linux/Chronicles_of_the_House_of_Osman.x86_64"
    echo "Linux executable ready at: $BUILD_DIR/linux/Chronicles_of_the_House_of_Osman.x86_64"
}

# -----------------------------------------------------------------------------
# Argument parsing
# -----------------------------------------------------------------------------
if [ $# -eq 0 ]; then
    echo "Usage: $0 [ios|android|mac|windows|linux|mobile|desktop|all]..." >&2
    echo "       $0 --install-templates" >&2
    exit 1
fi

# Handle template install flag first
if [ "$1" == "--install-templates" ]; then
    install_templates
    exit 0
fi

# For actual builds, make sure templates are present
check_templates

# Silence the harmless "cannot connect to daemon" message from the Android Debug Bridge
# when adb is installed but not yet running (Godot may probe it during any export).
if command -v adb &>/dev/null; then
    adb start-server >/dev/null 2>&1 || true
fi

for arg in "$@"; do
    case "$arg" in
        ios) build_ios ;;
        android) build_android ;;
        mac|macos) build_mac ;;
        windows|win) build_windows ;;
        linux) build_linux ;;
        mobile) build_android; build_ios ;;
        desktop) build_mac; build_windows; build_linux ;;
        all) build_android; build_ios; build_mac; build_windows; build_linux ;;
        *)
            echo "Unknown target: $arg" >&2
            echo "Valid targets: ios, android, mac, windows, linux, mobile, desktop, all" >&2
            exit 1
            ;;
    esac
done

echo ""
echo "Build outputs are in: $BUILD_DIR"
