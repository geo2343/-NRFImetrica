from __future__ import annotations

from datetime import datetime
from typing import Any, Mapping, Sequence

AGENT_ID = "@NRFiPrensa"
AGENT_VERSION = "V0.2-AGENT-1.4"
PROTOCOL_ID = "SO_MEDIA_NRFI_V02"
KERNEL_VERSION = "NRFIPRENSA-KERNEL-0.5-PRESS-DELTA-HANDOFF"
HANDOFF_CONTRACT_VERSION = "PRESS_METRICA_DELTA-1.0"
DOCUMENT_SHA256 = "e86937278245d6e14c96b16be30085884d1bde4e0b1de9a1eb7e5adc30b427ca"
DOCUMENT_LINES = 1544
SYSTEM_STATE = "RESEARCH_ONLY_TRADING_HALT"
REAL_MONEY_AUTHORITY = False
MAX_TRANSFER_CANDIDATES = 3

PHASES = ("F0", "F1", "F2", "F3", "F4", "F5", "F6", "F7", "F8", "F9", "F10")
REVIEW_PRIORITIES = ("REVIEW_PRIORITY_1", "REVIEW_PRIORITY_2", "REVIEW_PRIORITY_3")
F8_ALLOWED = ("SO_MEDIA_POSITIVE_NRFI", "SO_MEDIA_BALANCED", "SO_MEDIA_ADVERSE_NRFI", "SO_MEDIA_UNCERTIFIED")
RED_TEAM_FINAL_OK = ("RED_TEAM_CLEAR", "RED_TEAM_MATERIAL")
PACK_P_CLEAN = "PACK_P_CLEAN"
PACK_P_INTERPRETATION = "PACK_P_INTERPRETATION"

DELTA_CLASSES = {
    "STARTER_STATUS_DELTA", "VELOCITY_DELTA", "ARSENAL_DELTA", "COMMAND_DELTA",
    "MECHANICAL_DELTA", "HEALTH_DELTA", "ROLE_DELTA", "LINEUP_DELTA",
    "BATTER_HEALTH_DELTA", "CATCHER_DELTA", "ROOF_WEATHER_DELTA",
    "UMPIRE_CONTEXT_DELTA", "OTHER_MATERIAL_DELTA",
}
METRICA_DISPOSITIONS = {
    "INTEGRATED_GOVERNING", "INTEGRATED_MATERIAL", "INTEGRATED_MODULATOR",
    "CONTEXT_ONLY", "DESCRIPTIVE_ONLY", "REFUTED_BY_METRICS", "STALE",
    "DUPLICATE_EXISTING_INFORMATION", "NOT_NRFI_RELEVANT", "UNRESOLVED",
}
PACK_P_CLEAN_REQUIRED_ITEM_KEYS = {
    "press_evidence_id", "delta_class", "object_name", "half_affected", "fact",
    "source_original", "source_family_id", "as_of", "fact_status", "fact_confidence",
    "current_version_relevance", "freshness_status", "source_url", "new_state",
    "changed_object", "materiality_question",
}
PACK_P_CLEAN_FORBIDDEN_KEYS = {
    "external_picks", "picks", "consensus", "odds", "line_movement", "movement",
    "review_priority", "shortlist", "jrc", "jrc_status", "so_media_status",
    "f8_conclusion", "candidate_rank", "p_nrfi", "model_probability", "edge", "ev",
    "stake", "bet_amount", "final_pick", "nrfi_materiality", "materiality_answer",
    "press_verdict", "best_press_nrfi_case", "best_press_yrfi_case",
    "press_vulnerable_half", "press_breakpoints", "external_analyst_arguments",
}
INTERPRETATION_REQUIRED_KEYS = {
    "so_media_view", "best_press_nrfi_case", "best_press_yrfi_case",
    "press_vulnerable_half", "press_breakpoints", "external_analyst_arguments",
}
FORBIDDEN_EXECUTION_KEYS = {
    "p_nrfi", "model_probability", "edge", "ev", "stake", "bet_amount",
    "execution_authority", "final_pick",
}
PACK_I_FORBIDDEN_KEYS = {
    "external_picks", "picks", "consensus", "odds", "line_movement", "movement",
    "review_priority", "shortlist", "jrc", "jrc_status", "so_media_status",
    "f8_conclusion", "candidate_rank",
}


def _has_forbidden_key(value: Any, forbidden: set[str]) -> bool:
    if isinstance(value, Mapping):
        for key, child in value.items():
            if str(key).lower() in forbidden or _has_forbidden_key(child, forbidden):
                return True
    elif isinstance(value, Sequence) and not isinstance(value, (str, bytes, bytearray)):
        return any(_has_forbidden_key(child, forbidden) for child in value)
    return False


def validate_transfer_count(count: int) -> None:
    if count < 0 or count > MAX_TRANSFER_CANDIDATES:
        raise ValueError("NRFIPRENSA_MAX_THREE_TRANSFER_CANDIDATES")


def validate_research_only_language(*, disposition: str, final_seal: str | None) -> None:
    if disposition in REVIEW_PRIORITIES and final_seal != "PASS":
        raise ValueError("NRFIPRENSA_REVIEW_PRIORITY_REQUIRES_FINAL_PREGAME_SEAL_PASS")


