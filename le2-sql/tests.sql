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
    AND (SELECT count(*) = 6 FROM lernpfad.completion),
    'Bestand: 4 Semester, 3 Standorte, 4 Lehrpersonen, 10 Kurse, 3 Personen, 14 Voraussetzungen, 17 Durchfuehrungen, 6 Abschluesse');
SELECT pg_temp.check_result('P02',
    (SELECT array_agg(course_id ORDER BY course_id) FROM lernpfad.all_prerequisites('ML'))
     = ARRAY['ALGEBRA', 'ANALYSIS', 'BASICS', 'EDA', 'PYTHON', 'SQL'],
    'A-001: ML braucht ueber alle Stufen sechs Kurse');
SELECT pg_temp.check_result('P03',
    (SELECT count(*) = 0 FROM lernpfad.all_prerequisites('BASICS')),
    'A-001: BASICS hat keine Voraussetzungen');
SELECT pg_temp.check_result('P04',
    (SELECT array_agg(course_id ORDER BY course_id) FROM lernpfad.all_prerequisites('NOSQL'))
     = ARRAY['BASICS', 'DB_MODELING', 'SQL'],
    'A-001: SQL erscheint trotz zwei Wegen nur einmal');
SELECT pg_temp.check_result('P05',
    (SELECT array_agg(course_id ORDER BY course_id) FROM lernpfad.eligible_courses(1))
     = ARRAY['ALGEBRA', 'DB_MODELING', 'PYTHON'],
    'A-002: naechste Kurse fuer Student A');
SELECT pg_temp.check_result('P06',
    (SELECT array_agg(course_id ORDER BY course_id) FROM lernpfad.eligible_courses(2))
     = ARRAY['ANALYSIS', 'SQL'],
    'A-002: naechste Kurse fuer Student B');
SELECT pg_temp.check_result('P07',
    (SELECT array_agg(course_id ORDER BY course_id) FROM lernpfad.eligible_courses(3))
     = ARRAY['ALGEBRA', 'PYTHON', 'SQL'],
    'A-002: naechste Kurse fuer Student C');
SELECT pg_temp.check_result('P08',
    (SELECT count(*) = 0 FROM lernpfad.eligible_courses(999))
    AND (SELECT count(*) = 0 FROM lernpfad.missing_prerequisites('ML', 999))
    AND (SELECT count(*) = 0 FROM lernpfad.course_offers(999, 'BASICS', 'FS27')),
    'Unbekannte Person erhaelt keine Ergebnisse');
SELECT pg_temp.check_result('P09',
    (SELECT array_agg(course_id ORDER BY course_id) FROM lernpfad.missing_prerequisites('ML', 1))
     = ARRAY['ALGEBRA', 'ANALYSIS', 'EDA', 'PYTHON'],
    'A-003: Student A fehlen fuer ML vier Kurse');
SELECT pg_temp.check_result('P10',
    (SELECT count(*) = 5 FROM lernpfad.missing_prerequisites('ML', 3)),
    'A-003: Student C fehlen fuer ML fuenf Kurse');
SELECT pg_temp.check_result('P11',
    (SELECT array_agg(run_id::TEXT || ':' || location || ':' || lecturer)
     FROM lernpfad.course_offers(1, 'PYTHON', 'FS27')) = ARRAY['9:Brugg-Windisch:T. Brunner'],
    'A-004: Student A kann PYTHON im FS27 in Brugg-Windisch bei T. Brunner besuchen');
SELECT pg_temp.check_result('P12',
    (SELECT count(*) = 0 FROM lernpfad.course_offers(1, 'ML', 'FS27')),
    'A-004: kein Angebot, solange Vorkurse fehlen');
SELECT pg_temp.check_result('P13',
    (SELECT array_agg(run_id::TEXT || ':' || location ORDER BY run_id)
     FROM lernpfad.course_offers(2, 'SQL', 'FS27')) = ARRAY['13:Olten'],
    'A-004: Student B (Teilzeit) erhaelt nur die Teilzeit-Durchfuehrung');
