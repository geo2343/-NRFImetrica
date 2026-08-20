from __future__ import annotations

from typing import Any

AGENT_ID = "@AnalistaaNRFI"
AGENT_VERSION = "ANALISTAANRFI-AGENT-2.2"
SYSTEM_VERSION = "MLB-SYSTEM-V2"
KERNEL_VERSION = "MLB-V2-KERNEL-0.3-HARDENED"
PROTOCOL_ID = "ANALISTAANRFI_MLB_V2"
MOTHER_DOCUMENT_SHA256 = "c8511961eb94b90296163dc52056b4b217d2f8d6c459a1ebade5b80c5417f548"
PHASE_ORDER = tuple(f"A{i}" for i in range(1, 10))
RUN_PHASES = tuple(f"A{i}" for i in range(1, 9))
MISSION_PHASES = ("A9",)
SPORTS_STATES = {"NRFI_STRONG", "NRFI_PLAYABLE", "NRFI_NOT_SUPPORTED", "CRITICAL_DATA_BLOCK"}
FORBIDDEN_A8_KEYS = {
    "sportsbook", "current_nrfi_price", "current_yrfi_price", "opening_nrfi_price",
    "opening_yrfi_price", "price_status", "market_movement", "market_direction",
    "betting_verdict", "edge", "ev", "fair_price", "fair_odds", "probability", "p_nrfi",
}
FORBIDDEN_A9_KEYS = {
    "probability", "p_nrfi", "edge", "ev", "fair_price", "fair_odds",
    "calibrated_probability", "sports_reanalysis",
}
A9_MARKET_FIELDS = {
    "game_id", "sportsbook", "market", "current_nrfi_price", "current_yrfi_price",
    "snapshot_time", "market_movement", "market_direction", "price_status",
    "data_freshness", "source",
}


class AnalistaaNRFIViolation(ValueError):
    pass


def _walk_keys(value: Any):
    if isinstance(value, dict):
        for key, child in value.items():
            yield str(key).lower()
            yield from _walk_keys(child)
    elif isinstance(value, list):
        for child in value:
            yield from _walk_keys(child)


def _require_keys(payload: dict[str, Any], required: set[str], code: str) -> None:
    missing = sorted(required - set(payload))
    if missing:
        raise AnalistaaNRFIViolation(f"{code}:" + ",".join(missing))


def validate_phase_order(completed: set[str], phase_id: str) -> None:
    if phase_id not in PHASE_ORDER:
        raise AnalistaaNRFIViolation("UNKNOWN_PHASE")
    idx = PHASE_ORDER.index(phase_id)
    missing = [p for p in PHASE_ORDER[:idx] if p not in completed]
    if missing:
        raise AnalistaaNRFIViolation("PHASE_PREREQUISITES_INCOMPLETE:" + ",".join(missing))


def validate_requirement_coverage(binding_requirement_ids: set[str], states: dict[str, str], evaluated: set[str]) -> None:
    missing_state = sorted(binding_requirement_ids - set(states))
    if missing_state:
        raise AnalistaaNRFIViolation("BINDING_REQUIREMENT_STATE_MISSING:" + ",".join(missing_state))
    not_executed = sorted(r for r in binding_requirement_ids if states.get(r) == "NOT_EXECUTED")
    if not_executed:
        raise AnalistaaNRFIViolation("BINDING_REQUIREMENT_NOT_EXECUTED:" + ",".join(not_executed))
    missing_eval = sorted(binding_requirement_ids - evaluated)
    if missing_eval:
        raise AnalistaaNRFIViolation("REQUIREMENTS_EVALUATED_INCOMPLETE:" + ",".join(missing_eval))


def validate_a1(output: dict[str, Any], certified_handoff: bool) -> None:
    if not certified_handoff:
        raise AnalistaaNRFIViolation("A1_CERTIFIED_HANDOFF_REQUIRED")
    _require_keys(output, {"provenance_analyst_packet", "target_binding"}, "A1_OUTPUTS_INCOMPLETE")


def validate_a2_a3(phase_id: str, output: dict[str, Any]) -> None:
    side = "away" if phase_id == "A2" else "home"
    required = {
        f"{side}_starter_causal_packet", "current_version", "three_out_architecture",
        "traffic_architecture", "material_failure_routes", "best_supported_rival", "second_analytical_pass",
    }
    _require_keys(output, required, f"{phase_id}_OUTPUTS_INCOMPLETE")
    if {"top_half_status", "bottom_half_status", "sports_state", "betting_verdict"} & set(output):
        raise AnalistaaNRFIViolation(f"{phase_id}_PREMATURE_VERDICT")


def _validate_b1_b5(value: Any, phase_id: str) -> None:
    if not isinstance(value, list) or len(value) != 5:
        raise AnalistaaNRFIViolation(f"{phase_id}_B1_B5_EXACTLY_5")


