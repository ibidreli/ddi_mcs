# **Vergleich**

Messung von A-001 und A-003 in PostgreSQL und Neo4j mit erzeugten Datensätzen (K1 bis K3).

| Datei | Inhalt |
|---|---|
| `benchmark.pct.py` | Notebook zur Auswertung, erzeugt Tabelle und Diagramme |
| `results/benchmark.csv` | Einzelmessungen, je 20 Läufe pro Szenario, Abfrage und Datenbank |
| `results/environment.json` | Versionen und Messparameter |
| `results/benchmark-summary.md` | Medianwerte pro Szenario |
| `results/*.png` | Diagramme K3 und Faktor |

Messung mit `.\start.ps1 -Aktion Messen`, K4 mit `.venv\Scripts\python -m src.k4`.
