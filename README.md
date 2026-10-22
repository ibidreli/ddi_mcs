# **DDI – Mini-Challenge 3**

Lernpfadplanung mit PostgreSQL (LE2) und Neo4j (LE3) im Vergleich. Der Bericht ist `docs/MC3_Bericht_Pulver_Urech.docx`.

| Ordner oder Datei | Inhalt |
|---|---|
| `le2-sql/` | PostgreSQL, siehe `le2-sql/README.md` |
| `le3-nosql/` | Neo4j, siehe `le3-nosql/README.md` |
| `src/` | Export, Import, Abfragen beider Datenbanken, Messung, K4 |
| `tests/` | `pytest`: Generator, Dateiimport, K1 Korrektheit |
| `comparison/` | Messung und Auswertung, siehe `comparison/README.md` |
| `data/seed.json` | Export des Beispielbestands `synthetic-v2` |
| `docs/` | Bericht als Word-Dokument, Zusammenfassung in `summary.md` |

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
