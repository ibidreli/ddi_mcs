# **DDI – Mini-Challenge 3**

Lernpfadplanung mit PostgreSQL (LE2) und Neo4j (LE3) im Vergleich. Der Bericht ist [docs/mc3-report.md](docs/mc3-report.md).

| Ordner oder Datei | Inhalt |
|---|---|
| `le2-sql/` | `schema.sql`, `seed.sql`, `queries.sql`, `tests.sql` und Modelle |
| `le3-nosql/` | `schema.cypher`, `import.cypher`, `queries.cypher` und Graphmodell |
| `src/` | Export, Import, Abfragen beider Datenbanken, Messung, K4 |
| `tests/` | `pytest`: Generator, Dateiimport, K1 Korrektheit |
| `comparison/` | Notebook zur Auswertung, Resultate in `results/` |
| `data/seed.json` | Export des Beispielbestands `synthetic-v2` |
| `docs/` | Bericht, Auftrag, Review-Meetings |

## **Starten**

Voraussetzungen sind Docker Desktop und Python ab 3.10. Im Projektordner:

```powershell
.\start.ps1
```

Der Start baut beide Datenbanken auf, legt `.venv` an, exportiert `data/seed.json`, lädt Neo4j, führt `tests.sql` und `pytest` aus und zeigt A-001 bis A-005 in beiden Datenbanken.

| Aktion | Wirkung |
|---|---|
| `.\start.ps1 -Aktion Pruefen` | `tests.sql` und `pytest` erneut ausführen |
| `.\start.ps1 -Aktion Abfragen` | `queries.sql` und Vergleich beider Datenbanken |
| `.\start.ps1 -Aktion Messen` | Messung K1 bis K3, schreibt `comparison/results/benchmark.csv` |
| `.\start.ps1 -Aktion Shell` | `psql` in der Datenbank `lernpfad` |
| `.\start.ps1 -Aktion Cypher` | `cypher-shell` in Neo4j |
| `.\start.ps1 -Aktion Stop` | Container stoppen, Daten bleiben erhalten |

Neo4j Browser: <http://localhost:7474> mit `neo4j` / `ddi_lokal_demo`. PostgreSQL ist für DBeaver oder pgAdmin unter `localhost:55432` erreichbar (`ddi` / `ddi_lokal_demo`).

## **Auswertung**

Nach der Messung das Notebook erzeugen und in VS Code ausführen:

```powershell
.venv\Scripts\jupytext --sync comparison\benchmark.pct.py
```

K4 (Abfrageumfang) ohne Datenbank:

```powershell
.venv\Scripts\python -m src.k4
```
