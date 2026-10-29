"""Applies VJ Fit settings to the Android/iOS folders that `flutter create` generates in CI.

- App name shown on the phone: "VJ Fit"
- Lets the app open YouTube/browser links (Android 11+ package visibility)
- Camera / photo library permission text for iOS
- VJ Fit signing key with v1+v2+v3 signatures, so a new APK installs over the old one
  without losing data. If the KEYSTORE_B64 secret is set, that key is used instead.
"""
import base64
import json
import os
import re
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent


def patch_android():
    manifest = ROOT / "android/app/src/main/AndroidManifest.xml"
    s = manifest.read_text()
    s = re.sub(r'android:label="[^"]*"', 'android:label="VJ Fit"', s, count=1)
    if 'android.intent.action.VIEW' not in s:
        q = (
            '    <queries>\n'
            '        <intent>\n'
            '            <action android:name="android.intent.action.VIEW" />\n'
            '            <data android:scheme="https" />\n'
            '        </intent>\n'
            '    </queries>\n'
        )
        s = s.replace('</manifest>', q + '</manifest>')
    manifest.write_text(s)
    print("Android manifest patched")


def patch_ios():
    plist = ROOT / "ios/Runner/Info.plist"
    if not plist.exists():
        return
    s = plist.read_text()
    s = re.sub(r'(<key>CFBundleDisplayName</key>\s*<string>)[^<]*(</string>)', r'\1VJ Fit\2', s)
    extra = ''
    if 'NSCameraUsageDescription' not in s:
        extra += '\t<key>NSCameraUsageDescription</key>\n\t<string>Take photos of your own exercises.</string>\n'
    if 'NSPhotoLibraryUsageDescription' not in s:
        extra += '\t<key>NSPhotoLibraryUsageDescription</key>\n\t<string>Add photos of your own exercises.</string>\n'
    if extra:
        idx = s.rfind('</dict>')
        s = s[:idx] + extra + s[idx:]
    plist.write_text(s)
    print("iOS Info.plist patched")


def patch_web():
    """Name and colours for the browser version (shown when added to the home screen)."""
    web = ROOT / "web"
    if not web.exists():
        return
    mf = web / "manifest.json"
    m = json.loads(mf.read_text())
    m.update({
        "name": "VJ Fit",
        "short_name": "VJ Fit",
        "description": "Workout plans, exercise library and vegetarian diet charts.",
        "start_url": ".",
        "display": "standalone",
        "orientation": "portrait",
        "background_color": "#1F5FBF",
        "theme_color": "#1F5FBF",
    })
    mf.write_text(json.dumps(m, indent=2))
    page = web / "index.html"
    s = page.read_text()
    s = re.sub(r"<title>[^<]*</title>", "<title>VJ Fit</title>", s)
    s = re.sub(r'(name="apple-mobile-web-app-title" content=")[^"]*"', r'\1VJ Fit"', s)
    s = re.sub(r'(name="description" content=")[^"]*"', r'\1Workout plans, exercise library and vegetarian diet charts."', s)
    if 'name="theme-color"' not in s:
        s = s.replace("</head>", '  <meta name="theme-color" content="#1F5FBF">\n</head>')
    if "apple-mobile-web-app-status-bar-style" not in s:
        s = s.replace("</head>", '  <meta name="apple-mobile-web-app-status-bar-style" content="black-translucent">\n</head>')
    page.write_text(s)
    print("Web manifest and page patched")


def install_key():
    """Signs release APKs with the VJ Fit key, using v1 + v2 + v3 signatures.

    Some phone brands (Vivo/iQOO, Oppo, Xiaomi) reject APKs signed with Android's
    generic debug certificate or with only the newer signature format.
    If the KEYSTORE_B64 secret is set, that keystore is used instead (same alias and password).
    """
    key = ROOT / "tool/vjfit-release.jks"
    b64 = os.environ.get("KEYSTORE_B64", "").strip()
    if b64:
        key = ROOT / "build-release.jks"
        key.write_bytes(base64.b64decode(b64))
        print("Signing key from KEYSTORE_B64 secret")
    gradle = ROOT / "android/app/build.gradle.kts"
    s = gradle.read_text()
    block = (
        '    signingConfigs {\n'
        '        create("vjfit") {\n'
        f'            storeFile = file("{key.as_posix()}")\n'
        '            storePassword = "vjfitapp"\n'
        '            keyAlias = "vjfit"\n'
        '            keyPassword = "vjfitapp"\n'
        '            enableV1Signing = true\n'
        '            enableV2Signing = true\n'
        '            enableV3Signing = true\n'
        '        }\n'
        '    }\n\n'
    )
    if 'create("vjfit")' not in s:
        i = s.index("    buildTypes {")
        s = s[:i] + block + s[i:]
    s, n = re.subn(r'signingConfig\s*=\s*signingConfigs\.getByName\("debug"\)',
                   'signingConfig = signingConfigs.getByName("vjfit")', s)
    if n == 0 and 'getByName("vjfit")' not in s:
        raise SystemExit("Could not find the release signingConfig line in build.gradle.kts")
    gradle.write_text(s)
    print("Release signing set to the VJ Fit key (v1+v2+v3)")


if __name__ == "__main__":
    import sys
    if "--web" in sys.argv:
        patch_web()
    else:
        patch_android()
        patch_ios()
        install_key()
