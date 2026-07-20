"""Provenance tier helpers — official vs trusted third-party vs unofficial."""

from __future__ import annotations

OFFICIAL_PREFIXES = ("OFFICIAL_", "PROVENANCE_QUALIFIED_")
TIER_TRUSTED_THIRD_PARTY = "TRUSTED_THIRD_PARTY"
TIER_OFFICIAL = "OFFICIAL"
LICENSE_TRUSTED_THIRD_PARTY_ASSESSMENT = "TRUSTED_THIRD_PARTY_ASSESSMENT"


def license_to_tier(license_status: str | None) -> str:
    lic = license_status or ""
    if lic == LICENSE_TRUSTED_THIRD_PARTY_ASSESSMENT:
        return TIER_TRUSTED_THIRD_PARTY
    if lic.startswith("UNOFFICIAL"):
        return "UNOFFICIAL"
    if lic.startswith(OFFICIAL_PREFIXES):
        return TIER_OFFICIAL
    return "UNKNOWN"


def is_trusted_assessment(license_status: str | None) -> bool:
    return license_to_tier(license_status) == TIER_TRUSTED_THIRD_PARTY


def is_official(license_status: str | None) -> bool:
    return license_to_tier(license_status) == TIER_OFFICIAL
