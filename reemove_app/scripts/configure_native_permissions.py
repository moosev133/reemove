#!/usr/bin/env python3
"""Apply ReeMove Phase 4 native permission declarations idempotently.

Run after `flutter create` has generated android/ and ios/.
"""
from __future__ import annotations

import plistlib
import xml.etree.ElementTree as ET
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
ANDROID_NS = "http://schemas.android.com/apk/res/android"
ET.register_namespace("android", ANDROID_NS)


def configure_android() -> None:
    manifest = ROOT / "android/app/src/main/AndroidManifest.xml"
    if not manifest.exists():
        print("Android manifest not present; skipped.")
        return

    tree = ET.parse(manifest)
    root = tree.getroot()
    name_attr = f"{{{ANDROID_NS}}}name"
    required = (
        "android.permission.ACCESS_COARSE_LOCATION",
        "android.permission.ACCESS_FINE_LOCATION",
        "android.permission.POST_NOTIFICATIONS",
    )
    existing = {
        node.attrib.get(name_attr)
        for node in root.findall("uses-permission")
    }
    application = root.find("application")
    insert_at = list(root).index(application) if application is not None else 0
    for permission in required:
        if permission not in existing:
            node = ET.Element("uses-permission", {name_attr: permission})
            root.insert(insert_at, node)
            insert_at += 1

    if hasattr(ET, "indent"):
        ET.indent(tree, space="    ")
    tree.write(manifest, encoding="utf-8", xml_declaration=True)
    print(f"Configured {manifest.relative_to(ROOT)}")


def configure_ios_plist() -> None:
    plist_path = ROOT / "ios/Runner/Info.plist"
    if not plist_path.exists():
        print("iOS Info.plist not present; skipped.")
        return

    with plist_path.open("rb") as source:
        data = plistlib.load(source)
    data.setdefault(
        "NSCameraUsageDescription",
        "ReeMove uses the camera when you choose to take a profile photo.",
    )
    data.setdefault(
        "NSPhotoLibraryUsageDescription",
        "ReeMove lets you select a profile photo from your library.",
    )
    data.setdefault(
        "NSLocationWhenInUseUsageDescription",
        "ReeMove uses your location to show nearby sports people, places, and events.",
    )
    with plist_path.open("wb") as target:
        plistlib.dump(data, target, sort_keys=False)
    print(f"Configured {plist_path.relative_to(ROOT)}")


def configure_ios_podfile() -> None:
    podfile = ROOT / "ios/Podfile"
    if not podfile.exists():
        print("iOS Podfile not present; skipped.")
        return

    text = podfile.read_text(encoding="utf-8")
    marker = "BYPASS_PERMISSION_LOCATION_ALWAYS=1"
    if marker in text:
        print(f"Already configured {podfile.relative_to(ROOT)}")
        return

    anchor = "    flutter_additional_ios_build_settings(target)"
    addition = """
    target.build_configurations.each do |config|
      config.build_settings['GCC_PREPROCESSOR_DEFINITIONS'] ||= [
        '$(inherited)',
        'BYPASS_PERMISSION_LOCATION_ALWAYS=1',
      ]
    end"""
    if anchor not in text:
        raise RuntimeError(
            "Could not locate Flutter's post_install target settings in ios/Podfile.",
        )
    podfile.write_text(text.replace(anchor, anchor + addition, 1), encoding="utf-8")
    print(f"Configured {podfile.relative_to(ROOT)}")


if __name__ == "__main__":
    configure_android()
    configure_ios_plist()
    configure_ios_podfile()
