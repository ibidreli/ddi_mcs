"""test_dataset.py
Zweck: Messdaten-Generator pruefen (ohne Datenbank).
LE2, LE3.
"""
import re

from src import config, dataset


#-----------------------------------------------------------------------------
# Hilfsfunktion
#-----------------------------------------------------------------------------
def layer(course_id: str) -> int:
    return int(course_id[1:3])


#-----------------------------------------------------------------------------
# Pruefungen
#-----------------------------------------------------------------------------
def test_generator_is_deterministic():
    assert dataset.generate(10, 20) == dataset.generate(10, 20)


def test_sizes_and_ids():
    data = dataset.generate(10, 20)
    assert len(data["courses"]) == 200
    assert len(data["learners"]) == config.LEARNERS
    assert all(re.fullmatch(r"[A-Z][A-Z0-9_]{1,15}", c["course_id"]) for c in data["courses"])


def test_prerequisites_point_to_lower_layers():
    # Jede Kante fuehrt in eine tiefere Stufe, der Graph ist damit azyklisch
    data = dataset.generate(20, 20)
    assert all(layer(p["required_course_id"]) < layer(p["course_id"]) for p in data["prerequisites"])
    assert len({(p["course_id"], p["required_course_id"]) for p in data["prerequisites"]}) == len(
        data["prerequisites"])


def test_completions_reference_matching_runs():
    data = dataset.generate(10, 20)
    run_course = {r["run_id"]: r["course_id"] for r in data["course_runs"]}
    assert all(run_course[e["run_id"]] == e["course_id"] for e in data["completions"])
    assert len({(e["learner_id"], e["course_id"]) for e in data["completions"]}) == len(data["completions"])


def test_chain_has_only_adjacent_edges():
    # Reihe chain: ohne Zusatzkanten fuehrt jede Kante genau eine Stufe tiefer
    data = dataset.generate(20, 20, extra_edge_share=config.EXTRA_EDGE_SHARE_CHAIN)
    assert all(layer(p["course_id"]) - layer(p["required_course_id"]) == 1 for p in data["prerequisites"])


def test_recursion_depth():
    # Zusatzkanten kuerzen die Rekursion ab, ohne sie gilt Tiefe - 1
    for depth in (5, 20, 80):
        target = dataset.target_course(depth)
        chain = dataset.generate(depth, 20, extra_edge_share=config.EXTRA_EDGE_SHARE_CHAIN)
        assert dataset.recursion_depth(chain, target) == depth - 1
    shortcut = dataset.generate(80, 20)
    assert dataset.recursion_depth(shortcut, dataset.target_course(80)) < 79


def test_default_series_unchanged():
    # Der neue Parameter veraendert die bisherigen Reihen depth und width nicht
    data = dataset.generate(10, 20)
    assert data == dataset.generate(10, 20, extra_edge_share=config.EXTRA_EDGE_SHARE)
    assert len(data["prerequisites"]) == 438
