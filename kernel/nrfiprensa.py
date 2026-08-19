from __future__ import annotations

AGENT_ID = "@NRFiPrensa"
AGENT_VERSION = "V0.2-AGENT-1.0"
PROTOCOL_ID = "SO_MEDIA_NRFI_V02"
KERNEL_VERSION = "NRFIPRENSA-KERNEL-0.1-RESEARCH-CUSTODY"
DOCUMENT_SHA256 = "a6ed0be85ea66750dbea7e3deafe717675433a78d141f0656688421e15dacbac"
SYSTEM_STATE = "RESEARCH_ONLY_TRADING_HALT"
REAL_MONEY_AUTHORITY = False
MAX_TRANSFER_CANDIDATES = 3

PHASES = ("F0", "F1", "F2", "F3", "F4", "F5", "F6", "F7", "F8", "F9", "F10")
REVIEW_PRIORITIES = ("REVIEW_PRIORITY_1", "REVIEW_PRIORITY_2", "REVIEW_PRIORITY_3")
F8_ALLOWED = ("SO_MEDIA_POSITIVE_NRFI", "SO_MEDIA_BALANCED", "SO_MEDIA_ADVERSE_NRFI", "SO_MEDIA_UNCERTIFIED")
RED_TEAM_FINAL_OK = ("RED_TEAM_CLEAR", "RED_TEAM_MATERIAL")

FORBIDDEN_EXECUTION_KEYS = {
    "p_nrfi", "model_probability", "edge", "ev", "stake", "bet_amount",
    "execution_authority", "final_pick",
}
PACK_I_FORBIDDEN_KEYS = {
    "external_picks", "picks", "consensus", "odds", "line_movement", "movement",
    "review_priority", "shortlist", "jrc", "jrc_status", "so_media_status",
    "f8_conclusion", "candidate_rank",
}


def validate_transfer_count(count: int) -> None:
    if count < 0 or count > MAX_TRANSFER_CANDIDATES:
        raise ValueError("NRFIPRENSA_MAX_THREE_TRANSFER_CANDIDATES")


def validate_research_only_language(*, disposition: str, final_seal: str | None) -> None:
    if disposition in REVIEW_PRIORITIES and final_seal != "PASS":
        raise ValueError("NRFIPRENSA_REVIEW_PRIORITY_REQUIRES_FINAL_PREGAME_SEAL_PASS")
    if disposition == "HOLD_DYNAMIC":
        return


def validate_f8_status(status: str) -> None:
    if status == "SO_MEDIA_STRONG_NRFI":
        raise ValueError("NRFIPRENSA_STRONG_DISABLED_WHILE_RESEARCH_ONLY")
    if status not in F8_ALLOWED:
        raise ValueError(f"NRFIPRENSA_F8_STATUS_INVALID:{status}")


def doctrine() -> str:
    return (
        "PRESS_DISCOVERS -> VERIFICATION_CONFIRMS_FACT -> METRICS_TEST_CLAIM -> "
        "NRFI_LAYER_TESTS_FIRST_SIX_OUTS_MATERIALITY -> F8_FREEZES_INDEPENDENTLY -> "
        "F9_CONFRONTS_JRC -> F10_TRANSFERS_WITHOUT_BETTING_AUTHORITY"
    )
