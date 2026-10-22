// import.cypher
// Zweck: Datenbestand aus dem JSON-Export (gleiches Format wie lernpfad.export_data) laden
// LE3. Jeder Block erhaelt die Zeilen einer Tabelle als Parameter $rows.

// -----------------------------------------------------------------------------
// Bestand leeren
// Neo4j Community hat eine Datenbank, sie wird vor jedem Import geleert.
// -----------------------------------------------------------------------------
// name: clear
MATCH (n) DETACH DELETE n;

// -----------------------------------------------------------------------------
// Knoten
// -----------------------------------------------------------------------------
// name: semesters
UNWIND $rows AS r
CREATE (:Semester {id: r.semester_id, starts_on: date(r.starts_on), ends_on: date(r.ends_on)});

// name: locations
UNWIND $rows AS r
CREATE (:Location {id: r.location_id, name: r.name});

// name: lecturers
UNWIND $rows AS r
CREATE (:Lecturer {id: r.lecturer_id, name: r.display_name});

// name: courses
UNWIND $rows AS r
CREATE (:Course {id: r.course_id, title: r.title, hours: r.hours});

// name: learners
UNWIND $rows AS r
CREATE (:Learner {id: r.learner_id, name: r.display_name, study_mode: r.study_mode});

// -----------------------------------------------------------------------------
// Voraussetzungen
// Richtung Zielkurs -> Vorkurs, wie in lernpfad.prerequisite
// -----------------------------------------------------------------------------
// name: prerequisites
UNWIND $rows AS r
MATCH (target:Course {id: r.course_id})
MATCH (required:Course {id: r.required_course_id})
CREATE (target)-[:REQUIRES]->(required);

// -----------------------------------------------------------------------------
// Durchfuehrungen
// Die Fremdschluessel von course_run werden zu vier Kanten.
// -----------------------------------------------------------------------------
// name: course_runs
UNWIND $rows AS r
MATCH (c:Course {id: r.course_id})
MATCH (s:Semester {id: r.semester_id})
MATCH (o:Location {id: r.location_id})
MATCH (t:Lecturer {id: r.lecturer_id})
CREATE (run:Run {id: r.run_id, study_mode: r.study_mode})
CREATE (run)-[:OF]->(c)
CREATE (run)-[:IN]->(s)
CREATE (run)-[:AT]->(o)
CREATE (t)-[:TEACHES]->(run);

// -----------------------------------------------------------------------------
// Belegungen
// ENROLLED haelt jede Belegung an der Durchfuehrung fest. Abgeschlossene
// Belegungen erhalten zusaetzlich eine direkte Kante COMPLETED zum Kurs, weil
// A-003 bis A-005 nach abgeschlossenen Kursen fragen, nicht nach Durchfuehrungen.
// -----------------------------------------------------------------------------
// name: enrollments
UNWIND $rows AS r
MATCH (l:Learner {id: r.learner_id})
MATCH (run:Run {id: r.run_id})
CREATE (l)-[e:ENROLLED]->(run)
SET e.completed_on = CASE WHEN r.completed_on IS NULL THEN NULL ELSE date(r.completed_on) END;

// name: completions
UNWIND $rows AS r
WITH r WHERE r.completed_on IS NOT NULL
MATCH (l:Learner {id: r.learner_id})
MATCH (c:Course {id: r.course_id})
CREATE (l)-[:COMPLETED {completed_on: date(r.completed_on), run_id: r.run_id}]->(c);