SELECT pg_temp.check_result('P14',
    (SELECT array_agg(run_id::TEXT || ':' || course_id || ':' || location ORDER BY course_id, run_id)
     FROM lernpfad.lecturer_courses(2, 'FS27'))
     = ARRAY['11:DB_MODELING:Brugg-Windisch', '17:DB_MODELING:Olten', '16:NOSQL:Brugg-Windisch', '13:SQL:Olten'],
    'A-005: Kurse von M. Frei im FS27');
SELECT pg_temp.check_result('P15',
    (SELECT count(*) = 0 FROM lernpfad.prerequisite_cycles()),
    'Voraussetzungen sind azyklisch');

-- -----------------------------------------------------------------------------
-- Integritaet
-- Jeder Fehlerfall muss von der Datenbank abgewiesen werden.
-- -----------------------------------------------------------------------------
DO $$
BEGIN
    BEGIN
        INSERT INTO lernpfad.completion VALUES (999, 'BASICS', 1, DATE '2026-01-20');
        RAISE EXCEPTION 'Unbekannte Person wurde akzeptiert';
    EXCEPTION WHEN foreign_key_violation THEN NULL;
    END;
    PERFORM pg_temp.check_result('P16', TRUE, 'FK: Abschluss fuer unbekannte Person wird abgewiesen');

    BEGIN
        INSERT INTO lernpfad.completion VALUES (2, 'SQL', 4, DATE '2026-06-19');
        RAISE EXCEPTION 'Durchfuehrung eines anderen Kurses wurde akzeptiert';
    EXCEPTION WHEN foreign_key_violation THEN NULL;
    END;
    PERFORM pg_temp.check_result('P17', TRUE, 'Zusammengesetzter FK: Kurs muss zur Durchfuehrung passen');

    BEGIN
        INSERT INTO lernpfad.completion VALUES (1, 'SQL', 7, DATE '2027-01-22');
        RAISE EXCEPTION 'Zweiter Abschluss desselben Kurses wurde akzeptiert';
    EXCEPTION WHEN unique_violation THEN NULL;
    END;
    PERFORM pg_temp.check_result('P18', TRUE, 'PK: hoechstens ein Abschluss pro Person und Kurs');

    BEGIN
        INSERT INTO lernpfad.completion VALUES (3, 'SQL', 7, NULL);
        RAISE EXCEPTION 'Abschluss ohne Datum wurde akzeptiert';
    EXCEPTION WHEN not_null_violation THEN NULL;
    END;
    PERFORM pg_temp.check_result('P19', TRUE, 'NOT NULL: Abschluss braucht ein Datum');

    BEGIN
        INSERT INTO lernpfad.prerequisite VALUES ('SQL', 'SQL');
        RAISE EXCEPTION 'Selbstvoraussetzung wurde akzeptiert';
    EXCEPTION WHEN check_violation THEN NULL;
    END;
    PERFORM pg_temp.check_result('P20', TRUE, 'CHECK: direkte Selbstvoraussetzung wird abgewiesen');

    BEGIN
        INSERT INTO lernpfad.course VALUES ('ZERO', 'Fehlerfall', 0);
        RAISE EXCEPTION 'Nullstunden wurden akzeptiert';
    EXCEPTION WHEN check_violation THEN NULL;
    END;
    PERFORM pg_temp.check_result('P21', TRUE, 'CHECK: Stunden muessen positiv sein');

    BEGIN
        INSERT INTO lernpfad.prerequisite VALUES ('SQL', 'BASICS');
        RAISE EXCEPTION 'Doppelte Voraussetzung wurde akzeptiert';
    EXCEPTION WHEN unique_violation THEN NULL;
    END;
    PERFORM pg_temp.check_result('P22', TRUE, 'PK: doppelte Voraussetzung wird abgewiesen');

    BEGIN
        INSERT INTO lernpfad.course_run VALUES (99, 'SQL', 'FS27', 1, 1, 'XX');
        RAISE EXCEPTION 'Ungueltige Studienform wurde akzeptiert';
    EXCEPTION WHEN check_violation THEN NULL;
    END;
    PERFORM pg_temp.check_result('P23', TRUE, 'CHECK: Studienform nur VZ oder TZ');

    BEGIN
        INSERT INTO lernpfad.semester VALUES ('HS30', 'Herbstsemester 2030', DATE '2030-12-31', DATE '2030-09-01');
        RAISE EXCEPTION 'Semesterende vor Beginn wurde akzeptiert';
    EXCEPTION WHEN check_violation THEN NULL;
    END;
    PERFORM pg_temp.check_result('P24', TRUE, 'CHECK: Semesterende nach Beginn');

    BEGIN
        INSERT INTO lernpfad.course_run VALUES (99, 'NOSQL', 'FS27', 1, 1, 'VZ');
        RAISE EXCEPTION 'Doppeltes Angebot wurde akzeptiert';
    EXCEPTION WHEN unique_violation THEN NULL;
    END;
    PERFORM pg_temp.check_result('P25', TRUE, 'UNIQUE: ein Angebot pro Kurs, Semester, Standort und Studienform');

    BEGIN
        DELETE FROM lernpfad.course WHERE course_id = 'BASICS';
        RAISE EXCEPTION 'Referenzierter Kurs wurde geloescht';
    EXCEPTION WHEN foreign_key_violation OR restrict_violation THEN NULL;
    END;
    PERFORM pg_temp.check_result('P26', TRUE, 'ON DELETE RESTRICT schuetzt referenzierten Kurs');
