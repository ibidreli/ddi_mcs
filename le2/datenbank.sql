-- MC3 / LE2: Lernpfadplanung. Synthetischer Datensatz le2-synthetic-v1.
-- Mit psql ausfuehren. Wiederholtes Laden loescht keine bestehenden Daten.
\set ON_ERROR_STOP on
\pset pager off
\encoding UTF8

BEGIN;
CREATE SCHEMA IF NOT EXISTS le2;

CREATE TABLE IF NOT EXISTS le2.course (
    course_id text PRIMARY KEY,
    title text NOT NULL CHECK (length(btrim(title)) > 0),
    hours integer NOT NULL CHECK (hours > 0),
    CHECK (course_id ~ '^[A-Z][A-Z0-9_]{1,15}$')
);

CREATE TABLE IF NOT EXISTS le2.learner (
    learner_id integer PRIMARY KEY CHECK (learner_id > 0),
    display_name text NOT NULL CHECK (length(btrim(display_name)) > 0)
);

CREATE TABLE IF NOT EXISTS le2.prerequisite (
    course_id text NOT NULL REFERENCES le2.course(course_id)
        ON UPDATE CASCADE ON DELETE RESTRICT,
    required_course_id text NOT NULL REFERENCES le2.course(course_id)
        ON UPDATE CASCADE ON DELETE RESTRICT,
    PRIMARY KEY (course_id, required_course_id),
    CHECK (course_id <> required_course_id)
);

CREATE TABLE IF NOT EXISTS le2.completion (
    learner_id integer NOT NULL REFERENCES le2.learner(learner_id)
        ON UPDATE CASCADE ON DELETE RESTRICT,
    course_id text NOT NULL REFERENCES le2.course(course_id)
        ON UPDATE CASCADE ON DELETE RESTRICT,
    completed_on date NOT NULL,
    PRIMARY KEY (learner_id, course_id)
);

-- Die PK-Indizes decken Zielkurs->Voraussetzung und Lernende->Abschluss ab.
-- Diese beiden Indizes unterstuetzen die umgekehrte Suche und FK-Pruefungen.
CREATE INDEX IF NOT EXISTS prerequisite_required_idx
    ON le2.prerequisite (required_course_id, course_id);
CREATE INDEX IF NOT EXISTS completion_course_idx
    ON le2.completion (course_id, learner_id);

COMMENT ON SCHEMA le2 IS 'Lokaler MC3-LE2-Draft mit ausschliesslich synthetischen Beispieldaten';
COMMENT ON TABLE le2.prerequisite IS 'Zielkurs -> benoetigter Vorkurs; mehrere Kanten bedeuten UND';
COMMENT ON TABLE le2.completion IS 'Ein bestaetigter Abschluss pro lernender Person und Kurs';

INSERT INTO le2.course (course_id, title, hours) VALUES
    ('EIN',   'Digitale Grundlagen',      4),
    ('SQL',   'SQL-Grundlagen',           8),
    ('MOD',   'Datenmodellierung',        6),
    ('PY',    'Python-Grundlagen',        8),
    ('STAT',  'Statistik-Grundlagen',     6),
    ('NOSQL', 'NoSQL-Grundlagen',         8),
    ('ML',    'Machine Learning',       10),
    ('DE',    'Datenpipelines',          10),
    ('PROJ',  'Data-Science-Projekt',     12),
    ('VIS',   'Datenvisualisierung',       6)
ON CONFLICT (course_id) DO NOTHING;

INSERT INTO le2.learner (learner_id, display_name) VALUES
    (1, 'Lernende A'), (2, 'Lernende B'), (3, 'Lernende C')
ON CONFLICT (learner_id) DO NOTHING;

INSERT INTO le2.prerequisite (course_id, required_course_id) VALUES
    ('SQL', 'EIN'), ('MOD', 'EIN'), ('PY', 'EIN'), ('STAT', 'EIN'),
    ('NOSQL', 'MOD'), ('NOSQL', 'SQL'),
    ('ML', 'PY'), ('ML', 'STAT'),
    ('DE', 'SQL'), ('DE', 'PY'),
    ('PROJ', 'DE'), ('PROJ', 'ML'), ('PROJ', 'NOSQL'),
    ('VIS', 'PY')
ON CONFLICT (course_id, required_course_id) DO NOTHING;

INSERT INTO le2.completion (learner_id, course_id, completed_on) VALUES
    (1, 'EIN',  DATE '2026-09-01'),
    (1, 'SQL',  DATE '2026-09-15'),
    (1, 'MOD',  DATE '2026-09-16'),
    (2, 'EIN',  DATE '2026-09-01'),
    (2, 'PY',   DATE '2026-09-15'),
    (2, 'STAT', DATE '2026-09-16'),
    (3, 'EIN',  DATE '2026-09-01')
