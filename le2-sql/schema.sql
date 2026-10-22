-- schema.sql
-- Zweck: Schema, Constraints, Indizes, Abfragefunktionen und Exportansicht der Lernpfadplanung
-- LE2 (relationale Umsetzung). Baut das Schema bei jedem Lauf vollstaendig neu auf.

BEGIN;

-- -----------------------------------------------------------------------------
-- Schema neu anlegen
-- Reproduzierbar: Struktur und Daten entstehen nur aus den Skripten.
-- -----------------------------------------------------------------------------
DROP SCHEMA IF EXISTS lernpfad CASCADE;
CREATE SCHEMA lernpfad;
COMMENT ON SCHEMA lernpfad IS 'MC3 Lernpfadplanung mit ausschliesslich synthetischen Daten';

-- -----------------------------------------------------------------------------
-- Entitaeten
-- course, learner, semester, location, lecturer und course_run
-- -----------------------------------------------------------------------------
CREATE TABLE lernpfad.course (
    course_id   TEXT PRIMARY KEY CHECK (course_id ~ '^[A-Z][A-Z0-9_]{1,15}$'),
    title       TEXT NOT NULL CHECK (length(btrim(title)) > 0),
    hours       INTEGER NOT NULL CHECK (hours > 0)
);

CREATE TABLE lernpfad.learner (
    learner_id   INTEGER PRIMARY KEY CHECK (learner_id > 0),
    display_name TEXT NOT NULL CHECK (length(btrim(display_name)) > 0),
    study_mode   TEXT NOT NULL CHECK (study_mode IN ('VZ', 'TZ'))
);

CREATE TABLE lernpfad.semester (
    semester_id TEXT PRIMARY KEY CHECK (semester_id ~ '^(HS|FS)[0-9]{2}$'),
    name        TEXT NOT NULL UNIQUE CHECK (length(btrim(name)) > 0),
    starts_on   DATE NOT NULL,
    ends_on     DATE NOT NULL,
    CHECK (ends_on > starts_on)
);

CREATE TABLE lernpfad.location (
    location_id INTEGER PRIMARY KEY CHECK (location_id > 0),
    name        TEXT NOT NULL UNIQUE CHECK (length(btrim(name)) > 0)
);

CREATE TABLE lernpfad.lecturer (
    lecturer_id  INTEGER PRIMARY KEY CHECK (lecturer_id > 0),
    display_name TEXT NOT NULL CHECK (length(btrim(display_name)) > 0)
);

-- Eine Durchfuehrung ist ein Kurs in einem Semester an einem Standort mit einer Lehrperson.
CREATE TABLE lernpfad.course_run (
    run_id      INTEGER PRIMARY KEY CHECK (run_id > 0),
    course_id   TEXT NOT NULL REFERENCES lernpfad.course (course_id)
                    ON UPDATE CASCADE ON DELETE RESTRICT,
    semester_id TEXT NOT NULL REFERENCES lernpfad.semester (semester_id)
                    ON UPDATE CASCADE ON DELETE RESTRICT,
    location_id INTEGER NOT NULL REFERENCES lernpfad.location (location_id)
                    ON UPDATE CASCADE ON DELETE RESTRICT,
    lecturer_id INTEGER NOT NULL REFERENCES lernpfad.lecturer (lecturer_id)
                    ON UPDATE CASCADE ON DELETE RESTRICT,
    study_mode  TEXT NOT NULL CHECK (study_mode IN ('VZ', 'TZ')),
    -- Ziel des zusammengesetzten Fremdschluessels in completion
    UNIQUE (run_id, course_id),
    -- Ein Kurs wird pro Semester, Standort und Studienform hoechstens einmal angeboten
    UNIQUE (course_id, semester_id, location_id, study_mode)
);

-- -----------------------------------------------------------------------------
-- Beziehungen mit eigener Tabelle
-- prerequisite (Kurs setzt Kurs voraus) und completion (Person schliesst Durchfuehrung ab)
-- -----------------------------------------------------------------------------
CREATE TABLE lernpfad.prerequisite (
    course_id          TEXT NOT NULL REFERENCES lernpfad.course (course_id)
                           ON UPDATE CASCADE ON DELETE RESTRICT,
    required_course_id TEXT NOT NULL REFERENCES lernpfad.course (course_id)
                           ON UPDATE CASCADE ON DELETE RESTRICT,
    PRIMARY KEY (course_id, required_course_id),
    CHECK (course_id <> required_course_id)
);
COMMENT ON TABLE lernpfad.prerequisite IS 'Zielkurs benoetigt Vorkurs; mehrere Zeilen bedeuten UND';