END;
$$;

-- -----------------------------------------------------------------------------
-- Export und Import
-- Alle acht Tabellen werden aus dem JSON-Export zurueckgelesen und in beide
-- Richtungen mit EXCEPT verglichen, einschliesslich Datum.
-- -----------------------------------------------------------------------------
DO $$
DECLARE
    item RECORD;
    differences BIGINT;
BEGIN
    FOR item IN SELECT * FROM (VALUES
        ('semester', 'semesters'), ('location', 'locations'), ('lecturer', 'lecturers'),
        ('course', 'courses'), ('learner', 'learners'), ('prerequisite', 'prerequisites'),
        ('course_run', 'course_runs'), ('completion', 'completions')) AS t (tbl, json_key)
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
            RAISE EXCEPTION 'FAIL P27: Tabelle % weicht nach Rueckimport ab', item.tbl;
        END IF;
    END LOOP;
    PERFORM pg_temp.check_result('P27', TRUE, 'JSON-Export und Rueckimport: alle acht Tabellen identisch');
END;
$$;

-- -----------------------------------------------------------------------------
-- DML: Einfuegen, Aendern, Loeschen
-- -----------------------------------------------------------------------------
INSERT INTO lernpfad.course VALUES ('DEMO', 'Transaktionsdemo', 2);
UPDATE lernpfad.course SET hours = 3 WHERE course_id = 'DEMO';
SELECT pg_temp.check_result('P28',
    (SELECT hours = 3 FROM lernpfad.course WHERE course_id = 'DEMO'),
    'INSERT und UPDATE eines Kurses');
DELETE FROM lernpfad.course WHERE course_id = 'DEMO';
SELECT pg_temp.check_result('P29',
    NOT EXISTS (SELECT 1 FROM lernpfad.course WHERE course_id = 'DEMO'),
    'DELETE eines nicht referenzierten Kurses');

-- -----------------------------------------------------------------------------
-- Fachliche Reaktion auf Aenderungen
-- Jede Aenderung wird mit einem Savepoint zurueckgesetzt.
-- -----------------------------------------------------------------------------
SAVEPOINT cycle_case;
INSERT INTO lernpfad.prerequisite VALUES ('BASICS', 'ML');
SELECT pg_temp.check_result('P30', EXISTS (SELECT 1 FROM lernpfad.prerequisite_cycles()),
    'Zyklus ueber mehrere Stufen wird erkannt');
ROLLBACK TO SAVEPOINT cycle_case;
INSERT INTO results VALUES ('P30', 'Zyklus ueber mehrere Stufen wird erkannt; Testkante zurueckgerollt');

