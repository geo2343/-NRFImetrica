from __future__ import annotations

import hashlib
import json
from typing import Any, Iterable

AGENT_ID = "@Investigarfullunder"
AGENT_VERSION = "INVESTIGARFULLUNDER-AGENT-1.2"
KERNEL_VERSION = "FULLUNDER-RESEARCH-KERNEL-1.2-CONTROL-PLANE"
EDGE_KERNEL_VERSION = "FULLUNDER-EDGE-KERNEL-1.2-COMMAND-BUS"
CONTROL_PLANE_VERSION = "FULLUNDER-CONTROL-PLANE-1.2"
POLICY_VERSION = "IFU-POLICY-1.2"
PROTOCOL_ID = "INVESTIGARFULLUNDER_FULL_GAME_PREGAME_V1"
MOTHER_SHA256 = "18da7c034b9c2ff156b063ac1a12cc7f62b556c0bec55832d79a70c9246ab4de"
HANDOFF_FORMAT_CONTRACT = "FULLUNDER-HANDOFF-FORMAT-1.1"
REQUIRED_HANDOFF_SECTIONS = tuple(f"{i:02d}" for i in range(1, 21))
PHASE_ORDER = tuple(f"F{i}" for i in range(1, 9))
REQUIREMENT_COUNTS = {"F1": 93, "F2": 127, "F3": 132, "F4": 98, "F5": 159, "F6": 112, "F7": 122, "F8": 46}
TOTAL_REQUIREMENTS = sum(REQUIREMENT_COUNTS.values())

CONTROL_PLANE_PRINCIPLE = "KERNEL_CONTROLS_PROCESS_AI_CONTROLS_REASONING"
WRITE_MODEL = "LLM_PROPOSES_KERNEL_VALIDATES_KERNEL_COMMITS"

MARKET_KEYS = {
    "odds", "juice", "line_movement", "betting_consensus", "sportsbook",
    "market_total", "external_under_over_forecasts", "under_odds", "over_odds",
}
DECISION_KEYS = {
    "pick", "lean", "edge", "betting_value", "ev", "favors_under", "favors_over",
    "under_verdict", "over_verdict", "run_expectation", "will_score", "will_not_score",
    "good_matchup", "bad_matchup", "positive_for_under", "negative_for_under",
    "sports_decision", "bet_recommendation",
}
MARKET_TEXT = ("odds", "juice", "sportsbook", "betting consensus", "line movement", "market total", "betting line")

PHASE_ACTIONS = {
    **{f"F{i}": {
        "SET_REQUIREMENT_STATES", "REQUEST_TOOL", "COMPLETE_TOOL", "ADD_SOURCE", "ADD_EVIDENCE",
        "UPSERT_ISSUE", "UPSERT_CONTRADICTION", "ADD_DEPENDENCY", "INVALIDATE_DESCENDANTS",
        "RESOLVE_STALE", "SUBMIT_PHASE_RECEIPT",
    } for i in range(1, 9)},
    "POST_F8": {"REGISTER_ARTIFACT", "REGISTER_STRUCTURE_RECEIPT", "SUBMIT_HANDOFF", "PUBLISH", "SUBMIT_SEMANTIC_AUDIT"},
}
PHASE_ACTIONS["F8"].add("REGISTER_ARTIFACT")


class InvestigarFullUnderViolation(ValueError):
    pass


def _walk_keys(value: Any) -> Iterable[str]:
    if isinstance(value, dict):
        for key, child in value.items():
            yield str(key).lower()
            yield from _walk_keys(child)
    elif isinstance(value, list):
        for child in value:
            yield from _walk_keys(child)


def validate_no_market_or_decision_contamination(payload: dict[str, Any]) -> None:
    keys = set(_walk_keys(payload))
    market = sorted(keys & MARKET_KEYS)
    if market:
        raise InvestigarFullUnderViolation("MARKET_CONTAMINATION:" + ",".join(market))
    decision = sorted(keys & DECISION_KEYS)
    if decision:
        raise InvestigarFullUnderViolation("SPORTS_DECISION_CONTAMINATION:" + ",".join(decision))
    text = json.dumps(payload, ensure_ascii=False).lower()
    if any(term in text for term in MARKET_TEXT):
        raise InvestigarFullUnderViolation("MARKET_TEXT_CONTAMINATION")


def validate_command_envelope(
    envelope: dict[str, Any], *, current_state_version: int | None,
    active_phase: str | None, capability_active: bool, active_policy_version: str = POLICY_VERSION,
) -> None:
    if envelope.get("agent_id") != AGENT_ID:
        raise InvestigarFullUnderViolation("COMMAND_AGENT_INVALID")
    action = str(envelope.get("action") or "").upper()
    if not action or not str(envelope.get("idempotency_key") or "").strip():
        raise InvestigarFullUnderViolation("COMMAND_ENVELOPE_INCOMPLETE")
    if envelope.get("policy_version") != active_policy_version:
        raise InvestigarFullUnderViolation("STALE_OR_UNKNOWN_POLICY")
    if action == "CREATE_RUN":
        if envelope.get("run_id") or envelope.get("capability_grant_id"):
            raise InvestigarFullUnderViolation("CREATE_RUN_ENVELOPE_INVALID")
        return
    if active_phase is None or envelope.get("phase_id") != active_phase:
        raise InvestigarFullUnderViolation("ACTIVE_PHASE_MISMATCH")
    if envelope.get("expected_state_version") != current_state_version:
        raise InvestigarFullUnderViolation("EXPECTED_STATE_VERSION_MISMATCH")
    if not capability_active:
        raise InvestigarFullUnderViolation("CAPABILITY_INVALID_OR_EXPIRED")
    if action not in PHASE_ACTIONS.get(active_phase, set()):
        raise InvestigarFullUnderViolation("CAPABILITY_ACTION_FORBIDDEN")