-- Ein Kurs ist abgeschlossen oder nicht besucht, laufende Kurse werden nicht gespeichert.
-- course_id ist bewusst mitgefuehrt. Der zusammengesetzte Fremdschluessel
-- (run_id, course_id) stellt sicher, dass sie zur Durchfuehrung passt, und der
-- Primaerschluessel erlaubt pro Person und Kurs hoechstens einen Abschluss.
CREATE TABLE lernpfad.completion (
    learner_id   INTEGER NOT NULL REFERENCES lernpfad.learner (learner_id)
                     ON UPDATE CASCADE ON DELETE RESTRICT,
    course_id    TEXT NOT NULL,
    run_id       INTEGER NOT NULL,
    completed_on DATE NOT NULL,
    PRIMARY KEY (learner_id, course_id),
    FOREIGN KEY (run_id, course_id) REFERENCES lernpfad.course_run (run_id, course_id)
        ON UPDATE CASCADE ON DELETE RESTRICT
);

-- -----------------------------------------------------------------------------
-- Indizes
-- PK- und UNIQUE-Indizes decken die Suche ab Zielkurs, Person und Kurs ab,
-- der UNIQUE-Index auf course_run auch A-004 (Kurs, Semester).
-- Die folgenden Indizes stuetzen Gegenrichtung, FK-Pruefungen und A-005.
-- -----------------------------------------------------------------------------
CREATE INDEX prerequisite_required_idx ON lernpfad.prerequisite (required_course_id, course_id);
CREATE INDEX completion_run_idx        ON lernpfad.completion (run_id);
CREATE INDEX course_run_lecturer_idx   ON lernpfad.course_run (lecturer_id, semester_id);

-- -----------------------------------------------------------------------------
-- A-001: alle Voraussetzungen ueber alle Stufen
-- UNION auf der Kurs-ID zaehlt jeden Vorkurs einmal und beendet die Rekursion
-- auch bei fehlerhaften Zyklen.
-- -----------------------------------------------------------------------------
CREATE FUNCTION lernpfad.all_prerequisites(target_course TEXT)
RETURNS TABLE (course_id TEXT, title TEXT, hours INTEGER)
LANGUAGE sql STABLE AS $$
    WITH RECURSIVE needed (course_id) AS (
        SELECT p.required_course_id
        FROM lernpfad.prerequisite AS p
        WHERE p.course_id = target_course
        UNION
        SELECT p.required_course_id
        FROM lernpfad.prerequisite AS p
        JOIN needed AS n ON p.course_id = n.course_id
    )
    SELECT c.course_id, c.title, c.hours
    FROM needed AS n
    JOIN lernpfad.course AS c USING (course_id)
    WHERE c.course_id <> target_course;
$$;

-- -----------------------------------------------------------------------------
-- A-002: Kurse, die eine Person als Naechstes belegen darf
-- Noch nicht abgeschlossen und alle Voraussetzungen ueber alle Stufen abgeschlossen.
-- -----------------------------------------------------------------------------
CREATE FUNCTION lernpfad.eligible_courses(person_id INTEGER)
RETURNS TABLE (course_id TEXT, title TEXT, hours INTEGER)
LANGUAGE sql STABLE AS $$
    SELECT c.course_id, c.title, c.hours
    FROM lernpfad.course AS c
    WHERE EXISTS (SELECT 1 FROM lernpfad.learner AS l WHERE l.learner_id = person_id)
      AND NOT EXISTS (
          SELECT 1 FROM lernpfad.completion AS d
          WHERE d.learner_id = person_id AND d.course_id = c.course_id
      )
      AND NOT EXISTS (
          SELECT 1 FROM lernpfad.all_prerequisites(c.course_id) AS r
          WHERE NOT EXISTS (
              SELECT 1 FROM lernpfad.completion AS d
              WHERE d.learner_id = person_id AND d.course_id = r.course_id
          )
      );
$$;

-- -----------------------------------------------------------------------------
-- A-003: Kurse, die einer Person fuer einen Zielkurs noch fehlen
-- -----------------------------------------------------------------------------
CREATE FUNCTION lernpfad.missing_prerequisites(target_course TEXT, person_id INTEGER)
RETURNS TABLE (course_id TEXT, title TEXT, hours INTEGER)
LANGUAGE sql STABLE AS $$
    SELECT r.course_id, r.title, r.hours
    FROM lernpfad.all_prerequisites(target_course) AS r
    WHERE EXISTS (SELECT 1 FROM lernpfad.learner AS l WHERE l.learner_id = person_id)
      AND NOT EXISTS (
          SELECT 1 FROM lernpfad.completion AS d
          WHERE d.learner_id = person_id AND d.course_id = r.course_id
      );
