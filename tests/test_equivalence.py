"""test_equivalence.py
Zweck: K1 Korrektheit. A-001 bis A-005 liefern in PostgreSQL und Neo4j dieselben Ergebnisse.
LE2, LE3. Prueft alle Kurse, Personen und Kombinationen des Beispielbestands.
"""
import itertools

import pytest
from neo4j.exceptions import ConstraintError

from src import config, dataset
from src.db import neo4j_driver, pg_connect
from src.load import load_neo4j
from src.queries import run_cypher, run_sql

SEED = dataset.read_json(config.SEED_JSON)
COURSES = [c["course_id"] for c in SEED["courses"]]
LEARNERS = [l["learner_id"] for l in SEED["learners"]] + [999]
SEMESTERS = [s["semester_id"] for s in SEED["semesters"]]
LOCATIONS = [o["location_id"] for o in SEED["locations"]]


#-----------------------------------------------------------------------------
# Verbindungen; Neo4j wird vor den Pruefungen mit dem Beispielbestand geladen
#-----------------------------------------------------------------------------
@pytest.fixture(scope="module")
def dbs():
    with pg_connect() as conn, neo4j_driver() as driver:
        load_neo4j(SEED, driver=driver)
        with driver.session() as session:
            yield conn, session


def same(dbs, query_id, **params):
    conn, session = dbs
    assert run_sql(conn, query_id, **params) == run_cypher(session, query_id, **params), params


#-----------------------------------------------------------------------------
# Gleiche Ergebnisse fuer alle Parameter
#-----------------------------------------------------------------------------
@pytest.mark.parametrize("course", COURSES)
def test_a001(dbs, course):
    same(dbs, "A-001", course=course)


@pytest.mark.parametrize("course", COURSES)
def test_a002(dbs, course):
    same(dbs, "A-002", course=course)


@pytest.mark.parametrize("learner", LEARNERS)
def test_a003(dbs, learner):
    same(dbs, "A-003", learner=learner)


@pytest.mark.parametrize("course,learner", list(itertools.product(COURSES, LEARNERS)))
def test_a004(dbs, course, learner):
    same(dbs, "A-004", course=course, learner=learner)


@pytest.mark.parametrize("learner,semester,location", list(itertools.product(LEARNERS, SEMESTERS, LOCATIONS)))
def test_a005(dbs, learner, semester, location):
    same(dbs, "A-005", learner=learner, semester=semester, location=location)


#-----------------------------------------------------------------------------
# Erwartete Werte und Eindeutigkeit in Neo4j
#-----------------------------------------------------------------------------
def test_expected_values(dbs):
    _, session = dbs
    assert [r[0] for r in run_cypher(session, "A-004", course="PROJ", learner=1)] == \
        ["DE", "ML", "NOSQL", "PY", "STAT"]
    assert tuple(run_cypher(session, "A-004-summe", course="PROJ", learner=1)[0]) == (5, 42)
    assert [(r[0], r[1]) for r in run_cypher(session, "A-005", learner=1, semester="FS27", location=1)] == \
        [(10, "NOSQL"), (12, "PY")]


def test_neo4j_counts(dbs):
    _, session = dbs
    counts = dict(session.run("MATCH (n) RETURN labels(n)[0] AS label, count(*) AS n").values())
    assert counts == {"Semester": 4, "Location": 3, "Lecturer": 4, "Course": 10,
                      "Learner": 3, "Run": 17}
    rels = dict(session.run("MATCH ()-[r]->() RETURN type(r) AS t, count(*) AS n").values())
    assert rels == {"REQUIRES": 14, "OF": 17, "IN": 17, "AT": 17, "TEACHES": 17,
                    "ENROLLED": 8, "COMPLETED": 7}


def test_neo4j_rejects_duplicate_course(dbs):
    _, session = dbs
    with pytest.raises(ConstraintError):
        session.run("CREATE (:Course {id: 'PROJ', title: 'Doppelt', hours: 1})").consume()
