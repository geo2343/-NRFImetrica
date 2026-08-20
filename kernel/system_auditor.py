"""@AuditorSistema V1.1 process-compliance audit kernel.

Deterministic governance only. The auditor validates whether the target system
executed the authority that governed the selected RUN. It never redesigns the
target, never judges a sports result as process quality, and never repairs the
audited system during an AUDIT_RUN.
"""

from __future__ import annotations

from typing import Any, Mapping, Sequence

AUDITOR_AGENT_ID = "@AuditorSistema"
AUDITOR_AGENT_VERSION = "AUDITOR-SYSTEM-1.1"
AUDITOR_PROTOCOL_ID = "SYSTEM_AUDITOR_V1_1"
AUDITOR_KERNEL_VERSION = "SYSTEM-AUDITOR-KERNEL-1.1-TARGET-LOCK-FORENSIC"
AUDITOR_SCHEMA_VERSION = "V1.1"

READ_ONLY_TARGET = True
MAY_REPAIR_TARGET_DURING_AUDIT = False
MAY_REDESIGN_TARGET = False
NEW_AUDIT_RUN_PER_INVOCATION = True
NEW_DRIVE_FOLDER_PER_AUDIT = True
NEW_REPORT_PER_AUDIT = True
TARGET_LOCK_REQUIRED = True
FORENSIC_TRACE_REQUIRED = True
FORENSIC_CHAT_REPORT_REQUIRED = True
COMPLIANCE_ONLY_CORRECTIONS = True

TARGET_MENU = {
    "1": "@NRFiPrensa",
    "2": "@NRFImetrica",
    "3": "@DepuracionMLB",
    "4": "@investigacionNRFI",
    "5": "@ianalista",
}

TARGET_ALIASES = {
    "@nrfiprensa": "@NRFiPrensa",
    "@nrfimetrica": "@NRFImetrica",
    "@depuracionmlb": "@DepuracionMLB",
    "@mlbdepuracion": "@DepuracionMLB",
    "@mlbdepuración": "@DepuracionMLB",
    "@investigacionnrfi": "@investigacionNRFI",
    "@ianalista": "@ianalista",
    "@iaanalista": "@ianalista",
    "@iaanalissta": "@ianalista",
}

AUDIT_LAYERS = (
    "P0_TARGET_LOCK",
    "P1_AUTHORITY_AUDIT",
    "P2_CLEAN_ROOM_AUDIT",
    "P3_UNIVERSE_AUDIT",
    "P4_TOOL_EVIDENCE_AUDIT",
    "P5_PHASE_AUDIT",
    "P6_HARD_GATE_AUDIT",
    "P7_STATE_IDENTITY_AUDIT",
    "P8_ARTIFACT_HASH_AUDIT",
    "P9_CROSS_SYSTEM_CONSISTENCY",
    "P10_ADVERSARIAL_AUDIT",
    "P11_CLOSURE_AUDIT",
    "P12_VERDICT_AND_FORENSIC_CHAT_REPORT",
)

CHECK_STATUSES = (
    "PASS",
    "FAIL",
    "NOT_PROVEN",
    "NOT_APPLICABLE",
    "INCONSISTENT",
)

SEVERITIES = ("CRITICAL", "MAJOR", "MODERATE", "MINOR")

VERDICTS = (
    "PROCESS_VALIDATED",
    "PROCESS_VALIDATED_WITH_OBSERVATIONS",
    "PROCESS_INCOMPLETE",
    "PROCESS_INVALID",
    "STATE_MISREPRESENTATION",
    "AUDIT_BLOCKED",
)

TARGET_LOCK_STATUSES = (
    "UNRESOLVED",
    "CONFIRMED",
    "AMBIGUOUS",
    "MISMATCH",
    "LEGACY_UNVERIFIED",
)

