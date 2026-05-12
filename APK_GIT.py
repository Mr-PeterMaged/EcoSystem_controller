from __future__ import annotations

import argparse
import mimetypes
import os
import re
import sys
from pathlib import Path

import qrcode
import requests

from github_repos import (
    APK_REPO_NAME,
    APP_DISPLAY_NAME,
    GITHUB_OWNER,
    PROJECT_ROOT,
)


APK_BUILDS_DIR = PROJECT_ROOT / "apk_builds"
PUBSPEC_FILE = PROJECT_ROOT / "pubspec.yaml"
DEFAULT_QR_PATH = APK_BUILDS_DIR / "EcoSystem_Controller_download_qr.png"
DEFAULT_LINK_PATH = APK_BUILDS_DIR / "EcoSystem_Controller_download_link.txt"

OWNER = GITHUB_OWNER
REPO = APK_REPO_NAME
APP_NAME = APP_DISPLAY_NAME
GITHUB_API = "https://api.github.com"
GITHUB_REPO_URL = f"https://github.com/{OWNER}/{REPO}"


class ReleaseError(RuntimeError):
    pass


def load_secrets_env() -> None:
    secrets_file = PROJECT_ROOT / "secrets.env"
    if not secrets_file.exists():
        return

    for raw_line in secrets_file.read_text(encoding="utf-8").splitlines():
        line = raw_line.strip()
        if not line or line.startswith("#") or "=" not in line:
            continue
        key, _, value = line.partition("=")
        key = key.strip()
        value = value.strip().strip('"').strip("'")
        if key and key not in os.environ:
            os.environ[key] = value


def github_headers(token: str) -> dict[str, str]:
    return {
        "Authorization": f"Bearer {token}",
        "Accept": "application/vnd.github+json",
        "X-GitHub-Api-Version": "2022-11-28",
        "User-Agent": "EcoSystem-Controller-Release-Script",
    }


def request_json(
    method: str,
    url: str,
    *,
    token: str,
    expected: set[int],
    **kwargs: object,
) -> tuple[int, dict]:
    response = requests.request(
        method,
        url,
        headers=github_headers(token),
        timeout=60,
        **kwargs,
    )
    if response.status_code not in expected:
        raise ReleaseError(
            f"GitHub API request failed ({response.status_code}): {response.text}"
        )
    if not response.text:
        return response.status_code, {}
    return response.status_code, response.json()


def detect_latest_apk() -> Path:
    if not APK_BUILDS_DIR.exists():
        raise ReleaseError(f"APK folder not found: {APK_BUILDS_DIR}")

    apk_files = sorted(
        APK_BUILDS_DIR.glob("*.apk"),
        key=lambda path: path.stat().st_mtime,
        reverse=True,
    )
    if not apk_files:
        raise ReleaseError(f"No APK files found in {APK_BUILDS_DIR}")
    return apk_files[0].resolve()


def read_pubspec_version() -> str:
    if not PUBSPEC_FILE.exists():
        return "latest"

    match = re.search(
        r"(?m)^version:\s*(\S+)\s*$",
        PUBSPEC_FILE.read_text(encoding="utf-8"),
    )
    return match.group(1) if match else "latest"


def safe_tag(text: str) -> str:
    value = text.strip()
    value = value.replace("+", "-build.")
    value = re.sub(r"[^A-Za-z0-9._-]+", "-", value)
    value = value.strip(".-_")
    return f"v{value or 'latest'}"


def get_or_create_release(tag: str, token: str) -> dict:
    releases_url = f"{GITHUB_API}/repos/{OWNER}/{REPO}/releases"
    by_tag_url = f"{releases_url}/tags/{tag}"

    response = requests.get(
        by_tag_url,
        headers=github_headers(token),
        timeout=60,
    )
    if response.status_code == 200:
        release = response.json()
        print(f"Found release: {release['html_url']}")
        return release
    if response.status_code != 404:
        raise ReleaseError(
            f"Could not check release ({response.status_code}): {response.text}"
        )

    _, release = request_json(
        "POST",
        releases_url,
        token=token,
        expected={200, 201},
        json={
            "tag_name": tag,
            "name": f"{APP_NAME} {tag}",
            "body": (
                f"{APP_NAME} Android APK release.\n\n"
                "Download the APK asset below or scan the generated QR code."
            ),
            "draft": False,
            "prerelease": False,
        },
    )
    print(f"Created release: {release['html_url']}")
    return release


def delete_asset(asset: dict, token: str) -> None:
    response = requests.delete(
        asset["url"],
        headers=github_headers(token),
        timeout=60,
    )
    if response.status_code != 204:
        raise ReleaseError(
            f"Could not delete old release asset {asset['name']}: {response.text}"
        )