def validate_evidence_broker_lineage(*, origin: str, run_id: str, phase_id: str, tool_events: list[dict[str, Any]]) -> None:
    if origin.upper() in {"USER_PROVIDED", "SYSTEM_DERIVED"}:
        return
    if not tool_events:
        raise InvestigarFullUnderViolation("TOOL_EVENT_REQUIRED_FOR_EXTERNAL_EVIDENCE")
    for event in tool_events:
        if event.get("run_id") != run_id or event.get("phase_id") != phase_id or event.get("status") != "SUCCEEDED":
            raise InvestigarFullUnderViolation("TOOL_EVENT_INVALID_FOR_EVIDENCE")


def validate_phase_order(phase_cursor: int, phase_id: str) -> None:
    expected = f"F{phase_cursor + 1}"
    if phase_id != expected:
        raise InvestigarFullUnderViolation(f"PHASE_ORDER:{expected}:{phase_id}")


def validate_requirement_coverage(phase_id: str, states: list[dict[str, Any]]) -> None:
    expected = REQUIREMENT_COUNTS[phase_id]
    if len(states) != expected:
        raise InvestigarFullUnderViolation(f"REQUIREMENT_COVERAGE:{expected}:{len(states)}")
    for state in states:
        status = state.get("status")
        if status == "NOT_EXECUTED":
            raise InvestigarFullUnderViolation("REQUIRED_NOT_EXECUTED")
        if status == "SATISFIED" and not (state.get("evidence_refs") or state.get("output_refs")):
            raise InvestigarFullUnderViolation("SATISFIED_WITHOUT_REFERENCE")
        if status in {"NOT_APPLICABLE_WITH_REASON", "UNRESOLVED_AFTER_DOCUMENTED_RECOVERY"} and not str(state.get("reason") or "").strip():
            raise InvestigarFullUnderViolation("REQUIREMENT_REASON_REQUIRED")


def _require_true(payload: dict[str, Any], keys: Iterable[str], code: str) -> None:
    missing = [key for key in keys if payload.get(key) is not True]
    if missing:
        raise InvestigarFullUnderViolation(code + ":" + ",".join(missing))


def validate_phase_payload(phase_id: str, payload: dict[str, Any]) -> None:
    validate_no_market_or_decision_contamination(payload)
    if phase_id == "F1":
        _require_true(payload, ("game_constitution_packet", "previous_game_context"), "F1_INCOMPLETE")
        if int(payload.get("research_questions_opened", 0)) < 2 or payload.get("critical_identity_unresolved") is True:
            raise InvestigarFullUnderViolation("F1_INCOMPLETE")
    elif phase_id in {"F2", "F3"}:
        expected_side = "AWAY_PRODUCING" if phase_id == "F2" else "HOME_PRODUCING"
        if payload.get("side") != expected_side or int(payload.get("b1_b9_first_sweep_count", 0)) != 9:
            raise InvestigarFullUnderViolation("SIDE_DOSSIER_INCOMPLETE")
        _require_true(payload, (
            "first_sweep_complete", "selective_second_sweep_complete", "b6_b9_omission_check",
            "starter_current_version", "batter_pitch_matchup_matrix", "bullpen_today_reconstructed",
            "previous_game_deep_reconstruction",
        ), "SIDE_DOSSIER_INCOMPLETE")
    elif phase_id == "F4":
        _require_true(payload, ("shared_context_complete",), "F4_CONTEXT_INVALID")
        if payload.get("environment_to_conclusion") is True:
            raise InvestigarFullUnderViolation("F4_CONTEXT_INVALID")
    elif phase_id == "F5":
        _require_true(payload, ("raw_preserved", "normalized_separate", "comparability_gate", "contradiction_register_complete"), "F5_NORMALIZATION_INCOMPLETE")
    elif phase_id == "F6":
        _require_true(payload, ("autonomous_research_sweep_complete", "deep_dive_records_complete"), "F6_AUTONOMY_INCOMPLETE")
        if int(payload.get("open_triggered_questions_ignored", 0)) != 0:
            raise InvestigarFullUnderViolation("F6_AUTONOMY_INCOMPLETE")
    elif phase_id == "F7":
        _require_true(payload, ("all_dynamic_objects_checked", "changes_propagated"), "F7_REVALIDATION_INVALID")
        if int(payload.get("recoverable_pending_ignored", 0)) != 0 or payload.get("first_pitch_occurred") is True:
            raise InvestigarFullUnderViolation("F7_REVALIDATION_INVALID")
    elif phase_id == "F8":
        _require_true(payload, (
            "dossier_built", "handoff_brief_built", "attention_map_built", "evidence_tensions_built",
            "neutral_signal_semantics", "legitimate_open_gaps_documented", "final_source_snapshot_reference",
        ), "F8_HANDOFF_INCOMPLETE")
        if int(payload.get("questions_analyst_must_resolve_count", 0)) < 1:
            raise InvestigarFullUnderViolation("F8_HANDOFF_INCOMPLETE")
    else:
        raise InvestigarFullUnderViolation("UNKNOWN_PHASE")


