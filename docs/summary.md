# **Zusammenfassung MC3**

Kurzfassung der Aufgabenstellung und der Modelle aus dem Bericht `MC3_Bericht_Pulver_Urech.docx`.

## **1) Aufgabenstellung**

Ein Weiterbildungsanbieter will Studierenden zeigen, welche Kurse sie als Nächstes belegen können, was ihnen für ein Ziel noch fehlt und wo und bei wem die Kurse stattfinden. Kurse setzen andere Kurse voraus, oft über mehrere Stufen. Dieselbe Problemstellung wird in PostgreSQL und Neo4j umgesetzt und verglichen.

| ID | Frage | Beispiel |
|---|---|---|
| A-001 | Welche Kurse müssen über alle Stufen abgeschlossen sein, um Kurs X belegen zu können? | ML: ALGEBRA, ANALYSIS, BASICS, EDA, PYTHON, SQL |
| A-002 | Welche Kurse darf eine Person laut ihren Abschlüssen als Nächstes belegen? | Student A: ALGEBRA, DB_MODELING, PYTHON |
| A-003 | Welche Kurse fehlen einer Person noch für Kurs X? | Student A, ML: ALGEBRA, ANALYSIS, EDA, PYTHON |
| A-004 | Wo und bei wem kann eine Person Kurs X im Semester Y besuchen? | Student A, PYTHON, Frühlingssemester 2027: Brugg-Windisch bei T. Brunner |
| A-005 | Welche Kurse unterrichtet eine Lehrperson im Semester Y? | M. Frei, Frühlingssemester 2027: DB_MODELING und NOSQL in Brugg-Windisch, DB_MODELING und SQL in Olten |

| Kurs | Titel | Stunden | Voraussetzungen |
|---|---|---:|---|
| `BASICS` | Grundlagen Data Science | 4 | keine |
| `PYTHON` | Python-Grundlagen | 8 | BASICS |
| `SQL` | SQL-Grundlagen | 8 | BASICS |
| `ALGEBRA` | Lineare Algebra | 6 | BASICS |
| `ANALYSIS` | Analysis | 6 | ALGEBRA |
| `DB_MODELING` | Datenbankmodellierung | 6 | SQL |
| `NOSQL` | NoSQL-Datenbanken | 8 | DB_MODELING, SQL |
| `EDA` | Explorative Datenanalyse | 6 | PYTHON, SQL |
| `VISUALISATION` | Datenvisualisierung | 6 | EDA |
| `ML` | Machine Learning | 10 | EDA, PYTHON, ALGEBRA, ANALYSIS |

| Person | Studienform | Abgeschlossen |
|---|---|---|
| Student A | Vollzeit | BASICS, SQL |
| Student B | Teilzeit | BASICS, PYTHON, ALGEBRA |
| Student C | Vollzeit | BASICS |

**Regeln**
- **UND-Bedingung:** Alle Voraussetzungen eines Kurses gelten gemeinsam
- **Azyklisch:** Kein Kurs setzt sich direkt oder über mehrere Stufen selbst voraus
- **Abschluss:** Ein Kurs ist abgeschlossen oder nicht besucht, höchstens ein Abschluss pro Person und Kurs
- **Belegen:** erlaubt, wenn der Kurs nicht abgeschlossen ist und alle Voraussetzungen über alle Stufen abgeschlossen sind
- **Keine Doppelzählung:** Ein Vorkurs zählt einmal, auch über mehrere Wege

## **2) Modelle**

![Konzeptionelles Modell](../le2-sql/model/conceptual.png)

- **Konzeptionell:** 6 Entitäten in Chen-Notation. Ein Kurs wird mehrmals durchgeführt, jede Durchführung gehört zu einem Semester, einem Standort und einer Lehrperson
- **Beziehungen:** Personen schliessen Durchführungen ab (N:N mit Abschlussdatum), Kurse setzen Kurse voraus (N:N-Selbstbeziehung)

![Relationales Modell](../le2-sql/model/relational.png)

- **Relational:** 8 Tabellen. Die 1:N-Beziehungen sind Fremdschlüssel in `course_run`, die beiden N:N-Beziehungen eigene Tabellen
- **`completion`:** Primärschlüssel `(learner_id, course_id)` und Fremdschlüssel `(run_id, course_id)` erzwingen einen Abschluss pro Kurs mit passender Durchführung

![Graphmodell](../le3-nosql/model/graph.png)

- **Neo4j:** 6 Knotentypen, Fremdschlüssel und Zuordnungstabellen werden zu Kanten
- **`COMPLETED`:** abgeleitete Kante von der Person zum abgeschlossenen Kurs, damit A-002 bis A-004 nicht über die Durchführung gehen müssen
