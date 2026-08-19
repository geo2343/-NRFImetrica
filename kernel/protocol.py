from __future__ import annotations

from dataclasses import dataclass
from typing import Any


class ProtocolViolation(ValueError):
    pass


def _get_path(payload: dict[str, Any], path: str) -> Any:
    current: Any = payload
    for part in path.split('.'):
        if not isinstance(current, dict) or part not in current:
            return None
        current = current[part]
    return current


def _nonempty(value: Any) -> bool:
    if value is None:
        return False
    if isinstance(value, str):
        return bool(value.strip())
    if isinstance(value, (list, tuple, set, dict)):
        return len(value) > 0
    return True


def _unique_source_calls(source_calls: list[dict[str, Any]]) -> list[dict[str, Any]]:
    seen: set[tuple[str, str]] = set()
    unique: list[dict[str, Any]] = []
    for call in source_calls:
        source_ref = str(call.get('source_ref') or '').strip()
        evidence_id = str(call.get('evidence_id') or '').strip()
        retrieved_at = str(call.get('retrieved_at') or '').strip()
        if not source_ref or not evidence_id or not retrieved_at:
            raise ProtocolViolation('SOURCE_CALL_MISSING_REAL_TRACE_FIELDS')
        key = (source_ref, evidence_id)
        if key not in seen:
            seen.add(key)
            unique.append(call)
    return unique


def validate_ai_estimate(payload: dict[str, Any]) -> None:
    estimate = payload.get('ai_estimate')
    if not estimate:
        return
    if not isinstance(estimate, dict):
        raise ProtocolViolation('AI_ESTIMATE_MUST_BE_OBJECT')

    kind = str(estimate.get('kind') or '').strip()
    value = estimate.get('percent')
    label = estimate.get('label')

    if value is not None:
        if kind != 'AI_JUDGMENT_UNCALIBRATED':
            raise ProtocolViolation('AI_PERCENT_MUST_BE_LABELED_UNCALIBRATED_JUDGMENT')
        try:
            numeric = float(value)
        except (TypeError, ValueError) as exc:
            raise ProtocolViolation('AI_ESTIMATE_PERCENT_INVALID') from exc
        if not 0 <= numeric <= 100:
            raise ProtocolViolation('AI_ESTIMATE_PERCENT_OUT_OF_RANGE')

    if label is not None:
        allowed = {
            'STRONGLY_FAVORABLE',
            'MODERATELY_FAVORABLE',
            'SLIGHTLY_FAVORABLE',
            'BALANCED',
            'SLIGHTLY_UNFAVORABLE',
            'MODERATELY_UNFAVORABLE',
            'STRONGLY_UNFAVORABLE',
        }
        if str(label).strip().upper() not in allowed:
            raise ProtocolViolation('AI_ESTIMATE_LABEL_INVALID')

    forbidden = ('edge', 'ev', 'calibrated_probability', 'real_money_authority')
    for key in forbidden:
        if _nonempty(estimate.get(key)):
            raise ProtocolViolation(f'AI_ESTIMATE_FORBIDDEN_FIELD:{key}')


def validate_phase_submission(
    *,
    manifest: dict[str, Any],
    phase_id: str,
    completed_phase_ids: set[str],
    payload: dict[str, Any],
    evidence_ids: list[str],
    source_calls: list[dict[str, Any]],
    documents_analyzed: list[str],
    output_text: str,
    skip_reason: str | None = None,
) -> dict[str, Any]:
    phases = {p['phase_id']: p for p in manifest.get('phases', [])}
    if phase_id not in phases:
        raise ProtocolViolation(f'UNKNOWN_PHASE:{phase_id}')
    phase = phases[phase_id]

    missing_prereq = [p for p in phase.get('prerequisites', []) if p not in completed_phase_ids]
    if missing_prereq:
        raise ProtocolViolation('PREREQUISITES_INCOMPLETE:' + ','.join(missing_prereq))

    conditional = phase.get('conditional') or {}
    if conditional:
        trigger_value = _get_path(payload, conditional.get('trigger_path', ''))
        if not bool(trigger_value):
            if not skip_reason or len(skip_reason.strip()) < 12:
                raise ProtocolViolation('CONDITIONAL_SKIP_REQUIRES_MATERIAL_REASON')
            return {
                'status': 'SKIPPED_NOT_TRIGGERED',
                'checks': {
                    'prerequisites': True,
                    'conditional_triggered': False,
                    'skip_reason': skip_reason.strip(),
                },
            }

    missing_fields = [
        path for path in phase.get('required_fields', [])
        if not _nonempty(_get_path(payload, path))
    ]
    if missing_fields:
        raise ProtocolViolation('REQUIRED_FIELDS_MISSING:' + ','.join(missing_fields))

    max_items = phase.get('max_items', {})
    for path, maximum in max_items.items():
        value = _get_path(payload, path)
        if value is not None and hasattr(value, '__len__') and len(value) > int(maximum):
            raise ProtocolViolation(f'MAX_ITEMS_EXCEEDED:{path}:{maximum}')

    unique_calls = _unique_source_calls(source_calls)
    min_sources = int(phase.get('min_source_calls', 0))
    if len(unique_calls) < min_sources:
        raise ProtocolViolation(f'MIN_SOURCE_CALLS_NOT_MET:{len(unique_calls)}/{min_sources}')

    min_evidence = int(phase.get('min_evidence_ids', 0))
    unique_evidence = {str(item).strip() for item in evidence_ids if str(item).strip()}
    if len(unique_evidence) < min_evidence:
        raise ProtocolViolation(f'MIN_EVIDENCE_NOT_MET:{len(unique_evidence)}/{min_evidence}')

    required_docs = {str(x).strip() for x in phase.get('required_documents', []) if str(x).strip()}
    docs = {str(x).strip() for x in documents_analyzed if str(x).strip()}
    missing_docs = sorted(required_docs - docs)
    if missing_docs:
        raise ProtocolViolation('REQUIRED_DOCUMENTS_MISSING:' + ','.join(missing_docs))

    for phrase in phase.get('required_phrases', []):
        if str(phrase) not in output_text:
            raise ProtocolViolation('REQUIRED_PHRASE_MISSING:' + str(phrase))

    validate_ai_estimate(payload)

    return {
        'status': 'COMPLETE',
        'checks': {
            'prerequisites': True,
            'required_fields': True,
            'source_calls': len(unique_calls),
            'evidence_ids': len(unique_evidence),
            'documents_analyzed': sorted(docs),
            'required_phrases': len(phase.get('required_phrases', [])),
        },
    }


def decision_required_phases(manifest: dict[str, Any], decision: str) -> list[str]:
    return list((manifest.get('decision_gates') or {}).get(decision, []))
