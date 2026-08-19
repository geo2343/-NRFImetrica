from __future__ import annotations

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
    seen_evidence: set[str] = set()
    unique: list[dict[str, Any]] = []
    for call in source_calls:
        source_ref = str(call.get('source_ref') or '').strip()
        evidence_id = str(call.get('evidence_id') or '').strip()
        retrieved_at = str(call.get('retrieved_at') or '').strip()
        if not source_ref or not evidence_id or not retrieved_at:
            raise ProtocolViolation('SOURCE_CALL_MISSING_REAL_TRACE_FIELDS')
        if evidence_id not in seen_evidence:
            seen_evidence.add(evidence_id)
            unique.append(call)
    return unique


def _walk_keys(value: Any):
    if isinstance(value, dict):
        for key, child in value.items():
            yield str(key).lower()
            yield from _walk_keys(child)
    elif isinstance(value, list):
        for child in value:
            yield from _walk_keys(child)


def _number(value: Any, label: str) -> float:
    try:
        result = float(value)
    except (TypeError, ValueError) as exc:
        raise ProtocolViolation(f'NUMERIC_FIELD_INVALID:{label}') from exc
    if not 0.0 <= result <= 1.0:
        raise ProtocolViolation(f'PROBABILITY_OUT_OF_RANGE:{label}')
    return result


def _assert_distribution(payload: dict[str, Any], prefix: str, *, tolerance: float = 1e-6) -> tuple[float, float, float, float]:
    values = tuple(_number(_get_path(payload, f'{prefix}.{name}'), f'{prefix}.{name}') for name in ('p0', 'p1', 'p2', 'p3plus'))
    if abs(sum(values) - 1.0) > tolerance:
        raise ProtocolViolation(f'PROBABILITY_MASS_NOT_ONE:{prefix}:{sum(values):.8f}')
    return values  # type: ignore[return-value]


def _assert_bool_true(payload: dict[str, Any], path: str, code: str) -> None:
    if _get_path(payload, path) is not True:
        raise ProtocolViolation(code)


