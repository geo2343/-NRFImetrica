from kernel.system_auditor import normalize_target, target_prompt


def test_ianalista_is_fifth_auditor_target():
    prompt = target_prompt()
    assert "5 — @ianalista" in prompt
    assert normalize_target("5") == "@ianalista"


def test_ianalista_aliases_resolve_to_canonical_target():
    assert normalize_target("@ianalista") == "@ianalista"
    assert normalize_target("@IAanalista") == "@ianalista"
    assert normalize_target("@iaanalissta") == "@ianalista"
