#!/usr/bin/env python3
"""Fast idempotency test for the native deep-link patcher."""
from __future__ import annotations

import plistlib
import shutil
import subprocess
import tempfile
import xml.etree.ElementTree as ET
from pathlib import Path

ANDROID_NS = "http://schemas.android.com/apk/res/android"


def main() -> None:
    source_root = Path(__file__).resolve().parents[1]
    with tempfile.TemporaryDirectory() as temp_dir:
        root = Path(temp_dir)
        script_dir = root / "scripts"
        script_dir.mkdir(parents=True)
        shutil.copy2(
            source_root / "scripts/configure_deep_links.py",
            script_dir / "configure_deep_links.py",
        )

        manifest = root / "android/app/src/main/AndroidManifest.xml"
        manifest.parent.mkdir(parents=True)
        manifest.write_text(
            f'''<?xml version="1.0" encoding="utf-8"?>
<manifest xmlns:android="{ANDROID_NS}">
  <application android:label="ReeMove">
    <activity android:name=".MainActivity" android:exported="true" />
  </application>
</manifest>
''',
            encoding="utf-8",
        )

        info_plist = root / "ios/Runner/Info.plist"
        info_plist.parent.mkdir(parents=True)
        with info_plist.open("wb") as target:
            plistlib.dump({"CFBundleDisplayName": "ReeMove"}, target)

        project = root / "ios/Runner.xcodeproj/project.pbxproj"
        project.parent.mkdir(parents=True)
        project.write_text(
            "\n".join(
                [
                    "PRODUCT_BUNDLE_IDENTIFIER = com.reemove.app;",
                    "PRODUCT_BUNDLE_IDENTIFIER = com.reemove.app;",
                    "PRODUCT_BUNDLE_IDENTIFIER = com.reemove.app;",
                    "PRODUCT_BUNDLE_IDENTIFIER = com.reemove.app.RunnerTests;",
                ],
            ),
            encoding="utf-8",
        )

        command = [
            "python3",
            str(script_dir / "configure_deep_links.py"),
            "--host",
            "links.reemove.app",
        ]
        subprocess.run(command, cwd=root, check=True, capture_output=True, text=True)
        first = _snapshot(root)
        subprocess.run(command, cwd=root, check=True, capture_output=True, text=True)
        second = _snapshot(root)
        if first != second:
            raise AssertionError("Deep-link configuration is not idempotent.")

        tree = ET.parse(manifest)
        data_nodes = tree.getroot().findall(".//data")
        scheme = f"{{{ANDROID_NS}}}scheme"
        host = f"{{{ANDROID_NS}}}host"
        pairs = [(node.attrib.get(scheme), node.attrib.get(host)) for node in data_nodes]
        if pairs.count(("https", "links.reemove.app")) != 1:
            raise AssertionError("Expected one verified Android App Link filter.")
        if pairs.count(("reemove", "open")) != 1:
            raise AssertionError("Expected one ReeMove custom-scheme filter.")

        entitlements = root / "ios/Runner/Runner.entitlements"
        with entitlements.open("rb") as source:
            values = plistlib.load(source)
        domains = values["com.apple.developer.associated-domains"]
        if domains != ["applinks:links.reemove.app"]:
            raise AssertionError("Unexpected associated-domain entitlement content.")
        if project.read_text(encoding="utf-8").count(
            "CODE_SIGN_ENTITLEMENTS = Runner/Runner.entitlements;",
        ) != 3:
            raise AssertionError("Expected entitlement setting in three Runner configs.")

    print("Deep-link configurator idempotency test passed.")


def _snapshot(root: Path) -> dict[str, bytes]:
    paths = [
        root / "android/app/src/main/AndroidManifest.xml",
        root / "ios/Runner/Info.plist",
        root / "ios/Runner/Runner.entitlements",
        root / "ios/Runner.xcodeproj/project.pbxproj",
    ]
    return {str(path.relative_to(root)): path.read_bytes() for path in paths}


if __name__ == "__main__":
    main()
