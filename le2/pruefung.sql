\set ON_ERROR_STOP on
\pset pager off
\encoding UTF8
\echo 'MC3 / LE2: Funktionale Pruefung des unveraenderten synthetischen Beispielbestands'
SELECT version() AS database_version;
SELECT current_timestamp AS executed_at;

BEGIN;
CREATE TEMP TABLE results (test_id text PRIMARY KEY, description text NOT NULL) ON COMMIT DROP;
CREATE FUNCTION pg_temp.check_result(test_id text, ok boolean, description text)
RETURNS void LANGUAGE plpgsql AS $$
BEGIN
    IF ok IS DISTINCT FROM true THEN
        RAISE EXCEPTION 'FAIL %: %', test_id, description;
    END IF;
    INSERT INTO results VALUES (test_id, description);
END;
$$;

SELECT pg_temp.check_result('P01',
    (SELECT count(*) = 10 FROM le2.course)
    AND (SELECT count(*) = 3 FROM le2.learner)
    AND (SELECT count(*) = 14 FROM le2.prerequisite)
    AND (SELECT count(*) = 7 FROM le2.completion), 'Seed: 10 Kurse, 3 Personen, 14 Voraussetzungen, 7 Abschluesse');
SELECT pg_temp.check_result('P02',
    (SELECT array_agg(required_course_id ORDER BY required_course_id)
     FROM le2.prerequisite WHERE course_id = 'PROJ') = ARRAY['DE', 'ML', 'NOSQL'],
    'A-001: Direkte Voraussetzungen stimmen');
SELECT pg_temp.check_result('P03',
    (SELECT array_agg(course_id ORDER BY course_id) FROM le2.all_prerequisites('PROJ'))
     = ARRAY['DE', 'EIN', 'ML', 'MOD', 'NOSQL', 'PY', 'SQL', 'STAT'],
    'A-002: Acht eindeutige transitive Voraussetzungen');
SELECT pg_temp.check_result('P04',
    (SELECT count(*) = 0 FROM le2.all_prerequisites('EIN')), 'Wurzelkurs hat keine Voraussetzungen');
SELECT pg_temp.check_result('P05',
    (SELECT array_agg(course_id ORDER BY course_id) FROM le2.eligible_courses(1))
     = ARRAY['NOSQL', 'PY', 'STAT'], 'A-003: Empfehlungen fuer Person 1');
SELECT pg_temp.check_result('P06',
    (SELECT array_agg(course_id ORDER BY course_id) FROM le2.eligible_courses(2))
     = ARRAY['ML', 'MOD', 'SQL', 'VIS'], 'A-003: Empfehlungen fuer Person 2');
SELECT pg_temp.check_result('P07',
    (SELECT count(*) = 0 FROM le2.eligible_courses(999)), 'Unbekannte Person erhaelt keine Empfehlungen');
SELECT pg_temp.check_result('P08',
    (SELECT array_agg(course_id ORDER BY course_id) FROM le2.missing_prerequisites('PROJ', 1))
     = ARRAY['DE', 'ML', 'NOSQL', 'PY', 'STAT']
    AND (SELECT sum(hours) = 42 FROM le2.missing_prerequisites('PROJ', 1)),
    'A-004: Fuenf fehlende Vorkurse, 42 Stunden ohne Zielkurs');
SELECT pg_temp.check_result('P09',
    (SELECT count(*) = 0 FROM le2.prerequisite_cycles()), 'Beispielgraph ist azyklisch');