def delete_matching_assets(release: dict, token: str, asset_names: set[str]) -> None:
    for asset in release.get("assets", []):
        if asset.get("name") in asset_names:
            delete_asset(asset, token)
            print(f"Deleted old asset: {asset['name']}")


def upload_release_asset(release: dict, file_path: Path, token: str) -> str:
    upload_url = release["upload_url"].split("{", 1)[0]
    content_type = (
        mimetypes.guess_type(file_path.name)[0]
        or "application/octet-stream"
    )
    headers = github_headers(token)
    headers["Content-Type"] = content_type

    print(f"Uploading release asset: {file_path.name}")
    with file_path.open("rb") as file:
        response = requests.post(
            upload_url,
            headers=headers,
            params={"name": file_path.name},
            data=file,
            timeout=300,
        )
    if response.status_code not in {200, 201}:
        raise ReleaseError(
            f"Could not upload {file_path.name} ({response.status_code}): "
            f"{response.text}"
        )
    asset = response.json()
    return asset["browser_download_url"]


def save_download_link(url: str, output_path: Path) -> None:
    output_path.parent.mkdir(parents=True, exist_ok=True)
    output_path.write_text(f"{url}\n", encoding="utf-8")
    print(f"Download link saved: {output_path}")


def save_qr_code(url: str, output_path: Path) -> None:
    output_path.parent.mkdir(parents=True, exist_ok=True)

    qr = qrcode.QRCode(
        version=None,
        error_correction=qrcode.constants.ERROR_CORRECT_M,
        box_size=12,
        border=4,
    )
    qr.add_data(url)
    qr.make(fit=True)
    image = qr.make_image(fill_color="#16A34A", back_color="white")
    image.save(output_path)
    print(f"QR code saved: {output_path}")


def publish_release(
    *,
    apk_path: Path | None = None,
    version: str | None = None,
    tag: str | None = None,
    qr_path: Path = DEFAULT_QR_PATH,
    link_path: Path = DEFAULT_LINK_PATH,
    token: str | None = None,
    upload_qr_asset: bool = True,
) -> str:
    load_secrets_env()
    github_token = token or os.getenv("GITHUB_TOKEN")
    if not github_token:
        raise ReleaseError(
            "GITHUB_TOKEN is missing. Add it to secrets.env or set it in PowerShell:\n"
            "$env:GITHUB_TOKEN='your_token_here'"
        )

    apk = (apk_path or detect_latest_apk()).resolve()
    if not apk.exists():
        raise ReleaseError(f"APK file not found: {apk}")

    release_version = version or read_pubspec_version()
    release_tag = tag or safe_tag(release_version)

    print(f"Repository : {GITHUB_REPO_URL}")
    print(f"Release tag: {release_tag}")
    print(f"APK        : {apk}")

    release = get_or_create_release(release_tag, github_token)
    qr_asset_name = qr_path.name
    # Delete both the old APK and old QR in one pass before uploading anything.
    delete_matching_assets(release, github_token, {apk.name, qr_asset_name})

    download_url = upload_release_asset(release, apk, github_token)
    save_download_link(download_url, link_path)
    save_qr_code(download_url, qr_path)

    if upload_qr_asset:
        # QR was already removed above; upload the freshly generated image directly.
        upload_release_asset(release, qr_path, github_token)

    print(f"Direct download URL: {download_url}")
    return download_url


def build_parser() -> argparse.ArgumentParser:
    parser = argparse.ArgumentParser(
        description="Publish the latest APK to GitHub Releases and generate a QR code."
    )
    parser.add_argument("--apk", help="APK file to publish. Default: newest APK.")
    parser.add_argument("--version", help="Release version text. Default: pubspec.yaml version.")
    parser.add_argument("--tag", help="Release tag. Default: v<version>.")
    parser.add_argument(
        "--qr",
        default=str(DEFAULT_QR_PATH),
        help=f"QR image output path. Default: {DEFAULT_QR_PATH}",
    )
    parser.add_argument(
        "--link-file",
        default=str(DEFAULT_LINK_PATH),
        help=f"Text file for the direct download URL. Default: {DEFAULT_LINK_PATH}",
    )
    parser.add_argument("--token", help="GitHub token. Default: GITHUB_TOKEN/secrets.env.")
    parser.add_argument(
        "--no-upload-qr-asset",
        action="store_true",
        help="Save the QR locally but do not upload it as a release asset.",
    )
    return parser


def main(argv: list[str] | None = None) -> int:
    args = build_parser().parse_args(argv)
    try:
        publish_release(
            apk_path=Path(args.apk) if args.apk else None,
            version=args.version,
            tag=args.tag,
            qr_path=Path(args.qr),
            link_path=Path(args.link_file),
            token=args.token,
            upload_qr_asset=not args.no_upload_qr_asset,
        )
    except ReleaseError as exc:
        print(f"Error: {exc}", file=sys.stderr)
        return 1
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
