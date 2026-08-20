from __future__ import annotations

import hashlib
import json
from datetime import datetime, timezone
from typing import Any

SYSTEM_VERSION = "NRFIM MOTHER V3"
KERNEL_VERSION = "NRFIM-KERNEL-1.0-SELECTIVE-CONCLUSION"
SYSTEM_SCOPE = "FIRST_INNING_UNDER__NRFI_SOVEREIGN"
MOTHER_PROTOCOL_ID = "NRFIMETRICA_MOTHER_V3_AUTONOMOUS"
MOTHER_DOCUMENT_SHA256 = "d16896eba602af272117a5c83b56245aa201979d394301781d424e705b3642d3"
SYSTEM_STATE = "TRADING_HALT_RESEARCH"
AI_ANALYST_STATUS = "CHATGPT_CAUSAL_ANALYST"
NUMERIC_ENGINE_STATUS = "NO_ACTIVE_TRUSTED_ENGINE"
INDEPENDENT_AUDITOR_STATUS = "NO_ACTIVE_TRUSTED_AUDITOR"
NRFI_PRENSA_BRIDGE_STATUS = "NO_VERIFIED_REAL_PACKET_BRIDGE"
MODEL_STATUS = "NOT_CERTIFIED"
CALIBRATION_STATUS = "NOT_CERTIFIED"
REAL_MONEY_AUTHORITY = False

# Clean-room doctrine.
CLEAN_ROOM_EXECUTION_REQUIRED = True
NEW_RUN_PER_INVOCATION_REQUIRED = True
NEW_REPORT_DOCUMENT_PER_RUN_REQUIRED = True
PRIOR_RUN_REPORTS_AS_SPORTS_INPUT_ALLOWED = False

# Causal-authority doctrine: three separate axes.
SPORTS_PROCESS_EXECUTION_SEPARATION_REQUIRED = True
SPORTS_STATUS_VALUES = ("SPORTS_CANDIDATE", "NO_PLAY", "WATCHLIST", "AUDIT_ONLY")
PROCESS_STATUS_VALUES = ("VERIFIED", "FAIL", "REVIEW", "UNVERIFIED", "INCOMPLETE", "MISSING", "PENDING", "NOT_APPLICABLE")
EXECUTION_STATUS_VALUES = ("EXECUTABLE", "TECHNICAL_BLOCK", "PROCESS_BLOCK", "PENDING", "NOT_APPLICABLE", "WATCHLIST", "AUDIT_ONLY")

# A sports verdict is decided by causal analysis grounded in current-run data.
# Process validation may block execution, but it may not erase the sports verdict.
SPORTS_CANDIDATE_REQUIRES_PROCESS_PASS = False
SPORTS_CANDIDATE_REQUIRES_DRIVE_HASH_MATCH = False
SPORTS_CANDIDATE_REQUIRES_BASIC_CURRENT_RUN_DATA = True
SOURCE_FAMILY_FLOORS_DECIDE_SPORTS_CANDIDACY = False
A4_TECHNICAL_BLOCK_IS_SPORTS_REJECTION = False
PROCESS_FAILURE_IS_SPORTS_REJECTION = False

# Selective conclusion doctrine. The broad sports-candidate pool is not the
# final recommendation. The causal analyst must compare the pool and reduce it
# to exactly two primary candidates when at least two exist. A third is
# optional and exceptional. The Kernel validates evidence/membership/accounting
# but does not rank by metric score.
SPORTS_SHORTLIST_REQUIRED = True
SPORTS_SHORTLIST_PRIMARY_TARGET = 2
SPORTS_SHORTLIST_MAX = 3
SPORTS_SHORTLIST_OPTIONAL_THIRD = True
SPORTS_SHORTLIST_METRIC_SCORING_FORBIDDEN = True

# Zero sports candidates is not a default or process-generated outcome.
ZERO_SPORTS_CANDIDATES_REQUIRES_DATA_BURDEN = True
ZERO_SPORTS_CANDIDATES_MAY_BE_CAUSED_BY_PROCESS = False

# Legacy decisions are retained only for historical compatibility.
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
    if decision not in ALLOWED_DECISIONS:
        raise ValueError(f"INVALID_DECISION:{decision}")

    if decision != "AUDIT_ONLY":
        raise ValueError("LEGACY_DECISION_ENDPOINT_SUPERSEDED_BY_MOTHER_A1_A8")

    if numeric_status != "NOT_EXECUTED" or raw_p_nrfi is not None:
        raise ValueError("LEGACY_DECISION_CANNOT_CARRY_PROBABILITY")

    if model_version not in (None, "", "NOT_INTEGRATED"):
        raise ValueError("LEGACY_MODEL_VERSION_NOT_AUTHORIZED")

    if calibration_status not in (None, "", "NOT_CERTIFIED"):
        raise ValueError("LEGACY_CALIBRATION_NOT_AUTHORIZED")