DO $$
BEGIN
    BEGIN
        INSERT INTO le2.completion VALUES (1, 'UNBEKANNT', DATE '2026-10-19');
        RAISE EXCEPTION 'Ungueltiger FK wurde akzeptiert';
    EXCEPTION WHEN foreign_key_violation THEN NULL;
    END;
    PERFORM pg_temp.check_result('P10', true, 'Unbekannter Kurs beim Abschluss wird durch FK abgewiesen');
    BEGIN
        INSERT INTO le2.completion VALUES (999, 'EIN', DATE '2026-10-19');
        RAISE EXCEPTION 'Ungueltige Person wurde akzeptiert';
    EXCEPTION WHEN foreign_key_violation THEN NULL;
    END;
    PERFORM pg_temp.check_result('P11', true, 'Unbekannte Person beim Abschluss wird durch FK abgewiesen');
    BEGIN
        INSERT INTO le2.prerequisite VALUES ('SQL', 'SQL');
        RAISE EXCEPTION 'Direkte Selbstvoraussetzung wurde akzeptiert';
    EXCEPTION WHEN check_violation THEN NULL;
    END;
    PERFORM pg_temp.check_result('P12', true, 'Direkte Selbstvoraussetzung wird durch CHECK abgewiesen');
    BEGIN
        INSERT INTO le2.course VALUES ('ZERO', 'Fehlerfall', 0);
        RAISE EXCEPTION 'Ungueltiger Stundenwert wurde akzeptiert';
    EXCEPTION WHEN check_violation THEN NULL;
    END;
    PERFORM pg_temp.check_result('P13', true, 'Stunden muessen positiv sein');
    BEGIN
        INSERT INTO le2.prerequisite VALUES ('SQL', 'EIN');
        RAISE EXCEPTION 'Doppelte Voraussetzung wurde akzeptiert';
    EXCEPTION WHEN unique_violation THEN NULL;
    END;
    PERFORM pg_temp.check_result('P14', true, 'Zusammengesetzter PK verhindert doppelte Voraussetzung');
    BEGIN
        INSERT INTO le2.completion VALUES (1, 'EIN', DATE '2026-10-19');
        RAISE EXCEPTION 'Doppelter Abschluss wurde akzeptiert';
    EXCEPTION WHEN unique_violation THEN NULL;
    END;
    PERFORM pg_temp.check_result('P15', true, 'Zusammengesetzter PK verhindert doppelten Abschluss');
    BEGIN
        DELETE FROM le2.course WHERE course_id = 'EIN';
        RAISE EXCEPTION 'Referenzierter Kurs wurde geloescht';
    EXCEPTION WHEN foreign_key_violation OR restrict_violation THEN NULL;
    END;
    PERFORM pg_temp.check_result('P16', true, 'ON DELETE RESTRICT schuetzt referenzierten Kurs');
END;
$$;

-- Vollstaendiger JSON-Roundtrip aller vier Relationen, einschliesslich Datumstyp.
CREATE TEMP TABLE imported_course (LIKE le2.course INCLUDING ALL) ON COMMIT DROP;
CREATE TEMP TABLE imported_learner (LIKE le2.learner INCLUDING ALL) ON COMMIT DROP;
CREATE TEMP TABLE imported_prerequisite (LIKE le2.prerequisite INCLUDING ALL) ON COMMIT DROP;
CREATE TEMP TABLE imported_completion (LIKE le2.completion INCLUDING ALL) ON COMMIT DROP;
INSERT INTO imported_course SELECT r.* FROM le2.export_data AS e,
    LATERAL jsonb_populate_recordset(NULL::le2.course, e.payload->'courses') AS r;
INSERT INTO imported_learner SELECT r.* FROM le2.export_data AS e,
    LATERAL jsonb_populate_recordset(NULL::le2.learner, e.payload->'learners') AS r;
INSERT INTO imported_prerequisite SELECT r.* FROM le2.export_data AS e,
    LATERAL jsonb_populate_recordset(NULL::le2.prerequisite, e.payload->'prerequisites') AS r;
INSERT INTO imported_completion SELECT r.* FROM le2.export_data AS e,
    LATERAL jsonb_populate_recordset(NULL::le2.completion, e.payload->'completions') AS r;