SAVEPOINT new_completion;
INSERT INTO lernpfad.completion VALUES (1, 'PYTHON', 6, DATE '2027-01-22');
SELECT pg_temp.check_result('P31',
    (SELECT array_agg(course_id ORDER BY course_id) FROM lernpfad.eligible_courses(1))
     = ARRAY['ALGEBRA', 'DB_MODELING', 'EDA'],
    'Neuer Abschluss PYTHON: EDA wird fuer Student A frei');
SELECT pg_temp.check_result('P32',
    (SELECT array_agg(run_id::TEXT || ':' || lecturer) FROM lernpfad.course_offers(1, 'EDA', 'FS27'))
     = ARRAY['14:L. Keller'],
    'Neuer Abschluss PYTHON: Angebot fuer EDA im FS27 erscheint');
ROLLBACK TO SAVEPOINT new_completion;
INSERT INTO results VALUES ('P31', 'Neuer Abschluss aendert Empfehlungen; zurueckgerollt');
INSERT INTO results VALUES ('P32', 'Neuer Abschluss gibt Angebot frei; zurueckgerollt');

-- -----------------------------------------------------------------------------
-- DDL: Modell anpassen und loeschen
-- PostgreSQL fuehrt DDL transaktional aus, der Savepoint stellt das Schema wieder her.
-- -----------------------------------------------------------------------------
SAVEPOINT schema_change;
ALTER TABLE lernpfad.course ADD COLUMN description TEXT;
UPDATE lernpfad.course SET description = 'Einstieg' WHERE course_id = 'BASICS';
CREATE TABLE lernpfad.course_tag (
    course_id TEXT NOT NULL REFERENCES lernpfad.course (course_id),
    tag       TEXT NOT NULL,
    PRIMARY KEY (course_id, tag)
);
SELECT pg_temp.check_result('P33',
    EXISTS (SELECT 1 FROM information_schema.columns
            WHERE table_schema = 'lernpfad' AND table_name = 'course' AND column_name = 'description')
    AND EXISTS (SELECT 1 FROM information_schema.tables
                WHERE table_schema = 'lernpfad' AND table_name = 'course_tag'),
    'ALTER TABLE ADD COLUMN und CREATE TABLE');
DROP TABLE lernpfad.course_tag;
ALTER TABLE lernpfad.course DROP COLUMN description;
SELECT pg_temp.check_result('P34',
    NOT EXISTS (SELECT 1 FROM information_schema.columns
                WHERE table_schema = 'lernpfad' AND table_name = 'course' AND column_name = 'description')
    AND NOT EXISTS (SELECT 1 FROM information_schema.tables
                    WHERE table_schema = 'lernpfad' AND table_name = 'course_tag'),
    'DROP TABLE und ALTER TABLE DROP COLUMN');
ROLLBACK TO SAVEPOINT schema_change;
INSERT INTO results VALUES ('P33', 'ALTER TABLE ADD COLUMN und CREATE TABLE; zurueckgerollt');
INSERT INTO results VALUES ('P34', 'DROP TABLE und ALTER TABLE DROP COLUMN; zurueckgerollt');

SELECT pg_temp.check_result('P35',
    (SELECT array_agg(course_id ORDER BY course_id) FROM lernpfad.eligible_courses(1))
     = ARRAY['ALGEBRA', 'DB_MODELING', 'PYTHON']
    AND (SELECT count(*) = 6 FROM lernpfad.completion)
    AND NOT EXISTS (SELECT 1 FROM information_schema.columns
                    WHERE table_schema = 'lernpfad' AND table_name = 'course' AND column_name = 'description'),
    'Nach den Savepoints ist der Ausgangsstand wiederhergestellt');

-- -----------------------------------------------------------------------------
-- Zusammenfassung
-- -----------------------------------------------------------------------------
SELECT test_id, 'PASS' AS status, description FROM results ORDER BY test_id;
SELECT count(*) AS passed, 'Alle Pruefungen bestanden' AS result FROM results;
ROLLBACK;
