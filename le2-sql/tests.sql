-- tests.sql
-- Zweck: Pruefungen fuer Ergebnisse, Integritaet, Export/Import, DML, DDL und Transaktionen
-- LE2. Laeuft in einer Transaktion und hinterlaesst keine Aenderungen (ROLLBACK am Ende).
\set ON_ERROR_STOP on
\pset pager off
\encoding UTF8
\echo 'MC3: Pruefung des Beispielbestands synthetic-v2'
SELECT version() AS database_version;

BEGIN;

-- -----------------------------------------------------------------------------
-- Hilfsfunktion
-- Bricht beim ersten Fehler ab und protokolliert bestandene Pruefungen.
-- -----------------------------------------------------------------------------
CREATE TEMP TABLE results (test_id TEXT PRIMARY KEY, description TEXT NOT NULL) ON COMMIT DROP;
CREATE FUNCTION pg_temp.check_result(test_id TEXT, ok BOOLEAN, description TEXT)
RETURNS VOID LANGUAGE plpgsql AS $$
BEGIN
    IF ok IS DISTINCT FROM TRUE THEN
        RAISE EXCEPTION 'FAIL %: %', test_id, description;
    END IF;
    INSERT INTO results VALUES (test_id, description);
END;
$$;

-- -----------------------------------------------------------------------------
-- Bestand und Abfragen A-001 bis A-005
-- -----------------------------------------------------------------------------
SELECT pg_temp.check_result('P01',
    (SELECT count(*) = 4 FROM lernpfad.semester)
    AND (SELECT count(*) = 3 FROM lernpfad.location)
    AND (SELECT count(*) = 4 FROM lernpfad.lecturer)
    AND (SELECT count(*) = 10 FROM lernpfad.course)
    AND (SELECT count(*) = 3 FROM lernpfad.learner)
    AND (SELECT count(*) = 14 FROM lernpfad.prerequisite)
    AND (SELECT count(*) = 17 FROM lernpfad.course_run)
    AND (SELECT count(*) = 8 FROM lernpfad.enrollment)
    AND (SELECT count(*) = 7 FROM lernpfad.enrollment WHERE completed_on IS NOT NULL),
    'Bestand: 4 Semester, 3 Standorte, 4 Lehrpersonen, 10 Kurse, 3 Personen, 14 Voraussetzungen, 17 Durchfuehrungen, 8 Belegungen');
SELECT pg_temp.check_result('P02',
    (SELECT array_agg(required_course_id ORDER BY required_course_id)
     FROM lernpfad.prerequisite WHERE course_id = 'PROJ') = ARRAY['DE', 'ML', 'NOSQL'],
    'A-001: direkte Voraussetzungen von PROJ');
SELECT pg_temp.check_result('P03',
    (SELECT array_agg(course_id ORDER BY course_id) FROM lernpfad.all_prerequisites('PROJ'))
     = ARRAY['DE', 'EIN', 'ML', 'MOD', 'NOSQL', 'PY', 'SQL', 'STAT'],
    'A-002: acht eindeutige Voraussetzungen von PROJ');
SELECT pg_temp.check_result('P04',
    (SELECT count(*) = 0 FROM lernpfad.all_prerequisites('EIN')),
    'A-002: Grundlagenkurs EIN hat keine Voraussetzungen');
SELECT pg_temp.check_result('P05',
    (SELECT array_agg(course_id ORDER BY course_id) FROM lernpfad.eligible_courses(1))
     = ARRAY['NOSQL', 'PY', 'STAT'],
    'A-003: naechste Kurse fuer Person 1');
SELECT pg_temp.check_result('P06',
    (SELECT array_agg(course_id ORDER BY course_id) FROM lernpfad.eligible_courses(2))
     = ARRAY['ML', 'MOD', 'SQL', 'VIS'],
    'A-003: naechste Kurse fuer Person 2');
SELECT pg_temp.check_result('P07',
    (SELECT array_agg(course_id ORDER BY course_id) FROM lernpfad.eligible_courses(3))
     = ARRAY['MOD', 'PY', 'STAT'],
    'A-003: laufende Belegung SQL wird nicht erneut empfohlen');
SELECT pg_temp.check_result('P08',
    (SELECT count(*) = 0 FROM lernpfad.eligible_courses(999))
    AND (SELECT count(*) = 0 FROM lernpfad.missing_prerequisites('PROJ', 999))
    AND (SELECT count(*) = 0 FROM lernpfad.available_runs(999, 'FS27', 1)),
    'Unbekannte Person erhaelt keine Ergebnisse');