def validate_a4(output: dict[str, Any], run_id: str, game_id: str) -> None:
    _require_keys(output, {"top_half_causal_packet", "b1_b5", "material_run_routes", "best_supported_rival", "positive_containment_case", "red_team_result", "second_analytical_pass", "top_half_seal"}, "A4_OUTPUTS_INCOMPLETE")
    _validate_b1_b5(output["b1_b5"], "A4")
    if not isinstance(output["material_run_routes"], list) or not output["material_run_routes"]:
        raise AnalistaaNRFIViolation("A4_MATERIAL_RUN_ROUTE_REQUIRED")
    for key in ("best_supported_rival", "positive_containment_case", "red_team_result"):
        if not output.get(key):
            raise AnalistaaNRFIViolation("A4_CAUSAL_OR_REDTEAM_CONTENT_EMPTY")
    seal = output["top_half_seal"]
    _require_keys(seal, {"game_id", "run_id", "lineup_version", "starter_version", "evidence_as_of", "evidence_hash", "causal_packet_hash", "top_half_status", "material_route_open", "contradiction_open", "red_team_pass", "seal_state"}, "A4_SEAL_FIELDS_INCOMPLETE")
    if str(seal["run_id"]) != str(run_id) or str(seal["game_id"]) != str(game_id):
        raise AnalistaaNRFIViolation("A4_SEAL_IDENTITY_MISMATCH")
    if seal["top_half_status"] == "TOP_HALF_PASS" and (
        bool(seal["material_route_open"]) or bool(seal["contradiction_open"])
        or not bool(seal["red_team_pass"]) or seal["seal_state"] != "FINAL"
    ):
        raise AnalistaaNRFIViolation("A4_PASS_ILLEGAL_OPEN_ROUTE_CONTRADICTION_OR_REDTEAM")


def validate_a5(output: dict[str, Any], run_id: str, game_id: str) -> None:
    _require_keys(output, {"bottom_half_causal_packet", "b1_b5", "material_run_routes", "best_supported_rival", "positive_containment_case", "red_team_result", "second_analytical_pass", "bottom_half_seal"}, "A5_OUTPUTS_INCOMPLETE")
    _validate_b1_b5(output["b1_b5"], "A5")
    if not isinstance(output["material_run_routes"], list) or not output["material_run_routes"]:
        raise AnalistaaNRFIViolation("A5_MATERIAL_RUN_ROUTE_REQUIRED")
    for key in ("best_supported_rival", "positive_containment_case", "red_team_result"):
        if not output.get(key):
            raise AnalistaaNRFIViolation("A5_CAUSAL_OR_REDTEAM_CONTENT_EMPTY")
    seal = output["bottom_half_seal"]
    _require_keys(seal, {"game_id", "run_id", "lineup_version", "starter_version", "evidence_as_of", "evidence_hash", "causal_packet_hash", "bottom_half_status", "material_route_open", "material_contradiction_open", "red_team_result", "seal_state"}, "A5_SEAL_FIELDS_INCOMPLETE")
    if str(seal["run_id"]) != str(run_id) or str(seal["game_id"]) != str(game_id):
        raise AnalistaaNRFIViolation("A5_SEAL_IDENTITY_MISMATCH")
    if seal["bottom_half_status"] == "BOTTOM_HALF_PASS" and (
        bool(seal["material_route_open"]) or bool(seal["material_contradiction_open"])
        or seal["red_team_result"] != "PASS" or seal["seal_state"] != "FINAL"
    ):
        raise AnalistaaNRFIViolation("A5_PASS_ILLEGAL_OPEN_ROUTE_CONTRADICTION_OR_REDTEAM")


def validate_a6(output: dict[str, Any]) -> None:
    _require_keys(output, {"context_packet", "context_delta", "revalidation", "top_half_seal_v2", "bottom_half_seal_v2", "second_contextual_pass", "red_team_contextual"}, "A6_OUTPUTS_INCOMPLETE")
    if bool(output.get("context_delta", {}).get("material_change")) and not bool(output.get("revalidation", {}).get("selective_reopen_performed")):
        raise AnalistaaNRFIViolation("A6_MATERIAL_CHANGE_REQUIRES_SELECTIVE_REOPEN")


def validate_a7(output: dict[str, Any]) -> None:
    _require_keys(output, {"normalized_evidence_layer", "analytical_claim_audit", "route_technical_integrity", "neutralization_audit", "second_normalization_pass", "red_team_technical", "top_half_seal_v3", "bottom_half_seal_v3", "a7_state"}, "A7_OUTPUTS_INCOMPLETE")
    allowed = {"A7_TECHNICALLY_VALIDATED", "A7_VALIDATED_WITH_LIMITS", "A7_SELECTIVE_RECONSTRUCTION_COMPLETED", "A7_CRITICAL_TECHNICAL_UNRESOLVED"}
    if output["a7_state"] not in allowed:
        raise AnalistaaNRFIViolation("A7_STATE_INVALID")