FAILURE_MODES = (
    "NOT_EXECUTED",
    "PARTIALLY_EXECUTED",
    "EXECUTED_INCORRECTLY",
    "OUT_OF_ORDER",
    "WRONG_INPUT",
    "STALE_INPUT",
    "WRONG_AUTHORITY",
    "BYPASS",
    "FALSE_COMPLIANCE",
    "STATE_MISREPRESENTATION",
    "CONTAMINATION",
    "MISSING_ARTIFACT",
    "CROSS_SYSTEM_INCONSISTENCY",
    "AUTHORITY_CONFLICT",
    "TARGET_MISMATCH",
    "LEGACY_UNCLASSIFIED",
)

REQUIRED_TARGET_IDENTITY_KEYS = (
    "requested_reference",
    "requested_agent",
    "resolved_agent",
    "target_run_id",
    "target_scope",
    "target_report_locator",
    "target_match_basis",
)

FORENSIC_CHAT_REQUIRED_SECTIONS = (
    "target_identification",
    "authority_requirements",
    "chronological_reconstruction",
    "trace_matrix",
    "correct_processes",
    "root_failure",
    "propagation_map",
    "findings_explained",
    "p0_p12_matrix",
    "compliance_corrections",
    "retest",
)

UNIVERSAL_CHECK_IDS = (
    "SYS-P0-TARGET-IDENTITY",
    "SYS-P1-TARGET-TIME-AUTHORITY",
    "SYS-P10-FORENSIC-REPLAY",
    "SYS-P11-TRACE-COMPLETE",
    "SYS-P12-FORENSIC-CHAT-REPORT",
    "SYS-P12-COMPLIANCE-ONLY-CORRECTIONS",
)

SOVEREIGN_RULES = {
    "REPORT_TEXT_IS_NOT_PHYSICAL_PROOF": True,
    "PHYSICAL_STATE_BEATS_NARRATIVE": True,
    "SPORTS_RESULT_IS_NOT_PROCESS_VERDICT": True,
    "NO_TARGET_WRITE_DURING_AUDIT": True,
    "NO_TARGET_REDESIGN_BY_AUDITOR": True,
    "NO_HISTORICAL_RUN_AS_CURRENT_EVIDENCE": True,
    "NO_INVENTED_PHYSICAL_STATE": True,
    "WRONG_TARGET_INVALIDATES_AUDIT": True,
    "TARGET_LOCK_REQUIRED_BEFORE_P1": True,
    "AUTHORITY_MUST_BE_RESOLVED_FOR_TARGET_TIME": True,
    "OBJECT_EXISTS_DOES_NOT_PROVE_CORRECT_EXECUTION": True,
    "ROOT_FAILURE_MUST_BE_SEPARATED_FROM_DOWNSTREAM_EFFECTS": True,
    "FORENSIC_REPLAY_IS_READ_ONLY_AND_TIME_BOUNDED": True,
    "FORENSIC_CHAT_REPORT_IS_CLOSURE_PRODUCT": True,
    "CORRECTIONS_MUST_RESTORE_EXISTING_AUTHORITY_ONLY": True,
    "AUDIT_REPAIR_REAUDIT_ARE_SEPARATE_RUNS": True,
}


def target_prompt() -> str:
    return (
        "¿Qué sistema desea auditar?\n"
        "1 — @NRFiPrensa\n"
        "2 — @NRFImetrica\n"
        "3 — @DepuracionMLB\n"
        "4 — @investigacionNRFI\n"
        "5 — @ianalista"
    )


def normalize_target(value: str) -> str:
    value = value.strip()
    if value in TARGET_MENU:
        return TARGET_MENU[value]
    lowered = value.lower()
    if lowered in TARGET_ALIASES:
        return TARGET_ALIASES[lowered]
    raise ValueError("AUDITOR_UNKNOWN_TARGET")


