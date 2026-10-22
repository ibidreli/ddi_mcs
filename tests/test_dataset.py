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


def test_enrollments_reference_matching_runs():
    data = dataset.generate(10, 20)
    run_course = {r["run_id"]: r["course_id"] for r in data["course_runs"]}
    assert all(run_course[e["run_id"]] == e["course_id"] for e in data["enrollments"])
    assert len({(e["learner_id"], e["course_id"]) for e in data["enrollments"]}) == len(data["enrollments"])
