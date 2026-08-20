from __future__ import annotations

import hashlib
import json
from datetime import datetime, timezone
from typing import Any

SYSTEM_VERSION = "NRFIM MOTHER V3"
AGENT_VERSION = "MOTHER-V3-AGENT-1.13"
KERNEL_VERSION = "NRFIM-KERNEL-1.8-FORENSIC-REPAIR"
SYSTEM_SCOPE = "FIRST_INNING_UNDER__NRFI_SOVEREIGN"
MOTHER_PROTOCOL_ID = "NRFIMETRICA_MOTHER_V3_AUTONOMOUS"
MOTHER_DOCUMENT_SHA256 = "799ccb5a483e7991f880ae7d49d2f191a98e292478ec64e76a55aa8250ec498b"
A0_AUTHORITY_RESOLUTION = "DYNAMIC_AGENT_REGISTRY_PLUS_PROTOCOL_AUTHORITY"
SYSTEM_STATE = "ACTIVE_RESEARCH_ECONOMIC_FIREWALL"
AI_ANALYST_STATUS = "CHATGPT_CAUSAL_ANALYST"
NUMERIC_ENGINE_STATUS = "NO_ACTIVE_TRUSTED_GAME_SPECIFIC_ENGINE"
INDEPENDENT_AUDITOR_STATUS = "NO_ACTIVE_TRUSTED_AUDITOR"
MODEL_STATUS = "NOT_CERTIFIED_FOR_REAL_MONEY"
CALIBRATION_STATUS = "SYSTEM_AUDIT_ONLY_NO_GAME_OVERRIDE"
REAL_MONEY_AUTHORITY = False

# Clean-room doctrine.
CLEAN_ROOM_EXECUTION_REQUIRED = True
NEW_RUN_PER_INVOCATION_REQUIRED = True
NEW_REPORT_DOCUMENT_PER_RUN_REQUIRED = True
PRIOR_RUN_REPORTS_AS_SPORTS_INPUT_ALLOWED = False

# Forensic repair doctrine.
SPORTS_REASONING_INDEPENDENT_OF_CERTIFICATION_CHAIN = True
A0P_SPORTS_PREANALYSIS_MAY_RESOLVE_WITHOUT_A0 = True
A1_A8_REQUIRE_VALID_A0_AUTHORITY_SNAPSHOT = True
PACKET_REQUIRED_FOR_EVERY_GAME_RESOLUTION = True
NO_PLAY_SAME_RESEARCH_BURDEN = True
DB_DERIVED_FINAL_REPORT_REQUIRED = True
DRIVE_GAME_ARTIFACT_MANIFEST_REQUIRED = True
NO_PACKET_REPORT_STATE = "WATCHLIST_PROCESS_MISSING_DO_NOT_BET"

# Causal-authority doctrine: three separate axes.
SPORTS_PROCESS_EXECUTION_SEPARATION_REQUIRED = True
SPORTS_STATUS_VALUES = ("SPORTS_CANDIDATE", "NO_PLAY", "WATCHLIST", "AUDIT_ONLY")
PROCESS_STATUS_VALUES = (
    "VERIFIED",
    "FAIL",
    "REVIEW",
    "UNVERIFIED",
    "INCOMPLETE",
    "MISSING",
    "PENDING",
    "NOT_APPLICABLE",
)
EXECUTION_STATUS_VALUES = (
    "EXECUTABLE",
    "TECHNICAL_BLOCK",
    "PROCESS_BLOCK",
    "PENDING",
    "NOT_APPLICABLE",
    "WATCHLIST",
    "AUDIT_ONLY",
)

# A sports verdict is decided by causal analysis grounded in current-run data.
# Process validation may block execution, but it may not erase the sports verdict.
SPORTS_CANDIDATE_REQUIRES_PROCESS_PASS = False
SPORTS_CANDIDATE_REQUIRES_DRIVE_HASH_MATCH = False
SPORTS_CANDIDATE_REQUIRES_BASIC_CURRENT_RUN_DATA = True
SOURCE_FAMILY_FLOORS_DECIDE_SPORTS_CANDIDACY = False
A4_TECHNICAL_BLOCK_IS_SPORTS_REJECTION = False
PROCESS_FAILURE_IS_SPORTS_REJECTION = False