def validate_handoff_structure(structure: dict[str, Any]) -> None:
    if structure.get("format_contract_id") != HANDOFF_FORMAT_CONTRACT:
        raise InvestigarFullUnderViolation("HANDOFF_FORMAT_CONTRACT_INVALID")
    if structure.get("document_role") != "ANALYST_HANDOFF_BRIEF":
        raise InvestigarFullUnderViolation("HANDOFF_DOCUMENT_ROLE_INVALID")
    inventory = structure.get("section_inventory")
    if not isinstance(inventory, list) or len(inventory) != 20 or set(inventory) != set(REQUIRED_HANDOFF_SECTIONS):
        raise InvestigarFullUnderViolation("HANDOFF_SECTION_INVENTORY_INVALID")
    if int(structure.get("required_section_count", 0)) != 20:
        raise InvestigarFullUnderViolation("HANDOFF_SECTION_COUNT_INVALID")
    if int(structure.get("heading_count", 0)) < 20:
        raise InvestigarFullUnderViolation("HANDOFF_HEADINGS_INCOMPLETE")
    if int(structure.get("table_count", 0)) < 15:
        raise InvestigarFullUnderViolation("HANDOFF_TABLE_STRUCTURE_INCOMPLETE")
    if int(structure.get("bold_anchor_count", 0)) < 20:
        raise InvestigarFullUnderViolation("HANDOFF_BOLD_HIERARCHY_INCOMPLETE")
    if structure.get("visual_hierarchy_pass") is not True or structure.get("structure_readback_pass") is not True:
        raise InvestigarFullUnderViolation("HANDOFF_VISUAL_READBACK_REQUIRED")
    if not str(structure.get("structure_hash") or "").strip():
        raise InvestigarFullUnderViolation("HANDOFF_STRUCTURE_HASH_REQUIRED")


def compute_target_binding_hash(game_pk: int, away_team: str, home_team: str, utc_timestamp: str) -> str:
    raw = f"{game_pk}|{away_team.strip().upper()}|{home_team.strip().upper()}|{utc_timestamp}"
    return hashlib.sha256(raw.encode()).hexdigest()


def compute_handoff_hash(*, run_id: str, game_pk: int, dossier_hash: str, brief_hash: str, master_hash: str, structure_hash: str, target_binding_hash: str, mother_sha256: str = MOTHER_SHA256) -> str:
    raw = f"{run_id}|{game_pk}|{dossier_hash}|{brief_hash}|{master_hash}|{structure_hash}|{target_binding_hash}|{mother_sha256}"
    return hashlib.sha256(raw.encode()).hexdigest()


def validate_handoff(*, phase_cursor: int, receipt_count: int, artifacts: dict[str, dict[str, Any]], structure_receipt: dict[str, Any], source_snapshot_hash: str, handoff_hash: str, run_id: str, game_pk: int, target_binding_hash: str) -> None:
    if phase_cursor != 8 or receipt_count != 8:
        raise InvestigarFullUnderViolation("F1_F8_NOT_COMPLETE")
    required = ("FULL_UNDER_PREGAME_EVIDENCE_DOSSIER", "ANALYST_HANDOFF_BRIEF", "MASTER_RESEARCH_REPORT")
    if any(name not in artifacts for name in required):
        raise InvestigarFullUnderViolation("REQUIRED_ARTIFACTS_MISSING")
    for name in required:
        artifact = artifacts[name]
        if artifact.get("readback_pass") is not True or artifact.get("readback_hash") != artifact.get("content_hash"):
            raise InvestigarFullUnderViolation("ARTIFACT_READBACK_INVALID")
    validate_handoff_structure(structure_receipt)
    dossier_hash = artifacts[required[0]]["content_hash"]
    if source_snapshot_hash != dossier_hash:
        raise InvestigarFullUnderViolation("SOURCE_SNAPSHOT_HASH_MISMATCH")
    expected = compute_handoff_hash(
        run_id=run_id, game_pk=game_pk, dossier_hash=dossier_hash,
        brief_hash=artifacts[required[1]]["content_hash"], master_hash=artifacts[required[2]]["content_hash"],
        structure_hash=structure_receipt["structure_hash"], target_binding_hash=target_binding_hash,
    )
    if handoff_hash != expected:
        raise InvestigarFullUnderViolation("HANDOFF_HASH_INVALID")
