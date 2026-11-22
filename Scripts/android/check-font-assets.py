#!/usr/bin/env python3
"""Check bundled Android fonts and notices in source and, optionally, an APK or AAB."""

import argparse
import hashlib
import json
from pathlib import Path, PurePosixPath
from zipfile import BadZipFile, ZipFile


ROOT = Path(__file__).resolve().parents[2]
RESOURCES = ROOT / "MakhtootKit/Sources/MKFonts/Resources"
ANDROID_ASSETS = ROOT / "android/app/src/main/assets"
NOTICE = "LICENSE-OFL.txt"
FONT_SUFFIXES = {".ttf", ".otf", ".ttc"}


def is_font_asset(path):
    name = PurePosixPath(path)
    return name.suffix.lower() in FONT_SUFFIXES or name.name.lower() == NOTICE.lower()


def local_assets(directory):
    return [path.relative_to(directory.parent).as_posix()
            for path in directory.rglob("*") if path.is_file() and is_font_asset(path)]


def verify_paths(actual, expected, label):
    actual_set = set(actual)
    missing = sorted(set(expected) - actual_set)
    unexpected = sorted(actual_set - set(expected))
    if missing or unexpected or len(actual_set) != len(actual):
        details = []
        if missing:
            details.append(f"missing {', '.join(missing)}")
        if unexpected:
            details.append(f"unexpected {', '.join(unexpected)}")
        if len(actual_set) != len(actual):
            details.append("duplicate entries")
        raise ValueError(f"{label}: {'; '.join(details)}")


def verify_bytes(expected, read_asset, label):
    for path, source in expected.items():
        if read_asset(path) != source:
            raise ValueError(f"{label}: bytes differ from the original for {path}")


def expected_assets():
    records = json.loads((RESOURCES / "LicenseRecords/records.json").read_text(encoding="utf-8"))
    manifest = json.loads((ROOT / "android/strings/font-manifest.json").read_text(encoding="utf-8"))
    families = {family["familyId"]: family for family in manifest["families"]}
    verify_paths([family["familyId"] for family in manifest["families"]],
                 {record["fontID"] for record in records}, "Android manifest family IDs")

    source_paths = []
    expected = {}
    for record in records:
        family = families[record["fontID"]]
        source = PurePosixPath(family["sourceDirectory"])
        android_dir = PurePosixPath("fonts") / source.name
        notice_path = source / NOTICE
        if record["licenseFileBundlePath"] != notice_path.as_posix():
            raise ValueError(f"{record['fontID']}: recorded notice path {record['licenseFileBundlePath']} "
                             f"does not match {notice_path}")

        manifest_dir = ANDROID_ASSETS.relative_to(ROOT) / android_dir
        if family["androidAssetDirectory"] != manifest_dir.as_posix() + "/":
            raise ValueError(f"{record['fontID']}: Android manifest directory must match {manifest_dir}")

        hashes = {face["filename"]: face["sha256"] for face in record["faces"]}
        verify_paths([face["filename"] for face in family["faces"]], hashes, f"{record['fontID']} faces")
        for face in family["faces"]:
            filename = face["filename"]
            source_path = source / filename
            if face["androidAssetPath"] != (manifest_dir / filename).as_posix():
                raise ValueError(f"{record['fontID']}: inconsistent Android asset path for {filename}")
            font_bytes = (RESOURCES / source_path).read_bytes()
            actual_hash = hashlib.sha256(font_bytes).hexdigest()
            if actual_hash != hashes[filename] or face["sha256"] != actual_hash:
                raise ValueError(f"{record['fontID']}: SHA-256 mismatch for {filename}")
            source_paths.append(source_path.as_posix())
            expected[(android_dir / filename).as_posix()] = font_bytes

        source_paths.append(notice_path.as_posix())
        expected[(android_dir / NOTICE).as_posix()] = (RESOURCES / notice_path).read_bytes()

    # Exact name comparisons also catch cases masked by a case-insensitive checkout.
    verify_paths(local_assets(RESOURCES / "Fonts"), source_paths, "Canonical font resources")
    return expected, len(records)


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("artifact", nargs="?", type=Path, help="APK or AAB to check against source")
    args = parser.parse_args()
    try:
        expected, family_count = expected_assets()
        verify_paths(local_assets(ANDROID_ASSETS / "fonts"), expected, "Android source assets")
        verify_bytes(expected, lambda path: (ANDROID_ASSETS / path).read_bytes(), "Android source assets")
        print(f"Android source assets: {family_count} original notices and {len(expected) - family_count} font files verified.")

        if args.artifact:
            prefixes = {".aab": "base/assets/", ".apk": "assets/"}
            prefix = prefixes.get(args.artifact.suffix.lower())
            if prefix is None:
                raise ValueError("Expected an APK or AAB path")
            with ZipFile(args.artifact) as package:
                names = [name[len(prefix):] for name in package.namelist()
                         if name.startswith(f"{prefix}fonts/") and is_font_asset(name)]
                verify_paths(names, expected, str(args.artifact))
                verify_bytes(expected, lambda path: package.read(prefix + path), str(args.artifact))
            print(f"{args.artifact}: all font files and original notices verified.")
    except (OSError, ValueError, BadZipFile) as error:
        parser.exit(1, f"Font asset verification failed: {error}\n")


if __name__ == "__main__":
    main()
