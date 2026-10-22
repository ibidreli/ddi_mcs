-- queries.sql
-- Zweck: Abfragen A-001 bis A-005, CRUD-Demo und Ausfuehrungsplan am Beispielbestand
-- LE2. Aenderungen laufen in einer Transaktion und werden zurueckgerollt.
\set ON_ERROR_STOP on
\pset pager off
\encoding UTF8

-- -----------------------------------------------------------------------------
-- A-001 bis A-005
-- -----------------------------------------------------------------------------
\echo 'A-001: direkte Voraussetzungen von PROJ'
SELECT c.course_id, c.title
FROM lernpfad.prerequisite AS p
JOIN lernpfad.course AS c ON c.course_id = p.required_course_id
WHERE p.course_id = 'PROJ'
ORDER BY c.course_id;

\echo 'A-002: alle Voraussetzungen von PROJ ueber alle Stufen, ohne Duplikate'
SELECT * FROM lernpfad.all_prerequisites('PROJ') ORDER BY course_id;

\echo 'A-003: Kurse, die Person 1 jetzt belegen darf'
SELECT * FROM lernpfad.eligible_courses(1) ORDER BY course_id;

\echo 'A-004: fuer PROJ fehlende Vorkurse von Person 1'
SELECT * FROM lernpfad.missing_prerequisites('PROJ', 1) ORDER BY course_id;
SELECT count(*) AS missing_courses, coalesce(sum(hours), 0) AS missing_hours
FROM lernpfad.missing_prerequisites('PROJ', 1);

\echo 'A-005: passende Durchfuehrungen fuer Person 1 in FS27 am Standort 1'
SELECT * FROM lernpfad.available_runs(1, 'FS27', 1) ORDER BY course_id, run_id;

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
INSERT INTO lernpfad.enrollment (learner_id, course_id, run_id, completed_on)
VALUES (1, 'PY', 8, DATE '2026-12-18');
\echo 'Mit Abschluss PY: DE und VIS kommen dazu, PY entfaellt'
SELECT * FROM lernpfad.eligible_courses(1) ORDER BY course_id;
ROLLBACK;
\echo 'Nach ROLLBACK gilt wieder der Ausgangsstand'
SELECT * FROM lernpfad.eligible_courses(1) ORDER BY course_id;

-- -----------------------------------------------------------------------------
-- Ausfuehrungsplan
-- Zeigt Indexnutzung und Rekursion; ersetzt keine Messung.
-- -----------------------------------------------------------------------------
\echo 'Ausfuehrungsplan von A-002'
EXPLAIN (ANALYZE, BUFFERS, COSTS OFF)
SELECT * FROM lernpfad.all_prerequisites('PROJ');
