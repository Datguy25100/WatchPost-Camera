#!/usr/bin/env python3
"""
Run ONCE, right after `flutter create ...` (from the project root):

    python tool/setup_platforms.py

It patches the generated platform files so the app works in RELEASE builds too:
  Android: INTERNET permission (without it the release APK cannot reach n8n)
           + text-to-speech visibility (so the app can speak alerts)
           + plain-http for the live view, + app name "WatchPost"
  iOS:     camera / photo-library usage texts (needed by the People photo picker)
           + local-network access for the live view
Safe to run more than once.
"""
import os
import re
import sys

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
MANIFEST = os.path.join(ROOT, "android", "app", "src", "main", "AndroidManifest.xml")
PLIST = os.path.join(ROOT, "ios", "Runner", "Info.plist")


def patch_manifest():
    if not os.path.isfile(MANIFEST):
        print("! android/ not found - run `flutter create` first (skipping Android)")
        return
    s = open(MANIFEST, encoding="utf-8").read()
    changed = False
    if "android.permission.INTERNET" not in s:
        s = re.sub(r"(<manifest[^>]*>)", r'\1\n    <uses-permission android:name="android.permission.INTERNET"/>', s, count=1)
        changed = True
    if "android.intent.action.TTS_SERVICE" not in s:
        q = ('    <queries>\n        <intent>\n'
             '            <action android:name="android.intent.action.TTS_SERVICE"/>\n'
             '        </intent>\n    </queries>\n')
        if "<queries>" in s:  # merge into the existing block
            s = s.replace("<queries>", "<queries>\n        <intent>\n"
                          '            <action android:name="android.intent.action.TTS_SERVICE"/>\n'
                          "        </intent>", 1)
        else:
            s = s.replace("<application", q + "    <application", 1)
        changed = True
    # Live view loads http://<camera-ip>/shot.jpg (plain http on the home network).
    # Android 9+ blocks plain http unless this is set. The n8n API itself is https.
    if "usesCleartextTraffic" not in s:
        s = s.replace("<application", '<application\n        android:usesCleartextTraffic="true"', 1)
        changed = True
    # Launcher name: "WatchPost" instead of "watchpost"
    if 'android:label="watchpost"' in s:
        s = s.replace('android:label="watchpost"', 'android:label="WatchPost"')
        changed = True
    if changed:
        open(MANIFEST, "w", encoding="utf-8").write(s)
        print("+ patched AndroidManifest.xml")
    else:
        print("= AndroidManifest.xml already OK")


def patch_plist():
    if not os.path.isfile(PLIST):
        print("= ios/ not found (skipping iOS)")
        return
    s = open(PLIST, encoding="utf-8").read()
    add = ""
    if "NSCameraUsageDescription" not in s:
        add += ("\t<key>NSCameraUsageDescription</key>\n"
                "\t<string>WatchPost uses the camera so you can take a photo of a person to recognise.</string>\n")
    if "NSPhotoLibraryUsageDescription" not in s:
        add += ("\t<key>NSPhotoLibraryUsageDescription</key>\n"
                "\t<string>WatchPost needs your photos so you can pick pictures of people to recognise.</string>\n")
    if "NSAppTransportSecurity" not in s:   # allow http://192.168.x.x live view
        add += ("\t<key>NSAppTransportSecurity</key>\n\t<dict>\n"
                "\t\t<key>NSAllowsLocalNetworking</key>\n\t\t<true/>\n\t</dict>\n")
    if "NSLocalNetworkUsageDescription" not in s:
        add += ("\t<key>NSLocalNetworkUsageDescription</key>\n"
                "\t<string>WatchPost shows the live picture of your camera on your home network.</string>\n")
    if add:
        i = s.rfind("</dict>")
        s = s[:i] + add + s[i:]
        open(PLIST, "w", encoding="utf-8").write(s)
        print("+ patched Info.plist")
    else:
        print("= Info.plist already OK")


if __name__ == "__main__":
    patch_manifest()
    patch_plist()
    print("done.")
