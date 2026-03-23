#!/usr/bin/env python3
"""
Center-crop to square and resize to 1024 (for wide generator output).
Usage: python3 prepare_app_icon_from_wide.py [source.png] [dest.png]
"""
from __future__ import annotations

import subprocess
import sys
from pathlib import Path


def main() -> None:
    root = Path(__file__).resolve().parents[1]
    default_out = root / "MakTime/Resources/Assets.xcassets/AppIcon.appiconset/AppIcon.png"
    src = Path(sys.argv[1]) if len(sys.argv) > 1 else default_out
    dst = Path(sys.argv[2]) if len(sys.argv) > 2 else src
    tmp = Path("/tmp/appicon_square_crop.png")

    out = subprocess.run(
        ["sips", "-g", "pixelWidth", "-g", "pixelHeight", str(src)],
        capture_output=True,
        text=True,
        check=True,
    )
    w = h = None
    for line in out.stdout.splitlines():
        if "pixelWidth" in line:
            w = int(line.split(":")[-1].strip())
        if "pixelHeight" in line:
            h = int(line.split(":")[-1].strip())
    if not w or not h:
        raise SystemExit("Could not read dimensions")
    side = min(w, h)
    subprocess.run(["sips", "-c", str(side), str(side), str(src), "--out", str(tmp)], check=True)
    subprocess.run(["sips", "-z", "1024", "1024", str(tmp), "--out", str(dst)], check=True)
    print(dst)


if __name__ == "__main__":
    main()
