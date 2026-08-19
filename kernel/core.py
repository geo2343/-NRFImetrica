from __future__ import annotations

import hashlib
import json
from datetime import datetime, timezone
from typing import Any

SYSTEM_VERSION = "NRFIM MOTHER V3"
KERNEL_VERSION = "NRFIM-KERNEL-0.8-DUAL-STATUS"
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

# Clean-room doctrine: every new invocation is a new run with its own report
# document. Prior-run reports/packets are historical/audit material only and
# cannot be used as sports-analysis input for the current run.
CLEAN_ROOM_EXECUTION_REQUIRED = True
NEW_RUN_PER_INVOCATION_REQUIRED = True
NEW_REPORT_DOCUMENT_PER_RUN_REQUIRED = True
PRIOR_RUN_REPORTS_AS_SPORTS_INPUT_ALLOWED = False

# Dual-status doctrine: sports judgment and execution authority are separate
# axes. A technical A4/A6/A7 block may stop real-money execution but may never
# erase, rewrite, or relabel an audited sports judgment as a sports NO_PLAY.
SPORTS_EXECUTION_DUAL_STATUS_REQUIRED = True
SPORTS_STATUS_VALUES = ("SPORTS_CANDIDATE", "NO_PLAY", "WATCHLIST", "AUDIT_ONLY")
EXECUTION_STATUS_VALUES = ("EXECUTABLE", "TECHNICAL_BLOCK", "PENDING", "NOT_APPLICABLE", "WATCHLIST", "AUDIT_ONLY")
A4_TECHNICAL_BLOCK_IS_SPORTS_REJECTION = False

# Legacy decisions are retained only for historical compatibility. The active
# mother-document runtime is A1->A8 through protocol_phase_state.
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
