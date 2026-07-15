#!/usr/bin/env python3
from __future__ import annotations

import json
import re
import subprocess
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
EXCLUDED_PARTS = {"node_modules", ".git", ".dart_tool", "build"}
errors: list[str] = []


def included(path: Path) -> bool:
    return not any(part in EXCLUDED_PARTS for part in path.parts)


for path in ROOT.rglob("*.json"):
    if not included(path):
        continue
    try:
        json.loads(path.read_text(encoding="utf-8"))
    except Exception as exc:  # noqa: BLE001
        errors.append(f"Invalid JSON {path.relative_to(ROOT)}: {exc}")

try:
    import yaml  # type: ignore
except ImportError:
    yaml = None

if yaml is not None:
    yaml_paths = [
        ROOT / "pubspec.yaml",
        ROOT / "analysis_options.yaml",
        ROOT / ".github/workflows/ci.yml",
    ]
    for path in yaml_paths:
        try:
            yaml.safe_load(path.read_text(encoding="utf-8"))
        except Exception as exc:  # noqa: BLE001
            errors.append(f"Invalid YAML {path.relative_to(ROOT)}: {exc}")

relative_import = re.compile(r"^import\s+['\"](?P<path>\.{1,2}/[^'\"]+)['\"]", re.MULTILINE)
for dart_file in ROOT.rglob("*.dart"):
    if not included(dart_file):
        continue
    text = dart_file.read_text(encoding="utf-8")
    for match in relative_import.finditer(text):
        target = (dart_file.parent / match.group("path")).resolve()
        if not target.exists():
            errors.append(
                f"Missing Dart import in {dart_file.relative_to(ROOT)}: {match.group('path')}",
            )
    if "domain" in dart_file.parts and (
        "package:cloud_firestore" in text
        or "package:firebase_" in text
        or "DocumentSnapshot" in text
        or "GeoPoint" in text
        or "Timestamp" in text
    ):
        errors.append(f"Firebase type leaked into domain: {dart_file.relative_to(ROOT)}")

for shell_file in [ROOT / "scripts/bootstrap_project.sh"]:
    result = subprocess.run(
        ["bash", "-n", str(shell_file)],
        capture_output=True,
        text=True,
        check=False,
    )
    if result.returncode != 0:
        errors.append(f"Invalid shell script {shell_file.relative_to(ROOT)}: {result.stderr}")

for python_file in [
    ROOT / "scripts/validate_repository.py",
    ROOT / "scripts/configure_native_permissions.py",
]:
    result = subprocess.run(
        [sys.executable, "-m", "py_compile", str(python_file)],
        capture_output=True,
        text=True,
        check=False,
    )
    if result.returncode != 0:
        errors.append(
            f"Invalid Python script {python_file.relative_to(ROOT)}: {result.stderr}",
        )

for script in (ROOT / "firebase_tests/src").glob("*.mjs"):
    result = subprocess.run(
        ["node", "--check", str(script)],
        capture_output=True,
        text=True,
        check=False,
    )
    if result.returncode != 0:
        errors.append(f"Invalid JavaScript {script.relative_to(ROOT)}: {result.stderr}")

if errors:
    print("Repository validation failed:")
    for error in errors:
        print(f"- {error}")
    sys.exit(1)

print("Repository validation passed.")
