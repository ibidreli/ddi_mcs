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
    -- Ziel des zusammengesetzten Fremdschluessels in enrollment
    UNIQUE (run_id, course_id),
    -- Ein Kurs wird pro Semester, Standort und Studienform hoechstens einmal angeboten
    UNIQUE (course_id, semester_id, location_id, study_mode)
);

-- -----------------------------------------------------------------------------
-- Beziehungen mit eigener Tabelle
-- prerequisite (Kurs setzt Kurs voraus) und enrollment (Person belegt Durchfuehrung)
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

-- course_id ist hier bewusst mitgefuehrt. Der zusammengesetzte Fremdschluessel
-- (run_id, course_id) stellt sicher, dass sie zur Durchfuehrung passt, und der
-- Primaerschluessel erlaubt pro Person und Kurs hoechstens eine Belegung.
CREATE TABLE lernpfad.enrollment (
    learner_id   INTEGER NOT NULL REFERENCES lernpfad.learner (learner_id)
                     ON UPDATE CASCADE ON DELETE RESTRICT,
    course_id    TEXT NOT NULL,
    run_id       INTEGER NOT NULL,
    completed_on DATE,
    PRIMARY KEY (learner_id, course_id),
    FOREIGN KEY (run_id, course_id) REFERENCES lernpfad.course_run (run_id, course_id)
        ON UPDATE CASCADE ON DELETE RESTRICT
);
COMMENT ON COLUMN lernpfad.enrollment.completed_on IS 'NULL bedeutet: Belegung laeuft noch';

-- -----------------------------------------------------------------------------
-- Indizes
-- PK- und UNIQUE-Indizes decken die Suche ab Zielkurs, Person und Kurs ab.
-- Die folgenden Indizes stuetzen Gegenrichtung, FK-Pruefungen und A-005.
-- -----------------------------------------------------------------------------
CREATE INDEX prerequisite_required_idx ON lernpfad.prerequisite (required_course_id, course_id);
CREATE INDEX enrollment_run_idx        ON lernpfad.enrollment (run_id);
CREATE INDEX course_run_offer_idx      ON lernpfad.course_run (semester_id, location_id, study_mode);

-- -----------------------------------------------------------------------------
-- A-002: alle direkten und indirekten Voraussetzungen
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
-- A-003: Kurse, die eine Person jetzt belegen darf
-- Noch nicht belegt und alle Voraussetzungen abgeschlossen (completed_on gesetzt).
-- -----------------------------------------------------------------------------
CREATE FUNCTION lernpfad.eligible_courses(person_id INTEGER)
RETURNS TABLE (course_id TEXT, title TEXT, hours INTEGER)
LANGUAGE sql STABLE AS $$
    SELECT c.course_id, c.title, c.hours
    FROM lernpfad.course AS c
    WHERE EXISTS (SELECT 1 FROM lernpfad.learner AS l WHERE l.learner_id = person_id)
      AND NOT EXISTS (
          SELECT 1 FROM lernpfad.enrollment AS e
          WHERE e.learner_id = person_id AND e.course_id = c.course_id
      )
      AND NOT EXISTS (
          SELECT 1 FROM lernpfad.all_prerequisites(c.course_id) AS r
          WHERE NOT EXISTS (
              SELECT 1 FROM lernpfad.enrollment AS e
              WHERE e.learner_id = person_id
                AND e.course_id = r.course_id
                AND e.completed_on IS NOT NULL
          )
      );
$$;

-- -----------------------------------------------------------------------------
-- A-004: fehlende Vorkurse einer Person fuer einen Zielkurs
-- Laufende Belegungen zaehlen noch nicht als abgeschlossen.
-- -----------------------------------------------------------------------------
CREATE FUNCTION lernpfad.missing_prerequisites(target_course TEXT, person_id INTEGER)
RETURNS TABLE (course_id TEXT, title TEXT, hours INTEGER)
LANGUAGE sql STABLE AS $$
    SELECT r.course_id, r.title, r.hours
    FROM lernpfad.all_prerequisites(target_course) AS r
    WHERE EXISTS (SELECT 1 FROM lernpfad.learner AS l WHERE l.learner_id = person_id)
      AND NOT EXISTS (
          SELECT 1 FROM lernpfad.enrollment AS e
          WHERE e.learner_id = person_id
            AND e.course_id = r.course_id
            AND e.completed_on IS NOT NULL
      );
$$;

-- -----------------------------------------------------------------------------
-- A-005: passende Durchfuehrungen der naechsten Kurse
-- Semester und Standort als Parameter, Studienform aus der Person.
-- -----------------------------------------------------------------------------
CREATE FUNCTION lernpfad.available_runs(person_id INTEGER, target_semester TEXT, target_location INTEGER)
RETURNS TABLE (run_id INTEGER, course_id TEXT, title TEXT, lecturer TEXT)
LANGUAGE sql STABLE AS $$
    SELECT r.run_id, c.course_id, c.title, t.display_name
    FROM lernpfad.learner AS l
    JOIN lernpfad.course_run AS r
      ON r.study_mode = l.study_mode
     AND r.semester_id = target_semester
     AND r.location_id = target_location
    JOIN lernpfad.eligible_courses(person_id) AS c ON c.course_id = r.course_id
    JOIN lernpfad.lecturer AS t ON t.lecturer_id = r.lecturer_id
    WHERE l.learner_id = person_id;
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
    'enrollments',   (SELECT coalesce(jsonb_agg(to_jsonb(x) ORDER BY x.learner_id, x.course_id), '[]')
                      FROM lernpfad.enrollment AS x)
) AS payload;

COMMIT;
