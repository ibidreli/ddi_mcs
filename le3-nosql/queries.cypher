// queries.cypher
// Zweck: Abfragen A-001 bis A-005 in Cypher, gleiche Ergebnisse wie die SQL-Funktionen
// LE3. Parameter: $course, $learner, $semester, $location

// -----------------------------------------------------------------------------
// A-001: direkte Voraussetzungen
// -----------------------------------------------------------------------------
// name: A-001
MATCH (:Course {id: $course})-[:REQUIRES]->(p:Course)
RETURN p.id AS course_id, p.title AS title, p.hours AS hours
ORDER BY course_id;

// -----------------------------------------------------------------------------
// A-002: alle Voraussetzungen ueber beliebig viele Stufen
// WITH DISTINCT direkt nach dem Pfadmuster erlaubt Neo4j, jeden Kurs nur einmal
// zu besuchen, statt alle Pfade aufzuzaehlen.
// -----------------------------------------------------------------------------
// name: A-002
MATCH (:Course {id: $course})-[:REQUIRES*1..]->(p:Course)
WITH DISTINCT p
WHERE p.id <> $course
RETURN p.id AS course_id, p.title AS title, p.hours AS hours
ORDER BY course_id;

// -----------------------------------------------------------------------------
// A-003: Kurse, die eine Person jetzt belegen darf
// Noch nicht belegt und kein Vorkurs ohne Abschluss
// -----------------------------------------------------------------------------
// name: A-003
MATCH (l:Learner {id: $learner})
MATCH (c:Course)
WHERE NOT EXISTS { (l)-[:ENROLLED]->(:Run)-[:OF]->(c) }
  AND NOT EXISTS {
      MATCH (c)-[:REQUIRES*1..]->(p:Course)
      WHERE NOT EXISTS { (l)-[:COMPLETED]->(p) }
  }
RETURN c.id AS course_id, c.title AS title, c.hours AS hours
ORDER BY course_id;

// -----------------------------------------------------------------------------
// A-004: fehlende Vorkurse fuer einen Zielkurs
// Zuerst die eindeutige Menge aus A-002, danach die Abschluesse abziehen.
// -----------------------------------------------------------------------------
// name: A-004
MATCH (:Course {id: $course})-[:REQUIRES*1..]->(p:Course)
WITH DISTINCT p
WHERE p.id <> $course
MATCH (l:Learner {id: $learner})
WHERE NOT EXISTS { (l)-[:COMPLETED]->(p) }
RETURN p.id AS course_id, p.title AS title, p.hours AS hours
ORDER BY course_id;

// name: A-004-summe
MATCH (:Course {id: $course})-[:REQUIRES*1..]->(p:Course)
WITH DISTINCT p
WHERE p.id <> $course
MATCH (l:Learner {id: $learner})
WHERE NOT EXISTS { (l)-[:COMPLETED]->(p) }
RETURN count(p) AS missing_courses, coalesce(sum(p.hours), 0) AS missing_hours;

// -----------------------------------------------------------------------------
// A-005: passende Durchfuehrungen der naechsten Kurse
// Einstieg ueber Semester und Standort, Studienform aus der Person
// -----------------------------------------------------------------------------
// name: A-005
MATCH (l:Learner {id: $learner})
MATCH (:Semester {id: $semester})<-[:IN]-(r:Run)-[:AT]->(:Location {id: $location})
WHERE r.study_mode = l.study_mode
MATCH (r)-[:OF]->(c:Course)
WHERE NOT EXISTS { (l)-[:ENROLLED]->(:Run)-[:OF]->(c) }
  AND NOT EXISTS {
      MATCH (c)-[:REQUIRES*1..]->(p:Course)
      WHERE NOT EXISTS { (l)-[:COMPLETED]->(p) }
  }
MATCH (t:Lecturer)-[:TEACHES]->(r)
RETURN r.id AS run_id, c.id AS course_id, c.title AS title, t.name AS lecturer
ORDER BY course_id, run_id;
