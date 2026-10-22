-- seed.sql
-- Zweck: Beispielbestand synthetic-v2 laden (frei erfunden, kein realer Studienplan)
-- LE2 (DML). Setzt ein frisch aufgebautes Schema aus schema.sql voraus.

BEGIN;

-- -----------------------------------------------------------------------------
-- Stammdaten
-- Reihenfolge folgt den Fremdschluesseln: zuerst referenzierte Tabellen.
-- -----------------------------------------------------------------------------
INSERT INTO lernpfad.semester (semester_id, name, starts_on, ends_on) VALUES
    ('HS25', 'Herbstsemester 2025',   DATE '2025-09-15', DATE '2026-01-31'),
    ('FS26', 'Frühlingssemester 2026', DATE '2026-02-16', DATE '2026-07-31'),
    ('HS26', 'Herbstsemester 2026',   DATE '2026-09-14', DATE '2027-01-31'),
    ('FS27', 'Frühlingssemester 2027', DATE '2027-02-15', DATE '2027-07-31');

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
    ('BASICS',        'Grundlagen Data Science',  4),
    ('PYTHON',        'Python-Grundlagen',        8),
    ('SQL',           'SQL-Grundlagen',           8),
    ('ALGEBRA',       'Lineare Algebra',          6),
    ('ANALYSIS',      'Analysis',                 6),
    ('DB_MODELING',   'Datenbankmodellierung',    6),
    ('NOSQL',         'NoSQL-Datenbanken',        8),
    ('EDA',           'Explorative Datenanalyse', 6),
    ('VISUALISATION', 'Datenvisualisierung',      6),
    ('ML',            'Machine Learning',        10);

INSERT INTO lernpfad.learner (learner_id, display_name, study_mode) VALUES
    (1, 'Student A', 'VZ'),
    (2, 'Student B', 'TZ'),
    (3, 'Student C', 'VZ');

-- -----------------------------------------------------------------------------
-- Voraussetzungen
-- Zielkurs -> Vorkurs, mehrere Zeilen pro Zielkurs gelten gemeinsam
-- -----------------------------------------------------------------------------
INSERT INTO lernpfad.prerequisite (course_id, required_course_id) VALUES
    ('PYTHON', 'BASICS'), ('SQL', 'BASICS'), ('ALGEBRA', 'BASICS'),
    ('ANALYSIS', 'ALGEBRA'),
    ('DB_MODELING', 'SQL'),
    ('NOSQL', 'DB_MODELING'), ('NOSQL', 'SQL'),
    ('EDA', 'PYTHON'), ('EDA', 'SQL'),
    ('VISUALISATION', 'EDA'),
    ('ML', 'EDA'), ('ML', 'PYTHON'), ('ML', 'ALGEBRA'), ('ML', 'ANALYSIS');

-- -----------------------------------------------------------------------------
-- Durchfuehrungen
-- HS25 und FS26 vergangen, HS26 laufend, FS27 Angebot fuer A-004 und A-005
-- -----------------------------------------------------------------------------
INSERT INTO lernpfad.course_run (run_id, course_id, semester_id, location_id, lecturer_id, study_mode) VALUES
    ( 1, 'BASICS',      'HS25', 1, 1, 'VZ'),
    ( 2, 'BASICS',      'HS25', 2, 1, 'TZ'),
    ( 3, 'SQL',         'FS26', 1, 2, 'VZ'),
    ( 4, 'PYTHON',      'FS26', 2, 4, 'TZ'),
    ( 5, 'ALGEBRA',     'FS26', 2, 3, 'TZ'),
    ( 6, 'PYTHON',      'HS26', 1, 4, 'VZ'),
    ( 7, 'SQL',         'HS26', 1, 2, 'VZ'),
    ( 8, 'ALGEBRA',     'HS26', 2, 3, 'TZ'),
    ( 9, 'PYTHON',      'FS27', 1, 4, 'VZ'),
    (10, 'ALGEBRA',     'FS27', 1, 3, 'VZ'),
    (11, 'DB_MODELING', 'FS27', 1, 2, 'VZ'),
    (12, 'ANALYSIS',    'FS27', 2, 3, 'TZ'),
    (13, 'SQL',         'FS27', 2, 2, 'TZ'),
    (14, 'EDA',         'FS27', 1, 1, 'VZ'),
    (15, 'ML',          'FS27', 3, 4, 'VZ'),
    (16, 'NOSQL',       'FS27', 1, 2, 'VZ'),
    (17, 'DB_MODELING', 'FS27', 2, 2, 'TZ');

-- -----------------------------------------------------------------------------
-- Abschluesse
-- Gespeichert wird nur, was abgeschlossen ist
-- -----------------------------------------------------------------------------
INSERT INTO lernpfad.completion (learner_id, course_id, run_id, completed_on) VALUES
    (1, 'BASICS',  1, DATE '2026-01-20'),
    (1, 'SQL',     3, DATE '2026-06-19'),
    (2, 'BASICS',  2, DATE '2026-01-20'),
    (2, 'PYTHON',  4, DATE '2026-06-19'),
    (2, 'ALGEBRA', 5, DATE '2026-06-26'),
    (3, 'BASICS',  1, DATE '2026-01-20');

COMMIT;

ANALYZE lernpfad.semester;
ANALYZE lernpfad.location;
ANALYZE lernpfad.lecturer;
ANALYZE lernpfad.course;
ANALYZE lernpfad.learner;
ANALYZE lernpfad.prerequisite;
ANALYZE lernpfad.course_run;
ANALYZE lernpfad.completion;
