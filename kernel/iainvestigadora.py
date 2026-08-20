from __future__ import annotations

from typing import Any

AGENT_ID = "@iainvestigadora"
AGENT_VERSION = "IAINVESTIGADORA-AGENT-1.4"
SYSTEM_VERSION = "IAINVESTIGADORA-MLB-V1.4"
KERNEL_VERSION = "IAINV-KERNEL-0.1-CONNECTED"
PROTOCOL_ID = "IAINVESTIGADORA_MLB_V14"
PATCH_SHA256 = "785a42e9906b307ed66f16a1f1fed8ec82aa484eb663bfc272da1f60bf47bfaa"
REAL_MONEY_AUTHORITY = False
PHASE_ORDER = tuple(f"F{i}" for i in range(1, 13))
CONDITIONAL_PHASES = {"F6", "F8", "F11"}
RECEIPT_FIELDS = {
    "PHASE_ID", "STATUS", "START_AS_OF", "END_AS_OF", "INPUT_OBJECTS",
    "OPERATIONS_PERFORMED", "OUTPUT_OBJECTS", "SOURCES_OR_EVIDENCE",
    "AUDITOR_RESULT", "NEXT_PHASE", "UNRESOLVED_GOVERNING_OBJECTS", "REOPEN_TRIGGER",
}
FORBIDDEN_KEYS = {
    "pick", "stake", "odds", "ev", "edge", "bet_recommendation",
    "sports_verdict", "probability", "authoritative_probability", "real_money_authority",
}


class IAInvestigadoraViolation(ValueError):
    pass


def _walk_keys(value: Any):
    if isinstance(value, dict):
        for key, child in value.items():
            yield str(key).lower()
            yield from _walk_keys(child)
    elif isinstance(value, list):
        for child in value:
            yield from _walk_keys(child)


def forbid_decision_fields(payload: Any) -> None:
    found = sorted(set(_walk_keys(payload)) & FORBIDDEN_KEYS)
    if found:
        raise IAInvestigadoraViolation("FORBIDDEN_DECISION_FIELDS:" + ",".join(found))


def validate_target_binding(payload: dict[str, Any], game_id: str) -> None:
    target = payload.get("target_binding") or {}
    if str(target.get("game_id") or "") != str(game_id):
        raise IAInvestigadoraViolation("TARGET_BINDING_MISMATCH")


def validate_receipt(phase_id: str, status: str, receipt: dict[str, Any]) -> None:
    missing = sorted(k for k in RECEIPT_FIELDS if k not in receipt)
    if missing:
        raise IAInvestigadoraViolation("E1_RECEIPT_FIELDS_MISSING:" + ",".join(missing))
    if receipt.get("PHASE_ID") != phase_id:
        raise IAInvestigadoraViolation("E1_RECEIPT_PHASE_MISMATCH")
    expected = "NOT_APPLICABLE" if status == "SKIPPED_NOT_TRIGGERED" else "EXECUTED"
    if str(receipt.get("STATUS") or "").upper() != expected:
        raise IAInvestigadoraViolation("E1_RECEIPT_STATUS_MISMATCH")


def validate_phase_order(completed: set[str], phase_id: str) -> None:
    if phase_id not in PHASE_ORDER:
        raise IAInvestigadoraViolation("UNKNOWN_PHASE")
    idx = PHASE_ORDER.index(phase_id)
    missing = [p for p in PHASE_ORDER[:idx] if p not in completed]
    if missing:
        raise IAInvestigadoraViolation("PHASE_PREREQUISITES_INCOMPLETE:" + ",".join(missing))


def validate_conditional_phase(phase_id: str, status: str, payload: dict[str, Any]) -> None:
    if phase_id not in CONDITIONAL_PHASES:
        if status == "SKIPPED_NOT_TRIGGERED":
            raise IAInvestigadoraViolation("NONCONDITIONAL_PHASE_CANNOT_BE_SKIPPED")
        return
    t = payload.get("trigger_material_evaluation") or {}
    trigger = t.get("trigger_material")
    if status == "SKIPPED_NOT_TRIGGERED":
        if trigger is not False:
            raise IAInvestigadoraViolation("CONDITIONAL_SKIP_REQUIRES_TRIGGER_FALSE")
        if len(str(t.get("why_not_applicable") or "").strip()) < 20:
            raise IAInvestigadoraViolation("CONDITIONAL_SKIP_REASON_TOO_WEAK")
    elif trigger is not True:
        raise IAInvestigadoraViolation("CONDITIONAL_EXECUTION_REQUIRES_TRIGGER_TRUE")


def validate_f5_sentinel(payload: dict[str, Any]) -> None:
    sentinel = payload.get("sentinel_coverage") or {}
    for side in ("away", "home"):
        rows = sentinel.get(side)
        if not isinstance(rows, list) or len(rows) != 9:
            raise IAInvestigadoraViolation(f"F5_{side.upper()}_SENTINEL_1_9_REQUIRED")
        slots = []
        for row in rows:
            if not isinstance(row, dict) or not row.get("player_state"):
                raise IAInvestigadoraViolation(f"F5_{side.upper()}_SENTINEL_STRUCTURE_REQUIRED")
            try:
                slots.append(int(row.get("slot")))
            except (TypeError, ValueError):
                raise IAInvestigadoraViolation(f"F5_{side.upper()}_SENTINEL_SLOT_INVALID")
        if sorted(slots) != list(range(1, 10)):
            raise IAInvestigadoraViolation(f"F5_{side.upper()}_SLOTS_1_9_REQUIRED")


def validate_f12_payload(payload: dict[str, Any]) -> None:
    if str(payload.get("mandatory_phases_not_run") or "").upper() != "NONE":
        raise IAInvestigadoraViolation("F12_MANDATORY_PHASES_NOT_RUN")
    if payload.get("core_mission_complete") is not True:
        raise IAInvestigadoraViolation("F12_CORE_MISSION_NOT_PASS")
    if str(payload.get("drive_report_complete") or "").upper() != "PASS":
        raise IAInvestigadoraViolation("F12_DRIVE_REPORT_INCOMPLETE")
    if str(payload.get("chat_report_complete") or "").upper() != "PASS":
        raise IAInvestigadoraViolation("F12_CHAT_REPORT_INCOMPLETE")
    if payload.get("ready_for_handoff") is not True:
        raise IAInvestigadoraViolation("F12_NOT_READY_FOR_HANDOFF")
    if not payload.get("final_sports_store"):
        raise IAInvestigadoraViolation("F12_FINAL_SPORTS_STORE_REQUIRED")


def validate_phase_submission(*, phase_id: str, status: str, game_id: str, payload: dict[str, Any], completed: set[str]) -> None:
    forbid_decision_fields(payload)
    validate_target_binding(payload, game_id)
    validate_phase_order(completed, phase_id)
    receipt = payload.get("phase_execution_receipt")
    if not isinstance(receipt, dict):
        raise IAInvestigadoraViolation("E1_RECEIPT_REQUIRED")
    validate_receipt(phase_id, status, receipt)
    validate_conditional_phase(phase_id, status, payload)
    if phase_id == "F5":
        validate_f5_sentinel(payload)
    if phase_id == "F12":
        validate_f12_payload(payload)