SELECT pg_temp.check_result('P09',
    (SELECT array_agg(course_id ORDER BY course_id) FROM lernpfad.missing_prerequisites('PROJ', 1))
     = ARRAY['DE', 'ML', 'NOSQL', 'PY', 'STAT']
    AND (SELECT sum(hours) = 42 FROM lernpfad.missing_prerequisites('PROJ', 1)),
    'A-004: Person 1 fehlen 5 Vorkurse mit 42 Stunden');
SELECT pg_temp.check_result('P10',
    (SELECT count(*) = 7 AND sum(hours) = 56 FROM lernpfad.missing_prerequisites('PROJ', 3)),
    'A-004: laufende Belegung zaehlt noch als fehlend (7 Kurse, 56 Stunden)');
SELECT pg_temp.check_result('P11',
    (SELECT array_agg(run_id::TEXT || ':' || course_id ORDER BY course_id, run_id)
     FROM lernpfad.available_runs(1, 'FS27', 1)) = ARRAY['10:NOSQL', '12:PY'],
    'A-005: Person 1 (VZ) in FS27 am Standort 1');
SELECT pg_temp.check_result('P12',
    (SELECT array_agg(run_id::TEXT || ':' || course_id ORDER BY course_id, run_id)
     FROM lernpfad.available_runs(2, 'FS27', 2)) = ARRAY['17:MOD'],
    'A-005: Person 2 (TZ) in FS27 am Standort 2, nur passende Studienform');
SELECT pg_temp.check_result('P13',
    (SELECT count(*) = 0 FROM lernpfad.prerequisite_cycles()),
    'Voraussetzungen sind azyklisch');

-- -----------------------------------------------------------------------------
-- Integritaet
-- Jeder Fehlerfall muss von der Datenbank abgewiesen werden.
-- -----------------------------------------------------------------------------
DO $$
BEGIN
    BEGIN
        INSERT INTO lernpfad.enrollment VALUES (999, 'EIN', 1, NULL);
        RAISE EXCEPTION 'Unbekannte Person wurde akzeptiert';
    EXCEPTION WHEN foreign_key_violation THEN NULL;
    END;
    PERFORM pg_temp.check_result('P14', TRUE, 'FK: Belegung fuer unbekannte Person wird abgewiesen');

    BEGIN
        INSERT INTO lernpfad.enrollment VALUES (2, 'SQL', 4, NULL);
        RAISE EXCEPTION 'Durchfuehrung eines anderen Kurses wurde akzeptiert';
    EXCEPTION WHEN foreign_key_violation THEN NULL;
    END;
    PERFORM pg_temp.check_result('P15', TRUE, 'Zusammengesetzter FK: Kurs muss zur Durchfuehrung passen');

    BEGIN
        INSERT INTO lernpfad.enrollment VALUES (1, 'SQL', 7, NULL);
        RAISE EXCEPTION 'Zweite Belegung desselben Kurses wurde akzeptiert';
    EXCEPTION WHEN unique_violation THEN NULL;
    END;
    PERFORM pg_temp.check_result('P16', TRUE, 'PK: hoechstens eine Belegung pro Person und Kurs');

    BEGIN
        INSERT INTO lernpfad.prerequisite VALUES ('SQL', 'SQL');
        RAISE EXCEPTION 'Selbstvoraussetzung wurde akzeptiert';
    EXCEPTION WHEN check_violation THEN NULL;
    END;
    PERFORM pg_temp.check_result('P17', TRUE, 'CHECK: direkte Selbstvoraussetzung wird abgewiesen');

    BEGIN
        INSERT INTO lernpfad.course VALUES ('ZERO', 'Fehlerfall', 0);
        RAISE EXCEPTION 'Nullstunden wurden akzeptiert';
    EXCEPTION WHEN check_violation THEN NULL;
    END;
    PERFORM pg_temp.check_result('P18', TRUE, 'CHECK: Stunden muessen positiv sein');

    BEGIN
        INSERT INTO lernpfad.prerequisite VALUES ('SQL', 'EIN');
        RAISE EXCEPTION 'Doppelte Voraussetzung wurde akzeptiert';
    EXCEPTION WHEN unique_violation THEN NULL;
    END;
    PERFORM pg_temp.check_result('P19', TRUE, 'PK: doppelte Voraussetzung wird abgewiesen');

    BEGIN
        INSERT INTO lernpfad.course_run VALUES (99, 'SQL', 'FS27', 1, 1, 'XX');
        RAISE EXCEPTION 'Ungueltige Studienform wurde akzeptiert';
    EXCEPTION WHEN check_violation THEN NULL;
    END;
    PERFORM pg_temp.check_result('P20', TRUE, 'CHECK: Studienform nur VZ oder TZ');

    BEGIN
        INSERT INTO lernpfad.semester VALUES ('HS30', DATE '2030-12-31', DATE '2030-09-01');
        RAISE EXCEPTION 'Semesterende vor Beginn wurde akzeptiert';
    EXCEPTION WHEN check_violation THEN NULL;
    END;
    PERFORM pg_temp.check_result('P21', TRUE, 'CHECK: Semesterende nach Beginn');

    BEGIN
        INSERT INTO lernpfad.course_run VALUES (99, 'NOSQL', 'FS27', 1, 1, 'VZ');
        RAISE EXCEPTION 'Doppeltes Angebot wurde akzeptiert';
    EXCEPTION WHEN unique_violation THEN NULL;
    END;
    PERFORM pg_temp.check_result('P22', TRUE, 'UNIQUE: ein Angebot pro Kurs, Semester, Standort und Studienform');

    BEGIN
        DELETE FROM lernpfad.course WHERE course_id = 'EIN';
        RAISE EXCEPTION 'Referenzierter Kurs wurde geloescht';
    EXCEPTION WHEN foreign_key_violation OR restrict_violation THEN NULL;
    END;
    PERFORM pg_temp.check_result('P23', TRUE, 'ON DELETE RESTRICT schuetzt referenzierten Kurs');
