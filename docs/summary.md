# **Zusammenfassung MC3**

Kurzfassung der Aufgabenstellung und der Modelle aus dem Bericht `MC3_Bericht_Pulver_Urech.docx`.

## **1) Aufgabenstellung**

Ein Weiterbildungsanbieter will Lernenden zeigen, welche Kurse sie als Nächstes besuchen können, was ihnen für ein Ziel fehlt und wann und wo die passenden Kurse stattfinden. Kurse setzen andere Kurse voraus, oft über mehrere Stufen. Dieselbe Problemstellung wird in PostgreSQL und Neo4j umgesetzt und verglichen.

| ID | Frage | Beispiel |
|---|---|---|
| A-001 | Welche Kurse sind als Voraussetzung eines Kurses eingetragen? | ML: ALGEBRA, ANALYSIS, EDA, PYTHON |
| A-002 | Welche Kurse muss man insgesamt abschliessen, bevor man einen Kurs beginnen kann? | ML: zusätzlich BASICS und SQL, also 6 Kurse |
| A-003 | Welche Kurse kann eine Person als Nächstes beginnen? | Student A: ALGEBRA, DB_MODELING, PYTHON |
| A-004 | Welche Kurse fehlen einer Person noch für einen Zielkurs, und wie viele Stunden sind das? | Student A und ML: 4 Kurse, 26 Stunden |
| A-005 | Wann, wo und bei wem kann eine Person diese Kurse besuchen? | Student A, FS27, Brugg-Windisch: ALGEBRA, DB_MODELING, PYTHON |

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

| Person | Studienform | Abgeschlossen | Läuft gerade |
|---|---|---|---|
| Student A | Vollzeit | BASICS, SQL | – |
| Student B | Teilzeit | BASICS, PYTHON, ALGEBRA | – |
| Student C | Vollzeit | BASICS | PYTHON |

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
