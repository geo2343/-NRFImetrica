from __future__ import annotations

import hashlib
import json
from datetime import datetime, timezone
from typing import Any

AGENT_ID = "@investigacionNRFI"
AGENT_VERSION = "INVESTIGACION-NRFI-AGENT-1.0"
SYSTEM_VERSION = "INVESTIGACION-NRFI-HISTORICAL-V1.0"
KERNEL_VERSION = "INVESTIGACION-NRFI-KERNEL-0.1-CONNECTED"
PROTOCOL_ID = "INVESTIGACION_NRFI_HISTORICAL_V1"
MOTHER_DOCUMENT_SHA256 = "faaf79e94729a129ed790ee7cd9d90872c602cfdc3756769e5f6e415b25d89fd"
REAL_MONEY_AUTHORITY = False

PHASE_ORDER = (
    "F1_FORENSIC_CAPTURE",
    "F2_DEEP_RECONSTRUCTION",
    "F3_FEATURE_FACTORY",
    "F4_HISTORICAL_PRESS_RELIABILITY",
    "F5_QUERYABLE_INTELLIGENCE",
)

RECEIPT_FIELDS = (
    "PHASE_ID",
    "START_AS_OF",
    "END_AS_OF",
    "INPUT_OBJECTS",
    "OPERATIONS_PERFORMED",
    "OUTPUT_OBJECTS",
    "SOURCES_OR_EVIDENCE",
    "AUDITOR_RESULT",
    "NEXT_PHASE",
)

FORBIDDEN_OUTPUT_KEYS = {
    "pick",
    "stake",
    "ev",
    "sportsbook",
    "odds",
    "bet_recommendation",
    "authoritative_nrfi_probability",
    "metric_score_decision",
}

TEMPORAL_LANES = {
    "PREGAME_EVIDENCE",
    "POSTGAME_EXPLANATORY_EVIDENCE",
    "NOT_APPLICABLE",
}
EPISTEMIC_LANES = {"OBSERVED", "DERIVED", "HUMAN_INFORMATION"}


class InvestigacionNRFIProtocolViolation(ValueError):
    pass


def now_iso() -> str:
    return datetime.now(timezone.utc).isoformat()


def stable_hash(value: Any) -> str:
    blob = json.dumps(value, sort_keys=True, default=str, separators=(",", ":"))
    return hashlib.sha256(blob.encode("utf-8")).hexdigest()


def _walk_keys(value: Any):
    if isinstance(value, dict):
        for key, child in value.items():
            yield str(key).lower()
            yield from _walk_keys(child)
    elif isinstance(value, list):
        for child in value:
            yield from _walk_keys(child)


def forbid_decision_keys(payload: Any) -> None:
    found = sorted(set(_walk_keys(payload)) & FORBIDDEN_OUTPUT_KEYS)
    if found:
        raise InvestigacionNRFIProtocolViolation(
            "FORBIDDEN_PICK_OR_MARKET_OUTPUT:" + ",".join(found)
        )


def validate_phase_order(completed_phase_ids: set[str], phase_id: str) -> None:
    if phase_id not in PHASE_ORDER:
        raise InvestigacionNRFIProtocolViolation(f"UNKNOWN_PHASE:{phase_id}")
    index = PHASE_ORDER.index(phase_id)
    missing = [p for p in PHASE_ORDER[:index] if p not in completed_phase_ids]
    if missing:
        raise InvestigacionNRFIProtocolViolation(
            "PREREQUISITES_INCOMPLETE:" + ",".join(missing)
        )


def validate_receipt(phase_id: str, receipt: dict[str, Any]) -> None:
    missing = [field for field in RECEIPT_FIELDS if receipt.get(field) in (None, "", [])]
    if missing:
        raise InvestigacionNRFIProtocolViolation(
            "PHASE_EXECUTION_RECEIPT_MISSING_FIELDS:" + ",".join(missing)
        )
    if receipt.get("PHASE_ID") != phase_id:
        raise InvestigacionNRFIProtocolViolation("RECEIPT_PHASE_ID_MISMATCH")


def validate_temporal_evidence(
    *,
    temporal_lane: str,
    epistemic_lane: str,
    available_at: str | None,
    first_pitch_at: str | None,
) -> None:
    if temporal_lane not in TEMPORAL_LANES:
        raise InvestigacionNRFIProtocolViolation("INVALID_TEMPORAL_LANE")
    if epistemic_lane not in EPISTEMIC_LANES:
        raise InvestigacionNRFIProtocolViolation("INVALID_EPISTEMIC_LANE")
    if temporal_lane == "PREGAME_EVIDENCE":
        if not available_at or not first_pitch_at:
            raise InvestigacionNRFIProtocolViolation("PREGAME_TIMESTAMPS_REQUIRED")
        if str(available_at) >= str(first_pitch_at):
            raise InvestigacionNRFIProtocolViolation("POSTGAME_OR_LATE_EVIDENCE_CANNOT_BE_PREGAME")


def validate_as_of(*, object_time: str | None, as_of: str | None) -> None:
    if object_time and as_of and str(object_time) > str(as_of):
        raise InvestigacionNRFIProtocolViolation("FUTURE_OBJECT_FORBIDDEN_BY_AS_OF")


def capacity_state(character_count: int) -> str:
    if character_count < 700_000:
        return "HEALTHY"
    if character_count < 800_000:
        return "WATCH"
    if character_count < 900_000:
        return "NEAR_LIMIT"
    return "ROLLOVER_REQUIRED"


def validate_daily_close(
    *,
    expected_finalized: int,
    processed: int,
    excluded: int,
    completed_phase_ids: set[str],
    drive_append_verified: bool,
) -> None:
    missing = [p for p in PHASE_ORDER if p not in completed_phase_ids]
    if missing:
        raise InvestigacionNRFIProtocolViolation(
            "MANDATORY_PHASES_NOT_RUN:" + ",".join(missing)
        )
    if expected_finalized != processed + excluded:
        raise InvestigacionNRFIProtocolViolation("DAILY_UNIVERSE_ACCOUNTING_FAIL")
    if not drive_append_verified:
        raise InvestigacionNRFIProtocolViolation("DRIVE_APPEND_NOT_VERIFIED")
