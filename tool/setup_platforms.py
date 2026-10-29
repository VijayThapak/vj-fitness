"""Applies VJ Fit settings to the Android/iOS folders that `flutter create` generates in CI.

- App name shown on the phone: "VJ Fit"
- Lets the app open YouTube/browser links (Android 11+ package visibility)
- Camera / photo library permission text for iOS
- Fixed signing key, so a new APK installs over the old one without losing data.
  If the KEYSTORE_B64 environment variable is set (a GitHub secret), that key is used instead.
"""
import base64
import json
import os
import re
import shutil
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
    dest = Path.home() / ".android" / "debug.keystore"
    dest.parent.mkdir(parents=True, exist_ok=True)
    b64 = os.environ.get("KEYSTORE_B64", "").strip()
    if b64:
        dest.write_bytes(base64.b64decode(b64))
        print("Signing key installed from KEYSTORE_B64 secret")
    else:
        shutil.copy(ROOT / "tool/vjfit.keystore", dest)
        print("Signing key installed from tool/vjfit.keystore")


if __name__ == "__main__":
    import sys
    if "--web" in sys.argv:
        patch_web()
    else:
        patch_android()
        patch_ios()
        install_key()
