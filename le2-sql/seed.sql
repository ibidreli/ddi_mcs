-- seed.sql
-- Zweck: Beispielbestand synthetic-v2 laden (frei erfunden, kein realer Studienplan)
-- LE2 (DML). Setzt ein frisch aufgebautes Schema aus schema.sql voraus.

BEGIN;

-- -----------------------------------------------------------------------------
-- Stammdaten
-- Reihenfolge folgt den Fremdschluesseln: zuerst referenzierte Tabellen.
-- -----------------------------------------------------------------------------
INSERT INTO lernpfad.semester (semester_id, starts_on, ends_on) VALUES
    ('HS25', DATE '2025-09-15', DATE '2026-01-31'),
    ('FS26', DATE '2026-02-16', DATE '2026-07-31'),
    ('HS26', DATE '2026-09-14', DATE '2027-01-31'),
    ('FS27', DATE '2027-02-15', DATE '2027-07-31');

INSERT INTO lernpfad.location (location_id, name) VALUES
    (1, 'Brugg-Windisch'),
    (2, 'Olten'),
    (3, 'Basel');

INSERT INTO lernpfad.lecturer (lecturer_id, display_name) VALUES
    (1, 'L. Keller'),
    (2, 'M. Frei'),
    (3, 'S. Huber'),
    (4, 'T. Brunner');

INSERT INTO lernpfad.course (course_id, title, hours) VALUES
    ('EIN',   'Digitale Grundlagen',  4),
    ('SQL',   'SQL-Grundlagen',       8),
    ('MOD',   'Datenmodellierung',    6),
    ('PY',    'Python-Grundlagen',    8),
    ('STAT',  'Statistik-Grundlagen', 6),
    ('NOSQL', 'NoSQL-Grundlagen',     8),
    ('ML',    'Machine Learning',    10),
    ('DE',    'Datenpipelines',      10),
    ('PROJ',  'Data-Science-Projekt', 12),
    ('VIS',   'Datenvisualisierung',  6);

INSERT INTO lernpfad.learner (learner_id, display_name, study_mode) VALUES
    (1, 'Lernende A', 'VZ'),
    (2, 'Lernende B', 'TZ'),
    (3, 'Lernende C', 'VZ');

-- -----------------------------------------------------------------------------
-- Voraussetzungen
-- Zielkurs -> Vorkurs, mehrere Zeilen pro Zielkurs gelten gemeinsam
-- -----------------------------------------------------------------------------
INSERT INTO lernpfad.prerequisite (course_id, required_course_id) VALUES
    ('SQL', 'EIN'), ('MOD', 'EIN'), ('PY', 'EIN'), ('STAT', 'EIN'),
    ('NOSQL', 'MOD'), ('NOSQL', 'SQL'),
    ('ML', 'PY'), ('ML', 'STAT'),
    ('DE', 'SQL'), ('DE', 'PY'),
    ('PROJ', 'DE'), ('PROJ', 'ML'), ('PROJ', 'NOSQL'),
    ('VIS', 'PY');

-- -----------------------------------------------------------------------------
-- Durchfuehrungen
-- HS25 und FS26 abgeschlossen, HS26 laufend, FS27 Angebot fuer A-005
-- -----------------------------------------------------------------------------
INSERT INTO lernpfad.course_run (run_id, course_id, semester_id, location_id, lecturer_id, study_mode) VALUES
    ( 1, 'EIN',   'HS25', 1, 1, 'VZ'),
    ( 2, 'EIN',   'HS25', 2, 1, 'TZ'),
    ( 3, 'SQL',   'FS26', 1, 2, 'VZ'),
    ( 4, 'MOD',   'FS26', 1, 3, 'VZ'),
    ( 5, 'PY',    'FS26', 2, 4, 'TZ'),
    ( 6, 'STAT',  'FS26', 2, 3, 'TZ'),
    ( 7, 'SQL',   'HS26', 1, 2, 'VZ'),
    ( 8, 'PY',    'HS26', 1, 4, 'VZ'),
    ( 9, 'STAT',  'HS26', 2, 3, 'TZ'),
    (10, 'NOSQL', 'FS27', 1, 2, 'VZ'),
    (11, 'NOSQL', 'FS27', 2, 2, 'TZ'),
    (12, 'PY',    'FS27', 1, 4, 'VZ'),
    (13, 'STAT',  'FS27', 2, 3, 'VZ'),
    (14, 'DE',    'FS27', 1, 1, 'VZ'),
    (15, 'ML',    'FS27', 3, 4, 'VZ'),
    (16, 'VIS',   'FS27', 1, 3, 'VZ'),
    (17, 'MOD',   'FS27', 2, 3, 'TZ');

-- -----------------------------------------------------------------------------
-- Belegungen
-- completed_on NULL bedeutet laufend (Person 3 in SQL, HS26)
-- -----------------------------------------------------------------------------
INSERT INTO lernpfad.enrollment (learner_id, course_id, run_id, completed_on) VALUES
    (1, 'EIN',  1, DATE '2026-01-20'),
    (1, 'SQL',  3, DATE '2026-06-19'),
    (1, 'MOD',  4, DATE '2026-06-26'),
    (2, 'EIN',  2, DATE '2026-01-20'),
    (2, 'PY',   5, DATE '2026-06-19'),
    (2, 'STAT', 6, DATE '2026-06-26'),
    (3, 'EIN',  1, DATE '2026-01-20'),
    (3, 'SQL',  7, NULL);

COMMIT;

ANALYZE lernpfad.semester;
ANALYZE lernpfad.location;
ANALYZE lernpfad.lecturer;
ANALYZE lernpfad.course;
ANALYZE lernpfad.learner;
ANALYZE lernpfad.prerequisite;
ANALYZE lernpfad.course_run;
ANALYZE lernpfad.enrollment;