# Bilateral first-inning doctrine.
BILATERAL_RULE_VERSION = "BILATERAL-1.2"
NRFI_LEAN_REQUIRES_TOP_HALF_PASS = True
NRFI_LEAN_REQUIRES_BOTTOM_HALF_PASS = True
NO_COMPENSATION_BETWEEN_HALVES = True

# Selective conclusion doctrine. The broad sports-candidate pool is not the
# final recommendation. The causal analyst compares the physical candidate
# pool and reduces it to exactly two primary candidates when at least two
# exist. A third is optional and exceptional. Metric scoring cannot rank it.
SPORTS_SHORTLIST_REQUIRED = True
SPORTS_SHORTLIST_PRIMARY_TARGET = 2
SPORTS_SHORTLIST_MAX = 3
SPORTS_SHORTLIST_OPTIONAL_THIRD = True
SPORTS_SHORTLIST_METRIC_SCORING_FORBIDDEN = True

# Zero sports candidates is not a default or process-generated outcome.
ZERO_SPORTS_CANDIDATES_REQUIRES_DATA_BURDEN = True
ZERO_SPORTS_CANDIDATES_MAY_BE_CAUSED_BY_PROCESS = False

# Legacy endpoint values are retained only for historical compatibility.
ALLOWED_DECISIONS = {
    "NRFI_CANDIDATE",
    "NRFI_REJECTED",
    "RESEARCH_ONLY_DATA",
    "RESEARCH_ONLY_MODEL",
    "LOCAL_DATA_BLOCK",
    "AUDIT_ONLY",
}


def now_iso() -> str:
    return datetime.now(timezone.utc).isoformat()


def stable_hash(value: Any) -> str:
    blob = json.dumps(value, sort_keys=True, default=str, separators=(",", ":"))
    return hashlib.sha256(blob.encode("utf-8")).hexdigest()


def classify_game_status(abstract_state: str | None, detailed_state: str | None) -> str:
    a = (abstract_state or "").strip().lower()
    d = (detailed_state or "").strip().lower()
    if a in {"live", "final"}:
        return "AUDIT_ONLY"
    if any(token in d for token in ("in progress", "completed", "final", "game over")):
        return "AUDIT_ONLY"
    if any(token in d for token in ("postponed", "cancelled", "canceled", "suspended")):
        return "LOCAL_DATA_BLOCK"
    return "READY"


def validate_decision(
    *,
    decision: str,
    central_nrfi_case: Any,
    best_yrfi_rival: Any,
    decisive_factor: str,
    materiality: str,
    what_would_change: str,
    numeric_status: str,
    raw_p_nrfi: float | None,
    model_version: str | None,
    calibration_status: str | None,
) -> None:
    """Historical endpoint guard; current sports judgment uses packet V2."""
    if decision not in ALLOWED_DECISIONS:
        raise ValueError(f"INVALID_DECISION:{decision}")
    if decision != "AUDIT_ONLY":
        raise ValueError("LEGACY_DECISION_ENDPOINT_SUPERSEDED_BY_MOTHER_PACKET_V2_A1_A8")
    if numeric_status != "NOT_EXECUTED" or raw_p_nrfi is not None:
        raise ValueError("LEGACY_DECISION_CANNOT_CARRY_PROBABILITY")
    if model_version not in (None, "", "NOT_INTEGRATED"):
        raise ValueError("LEGACY_MODEL_VERSION_NOT_AUTHORIZED")
    if calibration_status not in (None, "", "NOT_CERTIFIED"):
        raise ValueError("LEGACY_CALIBRATION_NOT_AUTHORIZED")
