#!/usr/bin/env python3
"""Configure Google Maps API keys for Flutter Android and iOS idempotently.

Run after ``flutter create``. The script never writes a secret. Android reads
``MAPS_API_KEY`` from ``android/local.properties`` or the environment. iOS
reads it from ``ios/Flutter/Maps.xcconfig`` (gitignored) through Info.plist.
"""
from __future__ import annotations

import plistlib
import re
import xml.etree.ElementTree as ET
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
ANDROID_NS = "http://schemas.android.com/apk/res/android"
ET.register_namespace("android", ANDROID_NS)


def _android_attr(name: str) -> str:
    return f"{{{ANDROID_NS}}}{name}"


def configure_android_manifest() -> None:
    manifest = ROOT / "android/app/src/main/AndroidManifest.xml"
    if not manifest.exists():
        print("Android manifest not present; Google Maps manifest setup skipped.")
        return
    tree = ET.parse(manifest)
    application = tree.getroot().find("application")
    if application is None:
        raise RuntimeError("Android manifest has no <application> element.")
    name_attr = _android_attr("name")
    value_attr = _android_attr("value")
    node = next(
        (
            item
            for item in application.findall("meta-data")
            if item.attrib.get(name_attr) == "com.google.android.geo.API_KEY"
        ),
        None,
    )
    if node is None:
        node = ET.SubElement(application, "meta-data")
        node.set(name_attr, "com.google.android.geo.API_KEY")
    node.set(value_attr, "${MAPS_API_KEY}")
    if hasattr(ET, "indent"):
        ET.indent(tree, space="    ")
    tree.write(manifest, encoding="utf-8", xml_declaration=True)
    print(f"Configured {manifest.relative_to(ROOT)}")


def configure_android_gradle() -> None:
    kotlin = ROOT / "android/app/build.gradle.kts"
    groovy = ROOT / "android/app/build.gradle"
    if kotlin.exists():
        text = kotlin.read_text(encoding="utf-8")
        marker = "manifestPlaceholders[\"MAPS_API_KEY\"]"
        if marker not in text:
            imports = "import java.io.FileInputStream\nimport java.util.Properties\n\n"
            if "import java.util.Properties" not in text:
                text = imports + text
            properties = """val reemoveLocalProperties = Properties()
val reemoveLocalPropertiesFile = rootProject.file("local.properties")
if (reemoveLocalPropertiesFile.exists()) {
    reemoveLocalProperties.load(FileInputStream(reemoveLocalPropertiesFile))
}

"""
            if "val reemoveLocalProperties = Properties()" not in text:
                android_match = re.search(r"^android\s*\{", text, re.MULTILINE)
                if android_match is None:
                    raise RuntimeError("Could not locate Android block.")
                text = text[:android_match.start()] + properties + text[android_match.start():]
            default_config = re.compile(r"(?P<indent>\s*)defaultConfig\s*\{")
            addition = (
                '\n${indent}    val mapsApiKey = '
                'reemoveLocalProperties.getProperty("MAPS_API_KEY") '
                '?: System.getenv("MAPS_API_KEY") ?: ""\n'
                '${indent}    manifestPlaceholders["MAPS_API_KEY"] = mapsApiKey'
            )

            def replace(match: re.Match[str]) -> str:
                indent = match.group("indent")
                return match.group(0) + addition.replace("${indent}", indent)

            text, count = default_config.subn(replace, text, count=1)
            if count != 1:
                raise RuntimeError("Could not locate Android defaultConfig block.")
            kotlin.write_text(text, encoding="utf-8")
        print(f"Configured {kotlin.relative_to(ROOT)}")
        return
    if groovy.exists():
        text = groovy.read_text(encoding="utf-8")
        marker = "manifestPlaceholders = [MAPS_API_KEY: mapsApiKey]"
        if marker not in text:
            properties = """def localProperties = new Properties()
def localPropertiesFile = rootProject.file('local.properties')
if (localPropertiesFile.exists()) {
    localPropertiesFile.withInputStream { localProperties.load(it) }
}

"""
            if "def localProperties = new Properties()" not in text:
                android_match = re.search(r"^android\s*\{", text, re.MULTILINE)
                if android_match is None:
                    raise RuntimeError("Could not locate Android block.")
                text = text[:android_match.start()] + properties + text[android_match.start():]
            default_config = re.compile(r"(?P<indent>\s*)defaultConfig\s*\{")

            def replace(match: re.Match[str]) -> str:
                indent = match.group("indent")
                return (
                    match.group(0)
                    + f"\n{indent}    def mapsApiKey = localProperties.getProperty('MAPS_API_KEY') "
                    + "?: System.getenv('MAPS_API_KEY') ?: ''"
                    + f"\n{indent}    manifestPlaceholders = [MAPS_API_KEY: mapsApiKey]"
                )

            text, count = default_config.subn(replace, text, count=1)
            if count != 1:
                raise RuntimeError("Could not locate Android defaultConfig block.")
            groovy.write_text(text, encoding="utf-8")
        print(f"Configured {groovy.relative_to(ROOT)}")
        return
    print("Android Gradle app file not present; Google Maps Gradle setup skipped.")


