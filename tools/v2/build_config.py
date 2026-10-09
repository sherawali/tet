"""Shared build metadata for all generated bank artifacts."""

# Content releases use YYYYMMDD so SQLite meta and the CDN manifest move together.
# Bump this whenever pack content changes: a client only re-syncs when the manifest
# bank_version is greater than the one it already has.
BANK_VERSION = 20261009
