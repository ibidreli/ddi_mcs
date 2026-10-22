"""dataset.py
Zweck: Datenbestand im Exportformat lesen, schreiben und fuer die Messung erzeugen.
LE2, LE3. Das Format entspricht der Ansicht lernpfad.export_data.
"""
import json
import random
from pathlib import Path

from src import config

TABLES = ("semesters", "locations", "lecturers", "courses", "learners",
          "prerequisites", "course_runs", "completions")


#-----------------------------------------------------------------------------
# Lesen und Schreiben
#-----------------------------------------------------------------------------
def read_json(path: Path) -> dict:
    return json.loads(path.read_text(encoding="utf-8"))


def write_json(data: dict, path: Path) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_text(json.dumps(data, ensure_ascii=False, indent=2) + "\n", encoding="utf-8", newline="\n")


def course_id(layer: int, index: int) -> str:
    """Kurscode im erlaubten Format, z. B. C07_0012."""
    return f"C{layer:02d}_{index:04d}"


#-----------------------------------------------------------------------------
# Messdaten erzeugen
# Kurse liegen in Stufen. Jeder Kurs ab Stufe 1 benoetigt zwei Kurse der
# Stufe darunter und teilweise einen Kurs aus einer noch tieferen Stufe.
# Dadurch entstehen lange Ketten mit mehreren Wegen zum selben Vorkurs.
#-----------------------------------------------------------------------------
def generate(depth: int, width: int, seed: int = config.RANDOM_STATE) -> dict:
    rng = random.Random(seed * 1_000_003 + depth * 1_009 + width)
    semesters = [
        {"semester_id": "HS25", "name": "Herbstsemester 2025", "starts_on": "2025-09-15", "ends_on": "2026-01-31"},
        {"semester_id": "FS26", "name": "Frühlingssemester 2026", "starts_on": "2026-02-16", "ends_on": "2026-07-31"},
    ]
    locations = [{"location_id": 1, "name": "Brugg-Windisch"}, {"location_id": 2, "name": "Olten"}]
    lecturers = [{"lecturer_id": 1, "display_name": "L. Keller"}, {"lecturer_id": 2, "display_name": "M. Frei"}]

    courses, prerequisites = [], []
    for layer in range(depth):
        for i in range(width):
            cid = course_id(layer, i)
            courses.append({"course_id": cid, "title": f"Kurs {cid}", "hours": rng.randint(2, 12)})
            if layer == 0:
                continue
            required = set(rng.sample(range(width), k=min(2, width)))
            edges = {course_id(layer - 1, j) for j in required}
            if layer >= 2 and rng.random() < config.EXTRA_EDGE_SHARE:
                edges.add(course_id(rng.randrange(layer - 1), rng.randrange(width)))
            prerequisites += [{"course_id": cid, "required_course_id": e} for e in sorted(edges)]

    # Eine Durchfuehrung pro Kurs im HS25 genuegt fuer A-001 und A-003.
    course_runs = [
        {"run_id": n + 1, "course_id": c["course_id"], "semester_id": "HS25",
         "location_id": 1, "lecturer_id": 1, "study_mode": "VZ"}
        for n, c in enumerate(courses)
    ]
    run_of = {r["course_id"]: r["run_id"] for r in course_runs}

    learners = [{"learner_id": n, "display_name": f"Person {n}", "study_mode": "VZ"}
                for n in range(1, config.LEARNERS + 1)]

    # Person 1 hat die untere Haelfte der Stufen abgeschlossen, die anderen
    # Personen einen zufaelligen Teil der untersten Stufe.
    completions = []
    for c in courses:
        if int(c["course_id"][1:3]) < depth // 2:
            completions.append({"learner_id": 1, "course_id": c["course_id"],
                                "run_id": run_of[c["course_id"]], "completed_on": "2026-01-20"})
    for learner in range(2, config.LEARNERS + 1):
        for i in rng.sample(range(width), k=max(1, width // 4)):
            cid = course_id(0, i)
            completions.append({"learner_id": learner, "course_id": cid,
                                "run_id": run_of[cid], "completed_on": "2026-01-20"})

    return {
        "dataset_version": f"benchmark-d{depth}-w{width}",
        "semesters": semesters, "locations": locations, "lecturers": lecturers,
        "courses": courses, "learners": learners, "prerequisites": prerequisites,
        "course_runs": course_runs, "completions": completions,
    }


def target_course(depth: int) -> str:
    """Zielkurs der Messung: erster Kurs der obersten Stufe."""
    return course_id(depth - 1, 0)