def configure_ios() -> None:
    plist = ROOT / "ios/Runner/Info.plist"
    app_delegate = ROOT / "ios/Runner/AppDelegate.swift"
    if not plist.exists() or not app_delegate.exists():
        print("iOS Runner files not present; Google Maps iOS setup skipped.")
        return
    with plist.open("rb") as source:
        data = plistlib.load(source)
    data["MAPS_API_KEY"] = "$(MAPS_API_KEY)"
    with plist.open("wb") as target:
        plistlib.dump(data, target, sort_keys=False)

    text = app_delegate.read_text(encoding="utf-8")
    if "import GoogleMaps" not in text:
        text = text.replace("import Flutter\n", "import Flutter\nimport GoogleMaps\n", 1)
    marker = "GMSServices.provideAPIKey"
    if marker not in text:
        # Soft-activate when a real key is present. Nearby list mode still works
        # without Maps tiles; do not crash cold start for closed-beta builds.
        maps_init = """    if let mapsApiKey = Bundle.main.object(forInfoDictionaryKey: \"MAPS_API_KEY\") as? String,
       !mapsApiKey.isEmpty,
       mapsApiKey != \"$(MAPS_API_KEY)\" {
      GMSServices.provideAPIKey(mapsApiKey)
    }
"""
        anchors = (
            "    GeneratedPluginRegistrant.register(with: self)",
            "    GeneratedPluginRegistrant.register(with: engineBridge.pluginRegistry)",
        )
        replaced = False
        for anchor in anchors:
            if anchor in text:
                text = text.replace(anchor, maps_init + anchor, 1)
                replaced = True
                break
        if not replaced:
            raise RuntimeError(
                "Could not locate GeneratedPluginRegistrant registration in AppDelegate.swift.",
            )
    app_delegate.write_text(text, encoding="utf-8")

    flutter_dir = ROOT / "ios/Flutter"
    flutter_dir.mkdir(parents=True, exist_ok=True)
    example = flutter_dir / "Maps.xcconfig.example"
    example.write_text(
        "// Copy to Maps.xcconfig and replace with a restricted iOS Maps key.\n"
        "MAPS_API_KEY=YOUR_IOS_GOOGLE_MAPS_API_KEY\n",
        encoding="utf-8",
    )
    for name in ("Debug.xcconfig", "Release.xcconfig", "Profile.xcconfig"):
        path = flutter_dir / name
        if not path.exists():
            continue
        config = path.read_text(encoding="utf-8")
        include = '#include? "Maps.xcconfig"'
        if include not in config:
            path.write_text(include + "\n" + config, encoding="utf-8")
    print("Configured iOS Google Maps key injection.")


def configure_gitignore() -> None:
    gitignore = ROOT / ".gitignore"
    if not gitignore.exists():
        return
    text = gitignore.read_text(encoding="utf-8")
    entries = ["ios/Flutter/Maps.xcconfig", "android/key.properties"]
    changed = False
    for entry in entries:
        if entry not in text.splitlines():
            text = text.rstrip() + f"\n{entry}\n"
            changed = True
    if changed:
        gitignore.write_text(text, encoding="utf-8")


def main() -> None:
    configure_android_manifest()
    configure_android_gradle()
    configure_ios()
    configure_gitignore()


if __name__ == "__main__":
    main()