END;
$$;

-- -----------------------------------------------------------------------------
-- Export und Import
-- Alle acht Tabellen werden aus dem JSON-Export zurueckgelesen und in beide
-- Richtungen mit EXCEPT verglichen, einschliesslich Datum und NULL.
-- -----------------------------------------------------------------------------
DO $$
DECLARE
    item RECORD;
    differences BIGINT;
BEGIN
    FOR item IN SELECT * FROM (VALUES
        ('semester', 'semesters'), ('location', 'locations'), ('lecturer', 'lecturers'),
        ('course', 'courses'), ('learner', 'learners'), ('prerequisite', 'prerequisites'),
        ('course_run', 'course_runs'), ('enrollment', 'enrollments')) AS t (tbl, json_key)
    LOOP
        EXECUTE format(
            'SELECT count(*) FROM (
                (SELECT r.* FROM lernpfad.export_data AS e,
                     LATERAL jsonb_populate_recordset(NULL::lernpfad.%1$I, e.payload->%2$L) AS r
                 EXCEPT SELECT * FROM lernpfad.%1$I)
                UNION ALL
                (SELECT * FROM lernpfad.%1$I
                 EXCEPT SELECT r.* FROM lernpfad.export_data AS e,
                     LATERAL jsonb_populate_recordset(NULL::lernpfad.%1$I, e.payload->%2$L) AS r)
             ) AS d', item.tbl, item.json_key)
        INTO differences;
        IF differences <> 0 THEN
            RAISE EXCEPTION 'FAIL P24: Tabelle % weicht nach Rueckimport ab', item.tbl;
        END IF;
    END LOOP;
    PERFORM pg_temp.check_result('P24', TRUE, 'JSON-Export und Rueckimport: alle acht Tabellen identisch');
END;
$$;

-- -----------------------------------------------------------------------------
-- DML: Einfuegen, Aendern, Loeschen
-- -----------------------------------------------------------------------------
INSERT INTO lernpfad.course VALUES ('DEMO', 'Transaktionsdemo', 2);
UPDATE lernpfad.course SET hours = 3 WHERE course_id = 'DEMO';
SELECT pg_temp.check_result('P25',
    (SELECT hours = 3 FROM lernpfad.course WHERE course_id = 'DEMO'),
    'INSERT und UPDATE eines Kurses');
DELETE FROM lernpfad.course WHERE course_id = 'DEMO';
SELECT pg_temp.check_result('P26',
    NOT EXISTS (SELECT 1 FROM lernpfad.course WHERE course_id = 'DEMO'),
    'DELETE eines nicht referenzierten Kurses');

-- -----------------------------------------------------------------------------
-- Fachliche Reaktion auf Aenderungen
-- Jede Aenderung wird mit einem Savepoint zurueckgesetzt.
-- -----------------------------------------------------------------------------
SAVEPOINT cycle_case;
INSERT INTO lernpfad.prerequisite VALUES ('EIN', 'PROJ');
SELECT pg_temp.check_result('P27', EXISTS (SELECT 1 FROM lernpfad.prerequisite_cycles()),
    'Zyklus ueber mehrere Stufen wird erkannt');
