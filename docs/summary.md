# **Zusammenfassung MC3**

Kurzfassung der Aufgabenstellung und der Modelle aus dem Bericht `MC3_Bericht_Pulver_Urech.docx`.

## **1) Aufgabenstellung**

Ein Weiterbildungsanbieter will Lernenden zeigen, welche Kurse sie als Nächstes besuchen können, was ihnen für ein Ziel fehlt und wann und wo die passenden Kurse stattfinden. Kurse setzen andere Kurse voraus, oft über mehrere Stufen. Dieselbe Problemstellung wird in PostgreSQL und Neo4j umgesetzt und verglichen.

| ID | Frage |
|---|---|
| A-001 | Welche Kurse setzt ein Zielkurs direkt voraus? |
| A-002 | Welche Kurse setzt ein Zielkurs insgesamt voraus, über alle Stufen und ohne Duplikate? |
| A-003 | Welche Kurse darf eine Person als Nächstes belegen? |
| A-004 | Welche Vorkurse fehlen einer Person für einen Zielkurs, und wie viele Stunden sind das? |
| A-005 | Welche Durchführungen dieser Kurse finden in einem Semester an einem Standort in der Studienform der Person statt, und wer unterrichtet sie? |

**Regeln**
- **UND-Bedingung:** Alle Voraussetzungen eines Kurses gelten gemeinsam
- **Azyklisch:** Kein Kurs setzt sich direkt oder über mehrere Stufen selbst voraus
- **Belegung:** höchstens eine pro Person und Kurs, ohne Abschlussdatum läuft sie noch
- **Keine Doppelzählung:** Ein Vorkurs zählt einmal, der Zielkurs zählt nicht

## **2) Modelle**

![Konzeptionelles Modell](../le2-sql/model/conceptual.png)

- **Konzeptionell:** 6 Entitäten in Chen-Notation. Ein Kurs wird mehrmals durchgeführt, jede Durchführung gehört zu einem Semester, einem Standort und einer Lehrperson
- **Beziehungen:** Personen belegen Durchführungen (N:N mit Abschlussdatum), Kurse setzen Kurse voraus (N:N-Selbstbeziehung)

![Relationales Modell](../le2-sql/model/relational.png)

- **Relational:** 8 Tabellen. Die 1:N-Beziehungen sind Fremdschlüssel in `course_run`, die beiden N:N-Beziehungen eigene Tabellen
- **`enrollment`:** Primärschlüssel `(learner_id, course_id)` und Fremdschlüssel `(run_id, course_id)` erzwingen eine Belegung pro Kurs mit passender Durchführung

![Graphmodell](../le3-nosql/model/graph.png)

- **Neo4j:** 6 Knotentypen, Fremdschlüssel und Zuordnungstabellen werden zu Kanten
- **`COMPLETED`:** abgeleitete Kante von der Person zum abgeschlossenen Kurs, damit A-003 bis A-005 nicht über die Durchführung gehen müssen
