#!/usr/bin/env python3
"""Exports the screenshots ScreenshotTests attached to a result bundle.

    python3 scripts/export_screenshots.py ui.xcresult screenshots/

Uses `xcrun xcresulttool export attachments` (Xcode 16+), then renames each
file to the attachment's name (e.g. 01-onboarding-light.png) using the
manifest the tool writes.
"""

import json
import re
import shutil
import subprocess
import sys
from pathlib import Path


def main(bundle: str, out: str) -> int:
    raw = Path(out) / "_raw"
    shutil.rmtree(out, ignore_errors=True)
    raw.mkdir(parents=True)
    subprocess.run(
        ["xcrun", "xcresulttool", "export", "attachments", "--path", bundle, "--output-path", str(raw)],
        check=True,
    )
    manifest = json.loads((raw / "manifest.json").read_text())
    count = 0
    for test in manifest:
        for attachment in test.get("attachments", []):
            exported = raw / attachment["exportedFileName"]
            suggested = attachment.get("suggestedHumanReadableName") or exported.name
            # "01-onboarding-light_0_<UUID>.png" -> "01-onboarding-light.png"
            name = re.sub(r"_\d+_[0-9A-Fa-f-]{8,}(?=\.\w+$)", "", suggested)
            # Artifact uploads refuse " : < > | * ? and control characters,
            # which Xcode's automatic failure descriptions contain.
            name = re.sub(r'[\x00-\x1f":<>|*?\\/`]', "_", name)
            target = Path(out) / name
            if target.exists():
                target = target.with_stem(f"{target.stem}-{count}")
            shutil.move(exported, target)
            count += 1
    shutil.rmtree(raw)
    print(f"Exported {count} screenshots to {out}")
    return 0 if count else 1


if __name__ == "__main__":
    sys.exit(main(*sys.argv[1:3]))
