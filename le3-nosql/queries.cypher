// queries.cypher
// Zweck: Abfragen A-001 bis A-005 in Cypher, gleiche Ergebnisse wie die SQL-Funktionen
// LE3. Parameter: $course, $learner, $semester, $lecturer

// -----------------------------------------------------------------------------
// A-001: alle Voraussetzungen ueber alle Stufen
// WITH DISTINCT direkt nach dem Pfadmuster erlaubt Neo4j, jeden Kurs nur einmal
// zu besuchen, statt alle Pfade aufzuzaehlen.
// -----------------------------------------------------------------------------
// name: A-001
MATCH (:Course {id: $course})-[:REQUIRES*1..]->(p:Course)
WITH DISTINCT p
WHERE p.id <> $course
RETURN p.id AS course_id, p.title AS title, p.hours AS hours
ORDER BY course_id;

// -----------------------------------------------------------------------------
// A-002: Kurse, die eine Person als Naechstes belegen darf
// Noch nicht abgeschlossen und kein Vorkurs ohne Abschluss
// -----------------------------------------------------------------------------
// name: A-002
MATCH (l:Learner {id: $learner})
MATCH (c:Course)
WHERE NOT EXISTS { (l)-[:COMPLETED]->(c) }
  AND NOT EXISTS {
      MATCH (c)-[:REQUIRES*1..]->(p:Course)
      WHERE NOT EXISTS { (l)-[:COMPLETED]->(p) }
  }
RETURN c.id AS course_id, c.title AS title, c.hours AS hours
ORDER BY course_id;

// -----------------------------------------------------------------------------
// A-003: Kurse, die einer Person fuer einen Zielkurs noch fehlen
// Zuerst die eindeutige Menge aus A-001, danach die Abschluesse abziehen.
// -----------------------------------------------------------------------------
// name: A-003
MATCH (:Course {id: $course})-[:REQUIRES*1..]->(p:Course)
WITH DISTINCT p
WHERE p.id <> $course
MATCH (l:Learner {id: $learner})
WHERE NOT EXISTS { (l)-[:COMPLETED]->(p) }
RETURN p.id AS course_id, p.title AS title, p.hours AS hours
ORDER BY course_id;

// -----------------------------------------------------------------------------
// A-004: wo und bei wem eine Person einen Kurs in einem Semester besuchen kann
// Nur wenn sie ihn belegen darf und die Studienform passt
// -----------------------------------------------------------------------------
// name: A-004
MATCH (l:Learner {id: $learner})
MATCH (c:Course {id: $course})
WHERE NOT EXISTS { (l)-[:COMPLETED]->(c) }
  AND NOT EXISTS {
      MATCH (c)-[:REQUIRES*1..]->(p:Course)
      WHERE NOT EXISTS { (l)-[:COMPLETED]->(p) }
  }
MATCH (c)<-[:OF]-(r:Run)-[:IN]->(:Semester {id: $semester})
WHERE r.study_mode = l.study_mode
MATCH (r)-[:AT]->(o:Location)
MATCH (t:Lecturer)-[:TEACHES]->(r)
RETURN r.id AS run_id, o.name AS location, t.name AS lecturer
ORDER BY run_id;

// -----------------------------------------------------------------------------
// A-005: Kurse einer Lehrperson in einem Semester
// -----------------------------------------------------------------------------
// name: A-005
MATCH (:Lecturer {id: $lecturer})-[:TEACHES]->(r:Run)-[:IN]->(:Semester {id: $semester})
MATCH (r)-[:OF]->(c:Course)
MATCH (r)-[:AT]->(o:Location)
RETURN r.id AS run_id, c.id AS course_id, c.title AS title, o.name AS location, r.study_mode AS study_mode
ORDER BY course_id, run_id;