def validate_target_lock(
    *,
    target_system: str,
    target_run_id: str | None,
    target_lock_status: str,
    target_identity: Mapping[str, Any],
    target_ambiguity: Sequence[Any] = (),
    target_match_reason: str | None = None,
) -> bool:
    """Validate the P0 identity gate before any P1-P12 audit work.

    A technically correct audit of the wrong RUN/game/report is invalid. When
    more than one candidate is materially plausible, callers must keep the lock
    AMBIGUOUS and ask the user rather than guess.
    """
    if target_lock_status != "CONFIRMED":
        raise ValueError(f"AUDITOR_TARGET_NOT_CONFIRMED:{target_lock_status}")
    if not target_run_id:
        raise ValueError("AUDITOR_TARGET_RUN_REQUIRED")
    missing = [key for key in REQUIRED_TARGET_IDENTITY_KEYS if not str(target_identity.get(key, "")).strip()]
    if missing:
        raise ValueError("AUDITOR_TARGET_IDENTITY_MISSING:" + ",".join(missing))
    if target_identity.get("requested_agent") != target_system:
        raise ValueError("AUDITOR_REQUESTED_AGENT_MISMATCH")
    if target_identity.get("resolved_agent") != target_system:
        raise ValueError("AUDITOR_RESOLVED_AGENT_MISMATCH")
    if target_identity.get("target_run_id") != target_run_id:
        raise ValueError("AUDITOR_TARGET_RUN_MISMATCH")
    if target_ambiguity:
        raise ValueError("AUDITOR_CONFIRMED_TARGET_HAS_AMBIGUITY")
    if not target_match_reason or len(target_match_reason.strip()) < 40:
        raise ValueError("AUDITOR_TARGET_MATCH_REASON_TOO_THIN")
    scope = str(target_identity.get("target_scope", "")).upper()
    if scope == "GAME" and not str(target_identity.get("game_id", "")).strip():
        raise ValueError("AUDITOR_GAME_SCOPE_REQUIRES_GAME_ID")
    if scope == "SLATE" and not (target_identity.get("slate_date") or target_identity.get("game_ids")):
        raise ValueError("AUDITOR_SLATE_SCOPE_REQUIRES_DATE_OR_GAME_IDS")
    return True


def may_advance_to_layer(layer_id: str, target_lock_status: str) -> bool:
    """P0 may investigate identity; P1-P12 require a confirmed target lock."""
    if layer_id == "P0":
        return True
    return target_lock_status == "CONFIRMED"


def validate_forensic_chat_report(report_text: str, sections: Mapping[str, Any]) -> bool:
    if len(report_text.strip()) < 1200:
        raise ValueError("AUDITOR_FORENSIC_CHAT_REPORT_TOO_THIN")
    missing = [key for key in FORENSIC_CHAT_REQUIRED_SECTIONS if key not in sections]
    if missing:
        raise ValueError("AUDITOR_FORENSIC_CHAT_REPORT_MISSING:" + ",".join(missing))
    return True


def validate_finding(
    *,
    authority_rule_ref: str | None,
    failure_mode: str,
    severity: str,
    required_correction: str | None,
    retest_requirement: str | None,
) -> bool:
    """A finding is an authority-compliance statement, not a design opinion."""
    if not authority_rule_ref or len(authority_rule_ref.strip()) < 5:
        raise ValueError("AUDITOR_FINDING_REQUIRES_AUTHORITY_RULE")
    if failure_mode not in FAILURE_MODES:
        raise ValueError("AUDITOR_FINDING_INVALID_FAILURE_MODE")
    if severity in ("CRITICAL", "MAJOR"):
        if not required_correction or len(required_correction.strip()) < 20:
            raise ValueError("AUDITOR_FINDING_REQUIRES_COMPLIANCE_CORRECTION")
        if not retest_requirement or len(retest_requirement.strip()) < 20:
            raise ValueError("AUDITOR_FINDING_REQUIRES_RETEST")
    return True


def forensic_replay_allowed(*, target_write_performed: bool, data_cutoff_present: bool) -> bool:
    """Replay may reconstruct expected behavior but can never mutate target state."""
    return (not target_write_performed) and data_cutoff_present


def validated_verdict_allowed(critical_open_count: int) -> bool:
    return critical_open_count == 0


def process_invalid_allowed(critical_fail_or_inconsistent_count: int) -> bool:
    return critical_fail_or_inconsistent_count > 0


def may_write_target() -> bool:
    """Explicit invariant used by adapters/orchestrators."""
    return False


def may_redesign_target() -> bool:
    """Auditor corrections are limited to restoring the target's own authority."""
    return False