ON CONFLICT (learner_id, course_id) DO NOTHING;

-- A-002: Ein Kurs erscheint genau einmal, auch bei mehreren Pfaden.
-- UNION auf der Kurs-ID beendet die Rekursion auch bei fehlerhaften Zyklen.
CREATE OR REPLACE FUNCTION le2.all_prerequisites(target_course text)
RETURNS TABLE (course_id text, title text, hours integer)
LANGUAGE sql STABLE AS $$
    WITH RECURSIVE needed (course_id) AS (
        SELECT p.required_course_id
        FROM le2.prerequisite AS p WHERE p.course_id = target_course
        UNION
        SELECT p.required_course_id
        FROM le2.prerequisite AS p
        JOIN needed AS n ON p.course_id = n.course_id
    )
    SELECT c.course_id, c.title, c.hours
    FROM needed AS n JOIN le2.course AS c USING (course_id)
    WHERE c.course_id <> target_course;
$$;

-- A-003: Noch nicht absolvierte Kurse, deren gesamte Voraussetzungskette
-- abgeschlossen ist. Unbekannte Personen liefern keine Empfehlungen.
CREATE OR REPLACE FUNCTION le2.eligible_courses(person_id integer)
RETURNS TABLE (course_id text, title text, hours integer)
LANGUAGE sql STABLE AS $$
    SELECT c.course_id, c.title, c.hours
    FROM le2.course AS c
    WHERE EXISTS (SELECT 1 FROM le2.learner AS l WHERE l.learner_id = person_id)
      AND NOT EXISTS (
          SELECT 1 FROM le2.completion AS done
          WHERE done.learner_id = person_id AND done.course_id = c.course_id
      )
      AND NOT EXISTS (
          SELECT 1 FROM le2.all_prerequisites(c.course_id) AS required
          WHERE NOT EXISTS (
              SELECT 1 FROM le2.completion AS done
              WHERE done.learner_id = person_id AND done.course_id = required.course_id
          )
      );
$$;

-- A-004: Fehlende Vorkurse eines Zielkurses, ohne den Zielkurs selbst.
CREATE OR REPLACE FUNCTION le2.missing_prerequisites(target_course text, person_id integer)
RETURNS TABLE (course_id text, title text, hours integer)
LANGUAGE sql STABLE AS $$
    SELECT required.course_id, required.title, required.hours
    FROM le2.all_prerequisites(target_course) AS required
    WHERE EXISTS (SELECT 1 FROM le2.learner AS l WHERE l.learner_id = person_id)
      AND NOT EXISTS (
          SELECT 1 FROM le2.completion AS done
          WHERE done.learner_id = person_id AND done.course_id = required.course_id
      );
$$;

-- Fachliche Datenqualitaet: laengere Zyklen sind kein lokales CHECK-Kriterium.
-- Die Import-/Pruefroutine erkennt sie mit dieser endlichen Erreichbarkeitsmenge.
CREATE OR REPLACE FUNCTION le2.prerequisite_cycles()
RETURNS TABLE (course_id text)
LANGUAGE sql STABLE AS $$
    WITH RECURSIVE reach (origin, destination) AS (
        SELECT p.course_id, p.required_course_id FROM le2.prerequisite AS p
        UNION
        SELECT r.origin, p.required_course_id
        FROM reach AS r
        JOIN le2.prerequisite AS p ON p.course_id = r.destination
    )
    SELECT DISTINCT r.origin FROM reach AS r WHERE r.origin = r.destination;
$$;

-- Maschinenlesbarer, deterministisch sortierter Export fuer die spaetere LE3.
CREATE OR REPLACE VIEW le2.export_data AS
SELECT jsonb_build_object(
    'dataset_version', 'le2-synthetic-v1',
    'source', 'Synthetic example created for this draft; not an FHNW curriculum',
    'courses', (SELECT jsonb_agg(to_jsonb(c) ORDER BY c.course_id) FROM le2.course AS c),
    'learners', (SELECT jsonb_agg(to_jsonb(l) ORDER BY l.learner_id) FROM le2.learner AS l),
    'prerequisites', (SELECT jsonb_agg(to_jsonb(p) ORDER BY p.course_id, p.required_course_id)
                      FROM le2.prerequisite AS p),
    'completions', (SELECT jsonb_agg(to_jsonb(c) ORDER BY c.learner_id, c.course_id)
                    FROM le2.completion AS c)
) AS payload;
COMMIT;

ANALYZE le2.course;
ANALYZE le2.learner;
ANALYZE le2.prerequisite;
ANALYZE le2.completion;
\echo 'Schema, synthetische Daten, Abfragefunktionen und Exportansicht bereit.'
