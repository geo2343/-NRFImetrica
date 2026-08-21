import unittest

from kernel.investigarfullunder import (
    HANDOFF_FORMAT_CONTRACT,
    MOTHER_SHA256,
    TOTAL_REQUIREMENTS,
    InvestigarFullUnderViolation,
    compute_handoff_hash,
    validate_handoff,
    validate_handoff_structure,
    validate_phase_order,
    validate_phase_payload,
    validate_requirement_coverage,
)


class InvestigarFullUnderKernelTests(unittest.TestCase):
    def test_total_requirement_contract(self):
        self.assertEqual(TOTAL_REQUIREMENTS, 889)

    def test_phase_order(self):
        validate_phase_order(0, "F1")
        with self.assertRaises(InvestigarFullUnderViolation):
            validate_phase_order(0, "F2")

    def test_requirement_coverage(self):
        states = [{"status": "SATISFIED", "evidence_refs": ["e"]} for _ in range(93)]
        validate_requirement_coverage("F1", states)
        with self.assertRaises(InvestigarFullUnderViolation):
            validate_requirement_coverage("F1", states[:-1])

    def test_requirement_satisfied_requires_reference(self):
        states = [{"status": "SATISFIED", "evidence_refs": ["e"]} for _ in range(93)]
        states[0] = {"status": "SATISFIED", "evidence_refs": []}
        with self.assertRaises(InvestigarFullUnderViolation):
            validate_requirement_coverage("F1", states)

    def test_market_key_forbidden(self):
        with self.assertRaises(InvestigarFullUnderViolation):
            validate_phase_payload("F1", {"odds": "-110"})

    def test_market_text_forbidden(self):
        with self.assertRaises(InvestigarFullUnderViolation):
            validate_phase_payload("F1", {"notes": "sportsbook line movement"})

    def test_sports_decision_forbidden(self):
        with self.assertRaises(InvestigarFullUnderViolation):
            validate_phase_payload("F8", {"positive_for_under": True})

    def test_generic_value_key_not_betting_value(self):
        payload = {
            "game_constitution_packet": True,
            "previous_game_context": True,
            "research_questions_opened": 2,
            "critical_identity_unresolved": False,
            "measurement": {"value": 97.1},
        }
        validate_phase_payload("F1", payload)

    def test_valid_f1(self):
        validate_phase_payload("F1", {
            "game_constitution_packet": True,
            "previous_game_context": True,
            "research_questions_opened": 4,
            "critical_identity_unresolved": False,
        })

    def test_f2_requires_all_nine(self):
        with self.assertRaises(InvestigarFullUnderViolation):
            validate_phase_payload("F2", self._side("AWAY_PRODUCING", 8))

    def test_f2_requires_b6_b9_omission_check(self):
        p = self._side("AWAY_PRODUCING", 9)
        p["b6_b9_omission_check"] = False
        with self.assertRaises(InvestigarFullUnderViolation):
            validate_phase_payload("F2", p)

    def test_valid_f2_f3_symmetry(self):
        validate_phase_payload("F2", self._side("AWAY_PRODUCING", 9))
        validate_phase_payload("F3", self._side("HOME_PRODUCING", 9))

    def test_f4_no_environment_conclusion(self):
        with self.assertRaises(InvestigarFullUnderViolation):
            validate_phase_payload("F4", {"shared_context_complete": True, "environment_to_conclusion": True})

    def test_f5_raw_and_comparability(self):
        validate_phase_payload("F5", {"raw_preserved": True, "normalized_separate": True, "comparability_gate": True, "contradiction_register_complete": True})

    def test_f6_cannot_ignore_triggered_questions(self):
        with self.assertRaises(InvestigarFullUnderViolation):
            validate_phase_payload("F6", {"autonomous_research_sweep_complete": True, "deep_dive_records_complete": True, "open_triggered_questions_ignored": 1})

    def test_f7_legitimate_pending_is_allowed(self):
        validate_phase_payload("F7", {"all_dynamic_objects_checked": True, "changes_propagated": True, "recoverable_pending_ignored": 0, "first_pitch_occurred": False, "legitimate_pending_count": 3})

    def test_f7_recoverable_pending_is_not_allowed(self):
        with self.assertRaises(InvestigarFullUnderViolation):
            validate_phase_payload("F7", {"all_dynamic_objects_checked": True, "changes_propagated": True, "recoverable_pending_ignored": 1, "first_pitch_occurred": False})

    def test_f8_requires_questions_and_neutral_semantics(self):
        p = self._f8()
        validate_phase_payload("F8", p)
        p["questions_analyst_must_resolve_count"] = 0
        with self.assertRaises(InvestigarFullUnderViolation):
            validate_phase_payload("F8", p)

    def test_handoff_format_contract_pinned(self):
        self.assertEqual(HANDOFF_FORMAT_CONTRACT, "FULLUNDER-HANDOFF-FORMAT-1.1")

    def test_handoff_structure_requires_all_twenty_sections(self):
        s = self._structure()
        s["section_inventory"] = ["01", "02"]
        with self.assertRaises(InvestigarFullUnderViolation):
            validate_handoff_structure(s)

    def test_handoff_structure_requires_tables_and_hierarchy(self):
        s = self._structure()
        s["table_count"] = 5
        with self.assertRaises(InvestigarFullUnderViolation):
            validate_handoff_structure(s)
        s = self._structure()
        s["bold_anchor_count"] = 2
        with self.assertRaises(InvestigarFullUnderViolation):
            validate_handoff_structure(s)

    def test_valid_handoff_structure(self):
        validate_handoff_structure(self._structure())

    def test_valid_handoff_hash_readback_and_structure(self):
        artifacts = self._artifacts()
        structure = self._structure()
        h = compute_handoff_hash(run_id="r", game_pk=1, dossier_hash="d", brief_hash="b", master_hash="m", structure_hash=structure["structure_hash"], target_binding_hash="t")
        validate_handoff(phase_cursor=8, receipt_count=8, artifacts=artifacts, structure_receipt=structure, source_snapshot_hash="d", handoff_hash=h, run_id="r", game_pk=1, target_binding_hash="t")

    def test_handoff_rejects_bad_readback(self):
        artifacts = self._artifacts()
        artifacts["FULL_UNDER_PREGAME_EVIDENCE_DOSSIER"]["readback_hash"] = "x"
        with self.assertRaises(InvestigarFullUnderViolation):
            validate_handoff(phase_cursor=8, receipt_count=8, artifacts=artifacts, structure_receipt=self._structure(), source_snapshot_hash="d", handoff_hash="bad", run_id="r", game_pk=1, target_binding_hash="t")

    def test_handoff_rejects_missing_structure(self):
        with self.assertRaises(InvestigarFullUnderViolation):
            validate_handoff_structure({})

    def test_mother_hash_pinned(self):
        self.assertEqual(MOTHER_SHA256, "18da7c034b9c2ff156b063ac1a12cc7f62b556c0bec55832d79a70c9246ab4de")

    @staticmethod
    def _side(side, count):
        return {
            "side": side,
            "b1_b9_first_sweep_count": count,
            "first_sweep_complete": True,
            "selective_second_sweep_complete": True,
            "b6_b9_omission_check": True,
            "starter_current_version": True,
            "batter_pitch_matchup_matrix": True,
            "bullpen_today_reconstructed": True,
            "previous_game_deep_reconstruction": True,
        }

    @staticmethod
    def _f8():
        return {
            "dossier_built": True,
            "handoff_brief_built": True,
            "attention_map_built": True,
            "evidence_tensions_built": True,
            "questions_analyst_must_resolve_count": 5,
            "neutral_signal_semantics": True,
            "legitimate_open_gaps_documented": True,
            "final_source_snapshot_reference": True,
        }

    @staticmethod
    def _artifacts():
        return {
            "FULL_UNDER_PREGAME_EVIDENCE_DOSSIER": {"content_hash": "d", "readback_hash": "d", "readback_pass": True},
            "ANALYST_HANDOFF_BRIEF": {"content_hash": "b", "readback_hash": "b", "readback_pass": True},
            "MASTER_RESEARCH_REPORT": {"content_hash": "m", "readback_hash": "m", "readback_pass": True},
        }

    @staticmethod
    def _structure():
        return {
            "format_contract_id": "FULLUNDER-HANDOFF-FORMAT-1.1",
            "document_role": "ANALYST_HANDOFF_BRIEF",
            "required_section_count": 20,
            "section_inventory": [f"{i:02d}" for i in range(1, 21)],
            "heading_count": 24,
            "table_count": 21,
            "bold_anchor_count": 32,
            "visual_hierarchy_pass": True,
            "structure_readback_pass": True,
            "structure_hash": "s",
        }


if __name__ == "__main__":
    unittest.main()
