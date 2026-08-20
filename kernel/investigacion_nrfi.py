from __future__ import annotations

import hashlib
import json
from datetime import datetime, timezone
from typing import Any

AGENT_ID = "@investigacionNRFI"
AGENT_VERSION = "INVESTIGACION-NRFI-AGENT-1.1"
SYSTEM_VERSION = "INVESTIGACION-NRFI-HISTORICAL-V1.0"
KERNEL_VERSION = "INVESTIGACION-NRFI-KERNEL-0.2-SEMANTIC-COMPLETENESS"
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

REQUIRED_FEATURE_FAMILIES = {
    "RESULTS",
    "SEQUENCE",
    "EXPOSURE",
    "OUT_CREATION",
    "TRAFFIC",
    "DAMAGE",
    "PITCHER_PROCESS",
    "TOP_ORDER",
    "CONTEXT",
}
REQUIRED_SEQUENCE_WINDOWS = {"L3", "L5", "L10", "L15", "L20", "SEASON", "CAREER"}
REQUIRED_PACKET_KEYS = {
    "PITCHER_HISTORY",
    "TEAM_HISTORY",
    "TOP_ORDER_HISTORY",
    "PROCESS_HISTORY",
    "EVENT_PATHS",
    "CONTEXT",
    "PRESS_HISTORY_PREGAME",
    "POSTGAME_EXPLANATORY_SEPARATE",
    "SAMPLE_RELIABILITY",
    "DATA_COVERAGE",
    "SOURCE_LINEAGE",
    "UNCERTAINTY",
    "COMPARABLE_COHORTS",
}
REQUIRED_REPORT_MARKERS = {
    "EXECUTION_SUMMARY",
    "F1",
    "F2",
    "F3",
    "F4",
    "F5",
    "DAILY_CLOSURE",
    "GAME_BLOCKS",
}

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


def validate_feature_contract(features: list[dict[str, Any]]) -> None:
    families = {str(row.get("feature_family")) for row in features}
    missing_families = sorted(REQUIRED_FEATURE_FAMILIES - families)
    windows = {
        str(row.get("feature_window"))
        for row in features
        if str(row.get("feature_family")) == "SEQUENCE"
    }
    missing_windows = sorted(REQUIRED_SEQUENCE_WINDOWS - windows)
    if missing_families or missing_windows:
        raise InvestigacionNRFIProtocolViolation(
            "FEATURE_CONTRACT_INCOMPLETE:families="
            + ",".join(missing_families)
            + ";windows="
            + ",".join(missing_windows)
        )


def validate_evidence_packet(packet: dict[str, Any]) -> None:
    missing = sorted(REQUIRED_PACKET_KEYS - set(packet))
    if missing:
        raise InvestigacionNRFIProtocolViolation(
            "EVIDENCE_PACKET_REQUIRED_KEYS_MISSING:" + ",".join(missing)
        )


def validate_semantic_snapshot(snapshot: dict[str, Any]) -> None:
    required = ("f1_pass", "f2_pass", "f3_pass", "f4_pass", "f5_pass", "report_contract_pass", "pass")
    missing = [key for key in required if key not in snapshot]
    if missing:
        raise InvestigacionNRFIProtocolViolation(
            "SEMANTIC_SNAPSHOT_FIELDS_MISSING:" + ",".join(missing)
        )
    if not bool(snapshot.get("pass")):
        raise InvestigacionNRFIProtocolViolation(
            "SEMANTIC_COMPLETENESS_FAIL:" + stable_hash(snapshot)
        )


def validate_report_contract(
    *,
    nonexcluded_games: int,
    game_block_count: int,
    phase_section_count: int,
    daily_block_character_count: int,
    markers: dict[str, Any],
    report_contract_verified: bool,
) -> None:
    min_chars = max(12_000, nonexcluded_games * 1_800)
    missing_markers = sorted(
        key for key in REQUIRED_REPORT_MARKERS if markers.get(key) is not True
    )
    if not report_contract_verified:
        raise InvestigacionNRFIProtocolViolation("REPORT_CONTRACT_NOT_VERIFIED")
    if game_block_count != nonexcluded_games:
        raise InvestigacionNRFIProtocolViolation("REPORT_GAME_BLOCK_COUNT_MISMATCH")
    if phase_section_count < 5:
        raise InvestigacionNRFIProtocolViolation("REPORT_PHASE_SECTION_COUNT_INCOMPLETE")
    if daily_block_character_count < min_chars:
        raise InvestigacionNRFIProtocolViolation("REPORT_BLOCK_ANTI_EMPTY_FLOOR_FAIL")
    if missing_markers:
        raise InvestigacionNRFIProtocolViolation(
            "REPORT_REQUIRED_MARKERS_MISSING:" + ",".join(missing_markers)
        )


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
    semantic_completeness_pass: bool,
    report_contract_pass: bool,
) -> None:
    missing = [p for p in PHASE_ORDER if p not in completed_phase_ids]
    if missing:
        raise InvestigacionNRFIProtocolViolation(
            "MANDATORY_PHASES_NOT_RUN:" + ",".join(missing)
        )
    if expected_finalized != processed + excluded:
        raise InvestigacionNRFIProtocolViolation("DAILY_UNIVERSE_ACCOUNTING_FAIL")
    if not semantic_completeness_pass:
        raise InvestigacionNRFIProtocolViolation("SEMANTIC_COMPLETENESS_REQUIRED")
    if not report_contract_pass:
        raise InvestigacionNRFIProtocolViolation("REPORT_CONTRACT_REQUIRED")
    if not drive_append_verified:
        raise InvestigacionNRFIProtocolViolation("DRIVE_APPEND_NOT_VERIFIED")
