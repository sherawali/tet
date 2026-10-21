"""Creates the release keystore of the app.

The old keystore was lost twice, so this script

  1. creates a strong key (RSA 2048, valid for 30 years),
  2. writes `android/key.properties` for Gradle,
  3. keeps a copy of the key and of the password in two safe places
     (a backup folder next to the project and the Desktop).

Both the key and the password file are ignored by git, so they never reach
the repository.  Run it once:

    python bin/setup_release_keystore.py
"""
import os
import secrets
import shutil
import string
import subprocess
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
KEYSTORE = ROOT / "android" / "app" / "upload-keystore.jks"
KEY_PROPERTIES = ROOT / "android" / "key.properties"
BACKUP_FOLDERS = [
    ROOT / "keys-backup",
    Path.home() / "Desktop" / "tet_app_keys_backup",
]

ALIAS = "upload"
VALIDITY_DAYS = 10950  # 30 years
DNAME = "CN=Sherawali, OU=TET App, O=Sherawali, L=Dehradun, S=Uttarakhand, C=IN"


def strong_password(length: int = 28) -> str:
    """A password with letters, digits and symbols that keytool accepts."""
    alphabet = string.ascii_letters + string.digits + "-_@#%"
    while True:
        password = "".join(secrets.choice(alphabet) for _ in range(length))
        if (
            any(c.islower() for c in password)
            and any(c.isupper() for c in password)
            and any(c.isdigit() for c in password)
            and any(c in "-_@#%" for c in password)
        ):
            return password


def keytool() -> str:
    java_home = os.environ.get("JAVA_HOME")
    if java_home:
        candidate = Path(java_home) / "bin" / "keytool.exe"
        if candidate.exists():
            return str(candidate)
    found = shutil.which("keytool")
    if not found:
        raise SystemExit("keytool not found - set JAVA_HOME")
    return found


def main() -> int:
    if KEYSTORE.exists() and not sys.argv.__contains__("--force"):
        print(f"the keystore already exists: {KEYSTORE}")
        print("run again with --force to replace it (never do that for a")
        print("published app - the store would reject the update)")
        return 1

    password = strong_password()
    KEYSTORE.parent.mkdir(parents=True, exist_ok=True)

    command = [
        keytool(),
        "-genkeypair",
        "-v",
        "-keystore",
        str(KEYSTORE),
        "-storetype",
        "PKCS12",
        "-keyalg",
        "RSA",
        "-keysize",
        "2048",
        "-validity",
        str(VALIDITY_DAYS),
        "-alias",
        ALIAS,
        "-storepass",
        password,
        "-keypass",
        password,
        "-dname",
        DNAME,
    ]
    print("creating the keystore ...")
    subprocess.run(command, check=True)

    # A properties file reads a backslash as an escape, so the path uses
    # forward slashes.
    store_path = KEYSTORE.as_posix()

    KEY_PROPERTIES.write_text(
        "\n".join(
            [
                "# Release signing of the TET app. Never commit this file.",
                f"storePassword={password}",
                f"keyPassword={password}",
                f"keyAlias={ALIAS}",
                f"storeFile={store_path}",
                "",
            ]
        ),
        encoding="utf-8",
    )

    for folder in BACKUP_FOLDERS:
        try:
            folder.mkdir(parents=True, exist_ok=True)
            shutil.copy2(KEYSTORE, folder / KEYSTORE.name)
            shutil.copy2(KEY_PROPERTIES, folder / "key.properties.backup.txt")
            note = folder / "READ-ME.txt"
            note.write_text(
                "TET app release key\n"
                "==================\n\n"
                f"keystore : {KEYSTORE.name}\n"
                f"alias    : {ALIAS}\n"
                f"password : {password}\n\n"
                "Keep this folder safe. The Play Store only accepts an update\n"
                "that is signed with the very same key.\n",
                encoding="utf-8",
            )
            print(f"backup written to {folder}")
        except OSError as error:
            print(f"could not write the backup in {folder}: {error}")

    print("\nkeystore ready:", KEYSTORE)
    print("password is stored in", KEY_PROPERTIES)
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
