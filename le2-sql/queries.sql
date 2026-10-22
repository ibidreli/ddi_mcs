-- queries.sql
-- Zweck: Abfragen A-001 bis A-005, CRUD-Demo und Ausfuehrungsplan am Beispielbestand
-- LE2. Aenderungen laufen in einer Transaktion und werden zurueckgerollt.
\set ON_ERROR_STOP on
\pset pager off
\encoding UTF8

-- -----------------------------------------------------------------------------
-- A-001 bis A-005
-- -----------------------------------------------------------------------------
\echo 'A-001: Kurse, die ueber alle Stufen abgeschlossen sein muessen, um ML zu belegen'
SELECT * FROM lernpfad.all_prerequisites('ML') ORDER BY course_id;

\echo 'A-002: Kurse, die Student A laut Abschluessen als Naechstes belegen darf'
SELECT * FROM lernpfad.eligible_courses(1) ORDER BY course_id;

\echo 'A-003: Kurse, die Student A fuer ML noch fehlen'
SELECT * FROM lernpfad.missing_prerequisites('ML', 1) ORDER BY course_id;

\echo 'A-004: wo und bei wem Student A PYTHON im Fruehlingssemester 2027 besuchen kann'
SELECT * FROM lernpfad.course_offers(1, 'PYTHON', 'FS27') ORDER BY run_id;

\echo 'A-005: Kurse von M. Frei im Fruehlingssemester 2027'
SELECT * FROM lernpfad.lecturer_courses(2, 'FS27') ORDER BY course_id, run_id;

-- -----------------------------------------------------------------------------
-- CRUD-Demo
-- -----------------------------------------------------------------------------
\echo 'CRUD-Demo in einer Transaktion mit ROLLBACK'
BEGIN;
INSERT INTO lernpfad.course (course_id, title, hours)
VALUES ('DEMO', 'Nur fuer die Transaktionsdemo', 2)
RETURNING *;
UPDATE lernpfad.course SET hours = 3 WHERE course_id = 'DEMO' RETURNING *;
DELETE FROM lernpfad.course WHERE course_id = 'DEMO' RETURNING *;
INSERT INTO lernpfad.completion (learner_id, course_id, run_id, completed_on)
VALUES (1, 'PYTHON', 6, DATE '2027-01-22');
\echo 'Mit Abschluss PYTHON: EDA kommt dazu, PYTHON entfaellt'
SELECT * FROM lernpfad.eligible_courses(1) ORDER BY course_id;
ROLLBACK;
\echo 'Nach ROLLBACK gilt wieder der Ausgangsstand'
SELECT * FROM lernpfad.eligible_courses(1) ORDER BY course_id;

-- -----------------------------------------------------------------------------
-- Ausfuehrungsplan
-- Zeigt Indexnutzung und Rekursion; ersetzt keine Messung.
-- -----------------------------------------------------------------------------
\echo 'Ausfuehrungsplan von A-001'
EXPLAIN (ANALYZE, BUFFERS, COSTS OFF)
SELECT * FROM lernpfad.all_prerequisites('ML');
