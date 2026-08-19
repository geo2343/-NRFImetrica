"""@AuditorSistema process-audit kernel.

This module defines deterministic governance only. It does not perform sports
judgment and must not modify the audited system during an audit.
"""

AUDITOR_AGENT_ID = "@AuditorSistema"
AUDITOR_AGENT_VERSION = "AUDITOR-SYSTEM-1.0"
AUDITOR_PROTOCOL_ID = "SYSTEM_AUDITOR_V1"
AUDITOR_KERNEL_VERSION = "SYSTEM-AUDITOR-KERNEL-1.0"

READ_ONLY_TARGET = True
MAY_REPAIR_TARGET_DURING_AUDIT = False
NEW_AUDIT_RUN_PER_INVOCATION = True
NEW_DRIVE_FOLDER_PER_AUDIT = True
NEW_REPORT_PER_AUDIT = True

TARGET_MENU = {
    "1": "@NRFiPrensa",
    "2": "@NRFImetrica",
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
    "P12_VERDICT",
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

SOVEREIGN_RULES = {
    "REPORT_TEXT_IS_NOT_PHYSICAL_PROOF": True,
    "PHYSICAL_STATE_BEATS_NARRATIVE": True,
    "SPORTS_RESULT_IS_NOT_PROCESS_VERDICT": True,
    "NO_TARGET_WRITE_DURING_AUDIT": True,
    "NO_HISTORICAL_RUN_AS_CURRENT_EVIDENCE": True,
    "NO_INVENTED_PHYSICAL_STATE": True,
}


def target_prompt() -> str:
    return "¿Qué sistema desea auditar?\n1 — @NRFiPrensa\n2 — @NRFImetrica"


def normalize_target(value: str) -> str:
    value = value.strip()
    if value in TARGET_MENU:
        return TARGET_MENU[value]
    lowered = value.lower()
    if lowered == "@nrfiprensa":
        return "@NRFiPrensa"
    if lowered == "@nrfimetrica":
        return "@NRFImetrica"
    raise ValueError("AUDITOR_UNKNOWN_TARGET")


def validated_verdict_allowed(critical_open_count: int) -> bool:
    return critical_open_count == 0


def process_invalid_allowed(critical_fail_or_inconsistent_count: int) -> bool:
    return critical_fail_or_inconsistent_count > 0


def may_write_target() -> bool:
    """Explicit invariant used by adapters/orchestrators."""
    return False
