#!/usr/bin/env python3
"""Configure ReeMove custom links and verified app links idempotently.

Run after ``flutter create`` has generated android/ and ios/. The script keeps
platform files source-controlled while allowing the verified host to differ
between environments.
"""
from __future__ import annotations

import argparse
import plistlib
import re
import xml.etree.ElementTree as ET
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
ANDROID_NS = "http://schemas.android.com/apk/res/android"
ET.register_namespace("android", ANDROID_NS)


def _android_attr(name: str) -> str:
    return f"{{{ANDROID_NS}}}{name}"


def configure_android(host: str) -> None:
    manifest = ROOT / "android/app/src/main/AndroidManifest.xml"
    if not manifest.exists():
        print("Android manifest not present; deep-link configuration skipped.")
        return

    tree = ET.parse(manifest)
    root = tree.getroot()
    application = root.find("application")
    if application is None:
        raise RuntimeError("Android manifest has no <application> element.")

    metadata_name = _android_attr("name")
    metadata_value = _android_attr("value")
    deep_link_metadata = next(
        (
            node
            for node in application.findall("meta-data")
            if node.attrib.get(metadata_name) == "flutter_deeplinking_enabled"
        ),
        None,
    )
    if deep_link_metadata is None:
        deep_link_metadata = ET.SubElement(application, "meta-data")
        deep_link_metadata.set(metadata_name, "flutter_deeplinking_enabled")
    deep_link_metadata.set(metadata_value, "true")

    activity = next(
        (
            node
            for node in application.findall("activity")
            if "MainActivity" in node.attrib.get(metadata_name, "")
        ),
        None,
    )
    if activity is None:
        raise RuntimeError("Could not locate Android MainActivity in the manifest.")

    _ensure_android_filter(
        activity,
        scheme="https",
        host=host,
        auto_verify=True,
    )
    _ensure_android_filter(
        activity,
        scheme="reemove",
        host="open",
        auto_verify=False,
    )

    if hasattr(ET, "indent"):
        ET.indent(tree, space="    ")
    tree.write(manifest, encoding="utf-8", xml_declaration=True)
    print(f"Configured {manifest.relative_to(ROOT)} for {host}")


def _ensure_android_filter(
    activity: ET.Element,
    *,
    scheme: str,
    host: str,
    auto_verify: bool,
) -> None:
    scheme_attr = _android_attr("scheme")
    host_attr = _android_attr("host")
    for intent_filter in activity.findall("intent-filter"):
        for data in intent_filter.findall("data"):
            if (
                data.attrib.get(scheme_attr) == scheme
                and data.attrib.get(host_attr) == host
            ):
                return

    attributes: dict[str, str] = {}
    if auto_verify:
        attributes[_android_attr("autoVerify")] = "true"
    intent_filter = ET.SubElement(activity, "intent-filter", attributes)
    ET.SubElement(
        intent_filter,
        "action",
        {_android_attr("name"): "android.intent.action.VIEW"},
    )
    ET.SubElement(
        intent_filter,
        "category",
        {_android_attr("name"): "android.intent.category.DEFAULT"},
    )
    ET.SubElement(
        intent_filter,
        "category",
        {_android_attr("name"): "android.intent.category.BROWSABLE"},
    )
    ET.SubElement(
        intent_filter,
        "data",
        {
            scheme_attr: scheme,
            host_attr: host,
            _android_attr("pathPrefix"): "/",
        },
    )


def configure_ios(host: str) -> None:
    info_plist = ROOT / "ios/Runner/Info.plist"
    if not info_plist.exists():
        print("iOS Info.plist not present; deep-link configuration skipped.")
        return

    with info_plist.open("rb") as source:
        info = plistlib.load(source)
    info["FlutterDeepLinkingEnabled"] = True

    url_types = info.setdefault("CFBundleURLTypes", [])
    if not isinstance(url_types, list):
        raise RuntimeError("CFBundleURLTypes must be an array in ios/Runner/Info.plist.")
    has_scheme = any(
        isinstance(item, dict)
        and "reemove" in item.get("CFBundleURLSchemes", [])
        for item in url_types
    )
    if not has_scheme:
        url_types.append(
            {
                "CFBundleTypeRole": "Editor",
                "CFBundleURLName": "app.reemove.links",
                "CFBundleURLSchemes": ["reemove"],
            },
        )

    with info_plist.open("wb") as target:
        plistlib.dump(info, target, sort_keys=False)

    entitlements = ROOT / "ios/Runner/Runner.entitlements"
    entitlements_data: dict[str, object] = {}
    if entitlements.exists():
        with entitlements.open("rb") as source:
            entitlements_data = plistlib.load(source)
    domains = entitlements_data.setdefault(
        "com.apple.developer.associated-domains",
        [],
    )
    if not isinstance(domains, list):
        raise RuntimeError("Associated domains entitlement must be an array.")
    domain = f"applinks:{host}"
    if domain not in domains:
        domains.append(domain)
    with entitlements.open("wb") as target:
        plistlib.dump(entitlements_data, target, sort_keys=False)

    _configure_xcode_entitlements()
    print(f"Configured iOS links for {host}")


def _configure_xcode_entitlements() -> None:
    project = ROOT / "ios/Runner.xcodeproj/project.pbxproj"
    if not project.exists():
        print("Xcode project not present; entitlement build setting skipped.")
        return
    text = project.read_text(encoding="utf-8")
    setting = "CODE_SIGN_ENTITLEMENTS = Runner/Runner.entitlements;"
    # Apply to Runner app configs only (skip *.RunnerTests bundle IDs).
    pattern = re.compile(
        r"(?P<indent>\s*)PRODUCT_BUNDLE_IDENTIFIER = "
        r"(?!.*RunnerTests)[^;]+;",
    )
    lines = text.splitlines(keepends=True)
    output: list[str] = []
    runner_configs = 0
    for line in lines:
        match = pattern.search(line)
        if match is None or "RunnerTests" in line:
            output.append(line)
            continue
        runner_configs += 1
        previous_line = ""
        for candidate in reversed(output):
            if candidate.strip():
                previous_line = candidate
                break
        if setting not in previous_line:
            indent = match.group("indent")
            output.append(f"{indent}{setting}\n")
        output.append(line)
    if runner_configs == 0:
        raise RuntimeError(
            "Could not set CODE_SIGN_ENTITLEMENTS automatically. "
            "Set Runner/Runner.entitlements in Xcode Build Settings.",
        )
    project.write_text("".join(output), encoding="utf-8")


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser()
    parser.add_argument(
        "--host",
        default="links.reemove.app",
        help="Verified HTTPS host used by Android App Links and iOS Universal Links.",
    )
    return parser.parse_args()


def main() -> None:
    args = parse_args()
    host = args.host.strip().lower()
    if not re.fullmatch(r"[a-z0-9.-]+", host) or "." not in host:
        raise ValueError("--host must be a valid DNS hostname.")
    configure_android(host)
    configure_ios(host)


if __name__ == "__main__":
    main()
