#!/usr/bin/env python3
"""
Simple CLI to encrypt a GitHub Personal Access Token (PAT) for TET App.
Produces a Base64 XOR string compatible with GitHubReportService.

Usage:
  python bin/encrypt_api_key.py ghp_yourSecretGitHubTokenHere
"""

import sys
import base64

if sys.platform == "win32":
    try:
        sys.stdout.reconfigure(encoding="utf-8")
    except Exception:
        pass

XOR_KEY_PHRASE = b"TET_MASTER_VAULT_2026_SECRET"

def encrypt_token(raw_token: str) -> str:
    raw_bytes = raw_token.strip().encode("utf-8")
    enc_bytes = bytes([b ^ XOR_KEY_PHRASE[i % len(XOR_KEY_PHRASE)] for i, b in enumerate(raw_bytes)])
    return base64.b64encode(enc_bytes).decode("ascii")

def decrypt_token(enc_b64: str) -> str:
    enc_bytes = base64.b64decode(enc_b64.strip())
    dec_bytes = bytes([b ^ XOR_KEY_PHRASE[i % len(XOR_KEY_PHRASE)] for i, b in enumerate(enc_bytes)])
    return dec_bytes.decode("utf-8")

def main():
    if len(sys.argv) < 2:
        print("Usage: python bin/encrypt_api_key.py <RAW_GITHUB_TOKEN>")
        print("Example: python bin/encrypt_api_key.py ghp_Abc123Xyz...")
        sys.exit(1)

    raw_token = sys.argv[1].strip()
    encrypted = encrypt_token(raw_token)
    decrypted = decrypt_token(encrypted)

    assert decrypted == raw_token, "Decryption verification failed!"

    print("=" * 60)
    print("[LOCK] TET APP API KEY ENCRYPTION TOOL")
    print("=" * 60)
    print(f"Original Token Length : {len(raw_token)} chars")
    print(f"Token Prefix          : {raw_token[:4]}...")
    print(f"\nEncrypted Base64 String:")
    print(f"  {encrypted}")
    print("\nCopy & paste this into:")
    print("  lib/services/github_report_service.dart -> _bundledEncryptedToken")
    print("=" * 60)

if __name__ == "__main__":
    main()