def _mother_semantics(phase_id: str, payload: dict[str, Any], output_text: str) -> None:
    keys = set(_walk_keys(payload))
    if {'ai_estimate', 'ai_nrfi_estimate', 'ai_probability'} & keys:
        raise ProtocolViolation('MOTHER_DOCUMENT_FORBIDS_AI_PROBABILITY_FABRICATION')

    if phase_id == 'A1_DATA_INTEGRITY_FREEZE':
        if str(_get_path(payload, 'market_quarantine')).upper() not in {'PASS', 'SEALED', 'INTACT'}:
            raise ProtocolViolation('A1_MARKET_QUARANTINE_NOT_INTACT')
        if str(_get_path(payload, 'temporal_integrity')).upper() != 'PASS':
            raise ProtocolViolation('A1_TEMPORAL_INTEGRITY_FAIL')

    elif phase_id == 'A2_HIERARCHICAL_BASELINES':
        if str(_get_path(payload, 'market_blindness')).upper() != 'PASS':
            raise ProtocolViolation('A2_MARKET_BLINDNESS_FAIL')
        if str(_get_path(payload, 'double_count_check')).upper() != 'PASS':
            raise ProtocolViolation('A2_DEPENDENCY_CONTROL_FAIL')

    elif phase_id == 'A3_CURRENT_VERSION_MATCHUP':
        if str(_get_path(payload, 'market_blindness')).upper() != 'PASS':
            raise ProtocolViolation('A3_MARKET_BLINDNESS_FAIL')
        if str(_get_path(payload, 'numeric_fabrication_check')).upper() != 'PASS':
            raise ProtocolViolation('A3_NUMERIC_BOUNDARY_FAIL')

    elif phase_id == 'A4_NUMERIC_STATE_ENGINE':
        if str(_get_path(payload, 'numeric_engine.provenance_status')).upper() != 'PASS':
            raise ProtocolViolation('A4_NUMERIC_PROVENANCE_NOT_PASS')
        if str(_get_path(payload, 'numeric_engine.transformation_status')).upper() != 'PASS':
            raise ProtocolViolation('A4_TRANSFORMATION_NOT_VALIDATED')
        mode = str(_get_path(payload, 'numeric_engine.engine_mode')).upper()
        if mode not in {'PRODUCTION', 'REDUCED', 'BOOTSTRAP', 'HIGH_UNCERTAINTY'}:
            raise ProtocolViolation('A4_ENGINE_MODE_INVALID')
        _assert_distribution(payload, 'top')
        _assert_distribution(payload, 'bottom')
        if str(_get_path(payload, 'mass_conservation_check')).upper() != 'PASS':
            raise ProtocolViolation('A4_MASS_CONSERVATION_FAIL')
        if str(_get_path(payload, 'state_sanity_checks')).upper() != 'PASS':
            raise ProtocolViolation('A4_STATE_SANITY_FAIL')

    elif phase_id == 'A5_JOINT_INTEGRATION':
        p0, p1, p2, p3plus = _assert_distribution(payload, 'joint')
        p_u05 = _number(_get_path(payload, 'contracts.p_u0_5'), 'contracts.p_u0_5')
        p_u15 = _number(_get_path(payload, 'contracts.p_u1_5'), 'contracts.p_u1_5')
        p_u25 = _number(_get_path(payload, 'contracts.p_u2_5'), 'contracts.p_u2_5')
        p_yrfi = _number(_get_path(payload, 'p_yrfi'), 'p_yrfi')
        if abs(p_u05 - p0) > 1e-6:
            raise ProtocolViolation('A5_U05_DERIVATION_FAIL')
        if abs(p_u15 - (p0 + p1)) > 1e-6:
            raise ProtocolViolation('A5_U15_DERIVATION_FAIL')
        if abs(p_u25 - (p0 + p1 + p2)) > 1e-6:
            raise ProtocolViolation('A5_U25_DERIVATION_FAIL')
        if abs(p_yrfi - (1.0 - p0)) > 1e-6:
            raise ProtocolViolation('A5_COMPLEMENT_CHECK_FAIL')
        if str(_get_path(payload, 'same_context_realization_check')).upper() != 'PASS':
            raise ProtocolViolation('A5_SHARED_CONTEXT_FAIL')
        if str(_get_path(payload, 'double_adjustment_check')).upper() != 'PASS':
            raise ProtocolViolation('A5_DOUBLE_ADJUSTMENT_FAIL')

    elif phase_id == 'A6_CAUSAL_FALSIFICATION_SPORTS_SEAL':
        primary = str(_get_path(payload, 'primary_analyst_id') or '').strip()
        auditor = str(_get_path(payload, 'independent_audit.auditor_id') or '').strip()
        if not primary or not auditor or primary == auditor:
            raise ProtocolViolation('A6_INDEPENDENT_AUDIT_NOT_INDEPENDENT')
        sra_status = str(_get_path(payload, 'sra.packet_status')).upper()
        if sra_status not in {'COMPLETE', 'DATA_UNAVAILABLE'}:
            raise ProtocolViolation('SRA_GATE_NOT_EXECUTED')
        _assert_bool_true(payload, 'pre_press_verdict.frozen', 'A6_PRE_PRESS_VERDICT_NOT_FROZEN')
        if 'ESPERANDO RESULTADO DE NRFI-PRENSA' not in output_text:
            raise ProtocolViolation('A6_PRESS_WAIT_MARKER_MISSING')
        if str(_get_path(payload, 'sports_seal.market_blindness')).upper() != 'PASS':
            raise ProtocolViolation('A6_MARKET_BLINDNESS_FAIL')

    elif phase_id == 'A7_CALIBRATION_ELIGIBILITY_PRESS':
        release = str(_get_path(payload, 'release_token')).upper()
        calibration = str(_get_path(payload, 'calibration_status')).upper()
        region = str(_get_path(payload, 'calibration_region_support')).upper()
        oos = str(_get_path(payload, 'oos_validation_status')).upper()
        provenance = str(_get_path(payload, 'provenance_status')).upper()
        eligibility = str(_get_path(payload, 'absolute_eligibility')).upper()
        press_effect = str(_get_path(payload, 'nrfi_prensa.effect')).upper()
        if press_effect not in {'CONFIRM', 'STRENGTHEN', 'CONDITION', 'REVISE', 'REJECT', 'NON_DISCRIMINANT'}:
            raise ProtocolViolation('A7_NRFI_PRENSA_EFFECT_INVALID')
        if release == 'ISSUED':
            if calibration not in {'CERTIFIED', 'CERTIFIED_CONDITIONED'}:
                raise ProtocolViolation('A7_NOT_CERTIFIED_A8_LOCKED')
            if region not in {'HIGH', 'MEDIUM'}:
                raise ProtocolViolation('A7_REGION_SUPPORT_INSUFFICIENT')
            if oos != 'PASS' or provenance != 'PASS':
                raise ProtocolViolation('A7_RELEASE_WITHOUT_OOS_OR_PROVENANCE')
            if eligibility not in {'A7_ELIGIBLE', 'A7_ELIGIBLE_CONDITIONED'}:
                raise ProtocolViolation('A7_RELEASE_WITHOUT_ABSOLUTE_ELIGIBILITY')
        elif release not in {'NOT_ISSUED', 'BLOCKED', 'N/A', 'NA'}:
            raise ProtocolViolation('A7_RELEASE_TOKEN_INVALID')

    elif phase_id == 'A8_MARKET_VALUE_EXECUTION':
        p0, p1, p2, _ = _assert_distribution(payload, 'probability')
        line = str(_get_path(payload, 'line_recommended')).upper()
        if line not in {'U0.5', 'NRFI', 'U1.5', 'U2.5'}:
            raise ProtocolViolation('A8_LINE_INVALID')
        if str(_get_path(payload, 'a7_release_token')).upper() != 'ISSUED':
            raise ProtocolViolation('A8_RELEASE_BLOCKED')
        if str(_get_path(payload, 'a7_eligibility_status')).upper() not in {'A7_ELIGIBLE', 'A7_ELIGIBLE_CONDITIONED'}:
            raise ProtocolViolation('A8_ELIGIBILITY_BLOCKED')
        if str(_get_path(payload, 'calibration_status')).upper() not in {'CERTIFIED', 'CERTIFIED_CONDITIONED'}:
            raise ProtocolViolation('A8_REQUIRES_CERTIFIED_CALIBRATION')
        if line == 'U1.5' and 'El partido fue seleccionado por su fortaleza para cero carreras.' not in output_text:
            raise ProtocolViolation('A8_U15_REQUIRED_MESSAGE_MISSING')
        break_even = _number(_get_path(payload, 'market.break_even'), 'market.break_even')
        p_conservative = _number(_get_path(payload, 'market.p_conservative'), 'market.p_conservative')
        try:
            decimal_odds = float(_get_path(payload, 'market.decimal_odds'))
            edge = float(_get_path(payload, 'market.edge'))
            ev = float(_get_path(payload, 'market.ev'))
        except (TypeError, ValueError) as exc:
            raise ProtocolViolation('A8_MARKET_MATH_INVALID') from exc
        if decimal_odds <= 1.0:
            raise ProtocolViolation('A8_DECIMAL_ODDS_INVALID')
        if abs(edge - (p_conservative - break_even)) > 1e-6:
            raise ProtocolViolation('A8_EDGE_MATH_FAIL')
        if abs(ev - (p_conservative * decimal_odds - 1.0)) > 1e-6:
            raise ProtocolViolation('A8_EV_MATH_FAIL')
        final_verdict = str(_get_path(payload, 'final_verdict')).upper()
        if final_verdict == 'APOSTAR' and (edge <= 0 or ev <= 0):
            raise ProtocolViolation('A8_NONPOSITIVE_EDGE_OR_EV_NO_BET')
        if line in {'U0.5', 'NRFI'} and abs(p0 - _number(_get_path(payload, 'market.p_conservative'), 'market.p_conservative')) < -1:
            raise ProtocolViolation('UNREACHABLE')
        if line == 'U1.5' and p0 + p1 <= 0:
            raise ProtocolViolation('A8_U15_NOT_MODELLED')
        if line == 'U2.5' and p0 + p1 + p2 <= 0:
            raise ProtocolViolation('A8_U25_NOT_MODELLED')


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

    if required_docs:
        traced_docs = {
            str(call.get('document') or call.get('document_id') or '').strip()
            for call in unique_calls
            if str(call.get('document') or call.get('document_id') or '').strip()
        }
        untraced_docs = sorted(required_docs - traced_docs)
        if untraced_docs:
            raise ProtocolViolation('REQUIRED_DOCUMENTS_WITHOUT_REAL_TRACE:' + ','.join(untraced_docs))

    for phrase in phase.get('required_phrases', []):
        if str(phrase) not in output_text:
            raise ProtocolViolation('REQUIRED_PHRASE_MISSING:' + str(phrase))

    _mother_semantics(phase_id, payload, output_text)

    return {
        'status': 'COMPLETE',
        'checks': {
            'prerequisites': True,
            'required_fields': True,
            'source_calls': len(unique_calls),
            'evidence_ids': len(unique_evidence),
            'documents_analyzed': sorted(docs),
            'required_phrases': len(phase.get('required_phrases', [])),
            'mother_document_semantics': True,
        },
    }


def decision_required_phases(manifest: dict[str, Any], decision: str) -> list[str]:
    return list((manifest.get('decision_gates') or {}).get(decision, []))