$$;

-- -----------------------------------------------------------------------------
-- A-004: wo und bei wem eine Person einen Kurs in einem Semester besuchen kann
-- Nur wenn sie den Kurs belegen darf (A-002) und die Studienform passt.
-- -----------------------------------------------------------------------------
CREATE FUNCTION lernpfad.course_offers(person_id INTEGER, target_course TEXT, target_semester TEXT)
RETURNS TABLE (run_id INTEGER, location TEXT, lecturer TEXT)
LANGUAGE sql STABLE AS $$
    SELECT r.run_id, o.name, t.display_name
    FROM lernpfad.learner AS l
    JOIN lernpfad.course_run AS r
      ON r.course_id = target_course
     AND r.semester_id = target_semester
     AND r.study_mode = l.study_mode
    JOIN lernpfad.location AS o ON o.location_id = r.location_id
    JOIN lernpfad.lecturer AS t ON t.lecturer_id = r.lecturer_id
    WHERE l.learner_id = person_id
      AND target_course IN (SELECT e.course_id FROM lernpfad.eligible_courses(person_id) AS e);
$$;

-- -----------------------------------------------------------------------------
-- A-005: Kurse einer Lehrperson in einem Semester
-- -----------------------------------------------------------------------------
CREATE FUNCTION lernpfad.lecturer_courses(person_id INTEGER, target_semester TEXT)
RETURNS TABLE (run_id INTEGER, course_id TEXT, title TEXT, location TEXT, study_mode TEXT)
LANGUAGE sql STABLE AS $$
    SELECT r.run_id, c.course_id, c.title, o.name, r.study_mode
    FROM lernpfad.course_run AS r
    JOIN lernpfad.course AS c ON c.course_id = r.course_id
    JOIN lernpfad.location AS o ON o.location_id = r.location_id
    WHERE r.lecturer_id = person_id
      AND r.semester_id = target_semester;
$$;

-- -----------------------------------------------------------------------------
-- Datenqualitaet: Zyklen ueber mehrere Stufen
-- Ein CHECK sieht nur eine Zeile. Diese Funktion findet Kurse, die sich
-- ueber eine Kette selbst voraussetzen.
-- -----------------------------------------------------------------------------
CREATE FUNCTION lernpfad.prerequisite_cycles()
RETURNS TABLE (course_id TEXT)
LANGUAGE sql STABLE AS $$
    WITH RECURSIVE reach (origin, destination) AS (
        SELECT p.course_id, p.required_course_id FROM lernpfad.prerequisite AS p
        UNION
        SELECT r.origin, p.required_course_id
        FROM reach AS r
        JOIN lernpfad.prerequisite AS p ON p.course_id = r.destination
    )
    SELECT DISTINCT r.origin FROM reach AS r WHERE r.origin = r.destination;
$$;

-- -----------------------------------------------------------------------------
-- Export als JSON
-- Deterministisch sortiert, Quelle fuer den Neo4j-Import und den Dateiimport.
-- -----------------------------------------------------------------------------
CREATE VIEW lernpfad.export_data AS
SELECT jsonb_build_object(
    'dataset_version', 'synthetic-v2',
    'semesters',     (SELECT coalesce(jsonb_agg(to_jsonb(x) ORDER BY x.semester_id), '[]') FROM lernpfad.semester AS x),
    'locations',     (SELECT coalesce(jsonb_agg(to_jsonb(x) ORDER BY x.location_id), '[]') FROM lernpfad.location AS x),
    'lecturers',     (SELECT coalesce(jsonb_agg(to_jsonb(x) ORDER BY x.lecturer_id), '[]') FROM lernpfad.lecturer AS x),
    'courses',       (SELECT coalesce(jsonb_agg(to_jsonb(x) ORDER BY x.course_id), '[]') FROM lernpfad.course AS x),
    'learners',      (SELECT coalesce(jsonb_agg(to_jsonb(x) ORDER BY x.learner_id), '[]') FROM lernpfad.learner AS x),
    'prerequisites', (SELECT coalesce(jsonb_agg(to_jsonb(x) ORDER BY x.course_id, x.required_course_id), '[]')
                      FROM lernpfad.prerequisite AS x),
    'course_runs',   (SELECT coalesce(jsonb_agg(to_jsonb(x) ORDER BY x.run_id), '[]') FROM lernpfad.course_run AS x),
    'completions',   (SELECT coalesce(jsonb_agg(to_jsonb(x) ORDER BY x.learner_id, x.course_id), '[]')
                      FROM lernpfad.completion AS x)
) AS payload;

COMMIT;
