\set ON_ERROR_STOP on
\pset pager off
\encoding UTF8
\echo 'A-001: Direkte Voraussetzungen des Zielkurses PROJ'
SELECT c.course_id, c.title
FROM le2.prerequisite AS p
JOIN le2.course AS c ON c.course_id = p.required_course_id
WHERE p.course_id = 'PROJ'
ORDER BY c.course_id;

\echo 'A-002: Alle direkten und indirekten Voraussetzungen von PROJ, ohne Duplikate'
SELECT * FROM le2.all_prerequisites('PROJ') ORDER BY course_id;

\echo 'A-003: Jetzt zulaessige Kurse fuer Lernende A (ID 1)'
SELECT * FROM le2.eligible_courses(1) ORDER BY course_id;

\echo 'A-004: Fuer Lernende A vor PROJ noch fehlende Kurse'
SELECT * FROM le2.missing_prerequisites('PROJ', 1) ORDER BY course_id;
SELECT count(*) AS missing_courses, coalesce(sum(hours), 0) AS prerequisite_hours
FROM le2.missing_prerequisites('PROJ', 1);

\echo 'CRUD-Demo: Aenderungen nur in einer zurueckgerollten Transaktion'
BEGIN;
INSERT INTO le2.course (course_id, title, hours)
VALUES ('DEMO', 'Nur fuer die Transaktionsdemo', 2)
RETURNING *;
UPDATE le2.course SET hours = 3 WHERE course_id = 'DEMO' RETURNING *;
DELETE FROM le2.course WHERE course_id = 'DEMO' RETURNING *;
INSERT INTO le2.completion (learner_id, course_id, completed_on)
VALUES (1, 'PY', DATE '2026-10-19');
\echo 'Innerhalb der Transaktion: DE und VIS kommen hinzu, PY entfaellt'
SELECT * FROM le2.eligible_courses(1) ORDER BY course_id;
ROLLBACK;
\echo 'Nach ROLLBACK ist der Ausgangsstand wiederhergestellt'
SELECT * FROM le2.eligible_courses(1) ORDER BY course_id;

\echo 'Ausfuehrungsplan zur Einordnung; kein SQL/NoSQL-Benchmark'
EXPLAIN (ANALYZE, BUFFERS)
SELECT * FROM le2.all_prerequisites('PROJ');
