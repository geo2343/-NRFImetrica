from __future__ import annotations

import hashlib
import json
from datetime import datetime, timezone
from typing import Any

SYSTEM_VERSION = "NRFIM V2.1"
KERNEL_VERSION = "NRFIM-KERNEL-0.3-PROTOCOL-GATED"
SYSTEM_SCOPE = "NRFI_ONLY"
AI_ANALYST_STATUS = "CHATGPT_EXTERNAL_BRAIN"
NUMERIC_ENGINE_STATUS = "NOT_INTEGRATED"
MODEL_STATUS = "NOT_INTEGRATED"
CALIBRATION_STATUS = "NOT_CERTIFIED"

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

    # raw_p_nrfi is reserved for an identifiable numeric/calibrated engine.
    # The AI analyst may express an uncalibrated judgment estimate in the
    # protocol RECONSIDERATION payload, but it must never masquerade as raw_p_nrfi.
    if numeric_status != "NOT_EXECUTED" or raw_p_nrfi is not None:
        raise ValueError("NUMERIC_ENGINE_NOT_INTEGRATED")

    if model_version not in (None, "", "NOT_INTEGRATED"):
        raise ValueError("MODEL_VERSION_NOT_AUTHORIZED")

    if calibration_status not in (None, "", "NOT_CERTIFIED"):
        raise ValueError("CALIBRATION_NOT_CERTIFIED")

    if decision in {"NRFI_CANDIDATE", "NRFI_REJECTED"}:
        missing: list[str] = []
        if not central_nrfi_case:
            missing.append("central_nrfi_case")
        if not best_yrfi_rival:
            missing.append("best_yrfi_rival")
        if not decisive_factor.strip():
            missing.append("decisive_factor")
        if not materiality.strip():
            missing.append("materiality")
        if not what_would_change.strip():
            missing.append("what_would_change")
        if missing:
            raise ValueError("COMPETITIVE_DECISION_MISSING:" + ",".join(missing))

    if decision == "NRFI_REJECTED" and len(what_would_change.strip()) < 8:
        raise ValueError("REJECTION_MUST_STATE_CONCRETE_REVERSAL_CONDITION")
