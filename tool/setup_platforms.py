"""Applies VJ Fit settings to the Android/iOS folders that `flutter create` generates in CI.

- App name shown on the phone: "VJ Fit"
- Lets the app open YouTube/browser links (Android 11+ package visibility)
- Camera / photo library permission text for iOS
- Fixed signing key, so a new APK installs over the old one without losing data.
  If the KEYSTORE_B64 environment variable is set (a GitHub secret), that key is used instead.
"""
import base64
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
    patch_android()
    patch_ios()
    install_key()
