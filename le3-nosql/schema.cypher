// schema.cypher
// Zweck: Eindeutigkeit der Schluessel im Graphmodell festlegen (Neo4j Community)
// LE3. Jede Eindeutigkeitsregel legt zugleich einen Index fuer den Einstieg an.

// -----------------------------------------------------------------------------
// Eindeutige Schluessel
// Jede Abfrage beginnt bei einem Kurs, einer Person, einem Semester oder einem
// Standort und findet den Startknoten ueber diesen Index.
// -----------------------------------------------------------------------------
// name: course_id
CREATE CONSTRAINT course_id IF NOT EXISTS FOR (n:Course) REQUIRE n.id IS UNIQUE;

// name: learner_id
CREATE CONSTRAINT learner_id IF NOT EXISTS FOR (n:Learner) REQUIRE n.id IS UNIQUE;

// name: run_id
CREATE CONSTRAINT run_id IF NOT EXISTS FOR (n:Run) REQUIRE n.id IS UNIQUE;

// name: semester_id
CREATE CONSTRAINT semester_id IF NOT EXISTS FOR (n:Semester) REQUIRE n.id IS UNIQUE;

// name: location_id
CREATE CONSTRAINT location_id IF NOT EXISTS FOR (n:Location) REQUIRE n.id IS UNIQUE;

// name: lecturer_id
CREATE CONSTRAINT lecturer_id IF NOT EXISTS FOR (n:Lecturer) REQUIRE n.id IS UNIQUE;