ROLLBACK TO SAVEPOINT cycle_case;
INSERT INTO results VALUES ('P27', 'Zyklus ueber mehrere Stufen wird erkannt; Testkante zurueckgerollt');

SAVEPOINT new_completion;
INSERT INTO lernpfad.enrollment VALUES (1, 'PY', 8, DATE '2026-12-18');
SELECT pg_temp.check_result('P28',
    (SELECT array_agg(course_id ORDER BY course_id) FROM lernpfad.eligible_courses(1))
     = ARRAY['DE', 'NOSQL', 'STAT', 'VIS'],
    'Neuer Abschluss PY aendert die Empfehlungen von Person 1');
ROLLBACK TO SAVEPOINT new_completion;
INSERT INTO results VALUES ('P28', 'Neuer Abschluss aendert Empfehlungen; zurueckgerollt');

SAVEPOINT finish_running;
UPDATE lernpfad.enrollment SET completed_on = DATE '2027-01-22'
WHERE learner_id = 3 AND course_id = 'SQL';
SELECT pg_temp.check_result('P29',
    (SELECT sum(hours) = 48 FROM lernpfad.missing_prerequisites('PROJ', 3)),
    'Abschluss der laufenden Belegung senkt fehlende Stunden von 56 auf 48');
ROLLBACK TO SAVEPOINT finish_running;
INSERT INTO results VALUES ('P29', 'Laufende Belegung abgeschlossen senkt fehlende Stunden; zurueckgerollt');

-- -----------------------------------------------------------------------------
-- DDL: Modell anpassen und loeschen
-- PostgreSQL fuehrt DDL transaktional aus, der Savepoint stellt das Schema wieder her.
-- -----------------------------------------------------------------------------
SAVEPOINT schema_change;
ALTER TABLE lernpfad.course ADD COLUMN description TEXT;
UPDATE lernpfad.course SET description = 'Einstieg' WHERE course_id = 'EIN';
CREATE TABLE lernpfad.course_tag (
    course_id TEXT NOT NULL REFERENCES lernpfad.course (course_id),
    tag       TEXT NOT NULL,
    PRIMARY KEY (course_id, tag)
);
SELECT pg_temp.check_result('P30',
    EXISTS (SELECT 1 FROM information_schema.columns
            WHERE table_schema = 'lernpfad' AND table_name = 'course' AND column_name = 'description')
    AND EXISTS (SELECT 1 FROM information_schema.tables
                WHERE table_schema = 'lernpfad' AND table_name = 'course_tag'),
    'ALTER TABLE ADD COLUMN und CREATE TABLE');
DROP TABLE lernpfad.course_tag;
ALTER TABLE lernpfad.course DROP COLUMN description;
SELECT pg_temp.check_result('P31',
    NOT EXISTS (SELECT 1 FROM information_schema.columns
                WHERE table_schema = 'lernpfad' AND table_name = 'course' AND column_name = 'description')
    AND NOT EXISTS (SELECT 1 FROM information_schema.tables
                    WHERE table_schema = 'lernpfad' AND table_name = 'course_tag'),
    'DROP TABLE und ALTER TABLE DROP COLUMN');
ROLLBACK TO SAVEPOINT schema_change;
INSERT INTO results VALUES ('P30', 'ALTER TABLE ADD COLUMN und CREATE TABLE; zurueckgerollt');
INSERT INTO results VALUES ('P31', 'DROP TABLE und ALTER TABLE DROP COLUMN; zurueckgerollt');

SELECT pg_temp.check_result('P32',
    (SELECT array_agg(course_id ORDER BY course_id) FROM lernpfad.eligible_courses(1))
     = ARRAY['NOSQL', 'PY', 'STAT']
    AND (SELECT count(*) = 8 FROM lernpfad.enrollment)
    AND NOT EXISTS (SELECT 1 FROM information_schema.columns
                    WHERE table_schema = 'lernpfad' AND table_name = 'course' AND column_name = 'description'),
    'Nach den Savepoints ist der Ausgangsstand wiederhergestellt');

-- -----------------------------------------------------------------------------
-- Zusammenfassung
-- -----------------------------------------------------------------------------
SELECT test_id, 'PASS' AS status, description FROM results ORDER BY test_id;
SELECT count(*) AS passed, 'Alle Pruefungen bestanden' AS result FROM results;
ROLLBACK;