def validate_a8(output: dict[str, Any]) -> None:
    forbidden = sorted(set(_walk_keys(output)) & FORBIDDEN_A8_KEYS)
    if forbidden:
        raise AnalistaaNRFIViolation("A8_MARKET_OR_NUMERIC_FIELD_FORBIDDEN:" + ",".join(forbidden))
    _require_keys(output, {"a8_final_sports_packet", "sports_state", "top_state", "bottom_state", "what_really_governs", "best_argument_for_nrfi", "best_argument_against_nrfi", "governing_uncertainty", "sports_analysis_frozen"}, "A8_OUTPUTS_INCOMPLETE")
    if output["sports_state"] not in SPORTS_STATES:
        raise AnalistaaNRFIViolation("A8_SPORTS_STATE_INVALID")
    if output["sports_analysis_frozen"] is not True:
        raise AnalistaaNRFIViolation("A8_FREEZE_REQUIRED")
    for key in ("what_really_governs", "best_argument_for_nrfi", "best_argument_against_nrfi"):
        if not str(output.get(key) or "").strip():
            raise AnalistaaNRFIViolation("A8_GOVERNING_ARGUMENTS_REQUIRED")


def validate_a9_game_packet(packet: dict[str, Any], frozen_sports_state: str, frozen_hash: str) -> None:
    forbidden = sorted(set(_walk_keys(packet)) & FORBIDDEN_A9_KEYS)
    if forbidden:
        raise AnalistaaNRFIViolation("A9_UNCERTIFIED_NUMERIC_OR_REANALYSIS_FIELD_FORBIDDEN:" + ",".join(forbidden))
    _require_keys(packet, {"analyst_run_id", "game_id", "sports_state", "sports_freeze_hash", "betting_verdict"}, "A9_GAME_PACKET_FIELDS_INCOMPLETE")
    if packet["sports_state"] != frozen_sports_state or packet["sports_freeze_hash"] != frozen_hash:
        raise AnalistaaNRFIViolation("A9_CANNOT_REWRITE_A8")
    if frozen_sports_state == "NRFI_NOT_SUPPORTED" and packet["betting_verdict"] != "PASS_SPORTS":
        raise AnalistaaNRFIViolation("A9_NOT_SUPPORTED_MUST_PASS_SPORTS")
    if frozen_sports_state == "CRITICAL_DATA_BLOCK" and packet["betting_verdict"] != "BLOCKED_DATA":
        raise AnalistaaNRFIViolation("A9_CRITICAL_BLOCK_MUST_BLOCK_DATA")
    if frozen_sports_state in {"NRFI_STRONG", "NRFI_PLAYABLE"}:
        _require_keys(packet, {"market_packet", "price_status"}, "A9_MARKET_PACKET_REQUIRED_FOR_PLAYABLE_SPORTS")
        market = packet["market_packet"]
        if not isinstance(market, dict):
            raise AnalistaaNRFIViolation("A9_MARKET_PACKET_MINIMUM_FIELDS_INCOMPLETE")
        _require_keys(market, A9_MARKET_FIELDS, "A9_MARKET_PACKET_MINIMUM_FIELDS_INCOMPLETE")
        if str(market.get("game_id")) != str(packet.get("game_id")) or str(market.get("market", "")).upper() != "NRFI":
            raise AnalistaaNRFIViolation("A9_MARKET_PACKET_IDENTITY_INVALID")
        if packet["price_status"] != "PRICE_NOT_CERTIFIABLE":
            _require_keys(packet, {"price_policy_id", "price_policy_version"}, "A9_PRICE_POLICY_REQUIRED_FOR_CERTIFIED_PRICE_STATUS")


def validate_a9_outputs(*, game_packets: list[dict[str, Any]], eligible_count: int, qualified_bets_count: int, recommendations: list[Any]) -> None:
    if len(game_packets) != eligible_count:
        raise AnalistaaNRFIViolation("A9_GAME_PACKET_COVERAGE_MISMATCH")
    recs = len(recommendations)
    if qualified_bets_count >= 2 and recs < 2:
        raise AnalistaaNRFIViolation("A9_MINIMUM_TWO_WHEN_AVAILABLE")
    if qualified_bets_count == 1 and recs != 1:
        raise AnalistaaNRFIViolation("A9_ONE_AVAILABLE_REPORT_ONE")
    if qualified_bets_count == 0 and recs != 0:
        raise AnalistaaNRFIViolation("A9_ZERO_AVAILABLE_NO_FABRICATION")


def validate_finalization(*, master_report_readback: bool, a9_terminal: bool, drive_report_complete: bool, chat_report_complete: bool, report_verdict_hash: str, chat_verdict_hash: str, pending_games: int) -> None:
    if not master_report_readback:
        raise AnalistaaNRFIViolation("FINAL_MASTER_REPORT_READBACK_REQUIRED")
    if not a9_terminal:
        raise AnalistaaNRFIViolation("FINAL_A9_TERMINAL_REQUIRED")
    if not drive_report_complete or not chat_report_complete:
        raise AnalistaaNRFIViolation("FINAL_DRIVE_AND_CHAT_REQUIRED")
    if report_verdict_hash != chat_verdict_hash:
        raise AnalistaaNRFIViolation("FINAL_DRIVE_CHAT_VERDICT_MISMATCH")
    if pending_games:
        raise AnalistaaNRFIViolation("FINAL_UNIVERSE_PENDING")
