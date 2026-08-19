from __future__ import annotations

from typing import Any


class ReportViolation(ValueError):
    pass


def _decision_counts(decisions: list[dict[str, Any]]) -> dict[str, int]:
    counts: dict[str, int] = {}
    for row in decisions:
        key = str(row.get('decision') or '')
        counts[key] = counts.get(key, 0) + 1
    return counts


def build_expected_summary(
    *,
    games: list[dict[str, Any]],
    decisions: list[dict[str, Any]],
    recoveries: list[dict[str, Any]],
) -> dict[str, Any]:
    counts = _decision_counts(decisions)
    audit_only = sum(1 for g in games if g.get('status') == 'AUDIT_ONLY')
    decided_game_ids = {str(d.get('game_id')) for d in decisions}
    unresolved = [
        str(g.get('game_id'))
        for g in games
        if g.get('status') != 'AUDIT_ONLY' and str(g.get('game_id')) not in decided_game_ids
    ]
    return {
        'total_games': len(games),
        'processed': len(games) - len(unresolved),
        'audit_only': audit_only,
        'candidates': counts.get('NRFI_CANDIDATE', 0),
        'rejected': counts.get('NRFI_REJECTED', 0),
        'research_only': counts.get('RESEARCH_ONLY_DATA', 0) + counts.get('RESEARCH_ONLY_MODEL', 0),
        'local_failures': counts.get('LOCAL_DATA_BLOCK', 0),
        'recoveries': len(recoveries),
        'unresolved_games': unresolved,
    }


def validate_final_report(
    *,
    report: dict[str, Any],
    games: list[dict[str, Any]],
    decisions: list[dict[str, Any]],
    recoveries: list[dict[str, Any]],
) -> dict[str, Any]:
    expected = build_expected_summary(games=games, decisions=decisions, recoveries=recoveries)
    supplied = report.get('summary') or {}

    for key in ('total_games', 'processed', 'audit_only', 'candidates', 'rejected', 'research_only', 'local_failures', 'recoveries'):
        if supplied.get(key) != expected[key]:
            raise ReportViolation(f'SUMMARY_MISMATCH:{key}:{supplied.get(key)}/{expected[key]}')

    if expected['unresolved_games']:
        raise ReportViolation('RUN_INCOMPLETE:' + ','.join(expected['unresolved_games']))

    candidate_rows = [d for d in decisions if d.get('decision') == 'NRFI_CANDIDATE']
    expected_candidates = {str(d['game_id']): d for d in candidate_rows}
    ranking = report.get('ranking_nrfi') or []
    supplied_candidate_ids = [str(item.get('game_id') or '') for item in ranking]

    if len(supplied_candidate_ids) != len(set(supplied_candidate_ids)):
        raise ReportViolation('DUPLICATE_CANDIDATE_IN_RANKING')
    if set(supplied_candidate_ids) != set(expected_candidates):
        raise ReportViolation('RANKING_CANDIDATE_SET_MISMATCH')

    for item in ranking:
        game_id = str(item.get('game_id') or '')
        decision = expected_candidates[game_id]
        if item.get('decision') != 'NRFI_CANDIDATE':
            raise ReportViolation(f'RANKING_DECISION_INVALID:{game_id}')
        reasons = item.get('independent_causal_reasons') or []
        if not reasons or len(reasons) > 3:
            raise ReportViolation(f'RANKING_CAUSAL_REASONS_INVALID:{game_id}')
        for field in ('best_yrfi_rival', 'principal_risk', 'what_would_change', 'detailed_verdict'):
            if not item.get(field):
                raise ReportViolation(f'RANKING_FIELD_MISSING:{game_id}:{field}')
        if item.get('p_nrfi') is not None and decision.get('raw_p_nrfi') is None:
            raise ReportViolation(f'UNAUTHORIZED_P_NRFI_IN_REPORT:{game_id}')
        if item.get('edge') is not None or item.get('ev') is not None:
            if str(decision.get('calibration_status') or 'NOT_CERTIFIED') != 'CERTIFIED':
                raise ReportViolation(f'UNAUTHORIZED_EDGE_EV_IN_REPORT:{game_id}')

    final_verdict = report.get('final_verdict') or {}
    if not final_verdict.get('decision'):
        raise ReportViolation('FINAL_VERDICT_DECISION_MISSING')
    if not final_verdict.get('central_reason'):
        raise ReportViolation('FINAL_VERDICT_REASON_MISSING')
    if not final_verdict.get('central_risk'):
        raise ReportViolation('FINAL_VERDICT_RISK_MISSING')

    best_candidate = final_verdict.get('best_candidate_game_id')
    if expected['candidates'] == 0:
        if best_candidate not in (None, '', 'NONE'):
            raise ReportViolation('BEST_CANDIDATE_MUST_BE_EMPTY_WHEN_ZERO_CANDIDATES')
    else:
        if str(best_candidate or '') not in expected_candidates:
            raise ReportViolation('BEST_CANDIDATE_NOT_IN_REAL_CANDIDATES')

    return expected
