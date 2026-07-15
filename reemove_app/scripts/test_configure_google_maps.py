#!/usr/bin/env python3
"""Idempotency and secret-safety test for Google Maps native setup."""
from __future__ import annotations

import plistlib
import shutil
import subprocess
import tempfile
import xml.etree.ElementTree as ET
from pathlib import Path

ANDROID_NS = "http://schemas.android.com/apk/res/android"


def snapshot(root: Path) -> dict[str, bytes]:
    return {
        str(path.relative_to(root)): path.read_bytes()
        for path in root.rglob("*")
        if path.is_file()
    }


def main() -> None:
    source = Path(__file__).resolve().parents[1]
    with tempfile.TemporaryDirectory() as temp:
        root = Path(temp)
        (root / "scripts").mkdir()
        shutil.copy2(source / "scripts/configure_google_maps.py", root / "scripts/configure_google_maps.py")
        manifest = root / "android/app/src/main/AndroidManifest.xml"
        manifest.parent.mkdir(parents=True)
        manifest.write_text(
            f'<manifest xmlns:android="{ANDROID_NS}"><application android:label="ReeMove" /></manifest>',
            encoding="utf-8",
        )
        gradle = root / "android/app/build.gradle.kts"
        gradle.write_text("android {\n    defaultConfig {\n        applicationId = \"app.reemove\"\n    }\n}\n", encoding="utf-8")
        plist = root / "ios/Runner/Info.plist"
        plist.parent.mkdir(parents=True)
        with plist.open("wb") as target:
            plistlib.dump({"CFBundleDisplayName": "ReeMove"}, target)
        delegate = root / "ios/Runner/AppDelegate.swift"
        delegate.write_text(
            "import Flutter\nimport UIKit\n\n@main\nclass AppDelegate: FlutterAppDelegate {\n"
            "  override func application(_ application: UIApplication, didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?) -> Bool {\n"
            "    GeneratedPluginRegistrant.register(with: self)\n"
            "    return super.application(application, didFinishLaunchingWithOptions: launchOptions)\n  }\n}\n",
            encoding="utf-8",
        )
        flutter = root / "ios/Flutter"
        flutter.mkdir(parents=True)
        for name in ("Debug.xcconfig", "Release.xcconfig", "Profile.xcconfig"):
            (flutter / name).write_text('#include "Generated.xcconfig"\n', encoding="utf-8")
        (root / ".gitignore").write_text(".dart_tool/\n", encoding="utf-8")

        command = ["python3", str(root / "scripts/configure_google_maps.py")]
        subprocess.run(command, cwd=root, check=True, capture_output=True, text=True)
        first = snapshot(root)
        subprocess.run(command, cwd=root, check=True, capture_output=True, text=True)
        second = snapshot(root)
        if first != second:
            raise AssertionError("Google Maps configurator is not idempotent.")

        tree = ET.parse(manifest)
        nodes = tree.getroot().findall(".//meta-data")
        name = f"{{{ANDROID_NS}}}name"
        value = f"{{{ANDROID_NS}}}value"
        matches = [item for item in nodes if item.attrib.get(name) == "com.google.android.geo.API_KEY"]
        if len(matches) != 1 or matches[0].attrib.get(value) != "${MAPS_API_KEY}":
            raise AssertionError("Android Maps metadata was not configured safely.")
        if gradle.read_text(encoding="utf-8").count('manifestPlaceholders["MAPS_API_KEY"]') != 1:
            raise AssertionError("Android manifest placeholder is missing or duplicated.")
        with plist.open("rb") as source_plist:
            info = plistlib.load(source_plist)
        if info.get("MAPS_API_KEY") != "$(MAPS_API_KEY)":
            raise AssertionError("iOS Info.plist key substitution is missing.")
        if delegate.read_text(encoding="utf-8").count("GMSServices.provideAPIKey") != 1:
            raise AssertionError("iOS Maps registration is missing or duplicated.")
        if "YOUR_IOS_GOOGLE_MAPS_API_KEY" not in (flutter / "Maps.xcconfig.example").read_text(encoding="utf-8"):
            raise AssertionError("Safe iOS example key file is missing.")

    print("Google Maps configurator idempotency test passed.")


if __name__ == "__main__":
    main()