SELECT pg_temp.check_result('P17', NOT EXISTS (
    (SELECT * FROM imported_course EXCEPT SELECT * FROM le2.course)
    UNION ALL (SELECT * FROM le2.course EXCEPT SELECT * FROM imported_course)
), 'JSON-Export/-Import: Kurse identisch');
SELECT pg_temp.check_result('P18', NOT EXISTS (
    (SELECT * FROM imported_learner EXCEPT SELECT * FROM le2.learner)
    UNION ALL (SELECT * FROM le2.learner EXCEPT SELECT * FROM imported_learner)
), 'JSON-Export/-Import: Lernende identisch');
SELECT pg_temp.check_result('P19', NOT EXISTS (
    (SELECT * FROM imported_prerequisite EXCEPT SELECT * FROM le2.prerequisite)
    UNION ALL (SELECT * FROM le2.prerequisite EXCEPT SELECT * FROM imported_prerequisite)
), 'JSON-Export/-Import: Voraussetzungen identisch');
SELECT pg_temp.check_result('P20', NOT EXISTS (
    (SELECT * FROM imported_completion EXCEPT SELECT * FROM le2.completion)
    UNION ALL (SELECT * FROM le2.completion EXCEPT SELECT * FROM imported_completion)
), 'JSON-Export/-Import: Abschluesse einschliesslich Datum identisch');

SAVEPOINT crud_demo;
INSERT INTO le2.course VALUES ('DEMO', 'Transaktionsdemo', 2);
UPDATE le2.course SET hours = 3 WHERE course_id = 'DEMO';
SELECT pg_temp.check_result('P21', (SELECT hours = 3 FROM le2.course WHERE course_id = 'DEMO'),
    'INSERT und UPDATE funktionieren');
DELETE FROM le2.course WHERE course_id = 'DEMO';
SELECT pg_temp.check_result('P22', NOT EXISTS (SELECT 1 FROM le2.course WHERE course_id = 'DEMO'),
    'DELETE eines nicht referenzierten Kurses funktioniert');
-- Ergebnisse P21/P22 bleiben erhalten; die Demo hat ihren Kurs selbst entfernt.
RELEASE SAVEPOINT crud_demo;

SAVEPOINT test_cycle;
INSERT INTO le2.prerequisite VALUES ('EIN', 'PROJ');
SELECT pg_temp.check_result('P23', EXISTS (SELECT 1 FROM le2.prerequisite_cycles()),
    'Laengerer Zyklus wird durch fachliche Pruefung erkannt');
ROLLBACK TO SAVEPOINT test_cycle;
-- P23 wurde mit dem absichtlichen Fehler zurueckgerollt; jetzt registrieren.
INSERT INTO results VALUES ('P23', 'Laengerer Zyklus erkannt; Testkante vollstaendig zurueckgerollt');
RELEASE SAVEPOINT test_cycle;

SAVEPOINT changed_completion;
INSERT INTO le2.completion VALUES (1, 'PY', DATE '2026-10-19');
SELECT pg_temp.check_result('P24',
    (SELECT array_agg(course_id ORDER BY course_id) FROM le2.eligible_courses(1))
     = ARRAY['DE', 'NOSQL', 'STAT', 'VIS'], 'Neue Abschluesse aendern Empfehlungen korrekt');
ROLLBACK TO SAVEPOINT changed_completion;
INSERT INTO results VALUES ('P24', 'Empfehlungen reagieren auf Abschluss; Ausgangsstand wiederhergestellt');
RELEASE SAVEPOINT changed_completion;
SELECT pg_temp.check_result('P25',
    (SELECT array_agg(course_id ORDER BY course_id) FROM le2.eligible_courses(1))
     = ARRAY['NOSQL', 'PY', 'STAT']
    AND (SELECT count(*) = 0 FROM le2.prerequisite_cycles()), 'ROLLBACK erhaelt gueltigen Ausgangsstand');

SELECT test_id, 'PASS' AS status, description FROM results ORDER BY test_id;
SELECT count(*) AS passed, 'Alle Pruefungen bestanden' AS result FROM results;
ROLLBACK;