def validate_f8_status(status: str) -> None:
    if status == "SO_MEDIA_STRONG_NRFI":
        raise ValueError("NRFIPRENSA_STRONG_DISABLED_WHILE_RESEARCH_ONLY")
    if status not in F8_ALLOWED:
        raise ValueError(f"NRFIPRENSA_F8_STATUS_INVALID:{status}")


def validate_pack_p_clean(payload: Mapping[str, Any]) -> None:
    """PACK-P CLEAN carries facts/deltas, never Press's answer to the sports question."""
    if payload.get("packet_type") != PACK_P_CLEAN:
        raise ValueError("NRFIPRENSA_PACK_P_CLEAN_TYPE_REQUIRED")
    for key in ("sports_authority", "probability_authority", "ranking_authority", "market_authority", "conclusion_authority"):
        if payload.get(key, "NONE") != "NONE":
            raise ValueError(f"NRFIPRENSA_PACK_P_CLEAN_AUTHORITY_FORBIDDEN:{key}")
    if _has_forbidden_key(payload, PACK_P_CLEAN_FORBIDDEN_KEYS):
        raise ValueError("NRFIPRENSA_PACK_P_CLEAN_INTERPRETIVE_OR_MARKET_CONTAMINATION")
    items = payload.get("items")
    if not isinstance(items, list) or not items:
        raise ValueError("NRFIPRENSA_PACK_P_CLEAN_ITEMS_REQUIRED")
    for item in items:
        if not isinstance(item, Mapping):
            raise ValueError("NRFIPRENSA_PACK_P_CLEAN_ITEM_OBJECT_REQUIRED")
        missing = sorted(k for k in PACK_P_CLEAN_REQUIRED_ITEM_KEYS if not str(item.get(k, "")).strip())
        if missing:
            raise ValueError("NRFIPRENSA_PACK_P_CLEAN_ITEM_MISSING:" + ",".join(missing))
        if item["delta_class"] not in DELTA_CLASSES:
            raise ValueError("NRFIPRENSA_PACK_P_CLEAN_DELTA_CLASS_INVALID")
        if item["half_affected"] not in {"TOP_1ST", "BOTTOM_1ST", "SHARED"}:
            raise ValueError("NRFIPRENSA_PACK_P_CLEAN_HALF_INVALID")
        if item["delta_class"] == "LINEUP_DELTA" and not str(item.get("lineup_version_id", "")).strip():
            raise ValueError("NRFIPRENSA_LINEUP_DELTA_REQUIRES_LINEUP_VERSION_ID")
        if "materiality_answer" in item or "nrfi_materiality" in item:
            raise ValueError("NRFIPRENSA_CLEAN_MATERIALITY_QUESTION_NOT_ANSWER")


def validate_selective_deep(*, triggered: bool, reason: str | None, deep_metrics_payload: Mapping[str, Any]) -> str:
    if triggered:
        if not reason or len(reason.strip()) < 20:
            raise ValueError("NRFIPRENSA_DEEP_VERIFICATION_REQUIRES_TRIGGER_REASON")
        if not deep_metrics_payload:
            raise ValueError("NRFIPRENSA_TRIGGERED_DEEP_VERIFICATION_REQUIRES_PAYLOAD")
        return "SAFETY_PLUS_TRIGGERED_DEEP"
    if deep_metrics_payload:
        raise ValueError("NRFIPRENSA_DEEP_METRICS_FORBIDDEN_WITHOUT_TRIGGER")
    return "SAFETY_CORE"


def validate_interpretation_release(
    *,
    press_f8_frozen: bool,
    metrica_freeze_timestamp: datetime | None,
    metrica_packet_hash: str | None,
    released_at: datetime,
    payload: Mapping[str, Any],
) -> None:
    if not press_f8_frozen:
        raise ValueError("NRFIPRENSA_INTERPRETATION_REQUIRES_PRESS_F8_FROZEN")
    if metrica_freeze_timestamp is None or not metrica_packet_hash:
        raise ValueError("NRFIPRENSA_INTERPRETATION_FORBIDDEN_BEFORE_METRICA_FREEZE")
    if released_at < metrica_freeze_timestamp:
        raise ValueError("NRFIPRENSA_INTERPRETATION_RELEASE_BEFORE_METRICA_FREEZE_FORBIDDEN")
    missing = sorted(k for k in INTERPRETATION_REQUIRED_KEYS if k not in payload)
    if missing:
        raise ValueError("NRFIPRENSA_INTERPRETATION_REQUIRED_FIELDS_MISSING:" + ",".join(missing))
    if _has_forbidden_key(payload, {"odds", "line_movement", "movement", "stake", "ev", "bet_amount", "review_priority", "candidate_rank"}):
        raise ValueError("NRFIPRENSA_INTERPRETATION_MARKET_OR_RANKING_CONTAMINATION")


def material_delta_transfer_required(*, f6_result: str, f7_materiality: str) -> bool:
    return f6_result in {"CONFIRMADA", "PARCIALMENTE_CONFIRMADA"} and f7_materiality in {"GOVERNING_NRFI", "MATERIAL_NRFI"}


def doctrine() -> str:
    return (
        "PRESS_DISCOVERS_DELTA -> F6_VERIFIES_FACT -> PACK_P_CLEAN -> "
        "METRICA_INDEPENDENT_ANALYSIS -> METRICA_FREEZE -> PACK_P_INTERPRETATION -> "
        "CONFRONTATION; PRESS_NEVER_TRANSFERS_A_PICK_OR_GAME_PROBABILITY"
    )
