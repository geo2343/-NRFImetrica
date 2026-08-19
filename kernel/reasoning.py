from __future__ import annotations

from typing import Any

AI_ANALYST_STATUS = "EXTERNAL_AI_REASONING_LAYER"
AI_ESTIMATE_NOT_PROVIDED = "NOT_PROVIDED"
AI_ESTIMATE_UNCALIBRATED = "AI_REASONED_UNCALIBRATED"

_BANNED_MECHANICAL_KEYS = {
    "metric_votes",
    "metric_vote",
    "points",
    "point_total",
    "score_total",
    "final_score",
    "weighted_sum",
    "vote_total",
}


def _nonempty_text(value: Any) -> bool:
    return isinstance(value, str) and bool(value.strip())


def _walk_keys(value: Any):
    if isinstance(value, dict):
        for key, child in value.items():
            yield str(key).strip().lower()
            yield from _walk_keys(child)
    elif isinstance(value, list):
        for child in value:
            yield from _walk_keys(child)


def _validate_path(name: str, path: Any) -> list[str]:
    errors: list[str] = []
    if not isinstance(path, dict):
        return [f"{name}:object_required"]
    if not _nonempty_text(path.get("mechanism")):
        errors.append(f"{name}:mechanism")
    activators = path.get("activators")
    if not isinstance(activators, list) or not any(_nonempty_text(x) for x in activators):
        errors.append(f"{name}:activators")
    if not _nonempty_text(path.get("materialization")):
        errors.append(f"{name}:materialization")
    refs = path.get("evidence_refs")
    if not isinstance(refs, list) or not any(_nonempty_text(x) for x in refs):
        errors.append(f"{name}:evidence_refs")
    return errors


def validate_reasoning_artifact(
    artifact: Any,
    *,
    decision: str,
    ai_nrfi_estimate: float | None,
    ai_estimate_status: str,
) -> None:
    """Validate the IA reasoning contract without pretending to judge sports truth.

    This validator enforces structure and anti-mechanical rules. It does NOT certify
    that the causal interpretation is correct; that belongs to an independent
    AI_REASONING_VALIDATION pass grounded in the evidence trace.
    """
    if decision not in {"NRFI_CANDIDATE", "NRFI_REJECTED"}:
        if ai_nrfi_estimate is not None and ai_estimate_status != AI_ESTIMATE_UNCALIBRATED:
            raise ValueError("AI_ESTIMATE_STATUS_MISMATCH")
        return

    if not isinstance(artifact, dict) or not artifact:
        raise ValueError("AI_REASONING_ARTIFACT_REQUIRED")

    banned = sorted(set(_walk_keys(artifact)) & _BANNED_MECHANICAL_KEYS)
    if banned:
        raise ValueError("MECHANICAL_SCORING_FORBIDDEN:" + ",".join(banned))

    missing: list[str] = []
    if not _nonempty_text(artifact.get("meaning")):
        missing.append("meaning")

    families = artifact.get("causal_families")
    if not isinstance(families, list) or not families:
        missing.append("causal_families")
    else:
        seen_ids: set[str] = set()
        for idx, family in enumerate(families):
            if not isinstance(family, dict):
                missing.append(f"causal_families[{idx}]")
                continue
            family_id = str(family.get("family_id") or "").strip()
            if not family_id:
                missing.append(f"causal_families[{idx}].family_id")
            elif family_id in seen_ids:
                raise ValueError(f"DUPLICATE_CAUSAL_FAMILY:{family_id}")
            else:
                seen_ids.add(family_id)
            if family.get("direction") not in {"NRFI", "YRFI", "MIXED"}:
                missing.append(f"causal_families[{idx}].direction")
            if not _nonempty_text(family.get("mechanism")):
                missing.append(f"causal_families[{idx}].mechanism")
            refs = family.get("evidence_refs")
            if not isinstance(refs, list) or not any(_nonempty_text(x) for x in refs):
                missing.append(f"causal_families[{idx}].evidence_refs")

    relationships = artifact.get("relationships")
    if not isinstance(relationships, list) or not relationships:
        missing.append("relationships")
    else:
        for idx, relation in enumerate(relationships):
            if not isinstance(relation, dict):
                missing.append(f"relationships[{idx}]")
                continue
            for field in ("from_family", "to_family", "relation", "material_effect"):
                if not _nonempty_text(relation.get(field)):
                    missing.append(f"relationships[{idx}].{field}")

    missing.extend(_validate_path("nrfi_path", artifact.get("nrfi_path")))
    missing.extend(_validate_path("yrfi_path", artifact.get("yrfi_path")))

    hierarchy = artifact.get("hierarchy")
    if not isinstance(hierarchy, dict):
        missing.append("hierarchy")
    else:
        if hierarchy.get("governing_path") not in {"NRFI", "YRFI", "DATA_BLOCK"}:
            missing.append("hierarchy.governing_path")
        for field in ("decisive_reason", "why_rival_loses", "what_would_flip"):
            if not _nonempty_text(hierarchy.get(field)):
                missing.append(f"hierarchy.{field}")

    if not _nonempty_text(artifact.get("verdict")):
        missing.append("verdict")

    refs = artifact.get("evidence_refs")
    if not isinstance(refs, list) or not any(_nonempty_text(x) for x in refs):
        missing.append("evidence_refs")

    if missing:
        raise ValueError("AI_REASONING_INCOMPLETE:" + ",".join(missing))

    governing_path = artifact["hierarchy"]["governing_path"]
    if decision == "NRFI_CANDIDATE" and governing_path != "NRFI":
        raise ValueError("DECISION_REASONING_CONTRADICTION:CANDIDATE_WITHOUT_NRFI_GOVERNING_PATH")
    if decision == "NRFI_REJECTED" and governing_path not in {"YRFI", "DATA_BLOCK"}:
        raise ValueError("DECISION_REASONING_CONTRADICTION:REJECTION_WITHOUT_RIVAL_GOVERNING_PATH")

    if ai_nrfi_estimate is None:
        if ai_estimate_status != AI_ESTIMATE_NOT_PROVIDED:
            raise ValueError("AI_ESTIMATE_STATUS_MISMATCH")
    else:
        if not 0.0 <= float(ai_nrfi_estimate) <= 1.0:
            raise ValueError("AI_NRFI_ESTIMATE_OUT_OF_RANGE")
        if ai_estimate_status != AI_ESTIMATE_UNCALIBRATED:
            raise ValueError("UNCALIBRATED_AI_ESTIMATE_MUST_BE_EXPLICIT")


def collect_evidence_refs(artifact: Any) -> set[str]:
    refs: set[str] = set()
    if isinstance(artifact, dict):
        for key, value in artifact.items():
            if key == "evidence_refs" and isinstance(value, list):
                refs.update(str(item).strip() for item in value if str(item).strip())
            else:
                refs.update(collect_evidence_refs(value))
    elif isinstance(artifact, list):
        for value in artifact:
            refs.update(collect_evidence_refs(value))
    return refs
